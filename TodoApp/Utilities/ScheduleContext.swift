import Foundation

/// Groups all schedule-related parameters for cleaner view signatures
/// Consolidates 6 individual parameters into a single context object
struct ScheduleContext {
    // Due date
    let hasDueDate: Bool
    let dueDate: Date

    // Working window (start/end dates)
    let hasStartDate: Bool
    let startDate: Date
    let hasEndDate: Bool
    let endDate: Date

    // MARK: - Computed Properties

    /// Whether a valid working window is set (both start and end dates)
    var hasWorkingWindow: Bool {
        hasStartDate && hasEndDate
    }

    /// Calculate available work hours within the working window
    var availableWorkHours: Double? {
        guard hasWorkingWindow else { return nil }
        return WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
    }

    /// Available work duration in seconds
    var availableWorkSeconds: Int? {
        guard let hours = availableWorkHours else { return nil }
        return Int(hours * 3600)
    }

    /// Whether the task has a deadline but no working window
    var hasDeadlineOnly: Bool {
        hasDueDate && !hasWorkingWindow
    }

    // MARK: - Initialization

    /// Create a schedule context with all parameters
    init(
        hasDueDate: Bool,
        dueDate: Date,
        hasStartDate: Bool,
        startDate: Date,
        hasEndDate: Bool,
        endDate: Date
    ) {
        self.hasDueDate = hasDueDate
        self.dueDate = dueDate
        self.hasStartDate = hasStartDate
        self.startDate = startDate
        self.hasEndDate = hasEndDate
        self.endDate = endDate
    }

    /// Create an empty schedule context (no dates set)
    static var empty: ScheduleContext {
        ScheduleContext(
            hasDueDate: false,
            dueDate: Date(),
            hasStartDate: false,
            startDate: Date(),
            hasEndDate: false,
            endDate: Date()
        )
    }

    /// Create schedule context from a task
    static func from(task: Task) -> ScheduleContext {
        // Use endDate (new) with fallback to dueDate (legacy) for backwards compatibility
        let effectiveEnd = task.endDate ?? task.dueDate

        return ScheduleContext(
            hasDueDate: effectiveEnd != nil,
            dueDate: effectiveEnd ?? Date(),
            hasStartDate: task.startDate != nil,
            startDate: task.startDate ?? Date(),
            hasEndDate: task.endDate != nil,
            endDate: task.endDate ?? Date()
        )
    }
}

// MARK: - Equatable

extension ScheduleContext: Equatable {
    static func == (lhs: ScheduleContext, rhs: ScheduleContext) -> Bool {
        lhs.hasDueDate == rhs.hasDueDate &&
        lhs.dueDate == rhs.dueDate &&
        lhs.hasStartDate == rhs.hasStartDate &&
        lhs.startDate == rhs.startDate &&
        lhs.hasEndDate == rhs.hasEndDate &&
        lhs.endDate == rhs.endDate
    }
}
