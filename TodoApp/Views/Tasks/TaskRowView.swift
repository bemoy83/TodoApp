import SwiftUI
import SwiftData
internal import Combine

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @ObservedObject private var expansionState = TaskExpansionState.shared

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @Bindable var task: Task
    var onOpen: () -> Void = {}

    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false
    @State private var showingAddSubtaskSheet = false

    @State private var currentAlert: TaskActionAlert?
    @State private var currentTime = Date()

    private let router = TaskActionRouter()

    // MARK: - Computed Properties
    
    private var calculations: TaskRowCalculations {
        TaskRowCalculations(task: task, allTasks: allTasks, currentTime: currentTime)
    }
    
    private var unifiedCtx: TaskActionRouter.Context {
        TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
    }
    
    private var effectiveDueDate: Date? {
        task.effectiveDeadline ?? task.parentTask?.effectiveDeadline
    }

    private var isDueDateInherited: Bool {
        task.effectiveDeadline == nil && task.parentTask?.effectiveDeadline != nil
    }
    
    private var taskPriority: Priority {
        Priority(rawValue: task.priority) ?? .medium
    }
    
    private var shouldShowPriority: Bool {
        task.priority <= 1
    }
    
    private var shouldShowDueDate: Bool {
        guard let dueDate = effectiveDueDate else { return false }
        let cal = Calendar.current
        return dueDate < Date() || cal.isDateInToday(dueDate) || cal.isDateInTomorrow(dueDate)
    }
    
    private var hasMetadata: Bool {
        shouldShowDueDate || task.hasActiveTimer || calculations.hasSubtasks || task.effectiveEstimate != nil || task.hasDateConflicts || !(task.tags?.isEmpty ?? true)
    }
    
    private var isEditingList: Bool {
        (editMode?.wrappedValue.isEditing) ?? false
    }

    private var isExpanded: Bool {
        expansionState.isExpanded(task.id)
    }

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }

    // MARK: - Body
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            LeadingGutter(
                color: task.project.map { Color(hex: $0.color) },
                onToggle: {
                    let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                    _ = router.performWithExecutor(action, on: task, context: unifiedCtx) { alert in
                        currentAlert = alert
                    }
                },
                statusIcon: task.status.icon,
                statusColor: statusColor
            )

            HStack(spacing: DesignSystem.Spacing.xs) {
                if hasMetadata {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        // Title with priority
                        TaskRowTitleSection(
                            task: task,
                            shouldShowPriority: shouldShowPriority,
                            taskPriority: taskPriority
                        )

                        // Badges (only shown if has content)
                        TaskRowMetadataSection(
                            task: task,
                            calculations: calculations,
                            shouldShowDueDate: shouldShowDueDate,
                            effectiveDueDate: effectiveDueDate,
                            isDueDateInherited: isDueDateInherited
                        )

                        // Progress bar with subtask badge
                        TaskRowProgressBar(
                            task: task,
                            calculations: calculations,
                            subtaskBadge: calculations.hasSubtasks ?
                                TaskRowProgressBar.SubtaskBadgeData(
                                    completed: calculations.completedDirectSubtaskCount,
                                    total: calculations.subtaskCount
                                ) : nil
                        )
                        
                        // Expand/collapse chevron (centered)
                        if calculations.hasSubtasks {
                            Button {
                                HapticManager.light()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    expansionState.toggle(task.id)
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                } else {
                    // Simple title-only view when no metadata
                    TaskRowTitleSection(
                        task: task,
                        shouldShowPriority: shouldShowPriority,
                        taskPriority: taskPriority
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                if task.hasActiveTimer {
                    Image(systemName: "timer")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.timerActive)
                        .contentTransition(.symbolEffect(.replace))
                        .pulsingAnimation(active: task.hasActiveTimer)
                }
            }
        }
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: DesignSystem.Spacing.xs,
            bottom: 0,
            trailing: DesignSystem.Spacing.xs
        ))
        .rowContextMenu(
            task: task,
            isEnabled: !isEditingList,
            onEdit: { showingEditSheet = true },
            onMore: { showingMoreSheet = true },
            onAddSubtask: {
                // Small delay to let context menu fully dismiss before presenting sheet
                // Prevents @Query timeout in AddTaskView from nested modal state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.showingAddSubtaskSheet = true
                }
            },
            alert: $currentAlert
        )
        .rowSwipeActions(
            task: task,
            isEnabled: !isEditingList,
            onMore: { showingMoreSheet = true },
            alert: $currentAlert
        )
        .taskActionAlert(alert: $currentAlert)
        .sheet(isPresented: $showingEditSheet) {
            TaskEditView(task: task)
        }
        .sheet(isPresented: $showingAddSubtaskSheet) {
            AddTaskView(
                project: task.project,
                parentTask: task
            ) { newSubtask in
                // Task already inserted by AddTaskView
                // Calculate and assign order for subtask reordering support
                let maxOrder = (task.subtasks ?? []).compactMap(\.order).max() ?? -1
                newSubtask.order = maxOrder + 1

                if task.subtasks == nil { task.subtasks = [] }
                task.subtasks?.append(newSubtask)
            }
        }
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: task,
                onEdit: { showingEditSheet = true },
                onAddSubtask: {
                    showingMoreSheet = false
                    DispatchQueue.main.async {
                        self.showingAddSubtaskSheet = true
                    }
                }
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Update current time when any timer is active
            // 1-second refresh for accurate badge countdown
            if calculations.hasAnyTimerRunning {
                currentTime = Date()
            }
        }
    }
}

// MARK: - Leading Gutter
private struct LeadingGutter: View {
    let color: Color?
    let onToggle: () -> Void
    let statusIcon: String
    let statusColor: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Project color bar (slim, fixed height for alignment)
            if let color {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 3, height: 32)
            }

            // Status toggle button (centered between bar and content)
            Button(action: onToggle) {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.smooth(duration: 0.3), value: statusIcon)
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}
