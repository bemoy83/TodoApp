//
//  Priority.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 07/10/2025.
//

import SwiftUI

enum Priority: Int, CaseIterable, Hashable, Codable {
    case urgent = 0
    case high = 1
    case medium = 2
    case low = 3
    
    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
    
    var color: Color {
        switch self {
        case .urgent: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .green
        }
    }
    
    var icon: String {
        switch self {
        case .urgent: "exclamationmark.3"
        case .high: "exclamationmark.2"
        case .medium: "exclamationmark"
        case .low: "minus"
        }
    }
}
