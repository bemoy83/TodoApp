import SwiftUI
import SwiftData

/// Quick Actions / "More" for a Task. Executes via TaskActionRouter.
/// Shows: Edit, Add Subtask (if top-level), Duplicate, Priority, Move to Project, Delete.
struct TaskMoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: Task

    // Projects are top-level containers; subtasks inherit parent project.
    @Query(sort: \Project.order, order: .forward) private var projects: [Project]

    // Navigation callbacks owned by parent (edit + add-subtask UIs)
    var onEdit: () -> Void
    var onAddSubtask: () -> Void

    // Alert state for executor-backed router path
    @State private var currentAlert: TaskActionAlert?
    
    // ✅ NEW: State for move to task picker
    @State private var showingMoveToTaskPicker = false

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
                
                // ✅ NEW: Organization section for subtasks
                if task.parentTask != nil {
                    Section("Organization") {
                        Button {
                            showingMoveToTaskPicker = true
                        } label: {
                            Label("Move to Another Task", systemImage: "arrow.left.arrow.right")
                        }
                        .accessibilityLabel("Move to Another Task")
                    }
                }

                // Priority routes via executor; dismiss if no alert was shown
                Section("Priority") {
                    ForEach(Priority.allCases, id: \.self) { level in
                        Button {
                            var alerted = false
                            _ = router.performWithExecutor(.setPriority(level.rawValue), on: task, context: ctx) { alert in
                                alerted = true
                                currentAlert = wrapForAutoDismiss(alert)
                            }
                            if !alerted {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Label(level.label, systemImage: level.icon)
                                    .foregroundStyle(priorityColor(for: level))
                                Spacer()
                                if task.priority == level.rawValue {
                                    Image(systemName: "checkmark").accessibilityLabel("Selected")
                                }
                            }
                        }
                        .accessibilityLabel("\(level.label) Priority")
                    }
                }

                // Move to Project (top-level tasks only)
                if task.parentTask == nil, !projects.isEmpty {
                    Section("Move to Project") {
                        ForEach(projects) { project in
                            Button {
                                var alerted = false
                                _ = router.performWithExecutor(.moveToProject(project), on: task, context: ctx) { alert in
                                    alerted = true
                                    currentAlert = wrapForAutoDismiss(alert)
                                }
                                if !alerted {
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Circle()
                                        .fill(Color(hex: project.color))
                                        .frame(width: 12, height: 12)
                                        .accessibilityHidden(true)
                                    Text(project.title)
                                    Spacer()
                                    if task.project?.id == project.id {
                                        Image(systemName: "checkmark").accessibilityLabel("Current Project")
                                    }
                                }
                            }
                            .accessibilityLabel("Move to project \(project.title)")
                        }
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

    private func priorityColor(for level: Priority) -> Color {
        switch level {
        case .urgent: return DesignSystem.Colors.priorityUrgent
        case .high:   return DesignSystem.Colors.priorityHigh
        case .medium: return DesignSystem.Colors.priorityMedium
        case .low:    return DesignSystem.Colors.priorityLow
        }
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
