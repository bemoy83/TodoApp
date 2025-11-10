import Foundation

/// Pure utility for processing task input data into task properties.
/// Handles notes trimming, time estimate calculations, and effort/personnel logic.
/// Separated from views for consistency, testability, and maintainability.
struct TaskEstimator {

    // MARK: - Result Types

    /// Result of estimate calculation containing all computed values
    struct EstimateResult {
        let estimatedSeconds: Int?
        let hasCustomEstimate: Bool
        let effortHours: Double?
        let expectedPersonnelCount: Int?

        /// Empty result (no estimate set)
        static var none: EstimateResult {
            EstimateResult(
                estimatedSeconds: nil,
                hasCustomEstimate: false,
                effortHours: nil,
                expectedPersonnelCount: nil
            )
        }
    }

    // MARK: - Public Methods

    /// Trim whitespace from notes and convert empty strings to nil
    /// - Parameter notes: Raw notes text from input
    /// - Returns: Trimmed notes or nil if empty
    static func processNotes(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Calculate time estimate data from input parameters
    /// - Parameters:
    ///   - estimateByEffort: Whether using effort-based mode
    ///   - effortHours: Total work effort in person-hours
    ///   - hasEstimate: Whether duration estimate is set
    ///   - estimateHours: Duration hours input
    ///   - estimateMinutes: Duration minutes input
    ///   - hasCustomEstimate: Whether estimate overrides subtask calculations
    ///   - hasPersonnel: Whether personnel count is set
    ///   - expectedPersonnelCount: Number of people assigned
    /// - Returns: EstimateResult with calculated values
    static func calculateEstimate(
        estimateByEffort: Bool,
        effortHours: Double,
        hasEstimate: Bool,
        estimateHours: Int,
        estimateMinutes: Int,
        hasCustomEstimate: Bool,
        hasPersonnel: Bool,
        expectedPersonnelCount: Int?
    ) -> EstimateResult {

        // EFFORT-BASED MODE
        if estimateByEffort && effortHours > 0 {
            let personnel = expectedPersonnelCount ?? 1
            let durationHours = effortHours / Double(personnel)
            let estimatedSeconds = Int(durationHours * 3600) // Convert to seconds

            return EstimateResult(
                estimatedSeconds: estimatedSeconds,
                hasCustomEstimate: true,
                effortHours: effortHours,
                expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
            )
        }

        // DURATION-BASED MODE
        if hasEstimate {
            let totalMinutes = (estimateHours * 60) + estimateMinutes
            let totalSeconds = totalMinutes * 60
            let finalSeconds = totalSeconds > 0 ? totalSeconds : nil

            return EstimateResult(
                estimatedSeconds: finalSeconds,
                hasCustomEstimate: hasCustomEstimate && finalSeconds != nil,
                effortHours: nil,
                expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
            )
        }

        // NO ESTIMATE
        return EstimateResult(
            estimatedSeconds: nil,
            hasCustomEstimate: false,
            effortHours: nil,
            expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
        )
    }

    /// Apply estimate result to an existing task (for editing)
    /// - Parameters:
    ///   - task: Task to update
    ///   - result: EstimateResult to apply
    static func applyEstimate(to task: Task, result: EstimateResult) {
        task.estimatedSeconds = result.estimatedSeconds
        task.hasCustomEstimate = result.hasCustomEstimate
        task.effortHours = result.effortHours
        task.expectedPersonnelCount = result.expectedPersonnelCount
    }
}
