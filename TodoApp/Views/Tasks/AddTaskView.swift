import SwiftUI
import SwiftData

/// A unified Add Task screen used from both the Task list and Project detail.
/// Mirrors TaskEditView options by embedding TaskComposerForm.
struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Context of creation
    let preselectedProject: Project?
    let parentTask: Task?           // if adding a subtask
    let onAdded: ((Task) -> Void)?  // optional callback

    // Draft state
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedProject: Project?
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var priority: Int = 2  // Medium

    // NEW: Time estimate state
    @State private var hasEstimate: Bool = false
    @State private var estimateHours: Int = 0
    @State private var estimateMinutes: Int = 0
    @State private var hasCustomEstimate: Bool = false

    // Personnel state
    @State private var hasPersonnel: Bool = false
    @State private var expectedPersonnelCount: Int? = nil

    // Effort-based estimation state
    @State private var estimateByEffort: Bool = false
    @State private var effortHours: Double = 0

    // Quantity/unit state
    @State private var hasQuantity: Bool = false
    @State private var quantity: String = ""
    @State private var unit: UnitType = UnitType.none
    @State private var taskType: String? = nil

    // Template picker state
    @State private var showingTemplatePicker: Bool = true
    @State private var templateSelected: Bool = false

    // For list creation, compute next order to keep ordering stable
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }) private var tasks: [Task]
    private var nextOrder: Int {
        // top-level order only (subtasks ordering could be handled by parent)
        let topLevel = tasks.filter { $0.parentTask == nil }
        let maxOrder = topLevel.map { $0.order ?? 0 }.max() ?? -1
        return maxOrder + 1
    }

    init(project: Project? = nil,
         parentTask: Task? = nil,
         onAdded: ((Task) -> Void)? = nil) {
        self.preselectedProject = project
        self.parentTask = parentTask
        self.onAdded = onAdded
        _selectedProject = State(initialValue: project)
    }
    
    var body: some View {
        NavigationStack {
            TaskComposerForm(
                title: $title,
                notes: $notes,
                selectedProject: $selectedProject,
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                priority: $priority,
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasCustomEstimate: $hasCustomEstimate,
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                estimateByEffort: $estimateByEffort,
                effortHours: $effortHours,
                hasQuantity: $hasQuantity,
                quantity: $quantity,
                unit: $unit,
                isSubtask: parentTask != nil,
                parentTask: parentTask,
                editingTask: nil  // NEW: Not editing existing, so nil
            )
            .navigationTitle(parentTask == nil ? "New Task" : "New Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerSheet(
                    onSelect: { template in
                        applyTemplate(template)
                    },
                    onCancel: {
                        // User chose blank task, just close picker
                        templateSelected = true
                    }
                )
            }
        }
    }
    
    private func applyTemplate(_ template: TaskTemplate) {
        // Apply template defaults
        unit = template.defaultUnit

        // Enable quantity tracking if unit is quantifiable
        hasQuantity = template.defaultUnit.isQuantifiable

        // Set task type from template for productivity grouping
        taskType = template.taskType

        if let estimateSeconds = template.defaultEstimateSeconds {
            let totalMinutes = estimateSeconds / 60
            hasEstimate = true
            estimateHours = totalMinutes / 60
            estimateMinutes = totalMinutes % 60
            hasCustomEstimate = true
        }

        templateSelected = true
    }

    private func addTask() {
        // Process notes
        let processedNotes = TaskEstimator.processNotes(notes)

        // Calculate estimate
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

        // Parse quantity
        let parsedQuantity: Double? = hasQuantity && !quantity.isEmpty ? Double(quantity) : nil

        let task = Task(
            title: title,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            createdDate: .now,
            parentTask: parentTask,
            project: parentTask?.project ?? selectedProject,
            order: parentTask == nil ? nextOrder : nil,
            notes: processedNotes,
            estimatedSeconds: estimate.estimatedSeconds,
            hasCustomEstimate: estimate.hasCustomEstimate,
            expectedPersonnelCount: estimate.expectedPersonnelCount,
            effortHours: estimate.effortHours,
            quantity: parsedQuantity,
            unit: hasQuantity ? unit : UnitType.none,
            taskType: hasQuantity ? taskType : nil
        )
        modelContext.insert(task)
        onAdded?(task)
        dismiss()
    }
}

#Preview("Add Task") {
    AddTaskView()
        .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}

#Preview("Add Subtask") {
    let parent = Task(
        title: "Parent Task",
        priority: 1,
        dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        createdDate: Date(),
        estimatedSeconds: 240 * 60
    )
    
    return AddTaskView(parentTask: parent)
        .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}

#Preview("Add Task to Project") {
    let project = Project(title: "Work Project", color: "#007AFF")
    
    return AddTaskView(project: project)
        .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}
