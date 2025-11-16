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
    var totalTimeSpent: Int {
        tasks?.reduce(0) { $0 + $1.totalTimeSpent } ?? 0
    }

    @Transient
    var totalTimeSpentHours: Double {
        Double(totalTimeSpent) / 3600.0
    }

    @Transient
    var timeProgress: Double? {
        guard let estimate = estimatedHours, estimate > 0 else { return nil }
        return totalTimeSpentHours / estimate
    }

    @Transient
    var healthStatus: ProjectHealthStatus {
        let progress = timeProgress ?? 0
        let taskCompletion = tasks?.isEmpty == false ?
            Double(completedTasks) / Double(tasks!.count) : 0

        // Over budget or way behind schedule
        if progress > 1.0 || (progress > 0.9 && taskCompletion < 0.5) {
            return .critical
        }

        // Nearing budget or slightly behind
        if progress > 0.85 || (progress > 0.7 && taskCompletion < 0.4) {
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
