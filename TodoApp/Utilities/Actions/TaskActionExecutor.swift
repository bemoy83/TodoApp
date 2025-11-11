import Foundation
import SwiftData

// MARK: - KPI Update Hook

/// Callback type for triggering KPI recalculation after task actions
/// Use this to trigger analytics updates when tasks are completed or archived
typealias KPIUpdateHook = () -> Void

/// Pure business logic for task actions.
/// NOTE: This does not replace existing code; it's an additive layer you can call from routers or views.
/// - No SwiftUI, no haptics, no alerts.
/// - Delegates to existing Task/TaskService methods where appropriate.
/// - Supports optional KPI update hooks for analytics integration
enum TaskActionExecutor {
    
    // MARK: - Completion

    /// Complete a task, optionally forcing past blocks.
    /// - Parameters:
    ///   - task: Task to complete
    ///   - force: If true, bypasses blocking checks
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after completion
    /// - Throws: TaskActionExecError.taskBlocked if task is blocked and force == false
    /// - Note: Triggers KPI update - task completion affects efficiency and accuracy metrics
    static func complete(_ task: Task, force: Bool = false, onKPIUpdate: KPIUpdateHook? = nil) throws {
        guard force || task.canComplete else {
            throw TaskActionExecError.taskBlocked(dependencies: task.blockingDependencies)
        }
        task.completeTask() // existing Task API

        // Trigger KPI recalculation (completed task affects metrics)
        onKPIUpdate?()
    }
    
    /// Uncomplete a task (remove completion date).
    /// - Parameters:
    ///   - task: Task to uncomplete
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after uncomplete
    /// - Note: Triggers KPI update - uncompleting affects efficiency and accuracy metrics
    static func uncomplete(_ task: Task, onKPIUpdate: KPIUpdateHook? = nil) {
        task.completedDate = nil

        // Trigger KPI recalculation (uncompleted task affects metrics)
        onKPIUpdate?()
    }

    /// Complete a task and all its incomplete subtasks recursively.
    /// - Parameters:
    ///   - task: Task to complete
    ///   - force: If true, bypasses blocking checks
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after completion
    /// - Throws: TaskActionExecError.taskBlocked if task is blocked and force == false
    /// - Note: Triggers KPI update once after all completions - affects efficiency metrics
    static func completeWithSubtasks(_ task: Task, force: Bool = false, onKPIUpdate: KPIUpdateHook? = nil) throws {
        // Complete the parent task first (without triggering KPI yet)
        try complete(task, force: force, onKPIUpdate: nil)

        // Complete all incomplete subtasks recursively
        if let subtasks = task.subtasks {
            for subtask in subtasks where !subtask.isCompleted {
                try? completeWithSubtasks(subtask, force: force, onKPIUpdate: nil)
            }
        }

        // Trigger KPI recalculation once after all completions
        onKPIUpdate?()
    }

    /// Uncomplete a task and all its completed subtasks recursively.
    /// - Parameters:
    ///   - task: Task to uncomplete
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after uncomplete
    /// - Note: Triggers KPI update once after all uncompletes - affects efficiency metrics
    static func uncompleteWithSubtasks(_ task: Task, onKPIUpdate: KPIUpdateHook? = nil) {
        // Uncomplete the parent task (without triggering KPI yet)
        uncomplete(task, onKPIUpdate: nil)

        // Uncomplete all completed subtasks recursively
        if let subtasks = task.subtasks {
            for subtask in subtasks where subtask.isCompleted {
                uncompleteWithSubtasks(subtask, onKPIUpdate: nil)
            }
        }

        // Trigger KPI recalculation once after all uncompletes
        onKPIUpdate?()
    }

    /// Count incomplete subtasks recursively.
    static func countIncompleteSubtasks(_ task: Task) -> Int {
        guard let subtasks = task.subtasks else { return 0 }

        var count = 0
        for subtask in subtasks {
            if !subtask.isCompleted {
                count += 1
                count += countIncompleteSubtasks(subtask)
            }
        }
        return count
    }

    /// Count completed subtasks recursively.
    static func countCompletedSubtasks(_ task: Task) -> Int {
        guard let subtasks = task.subtasks else { return 0 }

        var count = 0
        for subtask in subtasks {
            if subtask.isCompleted {
                count += 1
                count += countCompletedSubtasks(subtask)
            }
        }
        return count
    }

