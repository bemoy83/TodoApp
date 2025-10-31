//
//  Project+Derived.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//

import SwiftData

extension Project {
    /// Total number of top-level tasks (excludes subtasks)
    var topLevelTaskCount: Int {
        (tasks ?? []).filter { $0.parentTask == nil }.count
    }

    /// Optional: active/completed splits, mirroring ProjectDetailView
    var activeTopLevelTaskCount: Int {
        (tasks ?? []).filter { $0.parentTask == nil && !$0.isCompleted }.count
    }

    var completedTopLevelTaskCount: Int {
        (tasks ?? []).filter { $0.parentTask == nil && $0.isCompleted }.count
    }
}
