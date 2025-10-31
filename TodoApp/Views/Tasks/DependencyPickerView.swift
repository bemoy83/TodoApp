//
//  DependencyPickerView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//
import SwiftUI

// MARK: - Dependency Picker View

struct DependencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task
    let allTasks: [Task]
    
    @State private var searchText = ""
    
    private var filteredTasks: [Task] {
        // First filter: only incomplete tasks (completed tasks can't block)
        let incompleteTasks = allTasks.filter { !$0.isCompleted }
        
        // Second filter: search text
        if searchText.isEmpty {
            return incompleteTasks
        }
        return incompleteTasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredTasks.isEmpty {
                    ContentUnavailableView(
                        "No Available Tasks",
                        systemImage: "tray",
                        description: Text(searchText.isEmpty
                            ? "All incomplete tasks are either already dependencies or would create circular references"
                            : "No incomplete tasks match your search")
                    )
                } else {
                    ForEach(filteredTasks) { potentialDependency in
                        Button {
                            addDependency(potentialDependency)
                        } label: {
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(.gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(potentialDependency.title)
                                        .foregroundStyle(.primary)
                                    
                                    if let project = potentialDependency.project {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: project.color))
                                                .frame(width: 6, height: 6)
                                            Text(project.title)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tasks")
            .navigationTitle("Add Dependency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addDependency(_ dependency: Task) {
        do {
            try TaskService.addDependency(from: task, to: dependency)
            dismiss()
        } catch {
            print("Failed to add dependency: \(error.localizedDescription)")
        }
    }
}
