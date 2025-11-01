//
//  Formatters.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//

import Foundation

public extension Int {
    /// Formats seconds as time like "1h 5m", "45m", "2h 30m".
    func formattedTime() -> String {
        let totalMinutes = self / 60
        let hours = totalMinutes / 60
        let mins  = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    /// Legacy alias for backwards compatibility (converts seconds to formatted time)
    @available(*, deprecated, renamed: "formattedTime", message: "Use formattedTime() - now expects seconds instead of minutes")
    func formattedMinutes() -> String {
        formattedTime()
    }
}
