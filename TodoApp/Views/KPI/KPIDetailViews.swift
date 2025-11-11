import SwiftUI

// MARK: - KPI Efficiency Detail View

struct KPIEfficiencyDetailView: View {
    let metrics: TaskEfficiencyMetrics
    let dateRange: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Summary card
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 48))
                            .foregroundStyle(scoreColor(metrics.efficiencyScore))

                        Text("\(Int(metrics.efficiencyScore))%")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(scoreColor(metrics.efficiencyScore))

                        Text("Efficiency Score")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.secondary)

                        Text(dateRange)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                            .fill(scoreColor(metrics.efficiencyScore).opacity(0.1))
                    )
                    .padding(.horizontal)

                    // Task breakdown
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Task Performance")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            efficiencyBar(
                                title: "Under Estimate",
                                count: metrics.tasksUnderEstimate,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.success
                            )

                            efficiencyBar(
                                title: "On Estimate (±10%)",
                                count: metrics.tasksOnEstimate,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.info
                            )

                            efficiencyBar(
                                title: "Over Estimate",
                                count: metrics.tasksOverEstimate,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.warning
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Detailed metrics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Detailed Metrics")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            if let avgRatio = metrics.averageEfficiencyRatio {
                                detailRow(
                                    label: "Average Efficiency Ratio",
                                    value: String(format: "%.2f", avgRatio),
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                                Divider().padding(.leading, 50)
                            }

                            if let avgDelta = metrics.averageTimeDelta {
                                let hours = Double(avgDelta) / 3600.0
                                let sign = hours > 0 ? "+" : ""
                                detailRow(
                                    label: "Avg Time Variance",
                                    value: "\(sign)\(String(format: "%.1f", hours)) hrs",
                                    icon: "clock.arrow.circlepath"
                                )
                                Divider().padding(.leading, 50)
                            }

                            detailRow(
                                label: "Total Time Spent",
                                value: formatSeconds(metrics.totalTimeSpent),
                                icon: "clock.fill"
                            )
                            Divider().padding(.leading, 50)

                            detailRow(
                                label: "Total Time Estimated",
                                value: formatSeconds(metrics.totalTimeEstimated),
                                icon: "clock.badge.checkmark"
                            )
                            Divider().padding(.leading, 50)

                            detailRow(
                                label: "Tasks Analyzed",
                                value: "\(metrics.totalTasksAnalyzed)",
                                icon: "checkmark.circle"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(Color(.systemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Interpretation
                    interpretationCard(
                        title: "Understanding Efficiency",
                        text: "Efficiency measures how well tasks are completed relative to estimates. A score of 100% means all tasks were completed on or under estimate. Lower scores indicate frequent overruns."
                    )
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Task Efficiency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return DesignSystem.Colors.success
        case 60..<80: return DesignSystem.Colors.info
        case 40..<60: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let hours = Double(seconds) / 3600.0
        return String(format: "%.1f hrs", hours)
    }
}

// MARK: - KPI Accuracy Detail View

struct KPIAccuracyDetailView: View {
    let metrics: EstimateAccuracyMetrics
    let dateRange: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Summary card
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundStyle(scoreColor(metrics.accuracyScore))

                        Text("\(Int(metrics.accuracyScore))%")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(scoreColor(metrics.accuracyScore))

                        Text("Accuracy Score")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.secondary)

                        Text(dateRange)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                            .fill(scoreColor(metrics.accuracyScore).opacity(0.1))
                    )
                    .padding(.horizontal)

                    // Accuracy breakdown
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Estimate Accuracy")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            accuracyBar(
                                title: "Within 10%",
                                count: metrics.estimatesWithin10Percent,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.success
                            )

                            accuracyBar(
                                title: "Within 25%",
                                count: metrics.estimatesWithin25Percent,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.info
                            )

                            accuracyBar(
                                title: "Over 25% Error",
                                count: metrics.totalTasksAnalyzed - metrics.estimatesWithin25Percent,
                                total: metrics.totalTasksAnalyzed,
                                color: DesignSystem.Colors.warning
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Statistical metrics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Statistical Measures")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            if let mape = metrics.meanAbsolutePercentageError {
                                detailRow(
                                    label: "Mean Absolute % Error",
                                    value: String(format: "%.1f%%", mape),
                                    icon: "percent"
                                )
                                Divider().padding(.leading, 50)
                            }

                            if let mae = metrics.meanAbsoluteError {
                                let hours = mae / 3600.0
                                detailRow(
                                    label: "Mean Absolute Error",
                                    value: String(format: "%.1f hrs", hours),
                                    icon: "plus.forwardslash.minus"
                                )
                                Divider().padding(.leading, 50)
                            }

                            if let rmse = metrics.rootMeanSquareError {
                                let hours = rmse / 3600.0
                                detailRow(
                                    label: "Root Mean Square Error",
                                    value: String(format: "%.1f hrs", hours),
                                    icon: "function"
                                )
                                Divider().padding(.leading, 50)
                            }

                            detailRow(
                                label: "Tasks Analyzed",
                                value: "\(metrics.totalTasksAnalyzed)",
                                icon: "checkmark.circle"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(Color(.systemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Interpretation
                    interpretationCard(
                        title: "Understanding Accuracy",
                        text: "Accuracy measures how close your estimates are to actual time spent. A score of 100% means all estimates were within 25% of actual time. Higher scores indicate more reliable estimation."
                    )
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Estimate Accuracy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return DesignSystem.Colors.success
        case 60..<80: return DesignSystem.Colors.info
        case 40..<60: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }
}

// MARK: - KPI Utilization Detail View

struct KPIUtilizationDetailView: View {
    let metrics: TeamUtilizationMetrics
    let dateRange: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Summary card
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(utilizationColor(metrics.utilizationPercentage))

                        Text("\(Int(metrics.utilizationPercentage))%")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(utilizationColor(metrics.utilizationPercentage))

                        Text("Team Utilization")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.secondary)

                        Text(dateRange)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiary)

                        // Utilization status
                        if metrics.isUnderUtilized {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("Under-utilized")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.warning.opacity(0.15))
                            )
                        } else if metrics.isOverUtilized {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("Over-utilized")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundStyle(DesignSystem.Colors.error)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.error.opacity(0.15))
                            )
                        } else {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Optimal")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundStyle(DesignSystem.Colors.success)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.success.opacity(0.15))
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                            .fill(utilizationColor(metrics.utilizationPercentage).opacity(0.1))
                    )
                    .padding(.horizontal)

                    // Capacity metrics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Capacity Analysis")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        // Progress bar
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack {
                                Text("Tracked")
                                    .font(DesignSystem.Typography.caption)
                                Spacer()
                                Text("Available")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundStyle(DesignSystem.Colors.secondary)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)

                                    // Progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(utilizationColor(metrics.utilizationPercentage))
                                        .frame(
                                            width: geometry.size.width * CGFloat(min(metrics.utilizationRate, 1.0)),
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)

                            HStack {
                                Text(String(format: "%.1f hrs", metrics.totalPersonHoursTracked))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(utilizationColor(metrics.utilizationPercentage))
                                Spacer()
                                Text(String(format: "%.1f hrs", metrics.totalPersonHoursAvailable))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(Color(.systemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Team metrics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Team Metrics")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            detailRow(
                                label: "Active Contributors",
                                value: "\(metrics.activeContributors)",
                                icon: "person.2"
                            )
                            Divider().padding(.leading, 50)

                            detailRow(
                                label: "Avg Hours/Contributor",
                                value: String(format: "%.1f hrs", metrics.averageHoursPerContributor),
                                icon: "chart.bar.fill"
                            )
                            Divider().padding(.leading, 50)

                            detailRow(
                                label: "Total Time Entries",
                                value: "\(metrics.totalTimeEntries)",
                                icon: "clock.badge.checkmark"
                            )
                            Divider().padding(.leading, 50)

                            detailRow(
                                label: "Utilization Rate",
                                value: String(format: "%.1f%%", metrics.utilizationPercentage),
                                icon: "percent"
                            )
                        }
                        .padding(.horizontal)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(Color(.systemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Interpretation
                    interpretationCard(
                        title: "Understanding Utilization",
                        text: "Utilization measures how effectively your team's capacity is being used. Optimal range is 70-90%. Below 70% indicates under-utilization; above 100% indicates overwork."
                    )
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Team Utilization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
}

// MARK: - Shared Components

private func efficiencyBar(title: String, count: Int, total: Int, color: Color) -> some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primary)
            Spacer()
            Text("\(count)")
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(color)
        }

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                if total > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * CGFloat(count) / CGFloat(total),
                            height: 8
                        )
                }
            }
        }
        .frame(height: 8)
    }
    .padding(DesignSystem.Spacing.md)
    .background(
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .fill(Color(.systemBackground))
    )
}

private func accuracyBar(title: String, count: Int, total: Int, color: Color) -> some View {
    efficiencyBar(title: title, count: count, total: total, color: color)
}

private func detailRow(label: String, value: String, icon: String) -> some View {
    HStack(spacing: DesignSystem.Spacing.md) {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(DesignSystem.Colors.info)
            .frame(width: 24)

        Text(label)
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.primary)

        Spacer()

        Text(value)
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(DesignSystem.Colors.secondary)
    }
    .padding(.vertical, DesignSystem.Spacing.sm)
}

private func interpretationCard(title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DesignSystem.Colors.info)

            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.primary)
        }

        Text(text)
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(DesignSystem.Spacing.md)
    .background(
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
            .fill(DesignSystem.Colors.info.opacity(0.1))
    )
    .padding(.horizontal)
}
