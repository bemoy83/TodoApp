import Foundation

/// Analytics for historical task type performance
/// Calculates accuracy, productivity, and variance metrics for completed tasks
struct TaskTypeAnalytics {
    let taskType: String
    let sampleSize: Int
    let avgAccuracy: Double           // e.g., 0.85 = typically takes 18% longer than estimated
    let avgProductivityRate: Double?  // For quantity-based tasks: units per person-hour

    /// Percentage by which tasks typically overrun estimates (positive = over, negative = under)
    var typicalOverrunPercentage: Int {
        Int((1.0 - avgAccuracy) * 100)
    }

    /// Whether this analytics data is statistically significant (minimum 3 samples)
    var isSignificant: Bool {
        sampleSize >= 3
    }

    /// Calculate analytics for a specific task type from completed tasks
    /// - Parameters:
    ///   - taskType: The task type to analyze
    ///   - tasks: All available tasks (will be filtered to completed tasks of this type)
    /// - Returns: Analytics if enough data exists, nil otherwise
    static func calculate(for taskType: String, from tasks: [Task]) -> TaskTypeAnalytics? {
        // Filter to completed tasks of this type with accuracy data
        let relevantTasks = tasks.filter {
            $0.taskType == taskType &&
            $0.isCompleted &&
            $0.estimateAccuracy != nil
        }

        guard relevantTasks.count >= 3 else { return nil } // Need minimum sample size

        // Calculate average accuracy
        let totalAccuracy = relevantTasks.reduce(0.0) { $0 + ($1.estimateAccuracy ?? 0) }
        let avgAccuracy = totalAccuracy / Double(relevantTasks.count)

        // Calculate average productivity rate (for quantity-based tasks)
        let tasksWithProductivity = relevantTasks.filter { $0.hasProductivityData }
        let avgProductivityRate: Double? = {
            guard !tasksWithProductivity.isEmpty else { return nil }
            let totalRate = tasksWithProductivity.reduce(0.0) { $0 + ($1.unitsPerHour ?? 0) }
            return totalRate / Double(tasksWithProductivity.count)
        }()

        return TaskTypeAnalytics(
            taskType: taskType,
            sampleSize: relevantTasks.count,
            avgAccuracy: avgAccuracy,
            avgProductivityRate: avgProductivityRate
        )
    }

    /// Adjust effort hours based on historical accuracy
    /// - Parameter effortHours: Original estimated effort
    /// - Returns: Adjusted effort accounting for typical overruns
    func adjustedEffort(from effortHours: Double) -> Double {
        effortHours / avgAccuracy
    }

    /// User-friendly description of the variance
    var varianceDescription: String {
        let overrun = typicalOverrunPercentage
        if abs(overrun) < 5 {
            return "typically on target"
        } else if overrun > 0 {
            return "typically \(overrun)% over estimate"
        } else {
            return "typically \(abs(overrun))% under estimate"
        }
    }
}
