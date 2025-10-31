//
//  Formatters.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//

import Foundation

public extension Int {
    /// Formats minute counts like "1h 05m", "45m", "2h".
    func formattedMinutes() -> String {
        let hours = self / 60
        let mins  = self % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}
