import SwiftUI
import SwiftData

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task
    @Query(sort: \Project.title) private var projects: [Project]
    
    let isNewTask: Bool
    let onSave: (Task) -> Void
    let onCancel: () -> Void
    
    // Draft mirrors task props to drive the shared form
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var selectedProject: Project?
    @State private var notesText: String
    
    // NEW: Time estimate state
    @State private var hasEstimate: Bool
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int
    @State private var hasCustomEstimate: Bool
    
    private var isSubtask: Bool { task.parentTask != nil }
    
    init(task: Task,
         isNewTask: Bool = false,
         onSave: @escaping (Task) -> Void = { _ in },
         onCancel: @escaping () -> Void = {}) {
        self.task = task
        self.isNewTask = isNewTask
        self.onSave = onSave
        self.onCancel = onCancel
        
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? .now)
        _selectedProject = State(initialValue: task.project)
        _notesText = State(initialValue: task.notes ?? "")
        
        // NEW: Initialize estimate state
        let estimate = task.estimatedMinutes ?? 0
        _hasEstimate = State(initialValue: task.estimatedMinutes != nil)
        _estimateHours = State(initialValue: estimate / 60)
        _estimateMinutes = State(initialValue: estimate % 60)
        _hasCustomEstimate = State(initialValue: task.hasCustomEstimate)
    }
    
    var body: some View {
        NavigationStack {
            TaskComposerForm(
                title: $task.title,
                notes: $notesText,
                selectedProject: Binding(
                    get: { task.project ?? selectedProject },
                    set: { task.project = $0; selectedProject = $0 }
                ),
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                priority: $task.priority,
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasCustomEstimate: $hasCustomEstimate,
                isSubtask: isSubtask,
                parentTask: task.parentTask,
                editingTask: task  // NEW: Pass the task being edited
            )
            .navigationTitle(isSubtask ? (isNewTask ? "New Subtask" : "Edit Subtask")
                                       : (isNewTask ? "New Task" : "Edit Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { handleCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewTask ? "Add" : "Save") { handleSave() }
                        .disabled(task.title.isEmpty)
                }
            }
        }
    }
    
    private func handleSave() {
        task.dueDate = hasDueDate ? dueDate : nil
        
        // Trim whitespace and set to nil if empty
        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        // NEW: Handle time estimate
        if hasEstimate {
            let totalMinutes = (estimateHours * 60) + estimateMinutes
            task.estimatedMinutes = totalMinutes > 0 ? totalMinutes : nil
            task.hasCustomEstimate = hasCustomEstimate
        } else {
            task.estimatedMinutes = nil
            task.hasCustomEstimate = false
        }
        
        onSave(task)
        dismiss()
    }
    
    private func handleCancel() {
        onCancel()
        dismiss()
    }
}

#Preview("Edit Task") {
    TaskEditView(
        task: Task(
            title: "Sample Task",
            priority: 1,
            notes: "Some existing notes here",
            estimatedMinutes: 120
        ),
        isNewTask: false
    )
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}

#Preview("New Task") {
    TaskEditView(
        task: Task(title: ""),
        isNewTask: true
    )
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}

#Preview("Edit Subtask") {
    let parent = Task(
        title: "Parent Task",
        priority: 1,
        dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        createdDate: Date(),
        estimatedMinutes: 240
    )
    
    let subtask = Task(
        title: "Subtask",
        priority: 2,
        createdDate: Date(),
        parentTask: parent,
        notes: "Subtask notes",
        estimatedMinutes: 60
    )
    
    return TaskEditView(
        task: subtask,
        isNewTask: false
    )
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}
