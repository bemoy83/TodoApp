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
    
    // For list creation, compute next order to keep ordering stable
    @Query private var tasks: [Task]
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
        }
    }
    
    private func addTask() {
        // Trim whitespace and set to nil if empty
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Calculate time estimate (convert hours/minutes to seconds for storage)
        let totalMinutes = hasEstimate ? (estimateHours * 60) + estimateMinutes : nil
        let totalSeconds = totalMinutes.map { $0 * 60 }
        let finalEstimate = (totalSeconds ?? 0) > 0 ? totalSeconds : nil

        let task = Task(
            title: title,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            createdDate: .now,
            parentTask: parentTask,
            project: parentTask?.project ?? selectedProject,
            order: parentTask == nil ? nextOrder : nil,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            estimatedSeconds: finalEstimate,
            hasCustomEstimate: hasCustomEstimate && finalEstimate != nil
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
