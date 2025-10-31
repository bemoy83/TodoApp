//
//  TaskEmptyStateView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  TaskEmptyStateView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//
//  Place in: Views/Tasks/

import SwiftUI

struct TaskEmptyStateView: View {
    let filter: TaskFilter
    let searchText: String
    let onAddTask: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            ZStack {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(.systemBlue))
            }

            Text("Nothing here!")
                .font(DesignSystem.Typography.title3)
            Text(emptyMessage)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
            
            /*Button {
                onAddTask()
            } label: {
                Label("Add Task", systemImage: "plus").fontWeight(.semibold)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, DesignSystem.Spacing.sm)*/
        }
        .emptyStateStyle()
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "No tasks match your search"
        }
        
        switch filter {
        case .all:
            return "Add your first task to get started"
        case .active:
            return "No active tasks"
        case .completed:
            return "No completed tasks yet"
        case .blocked:
            return "No blocked tasks"
        }
    }
}

// MARK: - Previews

#Preview("Empty - All Tasks") {
    List {
        TaskEmptyStateView(
            filter: .all,
            searchText: "",
            onAddTask: { print("Add task tapped") }
        )
    }
}

#Preview("Empty - Search") {
    List {
        TaskEmptyStateView(
            filter: .all,
            searchText: "meeting",
            onAddTask: { print("Add task tapped") }
        )
    }
}

#Preview("Empty - Active Filter") {
    List {
        TaskEmptyStateView(
            filter: .active,
            searchText: "",
            onAddTask: { print("Add task tapped") }
        )
    }
}

#Preview("Empty - Blocked Filter") {
    List {
        TaskEmptyStateView(
            filter: .blocked,
            searchText: "",
            onAddTask: { print("Add task tapped") }
        )
    }
}
