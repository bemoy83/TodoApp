import Foundation
import SwiftData

/// Pure business logic for task actions.
/// NOTE: This does not replace existing code; it’s an additive layer you can call from routers or views.
/// - No SwiftUI, no haptics, no alerts.
/// - Delegates to existing Task/TaskService methods where appropriate.
enum TaskActionExecutor {
    
    // MARK: - Completion
    
    /// Complete a task, optionally forcing past blocks.
    /// - Parameters:
    ///   - task: Task to complete
    ///   - force: If true, bypasses blocking checks
    /// - Throws: TaskActionExecError.taskBlocked if task is blocked and force == false
    static func complete(_ task: Task, force: Bool = false) throws {
        guard force || task.canComplete else {
            throw TaskActionExecError.taskBlocked(dependencies: task.blockingDependencies)
        }
        task.completeTask() // existing Task API
    }
    
    /// Uncomplete a task (remove completion date).
    static func uncomplete(_ task: Task) {
        task.completedDate = nil
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
}

// MARK: - Errors

enum TaskActionExecError: LocalizedError {
    case taskBlocked(dependencies: [Task])
    case timerAlreadyRunning
    case noActiveTimer
    
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
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .taskBlocked:
            return "Complete blocking tasks first, or use “Force Complete”."
        case .timerAlreadyRunning:
            return "Stop the current timer before starting a new one."
        case .noActiveTimer:
            return "Start a timer before trying to stop it."
        }
    }
}