    /// Check if all direct subtasks of a task are complete.
    static func areAllSubtasksComplete(_ task: Task) -> Bool {
        guard let subtasks = task.subtasks, !subtasks.isEmpty else {
            return false // No subtasks means not applicable
        }
        return subtasks.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Timer
    
    /// Start timer on task.
    /// - Parameters:
    ///   - task: Task to start timer on
    ///   - force: If true, bypasses blocking checks
    /// - Throws: TaskActionExecError.taskBlocked or TaskActionExecError.timerAlreadyRunning
    static func startTimer(_ task: Task, force: Bool = false) throws {
        guard force || task.canComplete else {
            throw TaskActionExecError.taskBlocked(dependencies: task.blockingDependencies)
        }
        guard !task.hasActiveTimer else {
            throw TaskActionExecError.timerAlreadyRunning
        }
        task.startTimer() // existing Task API
    }
    
    /// Stop active timer on task.
    /// - Throws: TaskActionExecError.noActiveTimer if no timer is running
    static func stopTimer(_ task: Task) throws {
        guard task.hasActiveTimer else {
            throw TaskActionExecError.noActiveTimer
        }
        task.stopTimer() // existing Task API
    }
    
    // MARK: - CRUD
    
    /// Delete task (delegates to existing TaskService).
    static func delete(_ task: Task, context: ModelContext) {
        TaskService.deleteTask(task, context: context)
    }
    
    /// Duplicate task (delegates to existing TaskService).
    /// - Returns: Newly created duplicate
    @discardableResult
    static func duplicate(_ task: Task, context: ModelContext) -> Task {
        TaskService.duplicateTask(task, context: context)
    }
    
    // MARK: - Updates
    
    /// Update task priority.
    static func setPriority(_ task: Task, priority: Int) {
        task.priority = priority
    }
    
    /// Move task to a project (or nil for no project).
    static func moveToProject(_ task: Task, project: Project?) {
        task.project = project
    }

    // MARK: - Archive

    /// Archive a task (delegates to ArchiveManager).
    /// - Parameters:
    ///   - task: Task to archive
    ///   - allTasks: All tasks in the context (needed for validation)
    ///   - context: Model context for saving
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after archiving
    /// - Throws: TaskActionExecError.cannotArchive if task cannot be archived
    /// - Note: Triggers KPI update - archiving affects task lifecycle metrics
    static func archive(_ task: Task, allTasks: [Task], context: ModelContext, onKPIUpdate: KPIUpdateHook? = nil) throws {
        let validation = ArchiveManager.validateArchive(task: task, allTasks: allTasks)

        guard validation.canArchive else {
            throw TaskActionExecError.cannotArchive(
                blockingIssues: validation.blockingIssues,
                warnings: validation.warnings
            )
        }

        // If there are warnings, throw them so the UI can show confirmation
        if validation.hasWarnings {
            throw TaskActionExecError.archiveWarning(warnings: validation.warnings)
        }

        ArchiveManager.archive(task: task, allTasks: allTasks, modelContext: context)

        // Trigger KPI recalculation (archived task affects lifecycle metrics)
        onKPIUpdate?()
    }

    /// Unarchive a task (delegates to ArchiveManager).
    /// - Parameters:
    ///   - task: Task to unarchive
    ///   - allTasks: All tasks in the context
    ///   - context: Model context for saving
    ///   - onKPIUpdate: Optional callback to trigger KPI recalculation after unarchiving
    /// - Note: Triggers KPI update - unarchiving affects task lifecycle metrics
    static func unarchive(_ task: Task, allTasks: [Task], context: ModelContext, onKPIUpdate: KPIUpdateHook? = nil) {
        ArchiveManager.unarchive(task: task, allTasks: allTasks, modelContext: context)

        // Trigger KPI recalculation (unarchived task affects lifecycle metrics)
        onKPIUpdate?()
    }
}

// MARK: - Errors

enum TaskActionExecError: LocalizedError {
    case taskBlocked(dependencies: [Task])
    case timerAlreadyRunning
    case noActiveTimer
    case cannotArchive(blockingIssues: [String], warnings: [String])
    case archiveWarning(warnings: [String])

    var errorDescription: String? {
        switch self {
        case .taskBlocked(let deps):
            if deps.isEmpty {
                return "Task is blocked"
            } else if deps.count == 1 {
                return "Blocked by: \(deps[0].title)"
            } else {
                let names = deps.prefix(2).map { $0.title }.joined(separator: ", ")
                let more = deps.count > 2 ? " +\(deps.count - 2) more" : ""
                return "Blocked by: \(names)\(more)"
            }
        case .timerAlreadyRunning:
            return "Timer is already running"
        case .noActiveTimer:
            return "No active timer to stop"
        case .cannotArchive(let issues, _):
            return "Cannot Archive: \(issues.first ?? "Unknown error")"
        case .archiveWarning(let warnings):
            return warnings.joined(separator: "\n")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .taskBlocked:
            return "Complete blocking tasks first, or use \"Force Complete\"."
        case .timerAlreadyRunning:
            return "Stop the current timer before starting a new one."
        case .noActiveTimer:
            return "Start a timer before trying to stop it."
        case .cannotArchive(let issues, _):
            if issues.count > 1 {
                return issues.dropFirst().joined(separator: "\n")
            }
            return nil
        case .archiveWarning:
            return "Archive anyway?"
        }
    }
}
