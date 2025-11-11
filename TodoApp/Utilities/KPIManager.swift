import Foundation
import SwiftData

/// Pure utility for calculating KPI (Key Performance Indicator) metrics.
/// Provides comprehensive analytics for task efficiency, estimate accuracy, and team utilization.
/// All methods are pure (no side effects) and suitable for integration with any data layer.
struct KPIManager {

    // MARK: - Main KPI Calculation

    /// Calculate comprehensive KPI metrics for a given date range
    /// - Parameters:
    ///   - tasks: All tasks to analyze
    ///   - timeEntries: All time entries to analyze
    ///   - dateRange: Date range for analysis
    ///   - availablePersonHoursPerDay: Expected available hours per person per day (default: 8.0)
    /// - Returns: Complete KPIResult with all metrics
    static func calculateKPIs(
        from tasks: [Task],
        timeEntries: [TimeEntry],
        dateRange: KPIDateRange,
        availablePersonHoursPerDay: Double = 8.0
    ) -> KPIResult {
        // Filter completed tasks in date range
        let completedTasks = filterCompletedTasks(tasks, in: dateRange)

        // Calculate individual metric categories
        let efficiency = calculateEfficiencyMetrics(from: completedTasks)
        let accuracy = calculateAccuracyMetrics(from: completedTasks)
        let utilization = calculateUtilizationMetrics(
            from: timeEntries,
            dateRange: dateRange,
            availablePersonHoursPerDay: availablePersonHoursPerDay
        )

        return KPIResult(
            dateRange: dateRange,
            calculatedAt: Date(),
            efficiency: efficiency,
            accuracy: accuracy,
            utilization: utilization,
            totalTasks: tasks.count,
            totalCompletedTasks: completedTasks.count
        )
    }

    // MARK: - Task Efficiency Calculations

    /// Calculate task efficiency metrics (actual vs estimated time)
    /// - Parameter tasks: Completed tasks to analyze
    /// - Returns: TaskEfficiencyMetrics with efficiency ratios and counts
    static func calculateEfficiencyMetrics(from tasks: [Task]) -> TaskEfficiencyMetrics {
        // Filter tasks that have both estimate and actual time
        let analyzableTasks = tasks.filter { task in
            guard let estimate = task.effectiveEstimate, estimate > 0 else { return false }
            return task.totalTimeSpent > 0
        }

        guard !analyzableTasks.isEmpty else {
            return TaskEfficiencyMetrics(
                averageEfficiencyRatio: nil,
                tasksUnderEstimate: 0,
                tasksOnEstimate: 0,
                tasksOverEstimate: 0,
                totalTasksAnalyzed: 0,
                totalTimeSpent: 0,
                totalTimeEstimated: 0
            )
        }

        // Calculate efficiency ratios and categorize tasks
        var totalRatio: Double = 0.0
        var tasksUnderEstimate = 0
        var tasksOnEstimate = 0
        var tasksOverEstimate = 0
        var totalTimeSpent = 0
        var totalTimeEstimated = 0

        for task in analyzableTasks {
            guard let estimate = task.effectiveEstimate else { continue }

            let actual = task.totalTimeSpent
            let ratio = Double(actual) / Double(estimate)
            totalRatio += ratio

            totalTimeSpent += actual
            totalTimeEstimated += estimate

            // Categorize: within 10% = on estimate
            if ratio < 0.9 {
                tasksUnderEstimate += 1
            } else if ratio <= 1.1 {
                tasksOnEstimate += 1
            } else {
                tasksOverEstimate += 1
            }
        }

        let averageRatio = totalRatio / Double(analyzableTasks.count)

        return TaskEfficiencyMetrics(
            averageEfficiencyRatio: averageRatio,
            tasksUnderEstimate: tasksUnderEstimate,
            tasksOnEstimate: tasksOnEstimate,
            tasksOverEstimate: tasksOverEstimate,
            totalTasksAnalyzed: analyzableTasks.count,
            totalTimeSpent: totalTimeSpent,
            totalTimeEstimated: totalTimeEstimated
        )
    }

    // MARK: - Estimate Accuracy Calculations

