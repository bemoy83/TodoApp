// MARK: - KPI Infrastructure Usage Examples
// This file demonstrates how to use the KPI system in your views and services

import Foundation
import SwiftData
import SwiftUI

// MARK: - Example 1: Basic KPI Calculation

/// Calculate KPIs for the current week
func exampleBasicKPICalculation(tasks: [Task], timeEntries: [TimeEntry]) {
    // Calculate KPIs for this week
    let dateRange = KPIDateRange.thisWeek
    let kpiResult = KPIManager.calculateKPIs(
        from: tasks,
        timeEntries: timeEntries,
        dateRange: dateRange
    )

    // Access metrics
    print("Overall Health Score: \(kpiResult.overallHealthScore)")
    print("Health Status: \(kpiResult.healthStatus.rawValue)")
    print("Efficiency Score: \(kpiResult.efficiency.efficiencyScore)%")
    print("Accuracy Score: \(kpiResult.accuracy.accuracyScore)%")
    print("Utilization: \(kpiResult.utilization.utilizationPercentage)%")
}

// MARK: - Example 2: Using KPI Hooks with TaskActionExecutor

/// Complete a task and update KPIs
func exampleCompleteTaskWithKPI(task: Task, allTasks: [Task], timeEntries: [TimeEntry]) throws {
    // Define KPI update callback
    let updateKPIs: KPIUpdateHook = {
        // Recalculate KPIs after task completion
        let dateRange = KPIDateRange.thisWeek
        let updatedKPIs = KPIManager.calculateKPIs(
            from: allTasks,
            timeEntries: timeEntries,
            dateRange: dateRange
        )

        // Optionally persist snapshot for historical tracking
        let snapshot = KPIManager.createSnapshot(from: updatedKPIs)
        print("KPIs updated - Health: \(updatedKPIs.healthStatus.rawValue)")

        // TODO: Save snapshot to persistent storage if needed
    }

    // Complete task with KPI hook
    try TaskActionExecutor.complete(task, force: false, onKPIUpdate: updateKPIs)
}

// MARK: - Example 3: SwiftUI View with KPI Display

struct KPIDashboardExampleView: View {
    @Query(filter: #Predicate<Task> { !$0.isArchived })
    private var tasks: [Task]

    @Query private var timeEntries: [TimeEntry]

    @State private var currentKPIs: KPIResult?
    @State private var selectedDateRange: DateRangeOption = .thisWeek

    enum DateRangeOption: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        var dateRange: KPIDateRange {
            switch self {
            case .today: return .today
            case .thisWeek: return .thisWeek
            case .thisMonth: return .thisMonth
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date range picker
                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(DateRangeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Overall health card
                    if let kpis = currentKPIs {
                        healthCard(kpis: kpis)
                        metricsGrid(kpis: kpis)
                        detailsSection(kpis: kpis)
                    } else {
                        ProgressView("Calculating KPIs...")
                    }
                }
            }
            .navigationTitle("KPI Dashboard")
            .onAppear { calculateKPIs() }
            .onChange(of: selectedDateRange) { calculateKPIs() }
        }
    }

    private func calculateKPIs() {
        let dateRange = selectedDateRange.dateRange
        currentKPIs = KPIManager.calculateKPIs(
            from: tasks,
            timeEntries: timeEntries,
            dateRange: dateRange
        )
    }

