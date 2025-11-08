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

    // Group tasks by top-level parents for better organization
    private var groupedTasks: [(parent: Task?, tasks: [Task])] {
        var groups: [UUID?: [Task]] = [:]

        for task in filteredTasks {
            let parentId = task.parentTask?.id
            groups[parentId, default: []].append(task)
        }

        // Convert to array and sort: top-level tasks first, then by parent
        var result: [(parent: Task?, tasks: [Task])] = []

        // Add top-level tasks first
        if let topLevelTasks = groups[nil] {
            result.append((parent: nil, tasks: topLevelTasks.sorted { ($0.order ?? 0) < ($1.order ?? 0) }))
        }

        // Add subtask groups, sorted by parent
        for (parentId, subtasks) in groups where parentId != nil {
            if let parent = allTasks.first(where: { $0.id == parentId }) {
                result.append((parent: parent, tasks: subtasks.sorted { ($0.order ?? 0) < ($1.order ?? 0) }))
            }
        }

        return result
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
                    ForEach(groupedTasks, id: \.parent?.id) { group in
                        Section {
                            ForEach(group.tasks) { potentialDependency in
                                Button {
                                    addDependency(potentialDependency)
                                } label: {
                                    TaskPickerRow(
                                        task: potentialDependency,
                                        showPriority: true,
                                        showStatus: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            if let parent = group.parent {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                    Text("Subtasks of \(parent.title)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
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