    /// Calculate estimate accuracy metrics using statistical measures
    /// - Parameter tasks: Completed tasks to analyze
    /// - Returns: EstimateAccuracyMetrics with MAE, MAPE, RMSE, and accuracy counts
    static func calculateAccuracyMetrics(from tasks: [Task]) -> EstimateAccuracyMetrics {
        // Filter tasks that have both estimate and actual time
        let analyzableTasks = tasks.filter { task in
            guard let estimate = task.effectiveEstimate, estimate > 0 else { return false }
            return task.totalTimeSpent > 0
        }

        guard !analyzableTasks.isEmpty else {
            return EstimateAccuracyMetrics(
                meanAbsoluteError: nil,
                meanAbsolutePercentageError: nil,
                rootMeanSquareError: nil,
                estimatesWithin10Percent: 0,
                estimatesWithin25Percent: 0,
                totalTasksAnalyzed: 0
            )
        }

        var sumAbsoluteError: Double = 0.0
        var sumAbsolutePercentageError: Double = 0.0
        var sumSquaredError: Double = 0.0
        var within10Percent = 0
        var within25Percent = 0

        for task in analyzableTasks {
            guard let estimate = task.effectiveEstimate, estimate > 0 else { continue }

            let actual = Double(task.totalTimeSpent)
            let estimated = Double(estimate)

            // Absolute error
            let absoluteError = abs(estimated - actual)
            sumAbsoluteError += absoluteError

            // Absolute percentage error
            let percentageError = (absoluteError / estimated) * 100.0
            sumAbsolutePercentageError += percentageError

            // Squared error
            let error = estimated - actual
            sumSquaredError += error * error

            // Count accuracy thresholds
            if percentageError <= 10.0 {
                within10Percent += 1
                within25Percent += 1
            } else if percentageError <= 25.0 {
                within25Percent += 1
            }
        }

        let count = Double(analyzableTasks.count)
        let mae = sumAbsoluteError / count
        let mape = sumAbsolutePercentageError / count
        let rmse = sqrt(sumSquaredError / count)

        return EstimateAccuracyMetrics(
            meanAbsoluteError: mae,
            meanAbsolutePercentageError: mape,
            rootMeanSquareError: rmse,
            estimatesWithin10Percent: within10Percent,
            estimatesWithin25Percent: within25Percent,
            totalTasksAnalyzed: analyzableTasks.count
        )
    }

    // MARK: - Team Utilization Calculations

    /// Calculate team utilization metrics (tracked vs available hours)
    /// - Parameters:
    ///   - timeEntries: Time entries to analyze
    ///   - dateRange: Date range for analysis
    ///   - availablePersonHoursPerDay: Expected available hours per person per day
    /// - Returns: TeamUtilizationMetrics with utilization rate and contributor stats
    static func calculateUtilizationMetrics(
        from timeEntries: [TimeEntry],
        dateRange: KPIDateRange,
        availablePersonHoursPerDay: Double
    ) -> TeamUtilizationMetrics {
        // Filter time entries that ended within the date range
        let relevantEntries = timeEntries.filter { entry in
            guard let endTime = entry.endTime else { return false }
            return endTime >= dateRange.start && endTime <= dateRange.end
        }

        guard !relevantEntries.isEmpty else {
            // No time tracked - return zero utilization
            let days = max(1, dateRange.days)
            let available = availablePersonHoursPerDay * Double(days)

            return TeamUtilizationMetrics(
                totalPersonHoursTracked: 0.0,
                totalPersonHoursAvailable: available,
                utilizationRate: 0.0,
                activeContributors: 0,
                averageHoursPerContributor: 0.0,
                totalTimeEntries: 0
            )
        }

        // Calculate total person-hours tracked
        var totalPersonHours: Double = 0.0
        var uniqueContributorDays = Set<String>() // Track unique "person-day" combinations

        for entry in relevantEntries {
            let personHours = TimeEntryManager.calculatePersonHours(for: entry)
            totalPersonHours += personHours

            // Track unique contributors (use personnel count as proxy for unique people)
            if let endTime = entry.endTime {
                let day = Calendar.current.startOfDay(for: endTime)
                let dayKey = ISO8601DateFormatter().string(from: day)
                for personIndex in 0..<entry.personnelCount {
                    uniqueContributorDays.insert("\(dayKey)-person\(personIndex)")
                }
            }
        }

        // Calculate available hours
        let days = max(1, dateRange.days)

        // Estimate active contributors from unique person-days
        let estimatedActiveContributors = max(1, uniqueContributorDays.count / max(1, days))
        let availablePersonHours = availablePersonHoursPerDay * Double(estimatedActiveContributors) * Double(days)

        // Calculate utilization rate (capped at a reasonable maximum)
        let utilizationRate = availablePersonHours > 0
            ? totalPersonHours / availablePersonHours
            : 0.0

        // Calculate average hours per contributor
        let averageHoursPerContributor = estimatedActiveContributors > 0
            ? totalPersonHours / Double(estimatedActiveContributors)
            : 0.0

        return TeamUtilizationMetrics(
            totalPersonHoursTracked: totalPersonHours,
            totalPersonHoursAvailable: availablePersonHours,
            utilizationRate: utilizationRate,
            activeContributors: estimatedActiveContributors,
            averageHoursPerContributor: averageHoursPerContributor,
            totalTimeEntries: relevantEntries.count
        )
    }

