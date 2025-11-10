//
//  TaskExpandedSubtasksView.swift
//  TodoApp
//

import SwiftUI
import SwiftData

/// Displays a parent task's subtasks inline with full actions.
/// Shown when parent is expanded in TaskListView.
struct TaskExpandedSubtasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Bindable var parentTask: Task

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]
    
    @State private var currentAlert: TaskActionAlert?
    
    private let router = TaskActionRouter()
    
    private var context: TaskActionRouter.Context {
        TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
    }
    
    private var subtasks: [Task] {
        allTasks
            .filter { $0.parentTask?.id == parentTask.id }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    
    private var isEditMode: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
    
    var body: some View {
        ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
            NavigationLink {
                TaskDetailView(task: subtask)
            } label: {
                ExpandedSubtaskRow(
                    subtask: subtask,
                    router: router,
                    context: context,
                    alert: $currentAlert,
                    isFirst: index == 0,
                    isLast: index == subtasks.count - 1,
                    isEditMode: isEditMode
                )
            }
            .buttonStyle(.plain)
            .disabled(isEditMode)
            .listRowSeparator(.hidden)
            .listRowSpacing(0)  // ✅ ADD THIS
            .listRowInsets(EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: DesignSystem.Spacing.lg
            ))
            .listRowBackground(
                Group {
                    if index == subtasks.count - 1 {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: DesignSystem.CornerRadius.md,
                            bottomTrailingRadius: DesignSystem.CornerRadius.md,
                            topTrailingRadius: 0
                        )
                        .fill(Color(UIColor.quaternarySystemFill))  // ✅ Back to gray
                    } else {
                        Rectangle()
                            .fill(Color(UIColor.quaternarySystemFill))  // ✅ Back to gray
                    }
                }
            )
        }
        .onMove { source, destination in
            reorderSubtasks(from: source, to: destination)
        }
        .taskActionAlert(alert: $currentAlert)
    }
    
    // MARK: - Reordering
    
    private func reorderSubtasks(from source: IndexSet, to destination: Int) {
        Reorderer.reorder(
            items: subtasks,
            currentOrder: { $0.order ?? Int.max },
            setOrder: { task, index in task.order = index },
            from: source,
            to: destination,
            save: { try modelContext.save() }
        )
        HapticManager.selection()
    }
}

// MARK: - Expanded Subtask Row

private struct ExpandedSubtaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var subtask: Task
    
    let router: TaskActionRouter
    let context: TaskActionRouter.Context
    @Binding var alert: TaskActionAlert?
    let isFirst: Bool
    let isLast: Bool
    let isEditMode: Bool
    
    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 0) {
                // Left indent (no bar)
                Color.clear
                    .frame(width: DesignSystem.Spacing.xl)
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Status icon
                    SubtaskStatusButton(
                        subtask: subtask,
                        action: {
                            let action: TaskAction = subtask.isCompleted ? .uncomplete : .complete
                            _ = router.performWithExecutor(action, on: subtask, context: context) { a in
                                alert = a
                            }
                        },
                        size: .compact
                    )
                    
                    // Content
                    SubtaskRowContent(subtask: subtask, style: .compact)
                    
                    Spacer()
                    
                    if subtask.hasActiveTimer {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.timerActive)
                            .pulsingAnimation(active: true)
                    }
                }
                .padding(.leading, DesignSystem.Spacing.sm)
                .padding(.trailing, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            
            // Divider between subtasks
            if !isLast {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.xl + DesignSystem.Spacing.xxl)
            }
        }
        .contentShape(Rectangle())
        
        .rowSwipeActions(
            task: subtask,
            isEnabled: !isEditMode,
            onMore: { showingMoreSheet = true },
            alert: $alert
        )
        
        .rowContextMenu(
            task: subtask,
            isEnabled: !isEditMode,
            onEdit: { showingEditSheet = true },
            onMore: { showingMoreSheet = true },
            alert: $alert
        )
        
        .sheet(isPresented: $showingEditSheet) {
            TaskEditView(task: subtask)
        }
        
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: subtask,
                onEdit: { showingEditSheet = true },
                onAddSubtask: { }
            )
        }
    }
}
