import SwiftUI
import SwiftData

/// Quick Actions / "More" for a Task. Executes via TaskActionRouter.
/// Shows: Edit, Add Subtask, Duplicate, Add Dependency, Delete.
/// Cleaned up duplicates: Priority (now in context menu + TaskEditView), Move to Project (in TaskEditView).
struct TaskMoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: Task

    // Projects are top-level containers; subtasks inherit parent project.
    @Query(sort: \Project.order, order: .forward) private var projects: [Project]

    // All tasks for dependency picker
    @Query(sort: \Task.order) private var allTasks: [Task]

    // Navigation callbacks owned by parent (edit + add-subtask UIs)
    var onEdit: () -> Void
    var onAddSubtask: () -> Void

    // Alert state for executor-backed router path
    @State private var currentAlert: TaskActionAlert?

    // ✅ NEW: State for move to task picker
    @State private var showingMoveToTaskPicker = false

    // ✅ NEW: State for dependency picker
    @State private var showingDependencyPicker = false

    var body: some View {
        let router = TaskActionRouter()
        let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        NavigationStack {
            List {
                // Quick Actions from availability
                Section("Quick Actions") {
                    let profile = TaskActionAvailability.profile(for: .init(
                        isCompleted: task.isCompleted,
                        isSubtask: task.parentTask != nil,
                        hasActiveTimer: task.hasActiveTimer,
                        inProjectDetail: false
                    ))
                    ForEach(profile.quickActions, id: \.selfHash) { action in
                        let meta = action.metadata
                        Button {
                            switch action {
                            case .edit:
                                var alerted = false
                                _ = router.performWithExecutor(.edit, on: task, context: ctx) { alert in
                                    alerted = true
                                    currentAlert = wrapForAutoDismiss(alert)
                                }
                                if !alerted {
                                    dismiss()
                                    onEdit()
                                }

                            case .addSubtask:
                                var alerted = false
                                _ = router.performWithExecutor(.addSubtask, on: task, context: ctx) { alert in
                                    alerted = true
                                    currentAlert = wrapForAutoDismiss(alert)
                                }
                                if !alerted {
                                    dismiss()
                                    onAddSubtask()
                                }

                            default:
                                var alerted = false
                                _ = router.performWithExecutor(action, on: task, context: ctx) { alert in
                                    alerted = true
                                    currentAlert = wrapForAutoDismiss(alert)
                                }
                                if !alerted {
                                    dismiss()
                                }
                            }
                        } label: {
                            Label(meta.label, systemImage: meta.systemImage)
                                .tint(meta.preferredTint)
                        }
                        .accessibilityLabel(meta.label)
                    }
                }
                
                // ✅ Relationships section
                Section("Relationships") {
                    // Add Dependency
                    Button {
                        showingDependencyPicker = true
                    } label: {
                        Label("Add Dependency", systemImage: "arrow.triangle.branch")
                    }
                    .accessibilityLabel("Add Dependency")

                    // Move to Another Task (subtasks only)
                    if task.parentTask != nil {
                        Button {
                            showingMoveToTaskPicker = true
                        } label: {
                            Label("Move to Another Task", systemImage: "arrow.left.arrow.right")
                        }
                        .accessibilityLabel("Move to Another Task")
                    }
                }

                // Destructive
                Section {
                    Button(role: .destructive) {
                        // Always confirm via executor; we auto-dismiss after user picks any button.
                        _ = router.performWithExecutor(.delete, on: task, context: ctx) { alert in
                            currentAlert = wrapForAutoDismiss(alert)
                        }
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                    .tint(DesignSystem.Colors.error)
                    .accessibilityLabel("Delete Task")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Present alerts from executor anywhere in this sheet
        .taskActionAlert(alert: $currentAlert)
        // ✅ NEW: Sheet for moving subtask to another parent task
        .sheet(isPresented: $showingMoveToTaskPicker) {
            MoveToTaskPicker(task: task)
        }
        // ✅ NEW: Sheet for adding dependencies
        .sheet(isPresented: $showingDependencyPicker) {
            DependencyPickerView(
                task: task,
                allTasks: TaskService.availableDependencies(for: task, from: allTasks)
            )
        }
    }

    // MARK: - Helpers

    /// Ensures the sheet dismisses after *any* alert action (cancel / confirm / destructive).
    private func wrapForAutoDismiss(_ alert: TaskActionAlert) -> TaskActionAlert {
        TaskActionAlert(
            title: alert.title,
            message: alert.message,
            actions: alert.actions.map { act in
                AlertAction(title: act.title, role: act.role) {
                    act.action()
                    // Defer to next runloop to avoid overlapping alert + sheet transitions.
                    DispatchQueue.main.async { dismiss() }
                }
            }
        )
    }

}

// Hash helper for parameterized actions
private extension TaskAction {
    var selfHash: String {
        switch self {
        case .complete: return "complete"
        case .uncomplete: return "uncomplete"
        case .startTimer: return "startTimer"
        case .stopTimer: return "stopTimer"
        case .duplicate: return "duplicate"
        case .setPriority(let v): return "setPriority_\(v)"
        case .moveToProject(let p): return "moveToProject_\(p.id.uuidString)"
        case .addSubtask: return "addSubtask"
        case .delete: return "delete"
        case .edit: return "edit"
        }
    }
}
