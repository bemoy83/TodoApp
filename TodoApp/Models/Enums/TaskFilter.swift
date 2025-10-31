//
//  TaskFilter.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  TaskFilter.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//
//  Place in: Models/ or Utilities/

import Foundation

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case active = "active"
    case completed = "completed"
    case blocked = "blocked"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .completed: return "Completed"
        case .blocked: return "Blocked"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .active: return "circle"
        case .completed: return "checkmark.circle"
        case .blocked: return "exclamationmark.circle"
        }
    }
}