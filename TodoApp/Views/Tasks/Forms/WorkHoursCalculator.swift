import Foundation

/// Pure utility for calculating available work hours and personnel requirements.
/// Separated from UI for testability and reusability.
struct WorkHoursCalculator {
    // MARK: - Configuration

    /// Work hours window (07:00 to 15:00 = 8-hour workday)
    static let workdayStart = 7
    static let workdayEnd = 15
    static var workdayHours: Double {
        Double(workdayEnd - workdayStart)
    }

    // MARK: - Public Methods

    /// Calculate available work hours from now until deadline
    /// - Parameters:
    ///   - from: Start date (typically current time)
    ///   - to: Deadline date
    /// - Returns: Total available work hours within workday windows
    static func calculateAvailableHours(from startDate: Date, to deadline: Date) -> Double {
        let calendar = Calendar.current

        // If deadline is in the past, return minimum
        guard deadline > startDate else { return 1.0 }

        var totalHours: Double = 0.0
        var currentDate = calendar.startOfDay(for: startDate)
        let deadlineDay = calendar.startOfDay(for: deadline)

        // Process each day from start to deadline
        while currentDate <= deadlineDay {
            if calendar.isDate(currentDate, inSameDayAs: startDate) {
                // Today: count from now until end of workday (or deadline if earlier)
                totalHours += calculateHoursForToday(
                    startDate: startDate,
                    deadline: deadline,
                    currentDate: currentDate,
                    calendar: calendar
                )
            } else if calendar.isDate(currentDate, inSameDayAs: deadline) {
                // Deadline day: count from start of workday until deadline time
                totalHours += calculateHoursForDeadlineDay(
                    deadline: deadline,
                    calendar: calendar
                )
            } else {
                // Full workday
                totalHours += workdayHours
            }

            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return max(totalHours, 1.0) // Minimum 1 hour
    }

    /// Calculate minimum personnel needed to complete effort within available time
    /// - Parameters:
    ///   - effortHours: Total work effort in person-hours
    ///   - availableHours: Available calendar hours until deadline
    /// - Returns: Minimum number of people needed (at least 1)
    static func calculateMinimumPersonnel(effortHours: Double, availableHours: Double) -> Int {
        guard availableHours > 0 else { return 1 }
        return max(Int(ceil(effortHours / availableHours)), 1)
    }

    /// Generate resource planning scenarios
    /// - Parameters:
    ///   - effortHours: Total work effort in person-hours
    ///   - minimumPersonnel: Minimum crew size needed
    /// - Returns: Array of scenarios (Tight, Safe, Buffer) with hours per person
    static func generateScenarios(effortHours: Double, minimumPersonnel: Int) -> [(people: Int, hoursPerPerson: Double, status: String, icon: String)] {
        guard minimumPersonnel > 0 else { return [] }

        return [
            (minimumPersonnel, effortHours / Double(minimumPersonnel), "Tight", "exclamationmark.triangle.fill"),
            (minimumPersonnel + 1, effortHours / Double(minimumPersonnel + 1), "Safe", "checkmark.circle.fill"),
            (minimumPersonnel + 2, effortHours / Double(minimumPersonnel + 2), "Buffer", "checkmark.circle.fill")
        ]
    }

    // MARK: - Private Helpers

    private static func calculateHoursForToday(
        startDate: Date,
        deadline: Date,
        currentDate: Date,
        calendar: Calendar
    ) -> Double {
        let nowComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let nowHour = Double(nowComponents.hour ?? 0) + Double(nowComponents.minute ?? 0) / 60.0

        guard nowHour < Double(workdayEnd) else { return 0.0 }

        // Still time left today
        let startHour = max(nowHour, Double(workdayStart))
        let endHour: Double

        if calendar.isDate(currentDate, inSameDayAs: deadline) {
            // Deadline is today
            let deadlineComponents = calendar.dateComponents([.hour, .minute], from: deadline)
            let deadlineHour = Double(deadlineComponents.hour ?? 0) + Double(deadlineComponents.minute ?? 0) / 60.0
            endHour = min(deadlineHour, Double(workdayEnd))
        } else {
            endHour = Double(workdayEnd)
        }

        return max(endHour - startHour, 0)
    }

    private static func calculateHoursForDeadlineDay(
        deadline: Date,
        calendar: Calendar
    ) -> Double {
        let deadlineComponents = calendar.dateComponents([.hour, .minute], from: deadline)
        let deadlineHour = Double(deadlineComponents.hour ?? 0) + Double(deadlineComponents.minute ?? 0) / 60.0

        let startHour = Double(workdayStart)
        let endHour = min(deadlineHour, Double(workdayEnd))

        return max(endHour - startHour, 0)
    }
}