    // MARK: - Helper Methods

    /// Filter tasks completed within a date range
    /// - Parameters:
    ///   - tasks: All tasks
    ///   - dateRange: Date range to filter by
    /// - Returns: Array of tasks completed within the range
    static func filterCompletedTasks(_ tasks: [Task], in dateRange: KPIDateRange) -> [Task] {
        tasks.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return completedDate >= dateRange.start && completedDate <= dateRange.end
        }
    }

    // MARK: - Quick Metrics (for dashboard cards)

    /// Get quick efficiency score for a task
    /// - Parameter task: Task to analyze
    /// - Returns: Efficiency ratio (actual/estimated), nil if no estimate
    static func getTaskEfficiencyRatio(_ task: Task) -> Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        guard task.totalTimeSpent > 0 else { return nil }
        return Double(task.totalTimeSpent) / Double(estimate)
    }

    /// Get quick accuracy score for a task (absolute percentage error)
    /// - Parameter task: Task to analyze
    /// - Returns: Percentage error (0-100+), nil if no estimate
    static func getTaskAccuracyError(_ task: Task) -> Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        guard task.totalTimeSpent > 0 else { return nil }

        let actual = Double(task.totalTimeSpent)
        let estimated = Double(estimate)
        let absoluteError = abs(estimated - actual)

        return (absoluteError / estimated) * 100.0
    }

    /// Check if task was completed within estimate
    /// - Parameter task: Task to analyze
    /// - Returns: true if actual time <= estimated time
    static func wasTaskCompletedWithinEstimate(_ task: Task) -> Bool {
        guard let estimate = task.effectiveEstimate else { return false }
        return task.totalTimeSpent <= estimate
    }

    // MARK: - Trending & Comparison

    /// Compare two KPI results to identify trends
    /// - Parameters:
    ///   - current: Current period KPI result
    ///   - previous: Previous period KPI result
    /// - Returns: Dictionary of metric changes (positive = improvement)
    static func compareKPIs(current: KPIResult, previous: KPIResult) -> [String: Double] {
        var changes: [String: Double] = [:]

        // Efficiency score change
        changes["efficiencyScore"] = current.efficiency.efficiencyScore - previous.efficiency.efficiencyScore

        // Accuracy score change
        changes["accuracyScore"] = current.accuracy.accuracyScore - previous.accuracy.accuracyScore

        // Utilization change (aim for ~80-90%, so we measure distance from ideal)
        let idealUtilization = 85.0
        let currentDistance = abs(current.utilization.utilizationPercentage - idealUtilization)
        let previousDistance = abs(previous.utilization.utilizationPercentage - idealUtilization)
        changes["utilizationImprovement"] = previousDistance - currentDistance // positive = closer to ideal

        // Overall health score change
        changes["overallHealthScore"] = current.overallHealthScore - previous.overallHealthScore

        return changes
    }

    // MARK: - Snapshot Management

    /// Create a lightweight snapshot from a KPI result
    /// - Parameter result: Full KPI result
    /// - Returns: Lightweight KPI snapshot for persistence
    static func createSnapshot(from result: KPIResult) -> KPISnapshot {
        KPISnapshot(from: result)
    }
}
