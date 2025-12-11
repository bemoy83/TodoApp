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
    @State private var hasNotes: Bool = false
    @State private var selectedProject: Project?
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var hasStartDate: Bool = false
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .now
    @State private var priority: Int = 2  // Medium
    @State private var selectedTagIds: Set<UUID> = []

    // Grouped estimation state (replaces 13 individual state properties)
    @State private var estimation = TaskEstimator.EstimationState()

    // For list creation, compute next order to keep ordering stable
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }) private var tasks: [Task]
    @Query(sort: \Tag.order) private var allTags: [Tag]
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

        // PHASE 1: Inherit project dates as defaults
        if let project = project {
            // Inherit start date from project
            if let projectStart = project.startDate {
                _hasStartDate = State(initialValue: true)
                _startDate = State(initialValue: projectStart)
            }

            // Inherit end date from project (sync both endDate and dueDate for backwards compatibility)
            if let projectDue = project.dueDate {
                _hasEndDate = State(initialValue: true)
                _endDate = State(initialValue: projectDue)
                // Keep dueDate synced for backwards compatibility
                _hasDueDate = State(initialValue: true)
                _dueDate = State(initialValue: projectDue)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            TaskComposerForm(
                title: $title,
                notes: $notes,
                hasNotes: $hasNotes,
                selectedProject: $selectedProject,
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                hasStartDate: $hasStartDate,
                startDate: $startDate,
                hasEndDate: $hasEndDate,
                endDate: $endDate,
                priority: $priority,
                selectedTagIds: $selectedTagIds,
                estimation: $estimation,
                isSubtask: parentTask != nil,
                parentTask: parentTask,
                editingTask: nil  // Not editing existing, so nil
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
        }
    }

    private func addTask() {
        // Process notes
        let processedNotes = TaskEstimator.processNotes(notes)

        // Calculate estimate (unified calculator already auto-populates all fields)
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

        // Parse quantity (only when in quantity mode)
        let hasQuantity = estimation.mode == .quantity
        let parsedQuantity: Double? = hasQuantity && !estimation.quantity.isEmpty ? Double(estimation.quantity) : nil

        let task = Task(
            title: title,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            startDate: hasStartDate ? startDate : nil,
            endDate: hasEndDate ? endDate : nil,
            createdDate: .now,
            parentTask: parentTask,
            project: parentTask?.project ?? selectedProject,
            order: parentTask == nil ? nextOrder : nil,
            notes: processedNotes,
            estimatedSeconds: estimate.estimatedSeconds,
            hasCustomEstimate: estimate.hasCustomEstimate,
            expectedPersonnelCount: estimate.expectedPersonnelCount,
            effortHours: estimate.effortHours,
            expectedQuantity: parsedQuantity,
            quantity: nil,
            unit: hasQuantity ? estimation.unit : UnitType.none,
            taskType: hasQuantity ? estimation.taskType : nil,
            taskTemplate: hasQuantity ? estimation.taskTemplate : nil
        )

        // Apply selected tags
        let selectedTags = allTags.filter { selectedTagIds.contains($0.id) }
        task.tags = selectedTags

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
