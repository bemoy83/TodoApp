//
//  TaskFilterMenu.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  TaskFilterMenu.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//
//  Place in: Views/Tasks/

import SwiftUI

struct TaskFilterMenu: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        Menu {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TaskFilter.allCases) { filter in
                    Label(filter.label, systemImage: filter.icon)
                        .tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: selectedFilter.icon)
        }
    }
}

// MARK: - Preview

#Preview("Filter Menu") {
    struct PreviewWrapper: View {
        @State private var selectedFilter: TaskFilter = .all
        
        var body: some View {
            NavigationStack {
                List {
                    Text("Sample Content")
                        .font(DesignSystem.Typography.body)
                    Text("Current filter: \(selectedFilter.label)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
                .navigationTitle("Tasks")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        TaskFilterMenu(selectedFilter: $selectedFilter)
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
}