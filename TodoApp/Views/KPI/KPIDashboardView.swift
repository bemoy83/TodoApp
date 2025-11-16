import Foundation
import SwiftUI
import SwiftData

struct KPIDashboardView: View {
    // Type alias to avoid name collision with Swift Concurrency's Task
    typealias TaskModel = Task

    // Include ALL tasks (including archived) for accurate KPI calculations
    @Query private var allTasks: [TaskModel]

    @Query private var allTimeEntries: [TimeEntry]

    @State private var selectedDateRange: DateRangeOption = .thisWeek
    @State private var currentKPIs: KPIResult?
    @State private var isCalculating = false

    // Detail sheet states
    @State private var showingAccuracyDetail = false

    // MARK: - Date Range Options

    enum DateRangeOption: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        var id: String { rawValue }

        var dateRange: KPIDateRange {
            switch self {
            case .today: return .today
            case .thisWeek: return .thisWeek
            case .thisMonth: return .thisMonth
            }
        }

        var subtitle: String {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                return formatter.string(from: now)

            case .thisWeek:
                if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let start = formatter.string(from: weekInterval.start)
                    let end = formatter.string(from: now)
                    return "\(start) - \(end)"
                }
                return "Current Week"

            case .thisMonth:
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: now)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Date Range Picker
                    dateRangePicker

                    if isCalculating {
                        ProgressView("Calculating KPIs...")
                            .padding(.vertical, DesignSystem.Spacing.massive)
                    } else if let kpis = currentKPIs {
                        // Key Metrics Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Key Metrics",
                                subtitle: "Performance breakdown",
                                icon: "chart.bar.fill",
                                iconColor: DesignSystem.Colors.info
                            )

                            metricsGrid(kpis: kpis)
                        }
                        .padding(.horizontal)

                        // Productivity Metrics Section
                        productivitySection
                    } else {
                        emptyStateView
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("KPI Dashboard")
            .onAppear {
                calculateKPIs()
            }
            .onChange(of: selectedDateRange) {
                calculateKPIs()
            }
            .onChange(of: allTasks.count) {
                calculateKPIs()
            }
            .sheet(isPresented: $showingAccuracyDetail) {
                if let kpis = currentKPIs {
                    KPIAccuracyDetailView(metrics: kpis.accuracy, dateRange: selectedDateRange.rawValue)
                }
            }
        }
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        Picker("Date Range", selection: $selectedDateRange) {
            ForEach(DateRangeOption.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Metrics Grid

    private func metricsGrid(kpis: KPIResult) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.md) {
            KPIMetricCard(
                icon: "target",
                title: "Accuracy",
                score: kpis.accuracy.accuracyScore,
                detail: kpis.accuracy.meanAbsolutePercentageError != nil ?
                    String(format: "%.1f%% avg error", kpis.accuracy.meanAbsolutePercentageError!) :
                    "No data",
                color: scoreColor(kpis.accuracy.accuracyScore),
                onTap: {
                    showingAccuracyDetail = true
                }
            )

            KPIMetricCard(
                icon: "checkmark.circle.fill",
                title: "Completed",
                score: kpis.totalTasks > 0 ? (Double(kpis.totalCompletedTasks) / Double(kpis.totalTasks)) * 100 : 0,
                detail: "\(kpis.totalCompletedTasks) of \(kpis.totalTasks) tasks",
                color: completionColor(completed: kpis.totalCompletedTasks, total: kpis.totalTasks)
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundStyle(DesignSystem.Colors.tertiary)

            Text("No KPI Data Available")
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.primary)

            Text("Complete tasks with estimates to see KPI metrics")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
        }
        .emptyStateStyle()
    }

    // MARK: - Color Helpers

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return DesignSystem.Colors.success
        case 60..<80: return DesignSystem.Colors.info
        case 40..<60: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }

    /// Color based on completion percentage
    private func completionColor(completed: Int, total: Int) -> Color {
        guard total > 0 else { return DesignSystem.Colors.info }
        let percentage = (Double(completed) / Double(total)) * 100
        return scoreColor(percentage)
    }

    // MARK: - Productivity Section

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(
                title: "Productivity",
                subtitle: "Per-person efficiency",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: DesignSystem.Colors.success
            )
            .padding(.horizontal)

            // Group tasks by task type + unit
            let tasksByType = tasksWithProductivityData

            if tasksByType.isEmpty {
                Text("Complete tasks with quantity tracking to see productivity metrics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                    .padding(.horizontal)
            } else {
                ForEach(Array(tasksByType.keys.sorted(by: { $0.sortKey < $1.sortKey })), id: \.self) { key in
                    if let tasks = tasksByType[key] {
                        ProductivityMetricsCard(
                            taskType: key.taskType,
                            unit: key.unit,
                            tasks: tasks,
                            dateRangeText: selectedDateRange.rawValue
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    /// Filter tasks with productivity data in the selected date range, grouped by task type + unit
    private var tasksWithProductivityData: [TaskTypeUnitKey: [TaskModel]] {
        let dateRange = selectedDateRange.dateRange

        let filteredTasks = allTasks.filter { task in
            // Must have productivity data
            guard task.hasProductivityData,
                  let completedDate = task.completedDate else { return false }

            // Must be completed in date range
            return completedDate >= dateRange.start && completedDate <= dateRange.end
        }

        // Group by task type + unit
        var grouped: [TaskTypeUnitKey: [TaskModel]] = [:]
        for task in filteredTasks {
            let key = TaskTypeUnitKey(taskType: task.taskType, unit: task.unit)
            if grouped[key] != nil {
                grouped[key]?.append(task)
            } else {
                grouped[key] = [task]
            }
        }

        return grouped
    }

    /// Key for grouping productivity by task type and unit
    private struct TaskTypeUnitKey: Hashable {
        let taskType: String?
        let unit: UnitType

        var sortKey: String {
            // Sort by task type (or "Unknown" if nil), then by unit
            let type = taskType ?? "Unknown"
            return "\(type)_\(unit.displayName)"
        }
    }

    // MARK: - Calculate KPIs

    private func calculateKPIs() {
        isCalculating = true

        // Use _Concurrency.Task to explicitly reference Swift Concurrency's Task
        // (not the SwiftData Task model)
        _Concurrency.Task {
            let dateRange = selectedDateRange.dateRange
            let kpis = KPIManager.calculateKPIs(
                from: allTasks,
                timeEntries: allTimeEntries,
                dateRange: dateRange
            )

            await MainActor.run {
                currentKPIs = kpis
                isCalculating = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    KPIDashboardView()
        .modelContainer(for: [Task.self, TimeEntry.self], inMemory: true)
}
