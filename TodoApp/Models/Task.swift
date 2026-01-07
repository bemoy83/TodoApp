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

    // MARK: - Thresholds

    /// Progress threshold for warning status (75%)
    static let warningThreshold: Double = 0.75
    /// Progress threshold for over status (100%)
    static let overThreshold: Double = 1.0

    /// Derive status from progress value (0.0 to 1.0+)
    static func from(progress: Double) -> TimeEstimateStatus {
        if progress >= overThreshold {
            return .over
        } else if progress >= warningThreshold {
            return .warning
        } else {
            return .onTrack
        }
    }

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

// MARK: - Productivity Pace Status Enum

enum ProductivityPaceStatus: Sendable {
    case ahead(percentage: Int)   // Working faster than needed
    case onPace                    // Within 10% of required rate
    case behind(percentage: Int)  // Working slower than needed

    var color: Color {
        switch self {
        case .ahead: return DesignSystem.Colors.success
        case .onPace: return DesignSystem.Colors.info
        case .behind: return DesignSystem.Colors.warning
        }
    }

    var icon: String {
        switch self {
        case .ahead: return "hare.fill"
        case .onPace: return "checkmark.circle.fill"
        case .behind: return "tortoise.fill"
        }
    }

    var label: String {
        switch self {
        case .ahead(let pct): return "\(pct)% ahead"
        case .onPace: return "On pace"
        case .behind(let pct): return "\(pct)% behind"
        }
    }
}

// MARK: - Unit Type Enum

enum UnitType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case squareMeters = "m²"
    case meters = "m"
    case pieces = "pcs"
    case kilograms = "kg"
    case liters = "L"

    var displayName: String {
        rawValue
    }

    var isQuantifiable: Bool {
        self != .none
    }

    var icon: String {
        switch self {
        case .none: return "minus.circle"
        case .squareMeters: return "square.grid.2x2"
        case .meters: return "ruler"
        case .pieces: return "cube.box"
        case .kilograms: return "scalemass"
        case .liters: return "drop"
        }
    }

    /// Default productivity rate (units per person-hour) as fallback when no historical data available
    var defaultProductivityRate: Double? {
        switch self {
        case .none: return nil
        case .squareMeters: return 10.0  // 10 m²/person-hr (e.g., carpet installation, painting)
        case .meters: return 5.0         // 5 m/person-hr (e.g., wall setup, piping)
        case .pieces: return 2.0         // 2 pcs/person-hr (e.g., furniture assembly)
        case .kilograms: return 50.0     // 50 kg/person-hr (e.g., material handling)
        case .liters: return 100.0       // 100 L/person-hr (e.g., liquid handling)
        }
    }
}

// MARK: - Task Model

@Model
final class Task: TitledItem {
    var id: UUID
    var title: String
    var priority: Int
    var dueDate: Date?
    var startDate: Date?  // When work is scheduled to start
    var endDate: Date?    // When work is scheduled to end
    var completedDate: Date?
    var createdDate: Date
    var order: Int?
    var notes: String? // User notes for the task

    // Time estimation (stored in seconds for accuracy)
    var estimatedSeconds: Int? // nil = no estimate set
    var hasCustomEstimate: Bool = false // true = user overrode auto-sum

    // Personnel planning
    var expectedPersonnelCount: Int? // Expected crew size for this task (nil = not set, defaults to 1 in calculations)

    // Effort-based estimation (for resource planning)
    var effortHours: Double? // Total work effort in person-hours (nil = not using effort-based estimation)

    // Productivity tracking (Quantified Tasks)
    var expectedQuantity: Double? // Expected/target quantity for planning (e.g., 45.5 square meters to complete)
    var quantity: Double? // Amount of work completed (e.g., 45.5 square meters, 120 pieces)
    var unit: UnitType = UnitType.none // Unit of measurement for quantity
    var taskType: String? // Task type/category for grouping productivity (e.g., "Carpet Installation", "Painting")
    var customProductivityRate: Double? // User's custom productivity rate (units per person-hour), overrides template/historical defaults

    // Archive status
    var isArchived: Bool = false // true = task is archived (hidden from main views)
    var archivedDate: Date? = nil // When task was archived

    // Relationship to project
    @Relationship(deleteRule: .nullify)
    var project: Project?

