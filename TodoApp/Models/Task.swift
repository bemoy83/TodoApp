import Foundation
import SwiftData
import SwiftUI

// MARK: - Task Status Enum

enum TaskStatus: String, Codable, Sendable {
    case blocked = "blocked"
    case ready = "ready"
    case inProgress = "inProgress"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .blocked: return "Blocked"
        case .ready: return "Ready"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .blocked: return "exclamationmark.circle.fill"
        case .ready: return "circle"
        case .inProgress: return "circle.lefthalf.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .blocked: return "red"
        case .ready: return "gray"
        case .inProgress: return "blue"
        case .completed: return "green"
        }
    }
}

// MARK: - Time Estimate Status Enum

enum TimeEstimateStatus: String, Codable, Sendable {
    case onTrack = "onTrack"       // < 75% time used
    case warning = "warning"        // 75-100% time used
    case over = "over"             // > 100% time used
    
    var color: Color {
        switch self {
        case .onTrack: return DesignSystem.Colors.success
        case .warning: return DesignSystem.Colors.warning
        case .over: return DesignSystem.Colors.error
        }
    }
    
    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .over: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Task Model

@Model
final class Task {
    var id: UUID
    var title: String
    var priority: Int
    var dueDate: Date?
    var completedDate: Date?
    var createdDate: Date
    var order: Int?
    var notes: String? // User notes for the task

    // Time estimation (stored in seconds for accuracy)
    var estimatedSeconds: Int? // nil = no estimate set
    var hasCustomEstimate: Bool = false // true = user overrode auto-sum
    
    // Relationship to project
    @Relationship(deleteRule: .nullify)
    var project: Project?
    
    // Parent-child subtask relationship
    @Relationship(deleteRule: .nullify)
    var parentTask: Task?
    
    @Relationship(deleteRule: .cascade)
    var subtasks: [Task]?
    
    // Time tracking relationship
    @Relationship(deleteRule: .cascade)
    var timeEntries: [TimeEntry]?
    
    // Task dependency relationships (many-to-many)
    @Relationship(deleteRule: .nullify)
    var dependsOn: [Task]?
    
    @Relationship(deleteRule: .nullify)
    var blockedBy: [Task]?
    
    init(
        id: UUID = UUID(),
        title: String,
        priority: Int = 2,
        dueDate: Date? = nil,
        completedDate: Date? = nil,
        createdDate: Date = Date(),
        parentTask: Task? = nil,
        project: Project? = nil,
        order: Int? = nil,
        notes: String? = nil,
        estimatedSeconds: Int? = nil,
        hasCustomEstimate: Bool = false
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.completedDate = completedDate
        self.createdDate = createdDate
        self.parentTask = parentTask
        self.project = project
        self.order = order ?? 0
        self.notes = notes
        self.estimatedSeconds = estimatedSeconds
        self.hasCustomEstimate = hasCustomEstimate
        self.subtasks = nil
        self.timeEntries = nil
        self.dependsOn = nil
        self.blockedBy = nil
    }
    
    // MARK: - Computed Properties
    
    @Transient
    var orderValue: Int {
        order ?? 0
    }
    
    @Transient
    var isCompleted: Bool {
        completedDate != nil
    }
    
    @Transient
    var hasActiveTimer: Bool {
        guard let entries = timeEntries else { return false }
        return entries.contains { $0.endTime == nil }
    }
    
    @Transient
    var directTimeSpent: Int {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { total, entry in
            guard let end = entry.endTime else { return total }
            let seconds = Int(end.timeIntervalSince(entry.startTime))
            return total + seconds
        }
    }
    
    @Transient
    var totalTimeSpent: Int {
        calculateTotalTime()
    }
    
    @Transient
    var status: TaskStatus {
        // Completed takes highest priority
        if isCompleted {
            return .completed
        }
        
        // Blocked if has incomplete dependencies (own or subtasks')
        if hasIncompleteDependencies {
            return .blocked
        }
        
        // In Progress if has time spent or active timer
        if directTimeSpent > 0 || hasActiveTimer {
            return .inProgress
        }
        
        // Default to Ready
        return .ready
    }
    
    @Transient
    var canComplete: Bool {
        // Can only complete if ready or in progress (not blocked)
        status == .ready || status == .inProgress
    }
    
    @Transient
    var hasIncompleteDependencies: Bool {
        // Check own dependencies
        if let deps = dependsOn, !deps.isEmpty {
            if deps.contains(where: { !$0.isCompleted }) {
                return true
            }
        }
        
        // Check subtask dependencies (recursive)
        if let subtasks = subtasks {
            for subtask in subtasks {
                if subtask.hasIncompleteDependencies {
                    return true
                }
            }
        }
        
        return false
    }
    
    @Transient
    var blockingDependencies: [Task] {
        guard let deps = dependsOn else { return [] }
        return deps.filter { !$0.isCompleted }
    }
    
