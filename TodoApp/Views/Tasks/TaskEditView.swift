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

    // Personnel state
    @State private var hasPersonnel: Bool
    @State private var expectedPersonnelCount: Int?

    // Effort-based estimation state
    @State private var estimateByEffort: Bool
    @State private var effortHours: Double

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

        // Initialize estimate state (convert seconds to hours/minutes for display)
        let estimateSeconds = task.estimatedSeconds ?? 0
        let estimateMinutes = estimateSeconds / 60
        _hasEstimate = State(initialValue: task.estimatedSeconds != nil)
        _estimateHours = State(initialValue: estimateMinutes / 60)
        _estimateMinutes = State(initialValue: estimateMinutes % 60)
        _hasCustomEstimate = State(initialValue: task.hasCustomEstimate)

        // Initialize personnel state
        _hasPersonnel = State(initialValue: task.expectedPersonnelCount != nil)
        _expectedPersonnelCount = State(initialValue: task.expectedPersonnelCount)

        // Initialize effort-based estimation state
        _estimateByEffort = State(initialValue: task.effortHours != nil)
        _effortHours = State(initialValue: task.effortHours ?? 0)
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
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                estimateByEffort: $estimateByEffort,
                effortHours: $effortHours,
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

        // Process notes
        task.notes = TaskEstimator.processNotes(notesText)

        // Calculate and apply estimate
        let estimate = TaskEstimator.calculateEstimate(
            estimateByEffort: estimateByEffort,
            effortHours: effortHours,
            hasEstimate: hasEstimate,
            estimateHours: estimateHours,
            estimateMinutes: estimateMinutes,
            hasCustomEstimate: hasCustomEstimate,
            hasPersonnel: hasPersonnel,
            expectedPersonnelCount: expectedPersonnelCount
        )
        TaskEstimator.applyEstimate(to: task, result: estimate)

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
            estimatedSeconds: 120 * 60
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
        estimatedSeconds: 240 * 60
    )

    let subtask = Task(
        title: "Subtask",
        priority: 2,
        createdDate: Date(),
        parentTask: parent,
        notes: "Subtask notes",
        estimatedSeconds: 60 * 60
    )
    
    return TaskEditView(
        task: subtask,
        isNewTask: false
    )
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}
