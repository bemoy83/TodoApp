import SwiftUI
import SwiftData
internal import Combine

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @ObservedObject private var expansionState = TaskExpansionState.shared
    
    @Query(sort: \Task.order) private var allTasks: [Task]

    @Bindable var task: Task
    var onOpen: () -> Void = {}

    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false
    @State private var showingAddSubtaskSheet = false

    @State private var draftSubtask: Task?
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
        task.dueDate ?? task.parentTask?.dueDate
    }
    
    private var isDueDateInherited: Bool {
        task.dueDate == nil && task.parentTask?.dueDate != nil
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
        shouldShowDueDate || task.hasActiveTimer || calculations.hasSubtasks || task.effectiveEstimate != nil
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
        HStack(spacing: 0) {
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
                        // Title with priority and subtask badge
                        TaskRowTitleSection(
                            task: task,
                            shouldShowPriority: shouldShowPriority,
                            taskPriority: taskPriority,
                            subtaskBadge: calculations.hasSubtasks ?
                                TaskRowTitleSection.SubtaskBadgeData(
                                    completed: calculations.completedDirectSubtaskCount,
                                    total: calculations.subtaskCount
                                ) : nil
                        )
                        
                        // Badges (only shown if has content)
                        TaskRowMetadataSection(
                            task: task,
                            calculations: calculations,
                            shouldShowDueDate: shouldShowDueDate,
                            effectiveDueDate: effectiveDueDate,
                            isDueDateInherited: isDueDateInherited
                        )
                        
                        // Progress bar
                        TaskRowProgressBar(
                            task: task,
                            calculations: calculations
                        )
                        
                        // Expand/collapse chevron
                        if calculations.hasSubtasks {
                            HStack {
                                Spacer()
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
                                Spacer()
                            }
                        }
                    }
                } else {
                    // Simple title-only view when no metadata
                    TaskRowTitleSection(
                        task: task,
                        shouldShowPriority: shouldShowPriority,
                        taskPriority: taskPriority,
                        subtaskBadge: calculations.hasSubtasks ?
                            TaskRowTitleSection.SubtaskBadgeData(
                                completed: calculations.completedDirectSubtaskCount,
                                total: calculations.subtaskCount
                            ) : nil
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
        .sheet(isPresented: $showingAddSubtaskSheet, onDismiss: { draftSubtask = nil }) {
            if let subtask = draftSubtask {
                TaskEditView(
                    task: subtask,
                    isNewTask: true,
                    onSave: { new in
                        modelContext.insert(new)
                        if task.subtasks == nil { task.subtasks = [] }
                        task.subtasks?.append(new)
                        HapticManager.success()
                    },
                    onCancel: { }
                )
            }
        }
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: task,
                onEdit: { showingEditSheet = true },
                onAddSubtask: {
                    showingMoreSheet = false
                    let draft = Task(
                        title: "",
                        priority: task.priority,
                        createdDate: Date(),
                        parentTask: task,
                        project: task.project
                    )
                    DispatchQueue.main.async {
                        self.draftSubtask = draft
                        self.showingAddSubtaskSheet = true
                    }
                }
            )
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            // Update current time when any timer is active
            // 30-second refresh for list view
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

    private let gutterWidth: CGFloat = 36
    

    var body: some View {
        ZStack(alignment: .leading) {
            if let color {
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                    .fill(color)
                    .frame(width: DesignSystem.Spacing.xs)
                    .frame(height: DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .alignmentGuide(.top) { d in d[.top] }
            }
            Button(action: onToggle) {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: DesignSystem.Spacing.xxl, height: DesignSystem.Spacing.xxl)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.smooth(duration: 0.3), value: statusIcon)
            }
            .buttonStyle(.plain)
            .padding(.leading, DesignSystem.Spacing.sm)  // Reduced from .md
        }
        .frame(width: gutterWidth, alignment: .leading)
    }
}