    @Transient
    var blockingSubtaskDependencies: [(subtask: Task, dependency: Task)] {
        guard let subtasks = subtasks else { return [] }
        
        var blocks: [(subtask: Task, dependency: Task)] = []
        
        for subtask in subtasks {
            if let deps = subtask.dependsOn {
                for dep in deps where !dep.isCompleted {
                    blocks.append((subtask, dep))
                }
            }
            // Recursively check nested subtasks
            let nestedBlocks = subtask.blockingSubtaskDependencies
            blocks.append(contentsOf: nestedBlocks)
        }
        
        return blocks
    }
    
    // MARK: - Subtask Counts
    
    /// Number of *direct* child subtasks (does not include grandchildren).
    @Transient
    var subtaskCount: Int {
        subtasks?.count ?? 0
    }
    
    /// Number of *direct* child subtasks that are completed.
    @Transient
    var completedDirectSubtaskCount: Int {
        guard let subtasks else { return 0 }
        return subtasks.filter { $0.isCompleted }.count
    }
    
    /// Number of *direct* child subtasks that are not completed.
    @Transient
    var incompleteDirectSubtaskCount: Int {
        max(0, subtaskCount - completedDirectSubtaskCount)
    }
    
    /// Total number of subtasks including all descendants (children, grandchildren, …).
    @Transient
    var recursiveSubtaskCount: Int {
        guard let subtasks else { return 0 }
        return subtasks.reduce(subtasks.count) { total, child in
            total + child.recursiveSubtaskCount
        }
    }
    
    /// Total number of completed subtasks including all descendants.
    @Transient
    var completedRecursiveSubtaskCount: Int {
        guard let subtasks else { return 0 }
        return subtasks.reduce(0) { total, child in
            let childCompleted = child.isCompleted ? 1 : 0
            return total + childCompleted + child.completedRecursiveSubtaskCount
        }
    }
    
    /// Total number of incomplete subtasks including all descendants.
    @Transient
    var incompleteRecursiveSubtaskCount: Int {
        max(0, recursiveSubtaskCount - completedRecursiveSubtaskCount)
    }
    
    // MARK: - Time Estimate Properties
    
    /// Calculated estimate from subtasks (nil if no subtasks or no subtask estimates)
    @Transient
    var calculatedEstimateFromSubtasks: Int? {
        guard let subtasks = subtasks, !subtasks.isEmpty else { return nil }
        
        let total = subtasks.reduce(0) { sum, subtask in
            // Use subtask's effective estimate (which may itself be calculated)
            sum + (subtask.effectiveEstimate ?? 0)
        }
        
        return total > 0 ? total : nil
    }
    
    /// The estimate to use: custom if set, otherwise calculated from subtasks
    @Transient
    var effectiveEstimate: Int? {
        if hasCustomEstimate {
            return estimatedSeconds
        } else {
            return calculatedEstimateFromSubtasks ?? estimatedSeconds
        }
    }
    
    /// Whether this task is using a calculated estimate (not custom)
    @Transient
    var isUsingCalculatedEstimate: Bool {
        !hasCustomEstimate && calculatedEstimateFromSubtasks != nil
    }
    
    /// Progress toward estimate (0.0 - 1.0+), nil if no estimate
    @Transient
    var timeProgress: Double? {
        guard let estimate = effectiveEstimate, estimate > 0 else { return nil }
        return Double(totalTimeSpent) / Double(estimate)
    }
    
    /// Whether actual time exceeds estimate
    @Transient
    var isOverEstimate: Bool {
        guard let progress = timeProgress else { return false }
        return progress > 1.0
    }
    
    /// Remaining estimated time in minutes (negative if over)
    @Transient
    var timeRemaining: Int? {
        guard let estimate = effectiveEstimate else { return nil }
        return estimate - totalTimeSpent
    }
    
    /// Time estimate status for UI display
    @Transient
    var estimateStatus: TimeEstimateStatus? {
        guard let progress = timeProgress else { return nil }
        
        if progress >= 1.0 {
            return .over
        } else if progress >= 0.75 {
            return .warning
        } else {
            return .onTrack
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateTotalTime() -> Int {
        var total = directTimeSpent
        
        // Add time from all subtasks recursively
        if let subtasks = subtasks {
            for subtask in subtasks {
                total += subtask.totalTimeSpent
            }
        }
        
        return total
    }
    
    // MARK: - Task Actions
    
    func completeTask() {
        completedDate = Date.now
        
        // Stop any active timers
        guard let entries = timeEntries else { return }
        for entry in entries where entry.endTime == nil {
            entry.endTime = Date.now
        }
    }
    
    func startTimer() {
        let newEntry = TimeEntry(
            startTime: Date.now,
            endTime: nil,
            task: self
        )
        
        if timeEntries == nil {
            timeEntries = []
        }
        timeEntries?.append(newEntry)
    }
    
    func stopTimer() {
        guard let entries = timeEntries else { return }
        
        for entry in entries where entry.endTime == nil {
            entry.endTime = Date.now
        }
    }
}
