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

    // NEW: Time estimate state
    @State private var hasEstimate: Bool
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int
    @State private var hasCustomEstimate: Bool

    // Personnel state
    @State private var hasPersonnel: Bool
    @State private var expectedPersonnelCount: Int?

    // Unified calculator state
    @State private var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode
    @State private var effortHours: Double
    @State private var quantity: String
    @State private var unit: UnitType
    @State private var taskType: String?
    @State private var quantityCalculationMode: TaskEstimator.QuantityCalculationMode
    @State private var productivityRate: Double?

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

        // Initialize unified calculator state
        // Determine initial mode based on existing task data
        let initialMode: TaskEstimator.UnifiedEstimationMode
        if task.unit.isQuantifiable {
            initialMode = .quantity
        } else if task.effortHours != nil {
            initialMode = .effort
        } else {
            initialMode = .duration
        }

        _unifiedEstimationMode = State(initialValue: initialMode)
        _effortHours = State(initialValue: task.effortHours ?? 0)
        _quantity = State(initialValue: task.quantity.map { String(format: "%.1f", $0) } ?? "")
        _unit = State(initialValue: task.unit)
        _taskType = State(initialValue: task.taskType)
        _quantityCalculationMode = State(initialValue: .manualEntry)
        _productivityRate = State(initialValue: nil)
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
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasCustomEstimate: $hasCustomEstimate,
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                unifiedEstimationMode: $unifiedEstimationMode,
                effortHours: $effortHours,
                quantity: $quantity,
                unit: $unit,
                taskType: $taskType,
                quantityCalculationMode: $quantityCalculationMode,
                productivityRate: $productivityRate,
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
        task.dueDate = hasDueDate ? dueDate : nil
        task.startDate = hasStartDate ? startDate : nil
        task.endDate = hasEndDate ? endDate : nil

        // Process notes
        task.notes = TaskEstimator.processNotes(notesText)

        // Calculate and apply estimate
        let estimate = TaskEstimator.calculateEstimate(
            estimateByEffort: unifiedEstimationMode == .effort,
            effortHours: effortHours,
            hasEstimate: hasEstimate,
            estimateHours: estimateHours,
            estimateMinutes: estimateMinutes,
            hasCustomEstimate: hasCustomEstimate,
            hasPersonnel: hasPersonnel,
            expectedPersonnelCount: expectedPersonnelCount
        )
        TaskEstimator.applyEstimate(to: task, result: estimate)

        // Apply quantity tracking (only when in quantity mode)
        if unifiedEstimationMode == .quantity {
            task.unit = unit
            task.quantity = !quantity.isEmpty ? Double(quantity) : nil
            task.taskType = taskType
        } else {
            task.unit = UnitType.none
            task.quantity = nil
            task.taskType = nil
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
