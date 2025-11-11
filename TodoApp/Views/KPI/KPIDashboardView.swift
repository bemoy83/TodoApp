import Foundation
import SwiftUI
import SwiftData

// Type alias to avoid name collision with Swift Concurrency's Task
typealias TaskModel = Task

struct KPIDashboardView: View {
    @Query(filter: #Predicate<TaskModel> { !$0.isArchived })
    private var allTasks: [TaskModel]

    @Query private var allTimeEntries: [TimeEntry]

    @State private var selectedDateRange: DateRangeOption = .thisWeek
    @State private var currentKPIs: KPIResult?
    @State private var isCalculating = false

    // Detail sheet states
    @State private var showingEfficiencyDetail = false
    @State private var showingAccuracyDetail = false
    @State private var showingUtilizationDetail = false
    @State private var showingTasksDetail = false

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
                        // Overall Health Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Overall Health",
                                subtitle: selectedDateRange.subtitle
                            )

                            KPIHealthCard(
                                healthStatus: kpis.healthStatus,
                                overallScore: kpis.overallHealthScore,
                                dateRangeText: selectedDateRange.rawValue
                            )
                        }
                        .padding(.horizontal)

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

                        // Detailed Insights Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Detailed Insights",
                                subtitle: "Metric breakdown",
                                icon: "list.bullet.clipboard",
                                iconColor: Color(hex: "#5856D6")
                            )

                            detailsSection(kpis: kpis)
                        }
                        .padding(.horizontal)
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
            .sheet(isPresented: $showingEfficiencyDetail) {
                if let kpis = currentKPIs {
                    KPIEfficiencyDetailView(metrics: kpis.efficiency, dateRange: selectedDateRange.rawValue)
                }
            }
            .sheet(isPresented: $showingAccuracyDetail) {
                if let kpis = currentKPIs {
                    KPIAccuracyDetailView(metrics: kpis.accuracy, dateRange: selectedDateRange.rawValue)
                }
            }
            .sheet(isPresented: $showingUtilizationDetail) {
                if let kpis = currentKPIs {
                    KPIUtilizationDetailView(metrics: kpis.utilization, dateRange: selectedDateRange.rawValue)
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
                icon: "gauge.with.dots.needle.67percent",
                title: "Efficiency",
                score: kpis.efficiency.efficiencyScore,
                detail: "\(kpis.efficiency.tasksUnderEstimate) under estimate",
                color: scoreColor(kpis.efficiency.efficiencyScore),
                onTap: {
                    showingEfficiencyDetail = true
                }
            )

            KPIMetricCard(
                icon: "target",
                title: "Accuracy",
                score: kpis.accuracy.accuracyScore,
                detail: "\(kpis.accuracy.estimatesWithin25Percent) within 25%",
                color: scoreColor(kpis.accuracy.accuracyScore),
                onTap: {
                    showingAccuracyDetail = true
                }
            )

            KPIMetricCard(
                icon: "person.2.fill",
                title: "Utilization",
                score: min(kpis.utilization.utilizationPercentage, 100),
                detail: String(format: "%.1f hrs tracked", kpis.utilization.totalPersonHoursTracked),
                color: utilizationColor(kpis.utilization.utilizationPercentage),
                onTap: {
                    showingUtilizationDetail = true
                }
            )

            KPIMetricCard(
                icon: "checkmark.circle.fill",
                title: "Completed",
                score: kpis.totalTasks > 0 ? (Double(kpis.totalCompletedTasks) / Double(kpis.totalTasks)) * 100 : 0,
                detail: "\(kpis.totalCompletedTasks) of \(kpis.totalTasks) tasks",
                color: DesignSystem.Colors.success
            )
        }
    }

    // MARK: - Details Section

    private func detailsSection(kpis: KPIResult) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Efficiency details
            detailCard(
                title: "Task Efficiency",
                icon: "gauge.with.dots.needle.67percent",
                color: scoreColor(kpis.efficiency.efficiencyScore)
            ) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let avgRatio = kpis.efficiency.averageEfficiencyRatio {
                        KPISummaryRow(
                            title: "Avg Efficiency Ratio",
                            value: String(format: "%.2f", avgRatio)
                        )
                    }

                    KPISummaryRow(
                        title: "Under Estimate",
                        value: "\(kpis.efficiency.tasksUnderEstimate)",
                        icon: "checkmark.circle.fill",
                        color: DesignSystem.Colors.success
                    )

                    KPISummaryRow(
                        title: "On Estimate",
                        value: "\(kpis.efficiency.tasksOnEstimate)",
                        icon: "checkmark.circle",
                        color: DesignSystem.Colors.info
                    )

                    KPISummaryRow(
                        title: "Over Estimate",
                        value: "\(kpis.efficiency.tasksOverEstimate)",
                        icon: "exclamationmark.circle",
                        color: DesignSystem.Colors.warning
                    )

                    KPISummaryRow(
                        title: "Tasks Analyzed",
                        value: "\(kpis.efficiency.totalTasksAnalyzed)"
                    )
                }
            }

            // Accuracy details
            detailCard(
                title: "Estimate Accuracy",
                icon: "target",
                color: scoreColor(kpis.accuracy.accuracyScore)
            ) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let mape = kpis.accuracy.meanAbsolutePercentageError {
                        KPISummaryRow(
                            title: "Avg Error",
                            value: String(format: "%.1f%%", mape)
                        )
                    }

                    KPISummaryRow(
                        title: "Within 10%",
                        value: "\(kpis.accuracy.estimatesWithin10Percent)",
                        icon: "checkmark.circle.fill",
                        color: DesignSystem.Colors.success
                    )

                    KPISummaryRow(
                        title: "Within 25%",
                        value: "\(kpis.accuracy.estimatesWithin25Percent)",
                        icon: "checkmark.circle",
                        color: DesignSystem.Colors.info
                    )

                    KPISummaryRow(
                        title: "Tasks Analyzed",
                        value: "\(kpis.accuracy.totalTasksAnalyzed)"
                    )
                }
            }

            // Utilization details
            detailCard(
                title: "Team Utilization",
                icon: "person.2.fill",
                color: utilizationColor(kpis.utilization.utilizationPercentage)
            ) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    KPISummaryRow(
                        title: "Person-Hours Tracked",
                        value: String(format: "%.1f", kpis.utilization.totalPersonHoursTracked)
                    )

                    KPISummaryRow(
                        title: "Available Capacity",
                        value: String(format: "%.1f", kpis.utilization.totalPersonHoursAvailable)
                    )

                    KPISummaryRow(
                        title: "Active Contributors",
                        value: "\(kpis.utilization.activeContributors)"
                    )

                    KPISummaryRow(
                        title: "Time Entries",
                        value: "\(kpis.utilization.totalTimeEntries)"
                    )

                    if kpis.utilization.isUnderUtilized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignSystem.Colors.warning)
                            Text("Team is under-utilized")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.warning)
                            Spacer()
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    } else if kpis.utilization.isOverUtilized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignSystem.Colors.error)
                            Text("Team is over-utilized")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.error)
                            Spacer()
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Detail Card Helper

    private func detailCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            content()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(Color(.systemBackground))
        )
        .designShadow(DesignSystem.Shadow.sm)
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

    private func utilizationColor(_ utilization: Double) -> Color {
        switch utilization {
        case 70...90: return DesignSystem.Colors.success
        case 50..<70: return DesignSystem.Colors.info
        case 0..<50: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }

    // MARK: - Calculate KPIs

    private func calculateKPIs() {
        isCalculating = true

        // Use async Task to calculate on background thread
        Task {
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
