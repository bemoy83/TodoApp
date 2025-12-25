//
//  Formatters.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//

import Foundation

public extension Int {
    /// Formats seconds as time.
    /// - Parameter showSeconds: If true, shows detailed format like "1h 5m 32s". If false (default), rounds to minutes like "1h 5m".
    /// - Returns: Formatted time string
    ///
    /// Examples:
    /// - Compact (default): `3665.formattedTime()` → "1h 1m"
    /// - Detailed: `3665.formattedTime(showSeconds: true)` → "1h 1m 5s"
    func formattedTime(showSeconds: Bool = false) -> String {
        if showSeconds {
            // Detailed mode: show seconds for detail views
            let hours = self / 3600
            let minutes = (self % 3600) / 60
            let seconds = self % 60

            if hours > 0 {
                // Has hours
                if minutes > 0 && seconds > 0 {
                    return "\(hours)h \(minutes)m \(seconds)s"
                } else if minutes > 0 {
                    return "\(hours)h \(minutes)m"
                } else if seconds > 0 {
                    return "\(hours)h \(seconds)s"
                } else {
                    return "\(hours)h"
                }
            } else if minutes > 0 {
                // Has minutes but no hours
                return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
            } else {
                // Only seconds
                return "\(seconds)s"
            }
        } else {
            // Compact mode: round to minutes (current behavior)
            let totalMinutes = self / 60
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60

            if hours > 0 {
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            } else {
                return "\(mins)m"
            }
        }
    }

    /// Legacy alias for backwards compatibility (converts seconds to formatted time)
    @available(*, deprecated, renamed: "formattedTime", message: "Use formattedTime() - now expects seconds instead of minutes")
    func formattedMinutes() -> String {
        formattedTime()
    }

    /// Formats seconds as digital stopwatch display (H:MM:SS or M:SS)
    /// - Returns: Formatted stopwatch string
    ///
    /// Examples:
    /// - `65.formattedStopwatch()` → "1:05"
    /// - `3665.formattedStopwatch()` → "1:01:05"
    func formattedStopwatch() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