    // Relationship to template (for accurate productivity tracking)
    @Relationship(deleteRule: .nullify)
    var taskTemplate: TaskTemplate?
    
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

    // Tags relationship (many-to-many)
    @Relationship(deleteRule: .nullify)
    var tags: [Tag]?
    
    init(
        id: UUID = UUID(),
        title: String,
        priority: Int = 2,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedDate: Date? = nil,
        createdDate: Date = Date(),
        parentTask: Task? = nil,
        project: Project? = nil,
        order: Int? = nil,
        notes: String? = nil,
        estimatedSeconds: Int? = nil,
        hasCustomEstimate: Bool = false,
        expectedPersonnelCount: Int? = nil,
        effortHours: Double? = nil,
        expectedQuantity: Double? = nil,
        quantity: Double? = nil,
        unit: UnitType = UnitType.none,
        taskType: String? = nil,
        taskTemplate: TaskTemplate? = nil
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.startDate = startDate
        self.endDate = endDate
        self.completedDate = completedDate
        self.createdDate = createdDate
        self.parentTask = parentTask
        self.project = project
        self.order = order ?? 0
        self.notes = notes
        self.estimatedSeconds = estimatedSeconds
        self.hasCustomEstimate = hasCustomEstimate
        self.expectedPersonnelCount = expectedPersonnelCount
        self.effortHours = effortHours
        self.expectedQuantity = expectedQuantity
        self.quantity = quantity
        self.unit = unit
        self.taskType = taskType
        self.taskTemplate = taskTemplate
        self.subtasks = nil
        self.timeEntries = nil
        self.dependsOn = nil
        self.blockedBy = nil
        self.tags = nil
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

    // MARK: - Unit Information (Backward Compatible)

    /// Unit display name with automatic fallback
    /// Prioritizes template's custom unit, falls back to legacy UnitType
    @Transient
    var unitDisplayName: String {
        taskTemplate?.unitDisplayName ?? unit.displayName
    }

    /// Unit icon with automatic fallback
    /// Prioritizes template's custom unit, falls back to legacy UnitType
    @Transient
    var unitIcon: String {
        taskTemplate?.unitIcon ?? unit.icon
    }

    /// Whether the unit is quantifiable with automatic fallback
    /// Prioritizes template's custom unit, falls back to legacy UnitType
    @Transient
    var isUnitQuantifiable: Bool {
        taskTemplate?.isQuantifiable ?? unit.isQuantifiable
    }

    // MARK: - Working Window (Start/End Dates)

    /// The working window for crew planning: when work actually happens
    /// Falls back intelligently: endDate/dueDate for end, startDate/NOW for start
    @Transient
    var workingWindow: (start: Date, end: Date)? {
        // Need an end date (either endDate or dueDate)
        guard let end = endDate ?? dueDate else { return nil }

        // Start date defaults to NOW if not explicitly set
        let start = startDate ?? Date()

        // Validate: start must be before end
        guard start < end else { return nil }

        return (start, end)
    }

    /// Effective deadline for crew planning (uses endDate if available, falls back to dueDate)
    @Transient
    var effectiveDeadline: Date? {
        endDate ?? dueDate
    }

    /// Available work hours for this task (considering working window)
    /// Returns nil if no deadline/endDate set
    @Transient
    var availableWorkHours: Double? {
        guard let window = workingWindow else { return nil }
        return WorkHoursCalculator.calculateAvailableHours(from: window.start, to: window.end)
    }

    @Transient
    var directTimeSpent: Int {
        guard let entries = timeEntries else { return 0 }
        return entries.reduce(0) { total, entry in
            guard let end = entry.endTime else { return total }
            let seconds = Int(TimeEntryManager.calculateDuration(start: entry.startTime, end: end))
            return total + seconds
        }
    }
    
    @Transient
    var totalTimeSpent: Int {
        calculateTotalTime()
    }

    // MARK: - Time Entry Helpers (for Execution Tab)

    /// Active timer entry (for quick stop/edit access)
    @Transient
    var activeTimerEntry: TimeEntry? {
        guard let entries = timeEntries else { return nil }
        return entries.first { $0.endTime == nil }
    }

    /// Today's completed time entries
    @Transient
    var todayEntries: [TimeEntry] {
        guard let entries = timeEntries else { return [] }
        let today = Date()
        return entries.filter { entry in
            guard let endTime = entry.endTime else { return false }
            return Calendar.current.isDate(endTime, inSameDayAs: today)
        }
    }

    /// Today's tracked hours (completed entries only)
    @Transient
    var todayHours: Double {
        let totalSeconds = todayEntries.reduce(0.0) { total, entry in
            return total + TimeEntryManager.calculateDuration(for: entry)
        }
        return totalSeconds / 3600.0
    }

    /// Today's person-hours (completed entries only)
    @Transient
    var todayPersonHours: Double {
        todayEntries.reduce(0.0) { total, entry in
            return total + TimeEntryManager.calculatePersonHours(for: entry)
        }
    }

    @Transient
    var hasCompletedSubtasks: Bool {
        guard let subtasks = subtasks, !subtasks.isEmpty else { return false }
        return subtasks.contains { $0.isCompleted }
    }

    @Transient
    var hasInProgressSubtasks: Bool {
        guard let subtasks = subtasks, !subtasks.isEmpty else { return false }
        return subtasks.contains { $0.status == .inProgress }
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

        // In Progress if:
        // - Has time spent or active timer
        // - Has at least one completed subtask (shows progress on parent)
        // - Has at least one in-progress subtask (propagates status up)
        if directTimeSpent > 0 || hasActiveTimer || hasCompletedSubtasks || hasInProgressSubtasks {
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

    // MARK: - Blocking Analysis (for Execution Tab)

    /// Human-readable blocking reasons for planning/execution visibility
    @Transient
    var blockingReasons: [String] {
        var reasons: [String] = []

        // Direct dependencies
        for dep in blockingDependencies {
            reasons.append("Waiting on: \(dep.title)")
        }

        // Subtask dependencies
        for (subtask, dep) in blockingSubtaskDependencies {
            reasons.append("Subtask '\(subtask.title)' blocked by: \(dep.title)")
        }

        return reasons
    }

    /// Whether this task can start work (not blocked, meets basic requirements)
    @Transient
    var canStartWork: Bool {
        // Can't start if blocked
        guard status != .blocked else { return false }

        // Can't start if already completed
        guard !isCompleted else { return false }

        // All clear to start
        return true
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
        return TimeEstimateStatus.from(progress: progress)
    }

    /// Estimate accuracy: ratio of estimated to actual time (1.0 = perfect, 0.8 = took 25% longer)
    /// Only available for completed tasks with estimates
    @Transient
    var estimateAccuracy: Double? {
        guard isCompleted else { return nil }
        guard let estimate = effectiveEstimate, estimate > 0 else { return nil }
        guard totalTimeSpent > 0 else { return nil }

        return Double(estimate) / Double(totalTimeSpent)
    }

    // MARK: - Productivity Metrics

    /// Total tracked time in hours (includes time from all time entries)
    @Transient
    var totalTrackedTimeHours: Double? {
        guard let entries = timeEntries, !entries.isEmpty else { return nil }
        let completedEntries = entries.filter { $0.endTime != nil }
        guard !completedEntries.isEmpty else { return nil }

        let totalSeconds = completedEntries.reduce(0.0) { sum, entry in
            return sum + TimeEntryManager.calculateDuration(for: entry)
        }

        return totalSeconds / 3600.0 // Convert to hours
    }

    /// Total person-hours tracked (time × personnel count for each entry)
    @Transient
    var totalPersonHours: Double? {
        guard let entries = timeEntries, !entries.isEmpty else { return nil }
        let completedEntries = entries.filter { $0.endTime != nil }
        guard !completedEntries.isEmpty else { return nil }

        return completedEntries.reduce(0.0) { sum, entry in
            return sum + TimeEntryManager.calculatePersonHours(for: entry)
        }
    }

    /// Productivity metric: units completed per person-hour worked
    /// Returns nil if task is not quantifiable, has no quantity, or has no tracked time
    @Transient
    var unitsPerHour: Double? {
        guard unit.isQuantifiable,
              let quantity = quantity,
              quantity > 0,
              let personHours = totalPersonHours,
              personHours > 0 else { return nil }

        return quantity / personHours
    }

    /// Whether this task has productivity data available
    @Transient
    var hasProductivityData: Bool {
        unitsPerHour != nil
    }

    /// Live productivity rate - works for in-progress tasks (not just completed)
    /// Returns current rate based on completed quantity and tracked person-hours
    @Transient
    var liveProductivityRate: Double? {
        guard unit.isQuantifiable,
              let qty = quantity, qty > 0,
              let personHours = totalPersonHours, personHours > 0 else {
            return nil
        }
        return qty / personHours
    }

    /// Required productivity rate to complete remaining work within time budget
    /// Calculates: remainingQuantity / remainingPersonHours
    @Transient
    var requiredProductivityRate: Double? {
        guard unit.isQuantifiable,
              let expected = expectedQuantity, expected > 0,
              let estimate = effectiveEstimate, estimate > 0 else {
            return nil
        }

        let completed = quantity ?? 0
        let remaining = expected - completed
        guard remaining > 0 else { return nil } // Already complete

        // Calculate remaining time budget in person-hours
        let totalBudgetSeconds = Double(estimate)
        let usedSeconds = Double(totalTimeSpent)
        let remainingSeconds = totalBudgetSeconds - usedSeconds
        guard remainingSeconds > 0 else { return nil } // No time left

        // Convert to hours, factor in personnel
        let personnel = Double(expectedPersonnelCount ?? 1)
        let remainingPersonHours = (remainingSeconds / 3600.0) * personnel

        return remaining / remainingPersonHours
    }

    /// Productivity pace status comparing current rate to required rate
    @Transient
    var productivityPaceStatus: ProductivityPaceStatus? {
        guard let current = liveProductivityRate,
              let required = requiredProductivityRate else {
            return nil
        }

        let ratio = current / required
        if ratio >= 1.1 {
            return .ahead(percentage: Int((ratio - 1.0) * 100))
        } else if ratio >= 0.9 {
            return .onPace
        } else {
            return .behind(percentage: Int((1.0 - ratio) * 100))
        }
    }

    /// Whether live productivity insights are available
    @Transient
    var hasLiveProductivityInsights: Bool {
        liveProductivityRate != nil || requiredProductivityRate != nil
    }

    /// Expected productivity rate from custom setting or task template
    /// Priority: customProductivityRate > taskTemplate.defaultProductivityRate
    @Transient
    var expectedProductivityRate: Double? {
        if let custom = customProductivityRate, custom > 0 {
            return custom
        }
        return taskTemplate?.defaultProductivityRate
    }

    /// Minimum required productivity rate to complete task within estimate
    /// Calculates: expectedQuantity / (estimatedSeconds/3600 * personnel)
    @Transient
    var minimumRequiredProductivityRate: Double? {
        guard unit.isQuantifiable,
              let expected = expectedQuantity, expected > 0,
              let estimate = effectiveEstimate, estimate > 0 else {
            return nil
        }

        let personnel = Double(expectedPersonnelCount ?? 1)
        let totalPersonHours = (Double(estimate) / 3600.0) * personnel

        guard totalPersonHours > 0 else { return nil }
        return expected / totalPersonHours
    }

    /// Whether productivity section should be shown
    /// Shows when task has quantifiable unit (quantity tracking enabled)
    @Transient
    var shouldShowProductivity: Bool {
        unit.isQuantifiable
    }

    // MARK: - Quantity Progress Tracking

    /// Progress toward expected quantity (0.0 - 1.0+), nil if no expected quantity set
    @Transient
    var quantityProgress: Double? {
        guard let expected = expectedQuantity, expected > 0 else { return nil }
        let completed = quantity ?? 0
        return completed / expected
    }

    /// Remaining quantity to complete (negative if over), nil if no expected quantity
    @Transient
    var quantityRemaining: Double? {
        guard let expected = expectedQuantity else { return nil }
        let completed = quantity ?? 0
        return expected - completed
    }

    /// Whether quantity progress tracking is available
    @Transient
    var hasQuantityProgress: Bool {
        expectedQuantity != nil && expectedQuantity! > 0
    }

    // MARK: - Date Conflict Detection (Phase 2: Hybrid Date Constraints)

    /// Whether task start date is before project start date
    @Transient
    var startsBeforeProject: Bool {
        guard let project = project,
              let projectStart = project.startDate,
              let taskStart = startDate else { return false }
        return taskStart < projectStart
    }

    /// Whether task due date is after project due date
    @Transient
    var endsAfterProject: Bool {
        guard let project = project,
              let projectDue = project.dueDate,
              let taskDue = endDate else { return false }
        return taskDue > projectDue
    }

    /// Whether task start date is after project due date
    @Transient
    var startsAfterProject: Bool {
        guard let project = project,
              let projectDue = project.dueDate,
              let taskStart = startDate else { return false }
        return taskStart > projectDue
    }

    /// Whether task end date is before project start date
    @Transient
    var endsBeforeProject: Bool {
        guard let project = project,
              let projectStart = project.startDate,
              let taskEnd = endDate else { return false }
        return taskEnd < projectStart
    }

    /// Whether task has any date conflicts with its project
    @Transient
    var hasDateConflicts: Bool {
        startsBeforeProject || endsAfterProject || startsAfterProject || endsBeforeProject
    }

    /// Human-readable description of date conflicts (nil if no conflicts)
    @Transient
    var dateConflictMessage: String? {
        guard hasDateConflicts else { return nil }

        var messages: [String] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if startsBeforeProject {
            if let projectStart = project?.startDate, let taskStart = startDate {
                messages.append("starts before event (\(formatter.string(from: taskStart)) vs \(formatter.string(from: projectStart)))")
            }
        }

        if endsAfterProject {
            if let projectDue = project?.dueDate, let taskDue = endDate {
                messages.append("ends after event (\(formatter.string(from: taskDue)) vs \(formatter.string(from: projectDue)))")
            }
        }

        if startsAfterProject {
            if let projectDue = project?.dueDate, let taskStart = startDate {
                messages.append("starts after event ends (\(formatter.string(from: taskStart)) vs \(formatter.string(from: projectDue)))")
            }
        }

        if endsBeforeProject {
            if let projectStart = project?.startDate, let taskEnd = endDate {
                messages.append("ends before event starts (\(formatter.string(from: taskEnd)) vs \(formatter.string(from: projectStart)))")
            }
        }

        return messages.isEmpty ? nil : messages.joined(separator: ", ")
    }

    /// Whether this task is within project timeline (for crew planning filtering)
    @Transient
    var isWithinProjectTimeline: Bool {
        guard let project = project else { return true } // No project = no constraints

        // If no project dates set, all tasks are considered in-scope
        guard project.startDate != nil || project.dueDate != nil else { return true }

        // Task dates (use defaults if not set)
        let taskStart = startDate ?? project.startDate ?? .distantPast
        let taskEnd = endDate ?? project.dueDate ?? .distantFuture

        // Project dates (use defaults if not set)
        let projectStart = project.startDate ?? .distantPast
        let projectEnd = project.dueDate ?? .distantFuture

        // Task must overlap with project timeline
        return taskStart <= projectEnd && taskEnd >= projectStart
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
            personnelCount: self.expectedPersonnelCount ?? 1,
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

    // MARK: - Date Conflict Resolution (Phase 5: Quick Fix Actions)

    /// Adjusts task dates to match project timeline (Quick Fix)
    /// Makes the task span the entire project timeline (from project start to project end)
    func adjustToProjectDates() {
        guard let project = project else { return }

        // Set task to span the full project timeline
        // This is the most predictable behavior for "Fit to Project"
        if let projectStart = project.startDate {
            startDate = projectStart
        }

        if let projectDue = project.dueDate {
            endDate = projectDue
            dueDate = projectDue  // Keep dueDate synced with endDate
        }
    }

    /// Expands project timeline to include this task's dates (Quick Fix)
    /// Handles all 4 conflict types by expanding project boundaries as needed
    func expandProjectToIncludeTask() {
        guard let project = project else { return }

        // Expand project start date to include task (handles startsBeforeProject and endsBeforeProject)
        if let taskStart = startDate {
            if let projectStart = project.startDate {
                project.startDate = min(projectStart, taskStart)
            } else {
                project.startDate = taskStart
            }
        }

        // Expand project end date to include task (handles endsAfterProject and startsAfterProject)
        if let taskEnd = endDate {
            if let projectDue = project.dueDate {
                project.dueDate = max(projectDue, taskEnd)
            } else {
                project.dueDate = taskEnd
            }
        }
    }
}
