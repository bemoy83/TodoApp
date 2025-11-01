import Foundation
import SwiftData
import SwiftUI

/// Service layer for task-related business logic
@MainActor
final class TaskService {
    
    // MARK: - Task Duplication

    /// Creates a sibling duplicate of the given task.
    /// - Notes:
    ///   - Copies: title, priority, dueDate, notes, project, parentTask, estimatedSeconds, hasCustomEstimate
    ///   - Resets: completedDate (nil), createdDate (now)
    ///   - Order: places after the original (orderValue + 1)
    @discardableResult
    static func duplicateTask(_ task: Task, context: ModelContext) -> Task {
        let duplicate = Task(
            title: task.title + " (Copy)",
            priority: task.priority,
            dueDate: task.dueDate,
            completedDate: nil,
            createdDate: Date(),
            parentTask: task.parentTask,
            project: task.project,
            order: task.orderValue + 1,
            notes: task.notes,
            estimatedSeconds: task.estimatedSeconds,
            hasCustomEstimate: task.hasCustomEstimate
        )
        context.insert(duplicate)
        return duplicate
    }
        
    // MARK: - Task Ordering

    /// Gets the next available order value for a new task at the same level
    /// - Parameters:
    ///   - parentTask: Optional parent task (nil for top-level tasks)
    ///   - allTasks: All tasks to check
    /// - Returns: Next order value
    static func nextOrderValue(for parentTask: Task?, from allTasks: [Task]) -> Int {
        // Filter to same-level tasks
        let sameLevelTasks = allTasks.filter { task in
            if let parent = parentTask {
                return task.parentTask?.id == parent.id
            } else {
                return task.parentTask == nil
            }
        }
        
        // Find max order and add 1
        let maxOrder = sameLevelTasks.map { $0.orderValue }.max() ?? -1
        return maxOrder + 1
    }

    /// Updates task order values after reordering
    /// - Parameters:
    ///   - tasks: Tasks in new order
    ///   - context: ModelContext
    static func updateTaskOrder(_ tasks: [Task], context: ModelContext) {
        for (index, task) in tasks.enumerated() {
            task.order = index
        }
        try? context.save()
    }
    
    // MARK: - Task Dependencies
    
    /// Checks if a dependency can be added without creating circular references
    /// - Parameters:
    ///   - from: The task that will depend on another
    ///   - to: The task to depend on
    /// - Returns: True if the dependency is valid, false if it would create a cycle
    static func canAddDependency(from: Task, to: Task) -> Bool {
        // Can't depend on self
        guard from.id != to.id else { return false }
        
        // Can't depend on own subtasks
        if isSubtask(task: to, of: from) {
            return false
        }
        
        // Can't depend on own parent
        if let parent = from.parentTask, parent.id == to.id {
            return false
        }
        
        // If this is a subtask, prevent depending on tasks that depend on the parent
        if let parent = from.parentTask {
            if taskDependsOn(task: to, target: parent) {
                return false
            }
        }
        
        // Check if already exists
        if let existing = from.dependsOn {
            if existing.contains(where: { $0.id == to.id }) {
                return false
            }
        }
        
        // Check for circular dependency (including subtask chains)
        return !wouldCreateCircularDependency(from: from, to: to)
    }

    // MARK: - Private Helper Methods

    /// Checks if a task depends on a target task (directly or through dependency chain)
    private static func taskDependsOn(task: Task, target: Task) -> Bool {
        var visited = Set<UUID>()
        var queue = [task]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            
            // If we found the target in the dependency chain, return true
            if current.id == target.id {
                return true
            }
            
            // Prevent infinite loops
            if visited.contains(current.id) {
                continue
            }
            visited.insert(current.id)
            
            // Add all tasks that this task depends on
            if let dependencies = current.dependsOn {
                queue.append(contentsOf: dependencies)
            }
        }
        
