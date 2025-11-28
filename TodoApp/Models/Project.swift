import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var title: String
    var color: String
    var createdDate: Date
    var order: Int?  // FIXED: Made optional to support migration

    // Event scheduling
    var startDate: Date?  // When build-up begins
    var dueDate: Date?    // When event goes live / tear-down completes
    var estimatedHours: Double?  // Total budget for the event
    var status: ProjectStatus  // Planning, In Progress, Completed

    @Relationship(deleteRule: .cascade, inverse: \Task.project)
    var tasks: [Task]?
    
    init(
        id: UUID = UUID(),
        title: String,
        color: String,
        createdDate: Date = Date(),
        order: Int? = nil,  // FIXED: Optional with nil default
        startDate: Date? = nil,
        dueDate: Date? = nil,
        estimatedHours: Double? = nil,
        status: ProjectStatus = .inProgress
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.createdDate = createdDate
        self.order = order ?? 0  // FIXED: Provide 0 if nil
        self.startDate = startDate
        self.dueDate = dueDate
        self.estimatedHours = estimatedHours
        self.status = status
        self.tasks = nil
    }
    
    // MARK: - Computed Properties
    
    @Transient
    var orderValue: Int {
        order ?? 0  // FIXED: Computed property for safe access
    }
    
    @Transient
    var incompleteTasks: Int {
        tasks?.filter { !$0.isCompleted }.count ?? 0
    }
    
    @Transient
    var completedTasks: Int {
        tasks?.filter { $0.isCompleted }.count ?? 0
    }

    @Transient
    var blockedTasks: Int {
        tasks?.filter { !$0.isCompleted && !$0.isArchived && $0.status == .blocked }.count ?? 0
    }

    @Transient
    var overdueTasks: Int {
        let now = Date()
        return tasks?.filter { task in
            !task.isCompleted && !task.isArchived && task.endDate != nil && task.endDate! < now
        }.count ?? 0
    }

    @Transient
    var tasksWithMissingEstimates: Int {
        // Only count missing estimates for non-planning projects and medium/high priority tasks
        guard status != .planning else { return 0 }
        return tasks?.filter { task in
            !task.isCompleted && !task.isArchived && task.effectiveEstimate == nil && task.priority < 3
        }.count ?? 0
    }

    @Transient
    var totalTimeSpent: Int {
        tasks?.reduce(0) { $0 + $1.totalTimeSpent } ?? 0
    }

    @Transient
    var totalTimeSpentHours: Double {
        Double(totalTimeSpent) / 3600.0
    }

    /// Sum of all task estimates converted to hours (what you think you need)
    @Transient
    var taskPlannedHours: Double? {
        guard let tasks = tasks, !tasks.isEmpty else { return nil }

        let totalSeconds = tasks.reduce(0) { sum, task in
            sum + (task.effectiveEstimate ?? 0)
        }

        return totalSeconds > 0 ? Double(totalSeconds) / 3600.0 : nil
    }

    /// Variance between planned task estimates and budget (positive = over budget)
    @Transient
    var planningVariance: Double? {
        guard let budget = estimatedHours, let planned = taskPlannedHours else { return nil }
        return planned - budget
    }

    /// Whether task planning exceeds the budget
    @Transient
    var isOverPlanned: Bool {
        guard let variance = planningVariance else { return false }
        return variance > 0
    }

    /// Progress against budget based on actual time spent
    @Transient
    var timeProgress: Double? {
        guard let estimate = estimatedHours, estimate > 0 else { return nil }
        return totalTimeSpentHours / estimate
    }

    /// Progress of task planning against budget
    @Transient
    var planningProgress: Double? {
        guard let budget = estimatedHours, budget > 0, let planned = taskPlannedHours else { return nil }
        return planned / budget
    }

    @Transient
    var healthStatus: ProjectHealthStatus {
        let actualProgress = timeProgress ?? 0
        let taskCompletion = tasks?.isEmpty == false ?
            Double(completedTasks) / Double(tasks!.count) : 0
        let planProgress = planningProgress ?? 0

        // Critical: Actual over budget OR Tasks over budget by 20%+ OR way behind schedule OR has overdue tasks
        if actualProgress > 1.0 ||
           planProgress > 1.2 ||
           (actualProgress > 0.9 && taskCompletion < 0.5) ||
           overdueTasks > 0 {
            return .critical
        }

        // Warning: Nearing budget OR Tasks over budget by 10%+ OR slightly behind OR has blocked tasks OR missing estimates OR date conflicts
        if actualProgress > 0.85 ||
           planProgress > 1.1 ||
           (actualProgress > 0.7 && taskCompletion < 0.4) ||
           blockedTasks > 0 ||
           tasksWithMissingEstimates > 0 ||
           tasksWithDateConflicts > 0 {
            return .warning
        }

        // On track
        return .onTrack
    }

    @Transient
    var isActive: Bool {
        status == .inProgress && incompleteTasks > 0
    }

    @Transient
    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }

    // MARK: - Date Conflict Detection (Phase 3: Hybrid Date Constraints)

    /// Count of tasks with date conflicts (outside project timeline)
    @Transient
    var tasksWithDateConflicts: Int {
        tasks?.filter { !$0.isCompleted && !$0.isArchived && $0.hasDateConflicts }.count ?? 0
    }
}

// MARK: - Project Status

enum ProjectStatus: String, Codable, CaseIterable {
    case planning = "Planning"
    case inProgress = "In Progress"
    case completed = "Completed"
    case onHold = "On Hold"
}

// MARK: - Project Health Status

enum ProjectHealthStatus {
    case onTrack
    case warning
    case critical

    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .onTrack: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}
