//
//  TaskActionAlert.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//
import SwiftUI

// MARK: - Alert Model

struct TaskActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actions: [AlertAction]
}

struct AlertAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void
}

// MARK: - View Modifier

extension View {
    /// Present TaskActionAlert as a native SwiftUI alert.
    /// Attach this once at a screen/list level and bind to a @State TaskActionAlert?.
    func taskActionAlert(
        alert: Binding<TaskActionAlert?>
    ) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { alertValue in
            ForEach(alertValue.actions.indices, id: \.self) { index in
                Button(
                    alertValue.actions[index].title,
                    role: alertValue.actions[index].role
                ) {
                    alertValue.actions[index].action()
                }
            }
        } message: { alertValue in
            Text(alertValue.message)
        }
    }
}

// MARK: - Factory Methods

extension TaskActionAlert {
    /// Alert when a task is blocked.
    /// - Parameters:
    ///   - task: The blocked task
    ///   - actionName: Action being attempted (e.g., "complete", "start timer")
    ///   - onForce: Callback to force the action anyway (destructive)
    static func blockedTask(
        task: Task,
        actionName: String = "complete",
        onForce: @escaping () -> Void
    ) -> TaskActionAlert {
        let deps = task.blockingDependencies
        var message = "This task is blocked and cannot be \(actionName)d."

        if !deps.isEmpty {
            if deps.count == 1 {
                message += "\n\nBlocked by:\n• \(deps[0].title)"
            } else {
                let names = deps.prefix(3).map { $0.title }.joined(separator: "\n• ")
                let more = deps.count > 3 ? "\n• ... and \(deps.count - 3) more" : ""
                message += "\n\nBlocked by:\n• \(names)\(more)"
            }
        }

        return TaskActionAlert(
            title: "Task Blocked",
            message: message,
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Force \(actionName.capitalized)", role: .destructive, action: onForce)
            ]
        )
    }

    /// Confirm deletion of a single task.
    static func confirmDelete(
        task: Task,
        onConfirm: @escaping () -> Void
    ) -> TaskActionAlert {
        var message = "Are you sure you want to delete \"\(task.title)\"?"

        let subCount = task.subtasks?.count ?? 0
        if subCount > 0 {
            message += "\n\nThis will also delete \(subCount) subtask\(subCount == 1 ? "" : "s")."
        }
        message += "\n\nThis action cannot be undone."

        return TaskActionAlert(
            title: "Delete Task?",
            message: message,
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Delete", role: .destructive, action: onConfirm)
            ]
        )
    }

    /// Confirm deletion of multiple tasks.
    static func confirmBulkDelete(
        count: Int,
        onConfirm: @escaping () -> Void
    ) -> TaskActionAlert {
        TaskActionAlert(
            title: "Delete \(count) Tasks?",
            message: "This will permanently delete \(count) task\(count == 1 ? "" : "s").\n\nThis action cannot be undone.",
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Delete All", role: .destructive, action: onConfirm)
            ]
        )
    }

    /// Timer already running: offer to stop it.
    static func timerAlreadyRunning(
        onStop: @escaping () -> Void
    ) -> TaskActionAlert {
        TaskActionAlert(
            title: "Timer Already Running",
            message: "A timer is already active for this task. Stop the current timer before starting a new one.",
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Stop Timer", role: .none, action: onStop)
            ]
        )
    }

    /// No active timer present.
    static func noActiveTimer() -> TaskActionAlert {
        TaskActionAlert(
            title: "No Active Timer",
            message: "There is no timer currently running for this task.",
            actions: [
                AlertAction(title: "OK", role: .cancel, action: {})
            ]
        )
    }

    /// Confirm completing parent task with incomplete subtasks.
    static func confirmCompleteWithSubtasks(
        task: Task,
        incompleteCount: Int,
        onConfirm: @escaping () -> Void
    ) -> TaskActionAlert {
        let message = "This will also complete \(incompleteCount) incomplete subtask\(incompleteCount == 1 ? "" : "s")."

        return TaskActionAlert(
            title: "Complete Task?",
            message: message,
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Complete All", role: .none, action: onConfirm)
            ]
        )
    }

    /// Confirm uncompleting parent task with completed subtasks.
    static func confirmUncompleteWithSubtasks(
        task: Task,
        completedCount: Int,
        onUncompleteAll: @escaping () -> Void,
        onUncompleteParentOnly: @escaping () -> Void
    ) -> TaskActionAlert {
        let message = "This task has \(completedCount) completed subtask\(completedCount == 1 ? "" : "s"). What would you like to do?"

        return TaskActionAlert(
            title: "Uncomplete Task?",
            message: message,
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Just Parent", role: .none, action: onUncompleteParentOnly),
                AlertAction(title: "Uncomplete All", role: .none, action: onUncompleteAll)
            ]
        )
    }

    /// Confirm completing parent task after all subtasks are complete.
    static func confirmCompleteParent(
        parentTask: Task,
        onConfirm: @escaping () -> Void
    ) -> TaskActionAlert {
        let message = "All subtasks are now complete. Would you like to also complete \"\(parentTask.title)\"?"

        return TaskActionAlert(
            title: "Complete Parent Task?",
            message: message,
            actions: [
                AlertAction(title: "Not Now", role: .cancel, action: {}),
                AlertAction(title: "Complete Parent", role: .none, action: onConfirm)
            ]
        )
    }

    /// Alert when a blocked task also has incomplete subtasks.
    static func blockedTaskWithSubtasks(
        task: Task,
        incompleteCount: Int,
        onForceCompleteAll: @escaping () -> Void
    ) -> TaskActionAlert {
        let deps = task.blockingDependencies
        var message = "This task is blocked and has \(incompleteCount) incomplete subtask\(incompleteCount == 1 ? "" : "s")."

        if !deps.isEmpty {
            if deps.count == 1 {
                message += "\n\nBlocked by:\n• \(deps[0].title)"
            } else {
                let names = deps.prefix(3).map { $0.title }.joined(separator: "\n• ")
                let more = deps.count > 3 ? "\n• ... and \(deps.count - 3) more" : ""
                message += "\n\nBlocked by:\n• \(names)\(more)"
            }
        }

        return TaskActionAlert(
            title: "Task Blocked",
            message: message,
            actions: [
                AlertAction(title: "Cancel", role: .cancel, action: {}),
                AlertAction(title: "Force Complete All", role: .destructive, action: onForceCompleteAll)
            ]
        )
    }
}

// MARK: - Optional: Map Executor Errors → Alerts

extension TaskActionAlert {
    /// Convert `TaskActionExecError` into a user-facing alert.
    /// Provide closures for force/stop paths as needed (defaults are no-ops).
    static func fromExecutorError(
        _ error: TaskActionExecError,
        task: Task,
        onForce: @escaping () -> Void = {},
        onStop: @escaping () -> Void = {}
    ) -> TaskActionAlert {
        switch error {
        case .taskBlocked:
            return .blockedTask(task: task, actionName: "complete", onForce: onForce)
        case .timerAlreadyRunning:
            return .timerAlreadyRunning(onStop: onStop)
        case .noActiveTimer:
            return .noActiveTimer()
        }
    }
}
