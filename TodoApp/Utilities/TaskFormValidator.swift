import Foundation

/// Pure utility for task form validation logic.
/// Provides testable validation methods for TaskComposerForm.
struct TaskFormValidator {

    // MARK: - Validation Results

    /// Result of due date validation
    struct DueDateValidation {
        let isValid: Bool
        let errorMessage: String?

        static var valid: DueDateValidation {
            DueDateValidation(isValid: true, errorMessage: nil)
        }

        static func invalid(_ message: String) -> DueDateValidation {
            DueDateValidation(isValid: false, errorMessage: message)
        }
    }

    /// Result of estimate validation
    struct EstimateValidation {
        let isValid: Bool
        let errorMessage: String?

        static var valid: EstimateValidation {
            EstimateValidation(isValid: true, errorMessage: nil)
        }

        static func invalid(_ message: String) -> EstimateValidation {
            EstimateValidation(isValid: false, errorMessage: message)
        }
    }

    // MARK: - Due Date Validation

    /// Validate subtask due date against parent's due date
    /// - Parameters:
    ///   - subtaskDate: Proposed due date for subtask
    ///   - parentDate: Parent task's due date
    ///   - isSubtask: Whether this is a subtask
    /// - Returns: Validation result with error message if invalid
    static func validateSubtaskDueDate(
        subtaskDate: Date,
        parentDate: Date?,
        isSubtask: Bool
    ) -> DueDateValidation {
        // Only validate if it's a subtask with parent due date
        guard isSubtask, let parentDue = parentDate else {
            return .valid
        }

        // Subtask due date must be on or before parent's due date
        if subtaskDate > parentDue {
            let formatter = DateFormatter()
            formatter.dateStyle = .abbreviated
            formatter.timeStyle = .shortened
            let parentDateStr = formatter.string(from: parentDue)

            return .invalid("Subtask due date cannot be later than parent's due date (\(parentDateStr)).")
        }

        return .valid
    }

    // MARK: - Estimate Validation

    /// Validate custom estimate against subtask estimates total
    /// - Parameters:
    ///   - estimateHours: Custom estimate hours
    ///   - estimateMinutes: Custom estimate minutes
    ///   - subtaskTotalMinutes: Total minutes from all subtask estimates
    ///   - hasCustomEstimate: Whether user set custom estimate (overriding subtasks)
    ///   - isSubtask: Whether this is a subtask (subtasks can't override)
    /// - Returns: Validation result with error message if invalid
    static func validateCustomEstimate(
        estimateHours: Int,
        estimateMinutes: Int,
        subtaskTotalMinutes: Int?,
        hasCustomEstimate: Bool,
        isSubtask: Bool
    ) -> EstimateValidation {
        // Only validate parent tasks with custom estimates
        guard !isSubtask, hasCustomEstimate else {
            return .valid
        }

        // Only validate if there are subtask estimates to compare against
        guard let subtaskTotal = subtaskTotalMinutes, subtaskTotal > 0 else {
            return .valid
        }

        let totalMinutes = (estimateHours * 60) + estimateMinutes

        // Custom estimate cannot be less than sum of subtask estimates
        if totalMinutes > 0 && totalMinutes < subtaskTotal {
            let customSeconds = totalMinutes * 60
            let subtaskSeconds = subtaskTotal * 60

            return .invalid("Custom estimate (\(customSeconds.formattedTime())) cannot be less than subtask estimates total (\(subtaskSeconds.formattedTime())).")
        }

        return .valid
    }

    // MARK: - Title Validation

    /// Validate task title is not empty
    /// - Parameter title: Task title to validate
    /// - Returns: true if title is not empty after trimming whitespace
    static func isValidTitle(_ title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
