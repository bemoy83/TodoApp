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
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var selectedProject: Project?
    @State private var notesText: String
    @State private var hasNotes: Bool

    // Grouped estimation state (replaces 13 individual state properties)
    @State private var estimation: TaskEstimator.EstimationState

    private var isSubtask: Bool { task.parentTask != nil }

    init(task: Task,
         isNewTask: Bool = false,
         onSave: @escaping (Task) -> Void = { _ in },
         onCancel: @escaping () -> Void = {}) {
        self.task = task
        self.isNewTask = isNewTask
        self.onSave = onSave
        self.onCancel = onCancel

        // Backward compatibility: use endDate if available, otherwise fall back to dueDate
        let effectiveEndDate = task.endDate ?? task.dueDate
        let hasDeadline = effectiveEndDate != nil

        _hasDueDate = State(initialValue: hasDeadline)
        _dueDate = State(initialValue: effectiveEndDate ?? .now)
        _hasStartDate = State(initialValue: task.startDate != nil)
        _startDate = State(initialValue: task.startDate ?? .now)
        _hasEndDate = State(initialValue: hasDeadline)
        _endDate = State(initialValue: effectiveEndDate ?? .now)
        _selectedProject = State(initialValue: task.project)
        _notesText = State(initialValue: task.notes ?? "")
        _hasNotes = State(initialValue: !(task.notes ?? "").isEmpty)

        // Initialize grouped estimation state from task
        var estimationState = TaskEstimator.EstimationState(from: task)

        // Determine initial mode based on existing task data
        if task.unit.isQuantifiable {
            estimationState.mode = .quantity
        } else if task.effortHours != nil {
            estimationState.mode = .effort
        } else {
            estimationState.mode = .duration
        }

        _estimation = State(initialValue: estimationState)
    }
    
    var body: some View {
        NavigationStack {
            TaskComposerForm(
                title: $task.title,
                notes: $notesText,
                hasNotes: $hasNotes,
                selectedProject: Binding(
                    get: { task.project ?? selectedProject },
                    set: { task.project = $0; selectedProject = $0 }
                ),
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                hasStartDate: $hasStartDate,
                startDate: $startDate,
                hasEndDate: $hasEndDate,
                endDate: $endDate,
                priority: $task.priority,
                estimation: $estimation,
                isSubtask: isSubtask,
                parentTask: task.parentTask,
                editingTask: task  // Pass the task being edited
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
        // Only write to endDate (primary field), keep dueDate for backwards compatibility (read-only)
        task.startDate = hasStartDate ? startDate : nil
        task.endDate = hasEndDate ? endDate : nil

        // Process notes
        task.notes = TaskEstimator.processNotes(notesText)

        // Calculate and apply estimate
        let estimate = TaskEstimator.calculateEstimate(
            estimateByEffort: estimation.mode == .effort,
            effortHours: estimation.effortHours,
            hasEstimate: estimation.hasEstimate,
            estimateHours: estimation.estimateHours,
            estimateMinutes: estimation.estimateMinutes,
            hasCustomEstimate: estimation.hasCustomEstimate,
            hasPersonnel: estimation.hasPersonnel,
            expectedPersonnelCount: estimation.expectedPersonnelCount
        )
        TaskEstimator.applyEstimate(to: task, result: estimate)

        // Apply quantity tracking (only when in quantity mode)
        if estimation.mode == .quantity {
            task.unit = estimation.unit
            task.quantity = !estimation.quantity.isEmpty ? Double(estimation.quantity) : nil
            task.taskType = estimation.taskType
            task.customProductivityRate = estimation.productivityRate // Save custom productivity rate
        } else {
            task.unit = UnitType.none
            task.quantity = nil
            task.taskType = nil
            task.customProductivityRate = nil
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
