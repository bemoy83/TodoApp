import Foundation
import SwiftData

// MARK: - KPI Date Range

/// Represents a date range for KPI calculation
struct KPIDateRange: Codable, Sendable {
    let start: Date
    let end: Date

    var days: Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static var today: KPIDateRange {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        return KPIDateRange(start: start, end: now)
    }

    static var thisWeek: KPIDateRange {
        let now = Date()
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return today
        }
        return KPIDateRange(start: weekStart, end: now)
    }

    static var thisMonth: KPIDateRange {
        let now = Date()
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return today
        }
        return KPIDateRange(start: monthStart, end: now)
    }

    static func custom(start: Date, end: Date) -> KPIDateRange {
        KPIDateRange(start: start, end: end)
    }
}

// MARK: - Task Efficiency Metrics

/// Measures how efficiently tasks are completed relative to estimates
struct TaskEfficiencyMetrics: Codable, Sendable {
    /// Average efficiency ratio: actual time / estimated time (lower = more efficient)
    /// Values: <1.0 = under estimate, 1.0 = on time, >1.0 = over estimate
    let averageEfficiencyRatio: Double?

    /// Number of tasks completed under estimate
    let tasksUnderEstimate: Int

    /// Number of tasks completed on estimate (within 10%)
    let tasksOnEstimate: Int

    /// Number of tasks completed over estimate
    let tasksOverEstimate: Int

    /// Total tasks analyzed (with both estimate and actual time)
    let totalTasksAnalyzed: Int

    /// Total time spent across analyzed tasks (seconds)
    let totalTimeSpent: Int

    /// Total time estimated across analyzed tasks (seconds)
    let totalTimeEstimated: Int

    /// Efficiency score (0-100): percentage of tasks completed under or on estimate
    var efficiencyScore: Double {
        guard totalTasksAnalyzed > 0 else { return 0.0 }
        let onOrUnder = tasksUnderEstimate + tasksOnEstimate
        return (Double(onOrUnder) / Double(totalTasksAnalyzed)) * 100.0
    }

    /// Average time saved/lost per task (negative = over estimate, positive = under estimate)
    var averageTimeDelta: Int? {
        guard totalTasksAnalyzed > 0 else { return nil }
        let delta = totalTimeEstimated - totalTimeSpent
        return delta / totalTasksAnalyzed
    }
}

// MARK: - Estimate Accuracy Metrics

/// Measures how accurate task estimates are
struct EstimateAccuracyMetrics: Codable, Sendable {
    /// Mean Absolute Error: average absolute difference between estimate and actual
    let meanAbsoluteError: Double?

    /// Mean Absolute Percentage Error: average percentage difference (0-100+)
    let meanAbsolutePercentageError: Double?

    /// Root Mean Square Error: square root of average squared differences
    let rootMeanSquareError: Double?

    /// Number of estimates within 10% accuracy
    let estimatesWithin10Percent: Int

    /// Number of estimates within 25% accuracy
    let estimatesWithin25Percent: Int

    /// Total tasks with estimates analyzed
    let totalTasksAnalyzed: Int

    /// Accuracy score (0-100): inverse of MAPE (lower error = higher accuracy)
    /// - 0% MAPE = 100% accuracy (perfect estimates)
    /// - 10% MAPE = 90% accuracy
    /// - 50% MAPE = 50% accuracy
    /// - 100%+ MAPE = 0% accuracy
    var accuracyScore: Double {
        guard let mape = meanAbsolutePercentageError else { return 0.0 }
        // Convert error percentage to accuracy score
        return max(0, 100 - mape)
    }
}

// MARK: - Team Utilization Metrics

/// Measures how effectively team capacity is being utilized
struct TeamUtilizationMetrics: Codable, Sendable {
    /// Total person-hours tracked in the period
    let totalPersonHoursTracked: Double

    /// Total available person-hours (capacity)
    let totalPersonHoursAvailable: Double

    /// Utilization rate: tracked / available (0.0 - 1.0+)
    let utilizationRate: Double

    /// Number of active contributors (people who logged time)
    let activeContributors: Int

    /// Average hours per contributor
    let averageHoursPerContributor: Double

    /// Total number of time entries
    let totalTimeEntries: Int

    /// Utilization percentage (0-100+)
    var utilizationPercentage: Double {
        utilizationRate * 100.0
    }

    /// Is team under-utilized? (< 70% utilization)
    var isUnderUtilized: Bool {
        utilizationRate < 0.70
    }

    /// Is team over-utilized? (> 100% utilization)
    var isOverUtilized: Bool {
        utilizationRate > 1.0
    }
}

// MARK: - Composite KPI Result

/// Comprehensive KPI analysis result containing all metrics
struct KPIResult: Codable, Sendable {
    /// Date range analyzed
    let dateRange: KPIDateRange

    /// Timestamp when KPI was calculated
    let calculatedAt: Date

    /// Task efficiency metrics
    let efficiency: TaskEfficiencyMetrics

    /// Estimate accuracy metrics
    let accuracy: EstimateAccuracyMetrics

    /// Team utilization metrics
    let utilization: TeamUtilizationMetrics

    /// Total tasks in dataset (including those without estimates)
    let totalTasks: Int

    /// Total completed tasks in date range
    let totalCompletedTasks: Int

    /// Overall health score (0-100): weighted average of all metrics
    var overallHealthScore: Double {
        let efficiencyWeight = 0.35
        let accuracyWeight = 0.35
        let utilizationWeight = 0.30

        // Cap utilization at 100% for scoring purposes
        let utilizationScore = min(utilization.utilizationPercentage, 100.0)

        return (efficiency.efficiencyScore * efficiencyWeight) +
               (accuracy.accuracyScore * accuracyWeight) +
               (utilizationScore * utilizationWeight)
    }

    /// Health status based on overall score
    var healthStatus: HealthStatus {
        switch overallHealthScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

// MARK: - Health Status Enum

enum HealthStatus: String, Codable, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    var color: String {
        switch self {
        case .excellent: return "#34C759"  // System green
        case .good: return "#007AFF"       // System blue
        case .fair: return "#FFD60A"       // System yellow
        case .poor: return "#FF9500"       // System orange
        case .critical: return "#FF3B30"   // System red
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.seal.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "exclamationmark.circle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Lightweight KPI Snapshot (for persistence)

/// Lightweight snapshot of KPI metrics for historical tracking
struct KPISnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let dateRange: KPIDateRange
    let calculatedAt: Date

    // Key metrics only
    let efficiencyScore: Double
    let accuracyScore: Double
    let utilizationPercentage: Double
    let overallHealthScore: Double
    let healthStatus: HealthStatus

    init(from result: KPIResult) {
        self.id = UUID()
        self.dateRange = result.dateRange
        self.calculatedAt = result.calculatedAt
        self.efficiencyScore = result.efficiency.efficiencyScore
        self.accuracyScore = result.accuracy.accuracyScore
        self.utilizationPercentage = result.utilization.utilizationPercentage
        self.overallHealthScore = result.overallHealthScore
        self.healthStatus = result.healthStatus
    }
}
