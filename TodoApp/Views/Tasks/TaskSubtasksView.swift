import SwiftUI
import SwiftData

struct TaskSubtasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    
    @Query(sort: \Task.order) private var allTasks: [Task]

    @State private var showingAddSubtask = false
    @State private var editingSubtask: Task?
    @State private var showingMoreSheetFor: Task?
    @State private var currentAlert: TaskActionAlert?

    private let router = TaskActionRouter()

    private var unifiedCtx: TaskActionRouter.Context {
        .init(modelContext: modelContext, hapticsEnabled: true)
    }

    private var canAddSubtasks: Bool { task.parentTask == nil }
    private var subtasks: [Task] {
            allTasks
                .filter { $0.parentTask?.id == task.id }
                .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
        }

    var body: some View {
        GroupBox("Subtasks") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

                if subtasks.isEmpty {
                    Text("No subtasks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            alert: $currentAlert,
                            onToggleComplete: { handleSubtaskCompletion(subtask) },
                            onEdit: { editingSubtask = subtask },
                            onMore: { showingMoreSheetFor = subtask }
                        )
                        .padding(.vertical, 4)
                    }
                    if canAddSubtasks { Divider() }
                }

                if canAddSubtasks {
                    Button {
                        showingAddSubtask = true
                    } label: {
                        Label("Add Subtask", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Subtasks can't have subtasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)

        // ✅ New subtask - uses AddTaskView (no phantom tasks)
        .sheet(isPresented: $showingAddSubtask) {
            AddTaskView(
                project: task.project,
                parentTask: task
            ) { newSubtask in
                // Task already inserted by AddTaskView
                if task.subtasks == nil { task.subtasks = [] }
                task.subtasks?.append(newSubtask)
            }
        }

        // Edit existing subtask
        .sheet(item: $editingSubtask) { sub in
            TaskEditView(task: sub)
        }

        // Shared More sheet
        .sheet(item: $showingMoreSheetFor) { sub in
            TaskMoreActionsSheet(
                task: sub,
                onEdit: { editingSubtask = sub },
                onAddSubtask: { /* hidden for subtasks */ }
            )
        }

        .taskActionAlert(alert: $currentAlert)
    }

    // MARK: - Actions

    private func handleSubtaskCompletion(_ subtask: Task) {
        let action: TaskAction = subtask.isCompleted ? .uncomplete : .complete
        _ = router.performWithExecutor(action, on: subtask, context: unifiedCtx) { alert in
            currentAlert = alert
        }
    }
}

// MARK: - Subtask Row

private struct SubtaskRow: View {
    @Bindable var subtask: Task
    @Binding var alert: TaskActionAlert?

    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            SubtaskStatusButton(
                subtask: subtask,
                action: onToggleComplete,
                size: .standard
            )

            NavigationLink(destination: TaskDetailView(task: subtask)) {
                HStack {
                    SubtaskRowContent(subtask: subtask, style: .detailed)
                    Spacer()
                    
                    if subtask.hasActiveTimer {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .rowContextMenu(
            task: subtask,
            isEnabled: true,
            onEdit: onEdit,
            onMore: onMore,
            alert: $alert
        )
        .rowSwipeActions(
            task: subtask,
            isEnabled: true,
            onMore: onMore,
            alert: $alert
        )
    }
}
