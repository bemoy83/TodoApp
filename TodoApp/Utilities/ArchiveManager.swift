import Foundation
import SwiftData

/// Utility for validating and managing task archiving operations.
/// Handles validation of archive eligibility and execution of archive/unarchive operations.
struct ArchiveManager {

    // MARK: - Validation Result

    /// Result of archive validation with warnings and blocking issues
    struct ValidationResult {
        let canArchive: Bool
        let warnings: [String]
        let blockingIssues: [String]

        static var allowed: ValidationResult {
            ValidationResult(canArchive: true, warnings: [], blockingIssues: [])
        }

        static func blocked(_ issues: [String]) -> ValidationResult {
            ValidationResult(canArchive: false, warnings: [], blockingIssues: issues)
        }

        static func withWarnings(_ warnings: [String]) -> ValidationResult {
            ValidationResult(canArchive: true, warnings: warnings, blockingIssues: [])
        }

        var hasWarnings: Bool {
            !warnings.isEmpty
        }

        var hasBlockingIssues: Bool {
            !blockingIssues.isEmpty
        }
    }

    // MARK: - Validation

    /// Validate if a task can be archived
    /// - Parameters:
    ///   - task: Task to validate
    ///   - allTasks: All tasks in the database (for dependency checking)
    /// - Returns: Validation result with any warnings or blocking issues
    static func validateArchive(task: Task, allTasks: [Task]) -> ValidationResult {
        var warnings: [String] = []
        var blockingIssues: [String] = []

        // 1. Check if task is completed
        if task.status != .completed {
            blockingIssues.append("Only completed tasks can be archived")
        }

        // 2. Check for incomplete subtasks (guard against orphans)
        let incompleteSubtasks = findIncompleteSubtasks(for: task, in: allTasks)
        if !incompleteSubtasks.isEmpty {
            let count = incompleteSubtasks.count
            blockingIssues.append("\(count) incomplete \(count == 1 ? "subtask" : "subtasks") will be archived with parent")
            // List subtask titles for clarity
            let subtaskTitles = incompleteSubtasks.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
            if incompleteSubtasks.count > 3 {
                blockingIssues.append("\(subtaskTitles)\n...and \(incompleteSubtasks.count - 3) more")
            } else {
                blockingIssues.append(subtaskTitles)
            }
        }

        // 3. Check for dependent tasks (tasks that depend on this one)
        let dependentTasks = findDependentTasks(for: task, in: allTasks)
        if !dependentTasks.isEmpty {
            let count = dependentTasks.count
            warnings.append("\(count) active \(count == 1 ? "task depends" : "tasks depend") on this archived task:")
            let taskTitles = dependentTasks.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
            if dependentTasks.count > 3 {
                warnings.append("\(taskTitles)\n...and \(dependentTasks.count - 3) more")
            } else {
                warnings.append(taskTitles)
            }
        }

        // Determine result
        if !blockingIssues.isEmpty {
            return .blocked(blockingIssues)
        } else if !warnings.isEmpty {
            return .withWarnings(warnings)
        } else {
            return .allowed
        }
    }

    // MARK: - Archive Operations

    /// Archive a task and all its subtasks
    /// - Parameters:
    ///   - task: Task to archive
    ///   - allTasks: All tasks in database
    ///   - modelContext: SwiftData model context
    static func archive(task: Task, allTasks: [Task], modelContext: ModelContext) {
        let now = Date()

        // Archive the task
        task.isArchived = true
        task.archivedDate = now

        // Archive all subtasks (completed or not)
        let subtasks = findAllSubtasks(for: task, in: allTasks)
        for subtask in subtasks {
            subtask.isArchived = true
            subtask.archivedDate = now
        }

        try? modelContext.save()
    }

    /// Unarchive a task and all its subtasks
    /// - Parameters:
    ///   - task: Task to unarchive
    ///   - allTasks: All tasks in database
    ///   - modelContext: SwiftData model context
    static func unarchive(task: Task, allTasks: [Task], modelContext: ModelContext) {
        // Unarchive the task
        task.isArchived = false
        task.archivedDate = nil

        // Unarchive all subtasks
        let subtasks = findAllSubtasks(for: task, in: allTasks)
        for subtask in subtasks {
            subtask.isArchived = false
            subtask.archivedDate = nil
        }

        try? modelContext.save()
    }

    // MARK: - Helper Methods

    /// Find all incomplete subtasks for a task
    private static func findIncompleteSubtasks(for task: Task, in allTasks: [Task]) -> [Task] {
        var incomplete: [Task] = []

        // Find direct subtasks
        let directSubtasks = allTasks.filter { $0.parentTask?.id == task.id }

        for subtask in directSubtasks {
            // Add if incomplete
            if subtask.status != .completed {
                incomplete.append(subtask)
            }

            // Recursively check nested subtasks
            incomplete.append(contentsOf: findIncompleteSubtasks(for: subtask, in: allTasks))
        }

        return incomplete
    }

    /// Find all subtasks (complete or incomplete) for a task
    private static func findAllSubtasks(for task: Task, in allTasks: [Task]) -> [Task] {
        var allSubtasks: [Task] = []

        // Find direct subtasks
        let directSubtasks = allTasks.filter { $0.parentTask?.id == task.id }

        for subtask in directSubtasks {
            allSubtasks.append(subtask)

            // Recursively find nested subtasks
            allSubtasks.append(contentsOf: findAllSubtasks(for: subtask, in: allTasks))
        }

        return allSubtasks
    }

    /// Find tasks that depend on this task (not archived)
    private static func findDependentTasks(for task: Task, in allTasks: [Task]) -> [Task] {
        allTasks.filter { otherTask in
            !otherTask.isArchived &&
            otherTask.id != task.id &&
            (otherTask.dependsOn?.contains { $0.id == task.id } ?? false)
        }
    }
}
