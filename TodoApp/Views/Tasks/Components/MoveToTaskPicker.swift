//
//  MoveToTaskPicker.swift
//  TodoApp
//

import SwiftUI
import SwiftData

struct MoveToTaskPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Task.order) private var allTasks: [Task]
    
    let task: Task  // The subtask being moved
    
    @State private var searchText = ""
    @State private var currentAlert: TaskActionAlert?
    
    // Available parent tasks (exclude current parent, self, and descendants)
    private var availableTasks: [Task] {
        allTasks.filter { potentialParent in
            // Must be a top-level task (not a subtask itself)
            guard potentialParent.parentTask == nil else { return false }
            
            // Can't be the task itself
            guard potentialParent.id != task.id else { return false }
            
            // Can't be current parent
            guard potentialParent.id != task.parentTask?.id else { return false }
            
            // Can't be a subtask of the task being moved (prevent circular dependency)
            guard !isDescendant(potentialParent, of: task) else { return false }
            
            // Search filter
            if !searchText.isEmpty {
                return potentialParent.title.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
        .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Show warning banner if timer is active
                if task.hasActiveTimer {
                    Section {
                        Label("Stop the timer before moving this task", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                            
                if availableTasks.isEmpty {
                    emptyState
                } else {
                    tasksList
                }
            }
            .searchable(text: $searchText, prompt: "Search tasks")
            .navigationTitle("Move to Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .taskActionAlert(alert: $currentAlert)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No Available Tasks",
            systemImage: "tray",
            description: Text("Create a parent task first to move this subtask.")
        )
    }
    
    @ViewBuilder
    private var tasksList: some View {
        ForEach(Array(availableTasks), id: \.id) { parentTask in
            Button {
                moveTask(to: parentTask)
            } label: {
                TaskPickerRow(task: parentTask, showSubtaskCount: true)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions

    private func moveTask(to newParent: Task) {
        // Validate move for circular dependencies
        let validation = TaskService.canMoveTask(task, toParent: newParent)

        switch validation {
        case .valid:
            // No issues, proceed with move
            performMove(to: newParent)

        case .circularDependency(let movingTask, let dependency, let reason):
            // Check if this is a direct dependency that can be auto-removed
            let canAutoFix = task.dependsOn?.contains(where: { $0.id == newParent.id }) ?? false

            if canAutoFix {
                // Offer to remove the blocking dependency
                currentAlert = TaskActionAlert(
                    title: "Circular Dependency Detected",
                    message: "Moving '\(movingTask.title)' to '\(newParent.title)' would create a circular dependency because \(reason).\n\nWould you like to remove the dependency and move the task?",
                    actions: [
                        AlertAction(title: "Cancel", role: .cancel) { },
                        AlertAction(title: "Remove Dependency & Move", role: .destructive) {
                            // Remove the circular dependency
                            TaskService.removeDependency(from: self.task, to: newParent)
                            // Proceed with move
                            self.performMove(to: newParent)
                        }
                    ]
                )
            } else {
                // Complex circular dependency that can't be auto-fixed
                currentAlert = TaskActionAlert(
                    title: "Cannot Move Task",
                    message: "Moving '\(movingTask.title)' to '\(newParent.title)' would create a circular dependency: \(reason)\n\nPlease remove the conflicting dependencies manually before moving this task.",
                    actions: [
                        AlertAction(title: "OK", role: .cancel) { }
                    ]
                )
            }

            HapticManager.warning()
        }
    }

    private func performMove(to newParent: Task) {
        // Store old parent reference
        let oldParent = task.parentTask
        
        // Update relationships
        task.parentTask = newParent
        task.project = newParent.project
        
        let maxOrder = (newParent.subtasks ?? []).compactMap(\.order).max() ?? -1
        task.order = maxOrder + 1
        
        // Manual array updates
        if let oldParent = oldParent {
            oldParent.subtasks?.removeAll { $0.id == task.id }
        }
        
        if newParent.subtasks == nil {
            newParent.subtasks = []
        }
        if !(newParent.subtasks?.contains { $0.id == task.id } ?? false) {
            newParent.subtasks?.append(task)
        }
        
        do {
            try modelContext.save()
            HapticManager.success()
            
            // ✅ Delay dismiss to let SwiftData propagate changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
            }
        } catch {
            currentAlert = TaskActionAlert(
                title: "Move Failed",
                message: "Failed to move task: \(error.localizedDescription)",
                actions: [
                    AlertAction(title: "OK", role: .cancel) { }
                ]
            )
            HapticManager.error()
        }
    }
        
        // Check if a task is a descendant of another (prevent circular dependencies)
        private func isDescendant(_ potentialDescendant: Task, of ancestor: Task) -> Bool {
            var current = potentialDescendant.parentTask
            while current != nil {
                if current?.id == ancestor.id {
                    return true
                }
                current = current?.parentTask
            }
            return false
        }
    }

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    
    let task1 = Task(title: "Parent Task 1", priority: 1, createdDate: Date())
    let task2 = Task(title: "Parent Task 2", priority: 1, createdDate: Date())
    let subtask = Task(title: "Subtask to Move", priority: 2, createdDate: Date(), parentTask: task1)
    
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)
    container.mainContext.insert(subtask)
    
    return MoveToTaskPicker(task: subtask)
        .modelContainer(container)
}