    private func healthCard(kpis: KPIResult) -> some View {
        VStack(spacing: 8) {
            Image(systemName: kpis.healthStatus.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color(kpis.healthStatus.color))

            Text("Overall Health")
                .font(.headline)

            Text(kpis.healthStatus.rawValue)
                .font(.title)
                .fontWeight(.bold)

            Text("\(Int(kpis.overallHealthScore))/100")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func metricsGrid(kpis: KPIResult) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            metricCard(
                title: "Efficiency",
                value: "\(Int(kpis.efficiency.efficiencyScore))%",
                subtitle: "\(kpis.efficiency.tasksUnderEstimate) under estimate",
                color: .blue
            )

            metricCard(
                title: "Accuracy",
                value: "\(Int(kpis.accuracy.accuracyScore))%",
                subtitle: "\(kpis.accuracy.estimatesWithin25Percent) within 25%",
                color: .green
            )

            metricCard(
                title: "Utilization",
                value: "\(Int(kpis.utilization.utilizationPercentage))%",
                subtitle: "\(Int(kpis.utilization.totalPersonHoursTracked)) hrs tracked",
                color: .purple
            )

            metricCard(
                title: "Tasks",
                value: "\(kpis.totalCompletedTasks)",
                subtitle: "of \(kpis.totalTasks) total",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func detailsSection(kpis: KPIResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Metrics")
                .font(.headline)

            // Efficiency details
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Efficiency")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let avgRatio = kpis.efficiency.averageEfficiencyRatio {
                    Text("Average Ratio: \(String(format: "%.2f", avgRatio))")
                        .font(.caption)
                }

                Text("Under: \(kpis.efficiency.tasksUnderEstimate) | On: \(kpis.efficiency.tasksOnEstimate) | Over: \(kpis.efficiency.tasksOverEstimate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Accuracy details
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimate Accuracy")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let mape = kpis.accuracy.meanAbsolutePercentageError {
                    Text("Avg Error: \(String(format: "%.1f%%", mape))")
                        .font(.caption)
                }

                Text("Within 10%: \(kpis.accuracy.estimatesWithin10Percent) | Within 25%: \(kpis.accuracy.estimatesWithin25Percent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Utilization details
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Utilization")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Tracked: \(String(format: "%.1f", kpis.utilization.totalPersonHoursTracked)) hrs")
                    .font(.caption)

                Text("Contributors: \(kpis.utilization.activeContributors) | Entries: \(kpis.utilization.totalTimeEntries)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if kpis.utilization.isUnderUtilized {
                    Text("⚠️ Team is under-utilized")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if kpis.utilization.isOverUtilized {
                    Text("⚠️ Team is over-utilized")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Example 4: Archive Task with KPI Update

func exampleArchiveTaskWithKPI(task: Task, allTasks: [Task], timeEntries: [TimeEntry], context: ModelContext) throws {
    let updateKPIs: KPIUpdateHook = {
        // Recalculate KPIs after archiving
        let kpis = KPIManager.calculateKPIs(
            from: allTasks,
            timeEntries: timeEntries,
            dateRange: .thisMonth
        )
        print("KPIs updated after archive - \(kpis.totalTasks) total tasks")
    }

    try TaskActionExecutor.archive(task, allTasks: allTasks, context: context, onKPIUpdate: updateKPIs)
}

// MARK: - Example 5: Time Entry Change Detection

func exampleTimeEntryKPIUpdate(entry: TimeEntry, allTasks: [Task], allTimeEntries: [TimeEntry]) {
    // Check if this time entry change should trigger KPI update
    if TimeEntryManager.shouldTriggerKPIUpdate(for: entry) {
        // Get the affected date range
        if let affectedRange = TimeEntryManager.getAffectedDateRange(for: entry) {
            // Recalculate KPIs for the affected range
            let kpis = KPIManager.calculateKPIs(
                from: allTasks,
                timeEntries: allTimeEntries,
                dateRange: affectedRange
            )

            print("KPIs updated for range: \(affectedRange.start) to \(affectedRange.end)")
            print("Utilization: \(kpis.utilization.utilizationPercentage)%")
        }
    }
}

// MARK: - Example 6: Quick Task Metrics

func exampleQuickTaskMetrics(task: Task) {
    // Get efficiency ratio for a single task
    if let efficiency = KPIManager.getTaskEfficiencyRatio(task) {
        print("Task efficiency: \(String(format: "%.2f", efficiency))")

        if efficiency < 1.0 {
            print("✅ Completed under estimate")
        } else {
            print("⚠️ Exceeded estimate")
        }
    }

    // Get accuracy error for a single task
    if let error = KPIManager.getTaskAccuracyError(task) {
        print("Estimate error: \(String(format: "%.1f%%", error))")
    }

    // Check if completed within estimate
    if KPIManager.wasTaskCompletedWithinEstimate(task) {
        print("✅ Task completed within estimate")
    }
}

// MARK: - Example 7: Comparing KPI Trends

func exampleComparingKPITrends(tasks: [Task], timeEntries: [TimeEntry]) {
    // Calculate current week KPIs
    let currentWeek = KPIManager.calculateKPIs(
        from: tasks,
        timeEntries: timeEntries,
        dateRange: .thisWeek
    )

    // Calculate previous week KPIs (you'd need to calculate the date range)
    let previousWeekStart = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
    let previousWeekEnd = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    let previousWeek = KPIManager.calculateKPIs(
        from: tasks,
        timeEntries: timeEntries,
        dateRange: .custom(start: previousWeekStart, end: previousWeekEnd)
    )

    // Compare trends
    let changes = KPIManager.compareKPIs(current: currentWeek, previous: previousWeek)

    print("=== KPI Trends ===")
    if let efficiencyChange = changes["efficiencyScore"] {
        print("Efficiency: \(efficiencyChange > 0 ? "+" : "")\(String(format: "%.1f", efficiencyChange))%")
    }

    if let accuracyChange = changes["accuracyScore"] {
        print("Accuracy: \(accuracyChange > 0 ? "+" : "")\(String(format: "%.1f", accuracyChange))%")
    }

    if let healthChange = changes["overallHealthScore"] {
        print("Overall Health: \(healthChange > 0 ? "+" : "")\(String(format: "%.1f", healthChange))%")
    }
}

// MARK: - Example 8: Persisting KPI Snapshots

func examplePersistKPISnapshots(kpiResult: KPIResult) {
    // Create lightweight snapshot
    let snapshot = KPIManager.createSnapshot(from: kpiResult)

    // Save to UserDefaults or SwiftData
    // Example: Encode and save to UserDefaults
    if let encoded = try? JSONEncoder().encode(snapshot) {
        UserDefaults.standard.set(encoded, forKey: "kpi_snapshot_\(snapshot.id)")
        print("Saved KPI snapshot: \(snapshot.id)")
    }

    // Later, retrieve and decode
    if let data = UserDefaults.standard.data(forKey: "kpi_snapshot_\(snapshot.id)"),
       let decoded = try? JSONDecoder().decode(KPISnapshot.self, from: data) {
        print("Retrieved snapshot - Health: \(decoded.healthStatus.rawValue)")
    }
}

// MARK: - Example 9: Custom Date Range Analysis

func exampleCustomDateRangeAnalysis(tasks: [Task], timeEntries: [TimeEntry]) {
    // Analyze specific project period (e.g., Q1 2025)
    let q1Start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
    let q1End = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 31))!

    let q1KPIs = KPIManager.calculateKPIs(
        from: tasks,
        timeEntries: timeEntries,
        dateRange: .custom(start: q1Start, end: q1End),
        availablePersonHoursPerDay: 8.0 // Standard workday
    )

    print("Q1 2025 Performance:")
    print("- Completed Tasks: \(q1KPIs.totalCompletedTasks)")
    print("- Efficiency: \(Int(q1KPIs.efficiency.efficiencyScore))%")
    print("- Health: \(q1KPIs.healthStatus.rawValue)")
}

// MARK: - Example 10: Integration in TaskActionRouter (Hypothetical)

/*
 In your TaskActionRouter or similar service layer, you could integrate KPI updates like this:

 class TaskActionRouter {
     private let modelContext: ModelContext
     private var allTasks: [Task] { /* fetch from context */ }
     private var allTimeEntries: [TimeEntry] { /* fetch from context */ }

     func completeTask(_ task: Task, force: Bool = false) throws {
         try TaskActionExecutor.complete(task, force: force) { [weak self] in
             self?.updateKPIs()
         }
     }

     private func updateKPIs() {
         let kpis = KPIManager.calculateKPIs(
             from: allTasks,
             timeEntries: allTimeEntries,
             dateRange: .thisWeek
         )

         // Optionally post notification or update published state
         NotificationCenter.default.post(
             name: .kpisDidUpdate,
             object: kpis
         )
     }
 }

 extension Notification.Name {
     static let kpisDidUpdate = Notification.Name("kpisDidUpdate")
 }
 */
