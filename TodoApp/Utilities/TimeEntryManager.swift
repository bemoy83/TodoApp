import Foundation

/// Pure utility for time entry calculations, formatting, and validation.
/// Provides shared logic for displaying and managing time entries across all time tracking views.
struct TimeEntryManager {

    // MARK: - Duration Calculations

    /// Calculate duration between start and end times
    /// - Parameters:
    ///   - start: Start time
    ///   - end: Optional end time (nil means ongoing, uses current time)
    /// - Returns: Duration in seconds
    static func calculateDuration(start: Date, end: Date?) -> TimeInterval {
        let endTime = end ?? Date()
        return endTime.timeIntervalSince(start)
    }

    /// Calculate duration for a time entry
    /// - Parameter entry: Time entry to calculate duration for
    /// - Returns: Duration in seconds
    static func calculateDuration(for entry: TimeEntry) -> TimeInterval {
        calculateDuration(start: entry.startTime, end: entry.endTime)
    }

    // MARK: - Person-Hours Calculations

    /// Calculate person-hours (total work effort)
    /// - Parameters:
    ///   - durationSeconds: Duration in seconds
    ///   - personnelCount: Number of people working
    /// - Returns: Person-hours as a Double
    static func calculatePersonHours(durationSeconds: TimeInterval, personnelCount: Int) -> Double {
        (durationSeconds / 3600.0) * Double(personnelCount)
    }

    /// Calculate person-hours for a time entry
    /// - Parameter entry: Time entry to calculate person-hours for
    /// - Returns: Person-hours as a Double
    static func calculatePersonHours(for entry: TimeEntry) -> Double {
        let duration = calculateDuration(for: entry)
        return calculatePersonHours(durationSeconds: duration, personnelCount: entry.personnelCount)
    }

    // MARK: - Formatting

    /// Format duration as human-readable string
    /// - Parameters:
    ///   - seconds: Duration in seconds
    ///   - showSeconds: Whether to include seconds in output
    /// - Returns: Formatted string (e.g., "2h 30m" or "2h 30m 15s")
    static func formatDuration(_ seconds: TimeInterval, showSeconds: Bool = false) -> String {
        Int(seconds).formattedTime(showSeconds: showSeconds)
    }

    /// Format duration for a time entry
    /// - Parameters:
    ///   - entry: Time entry to format
    ///   - showSeconds: Whether to include seconds
    /// - Returns: Formatted duration string
    static func formatDuration(for entry: TimeEntry, showSeconds: Bool = false) -> String {
        let duration = calculateDuration(for: entry)
        return formatDuration(duration, showSeconds: showSeconds)
    }

    /// Format person-hours with one decimal place
    /// - Parameter personHours: Person-hours value
    /// - Returns: Formatted string (e.g., "4.5 hrs")
    static func formatPersonHours(_ personHours: Double) -> String {
        String(format: "%.1f hrs", personHours)
    }

    /// Format person-hours for a time entry
    /// - Parameter entry: Time entry to format
    /// - Returns: Formatted person-hours string
    static func formatPersonHours(for entry: TimeEntry) -> String {
        let personHours = calculatePersonHours(for: entry)
        return formatPersonHours(personHours)
    }

    /// Format date as relative or absolute string
    /// - Parameter date: Date to format
    /// - Returns: "Today", "Yesterday", or formatted date string
    static func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    /// Format time range as string
    /// - Parameters:
    ///   - start: Start time
    ///   - end: Optional end time (nil shows "Now")
    /// - Returns: Formatted range (e.g., "2:30 PM - 4:45 PM" or "2:30 PM - Now")
    static func formatTimeRange(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let startStr = formatter.string(from: start)

        if let endTime = end {
            let endStr = formatter.string(from: endTime)
            return "\(startStr) - \(endStr)"
        } else {
            return "\(startStr) - Now"
        }
    }

    /// Format time range for a time entry
    /// - Parameter entry: Time entry to format
    /// - Returns: Formatted time range string
    static func formatTimeRange(for entry: TimeEntry) -> String {
        formatTimeRange(start: entry.startTime, end: entry.endTime)
    }

    // MARK: - Validation

    /// Validate time entry dates
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: true if valid (end is after start)
    static func isValid(start: Date, end: Date) -> Bool {
        end > start
    }

    /// Validation error message for invalid dates
    static let validationErrorMessage = "End time must be after start time"

    // MARK: - Entry Status

    /// Check if time entry represents an active timer
    /// - Parameter entry: Time entry to check
    /// - Returns: true if entry has no end time
    static func isActiveTimer(_ entry: TimeEntry) -> Bool {
        entry.endTime == nil
    }
}
