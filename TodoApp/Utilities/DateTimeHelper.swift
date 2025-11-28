//
//  DateTimeHelper.swift
//  TodoApp
//
//  Smart date and time defaults for scheduling based on user's work hours
//

import Foundation

struct DateTimeHelper {
    // MARK: - Smart Date Defaults

    /// Get a smart default date with appropriate time based on context
    /// - Parameters:
    ///   - baseDate: The date selected by the user (time component will be adjusted)
    ///   - isStartDate: True for start dates (defaults to workday start), false for due dates (defaults to workday end)
    ///   - currentDate: Current date for comparison (defaults to now)
    /// - Returns: Date with smart time default
    static func smartDefault(
        for baseDate: Date,
        isStartDate: Bool,
        currentDate: Date = Date()
    ) -> Date {
        let calendar = Calendar.current

        // If the base date is in the past or today, use current time
        guard baseDate > calendar.startOfDay(for: currentDate) else {
            return baseDate
        }

        // Future date - apply smart defaults
        let targetHour = isStartDate ? WorkHoursCalculator.workdayStart : WorkHoursCalculator.workdayEnd

        return calendar.date(
            bySettingHour: targetHour,
            minute: 0,
            second: 0,
            of: baseDate
        ) ?? baseDate
    }

    /// Get smart default for a start date
    /// Future dates default to workday start (e.g., 07:00)
    static func smartStartDate(for date: Date) -> Date {
        smartDefault(for: date, isStartDate: true)
    }

    /// Get smart default for a due/end date
    /// Future dates default to workday end (e.g., 15:00)
    static func smartDueDate(for date: Date) -> Date {
        smartDefault(for: date, isStartDate: false)
    }

    // MARK: - Date Comparison Helpers

    /// Check if a date is in the future (after today)
    static func isFutureDate(_ date: Date, comparedTo currentDate: Date = Date()) -> Bool {
        let calendar = Calendar.current
        return date > calendar.startOfDay(for: currentDate)
    }

    /// Check if a date is today or in the past
    static func isTodayOrPast(_ date: Date, comparedTo currentDate: Date = Date()) -> Bool {
        !isFutureDate(date, comparedTo: currentDate)
    }

    // MARK: - Time Component Helpers

    /// Extract hour from date
    static func hour(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    /// Check if a time falls within work hours
    static func isWithinWorkHours(_ date: Date) -> Bool {
        let hour = hour(from: date)
        return hour >= WorkHoursCalculator.workdayStart && hour < WorkHoursCalculator.workdayEnd
    }

    /// Format date for display in pickers
    static func formatForPicker(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