        return false
    }

    /// Checks if a task is a subtask (at any depth) of another task
    private static func isSubtask(task: Task, of potentialParent: Task) -> Bool {
        guard let subtasks = potentialParent.subtasks else { return false }
        
        for subtask in subtasks {
            if subtask.id == task.id {
                return true
            }
            if isSubtask(task: task, of: subtask) {
                return true
            }
        }
        
        return false
    }

    /// Checks if adding a dependency would create a circular reference
    /// This includes checking subtask dependencies since they block their parent
    private static func wouldCreateCircularDependency(from: Task, to: Task) -> Bool {
        // Check if 'to' task already depends on 'from' task (directly or indirectly)
        // IMPORTANT: This now includes checking if 'to' depends on 'from' through subtask chains
        var visited = Set<UUID>()
        var queue = [to]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            
            // If we found 'from' in the dependency chain of 'to', it's circular
            if current.id == from.id {
                return true
            }
            
            // NEW: If 'from' is a subtask, also check if we've found its parent
            // Because if 'to' depends on the parent, and the parent is blocked by 'from',
            // then 'from' depending on 'to' creates a circle
            if let parent = from.parentTask, current.id == parent.id {
                return true
            }
            
            // Prevent infinite loops
            if visited.contains(current.id) {
                continue
            }
            visited.insert(current.id)
            
            // Add all direct dependencies to check
            if let dependencies = current.dependsOn {
                queue.append(contentsOf: dependencies)
            }
            
            // NEW: Add all subtask dependencies to check
            // Because if a task has blocked subtasks, it's effectively blocked by those dependencies too
            if let subtasks = current.subtasks {
                for subtask in subtasks {
                    if let subtaskDeps = subtask.dependsOn {
                        queue.append(contentsOf: subtaskDeps)
                    }
                }
            }
        }
        
        return false
    }

    /// Gets all subtask IDs recursively
    private static func getAllSubtaskIds(_ task: Task) -> Set<UUID> {
        var ids = Set<UUID>()
        
        guard let subtasks = task.subtasks else { return ids }
        
        for subtask in subtasks {
            ids.insert(subtask.id)
            ids.formUnion(getAllSubtaskIds(subtask))
        }
        
        return ids
    }
    
    /// Adds a dependency between two tasks
    /// - Parameters:
    ///   - from: The task that will depend on another
    ///   - to: The task to depend on
    /// - Throws: TaskServiceError if dependency cannot be added
    static func addDependency(from: Task, to: Task) throws {
        guard canAddDependency(from: from, to: to) else {
            throw TaskServiceError.invalidDependency
        }
        
        if from.dependsOn == nil {
            from.dependsOn = []
        }
        
        from.dependsOn?.append(to)
    }
    
    /// Removes a dependency between two tasks
    /// - Parameters:
    ///   - from: The task with the dependency
    ///   - to: The dependency to remove
    static func removeDependency(from: Task, to: Task) {
        from.dependsOn?.removeAll { $0.id == to.id }
    }
    
    // MARK: - Task Deletion
    
    /// Deletes a task from the model context
    /// Clears all relationships first to avoid SwiftData "future" errors
    /// - Parameters:
    ///   - task: The task to delete
    ///   - context: ModelContext for deletion
    static func deleteTask(_ task: Task, context: ModelContext) {
        // Clear all relationships to prevent "future" access during cascade deletion
        // This is critical - SwiftData will try to access these during cascade
        task.dependsOn?.removeAll()
        task.blockedBy?.removeAll()
        task.subtasks?.removeAll()
        task.timeEntries?.removeAll()
        task.parentTask = nil
        task.project = nil
        
        // Now safe to delete
        context.delete(task)
    }
    
    // MARK: - Task Filtering
    
    /// Returns all tasks that are valid dependency candidates for a given task
    /// - Parameters:
    ///   - task: The task needing dependencies
    ///   - allTasks: All available tasks
    /// - Returns: Array of tasks that can be added as dependencies
    static func availableDependencies(for task: Task, from allTasks: [Task]) -> [Task] {
        return allTasks.filter { potentialDependency in
            canAddDependency(from: task, to: potentialDependency)
        }
    }
    
    /// Returns all tasks that depend on the given task (blocked by relationship)
    /// - Parameters:
    ///   - task: The task to check
    ///   - allTasks: All available tasks
    /// - Returns: Array of tasks that depend on this task
    static func blockedByTasks(for task: Task, from allTasks: [Task]) -> [Task] {
        return allTasks.filter { otherTask in
            otherTask.dependsOn?.contains(where: { $0.id == task.id }) ?? false
        }
    }
    
    /// Checks if a task is blocked (has incomplete dependencies or subtasks with incomplete dependencies)
    /// - Parameter task: The task to check
    /// - Returns: True if the task or any of its subtasks are blocked
    static func isBlocked(_ task: Task) -> Bool {
        // Check if task itself is blocked
        if let dependencies = task.dependsOn, !dependencies.isEmpty {
            if dependencies.contains(where: { !$0.isCompleted }) {
                return true
            }
        }
        
        // Check if any subtasks are blocked
        if let subtasks = task.subtasks {
            for subtask in subtasks {
                if isBlocked(subtask) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Counts total blocks for a task including its subtasks
    /// - Parameter task: The task to check
    /// - Returns: Number of incomplete dependencies across task and all subtasks
    static func totalBlockCount(_ task: Task) -> Int {
        var count = 0
        
        // Count own incomplete dependencies
        if let dependencies = task.dependsOn {
            count += dependencies.filter { !$0.isCompleted }.count
        }
        
        // Count subtasks' incomplete dependencies
        if let subtasks = task.subtasks {
            for subtask in subtasks {
                count += totalBlockCount(subtask)
            }
        }
        
        return count
    }
    
    // MARK: - Time Estimate Validation
    
    /// Validates that a custom estimate is not less than subtask total
    /// - Parameters:
    ///   - task: The task to validate
    ///   - proposedEstimate: The proposed estimate in minutes
    /// - Returns: Validation result with error message if invalid
    static func validateCustomEstimate(for task: Task, proposedEstimate: Int) -> EstimateValidationResult {
        // Only validate for parent tasks with subtask estimates
        guard let subtaskTotal = task.calculatedEstimateFromSubtasks,
              subtaskTotal > 0,
              task.hasCustomEstimate else {
            return .valid
        }
        
        if proposedEstimate < subtaskTotal {
            return .invalid("Custom estimate (\(formatMinutes(proposedEstimate))) cannot be less than subtask estimates total (\(formatMinutes(subtaskTotal)))")
        }
        
        return .valid
    }
    
    /// Calculates recommended estimate based on historical accuracy (future feature)
    /// - Parameter task: The task to analyze
    /// - Returns: Suggested estimate in minutes, or nil if insufficient data
    static func suggestedEstimate(for task: Task) -> Int? {
        // TODO: Implement historical accuracy tracking
        // This would analyze past tasks with similar characteristics
        // and suggest estimates based on actual time spent
        return nil
    }
    
    /// Formats minutes into human-readable string
    /// - Parameter minutes: Minutes to format
    /// - Returns: Formatted string (e.g., "2h 30m", "45m", "3h")
    static func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    // MARK: - Error Types
    
    enum TaskServiceError: Error, LocalizedError {
        case invalidDependency
        case circularDependency
        case selfDependency
        case subtaskDependency
        case invalidEstimate(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidDependency:
                return "Cannot add this dependency"
            case .circularDependency:
                return "Adding this dependency would create a circular reference"
            case .selfDependency:
                return "A task cannot depend on itself"
            case .subtaskDependency:
                return "A task cannot depend on its own subtasks"
            case .invalidEstimate(let message):
                return message
            }
        }
    }
    
    enum EstimateValidationResult {
        case valid
        case invalid(String)
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }
}
