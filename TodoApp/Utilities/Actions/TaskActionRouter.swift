// Utilities/TaskActionRouter.swift
import SwiftUI
import SwiftData

/// Thin coordinator that delegates to existing app logic:
/// - Destructive ops: TaskService
/// - Timers: Task.startTimer()/stopTimer()
/// - Haptics: HapticManager
struct TaskActionRouter {
    struct Context {
        let modelContext: ModelContext
        let hapticsEnabled: Bool
        init(modelContext: ModelContext, hapticsEnabled: Bool = true) {
            self.modelContext = modelContext
            self.hapticsEnabled = hapticsEnabled
        }
    }
}

// MARK: - New Executor-Based API (Coexists with existing methods)

extension TaskActionRouter {
    
    /// Perform action using the new Executor + Alerts system.
    /// This coexists with the original `perform(_:on:context:)` and does not change existing behavior.
    /// - Parameters:
    ///   - action: The action to perform
    ///   - task: The task to act on
    ///   - context: Execution context (modelContext, haptics)
    ///   - presentAlert: Callback that presents a `TaskActionAlert` to the user
    /// - Returns: Result indicating success or failure
    func performWithExecutor(
        _ action: TaskAction,
        on task: Task,
        context: Context,
        presentAlert: @escaping (TaskActionAlert) -> Void
    ) -> Result<Void, Error> {
        do {
            switch action {
            case .complete:
                // Helper to check if we should offer to complete parent after subtask completion
                let checkParentCompletion: () -> Void = {
                    // Check if this is a subtask and if parent should be offered for completion
                    if let parent = task.parentTask,
                       !parent.isCompleted,
                       TaskActionExecutor.areAllSubtasksComplete(parent) {
                        let parentAlert = TaskActionAlert.confirmCompleteParent(parentTask: parent) {
                            _ = try? TaskActionExecutor.complete(parent, force: false)
                            if context.hapticsEnabled { HapticManager.success() }
                        }
                        presentAlert(parentAlert)
                    }
                }

                // Check state: incomplete subtasks and blocking status
                let incompleteCount = TaskActionExecutor.countIncompleteSubtasks(task)
                let isBlocked = !task.canComplete

                // Route to appropriate alert based on state
                if isBlocked && incompleteCount > 0 {
                    // Blocked AND has subtasks: show combined alert
                    let alert = TaskActionAlert.blockedTaskWithSubtasks(
                        task: task,
                        incompleteCount: incompleteCount
                    ) {
                        _ = try? TaskActionExecutor.completeWithSubtasks(task, force: true)
                        if context.hapticsEnabled { HapticManager.success() }
                        checkParentCompletion()
                    }
                    presentAlert(alert)
                    return .success(())

                } else if isBlocked {
                    // Only blocked: show blocking alert
                    let alert = TaskActionAlert.blockedTask(task: task, actionName: "complete") {
                        _ = try? TaskActionExecutor.complete(task, force: true)
                        if context.hapticsEnabled { HapticManager.success() }
                        checkParentCompletion()
                    }
                    presentAlert(alert)
                    return .success(())

                } else if incompleteCount > 0 {
                    // Only has subtasks: show subtask warning
                    let alert = TaskActionAlert.confirmCompleteWithSubtasks(
                        task: task,
                        incompleteCount: incompleteCount
                    ) {
                        _ = try? TaskActionExecutor.completeWithSubtasks(task, force: false)
                        if context.hapticsEnabled { HapticManager.success() }
                        checkParentCompletion()
                    }
                    presentAlert(alert)
                    return .success(())

                } else {
                    // Neither blocked nor has subtasks: complete normally
                    try TaskActionExecutor.complete(task, force: false)
                    checkParentCompletion()
                }

            case .uncomplete:
                // Check for completed subtasks
                let completedCount = TaskActionExecutor.countCompletedSubtasks(task)

                if completedCount > 0 {
                    // Show alert with options
                    let alert = TaskActionAlert.confirmUncompleteWithSubtasks(
                        task: task,
                        completedCount: completedCount,
                        onUncompleteAll: {
                            TaskActionExecutor.uncompleteWithSubtasks(task)
                            if context.hapticsEnabled { HapticManager.light() }
                        },
                        onUncompleteParentOnly: {
                            TaskActionExecutor.uncomplete(task)
                            if context.hapticsEnabled { HapticManager.light() }
                        }
                    )
                    presentAlert(alert)
                    return .success(())
                } else {
                    // No completed subtasks, uncomplete normally
                    TaskActionExecutor.uncomplete(task)
                }

            case .startTimer:
                do {
                    try TaskActionExecutor.startTimer(task, force: false)
                } catch TaskActionExecError.taskBlocked {
                    let alert = TaskActionAlert.blockedTask(task: task, actionName: "start timer") {
                        _ = try? TaskActionExecutor.startTimer(task, force: true)
                        if context.hapticsEnabled { HapticManager.medium() }
                    }
                    presentAlert(alert)
                    return .success(())
                } catch TaskActionExecError.timerAlreadyRunning {
                    let alert = TaskActionAlert.timerAlreadyRunning {
                        _ = try? TaskActionExecutor.stopTimer(task)
                        if context.hapticsEnabled { HapticManager.light() }
                    }
                    presentAlert(alert)
                    return .success(())
                }

            case .stopTimer:
                do {
                    try TaskActionExecutor.stopTimer(task)
                } catch TaskActionExecError.noActiveTimer {
                    presentAlert(TaskActionAlert.noActiveTimer())
                    return .success(())
                }

            case .delete:
                // Always confirm deletes; perform actual deletion in the alert action.
                let alert = TaskActionAlert.confirmDelete(task: task) {
                    TaskActionExecutor.delete(task, context: context.modelContext)
                    if context.hapticsEnabled { HapticManager.warning() }
                }
                presentAlert(alert)
                return .success(())

            case .duplicate:
                _ = TaskActionExecutor.duplicate(task, context: context.modelContext)

            case .setPriority(let priority):
                TaskActionExecutor.setPriority(task, priority: priority)

            case .moveToProject(let project):
                TaskActionExecutor.moveToProject(task, project: project)

            case .addSubtask:
                // Intent-only; UI presents add-subtask surface.
                break

            case .edit:
                // Intent-only; UI presents edit surface.
                break
            }

            // Fire haptics after successful execution (no-op for intent-only actions).
            if context.hapticsEnabled {
                triggerHapticForAction(action)
            }
            return .success(())
        } catch {
            // Unexpected error path (should be rare since we handle known cases above).
            return .failure(error)
        }
    }

    /// Private helper: map actions to haptic styles.
    private func triggerHapticForAction(_ action: TaskAction) {
        switch action {
        case .complete, .duplicate:
            HapticManager.success()
        case .uncomplete, .stopTimer:
            HapticManager.light()
        case .startTimer:
            HapticManager.medium()
        case .delete:
            HapticManager.warning()
        case .setPriority, .moveToProject:
            HapticManager.selection()
        case .addSubtask, .edit:
            HapticManager.selection()
        }
    }
}
