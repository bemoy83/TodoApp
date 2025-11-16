import SwiftUI

/// Card showing estimate accuracy with inline expand/collapse
struct AccuracyMetricsCard: View {
    let metrics: EstimateAccuracyMetrics
    let dateRangeText: String

    @State private var isExpanded = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header - tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundStyle(scoreColor(metrics.accuracyScore))

                    Text("Accuracy")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Score
                    Text("\(Int(metrics.accuracyScore))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor(metrics.accuracyScore))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Detail text
            if let mape = metrics.meanAbsolutePercentageError {
                Text(String(format: "%.1f%% avg error", mape))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if metrics.totalTasksAnalyzed > 0 {
                // Collapsed view: Show top 2 problematic task types
                if !isExpanded {
                    collapsedSummary
                }

                // Expanded view: Full breakdown
                if isExpanded {
                    Divider()

                    // Accuracy breakdown bars
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Error Distribution")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        accuracyBreakdownBar(
                            title: "Excellent (0-20%)",
                            count: metrics.estimatesWithin20Percent,
                            total: metrics.totalTasksAnalyzed,
                            color: DesignSystem.Colors.success
                        )

                        accuracyBreakdownBar(
                            title: "Good (21-40%)",
                            count: metrics.estimatesWithin40Percent - metrics.estimatesWithin20Percent,
                            total: metrics.totalTasksAnalyzed,
                            color: DesignSystem.Colors.info
                        )

                        accuracyBreakdownBar(
                            title: "Needs Work (41-60%)",
                            count: metrics.estimatesWithin60Percent - metrics.estimatesWithin40Percent,
                            total: metrics.totalTasksAnalyzed,
                            color: DesignSystem.Colors.warning
                        )

                        accuracyBreakdownBar(
                            title: "Poor (>60%)",
                            count: metrics.totalTasksAnalyzed - metrics.estimatesWithin60Percent,
                            total: metrics.totalTasksAnalyzed,
                            color: DesignSystem.Colors.error
                        )
                    }

                    // Accuracy by task type
                    if !metrics.byTaskType.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Accuracy by Task Type")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(metrics.byTaskType) { taskTypeAccuracy in
                                    taskTypeRow(taskTypeAccuracy)
                                }
                            }
                        }
                    }
                }
            } else {
                // Empty state
                Text("Complete tasks with estimates to see accuracy metrics")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .statCardStyle()
    }

    // MARK: - Helper Views

    private var collapsedSummary: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Show top 2 worst performing task types
            ForEach(metrics.byTaskType.prefix(2)) { taskTypeAccuracy in
                HStack(spacing: 4) {
                    Image(systemName: taskTypeAccuracy.status.icon)
                        .font(.caption2)
                        .foregroundStyle(statusColor(taskTypeAccuracy.status))

                    Text(taskTypeAccuracy.taskType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(String(format: "%.0f%%", taskTypeAccuracy.averageError))
                        .font(.caption)
                        .foregroundStyle(statusColor(taskTypeAccuracy.status))
                        .fontWeight(.medium)
                }
            }

            if metrics.byTaskType.count > 2 {
                Text("+\(metrics.byTaskType.count - 2) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private func accuracyBreakdownBar(title: String, count: Int, total: Int, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    // Progress
                    if total > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(
                                width: geometry.size.width * CGFloat(count) / CGFloat(total),
                                height: 6
                            )
                    }
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func taskTypeRow(_ taskTypeAccuracy: TaskTypeAccuracy) -> some View {
        let color = statusColor(taskTypeAccuracy.status)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(taskTypeAccuracy.taskType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: taskTypeAccuracy.status.icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }

            HStack(spacing: 4) {
                Text(String(format: "%.1f%% avg error", taskTypeAccuracy.averageError))
                    .font(.caption)
                    .foregroundStyle(color)
                    .fontWeight(.medium)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text("\(taskTypeAccuracy.taskCount) task\(taskTypeAccuracy.taskCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Status label
            HStack(spacing: 4) {
                Image(systemName: taskTypeAccuracy.status.icon)
                    .font(.caption2)
                    .foregroundStyle(color)

                Text(taskTypeAccuracy.status.label)
                    .font(.caption)
                    .foregroundStyle(color)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.1))
            )
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(.systemGray6))
        )
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

    private func statusColor(_ status: TaskTypeAccuracy.AccuracyStatus) -> Color {
        switch status {
        case .excellent: return DesignSystem.Colors.success
        case .good: return DesignSystem.Colors.info
        case .needsImprovement: return DesignSystem.Colors.warning
        case .poor: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    let metrics = EstimateAccuracyMetrics(
        meanAbsoluteError: 1800.0,
        meanAbsolutePercentageError: 25.5,
        rootMeanSquareError: 2400.0,
        estimatesWithin10Percent: 5,
        estimatesWithin25Percent: 12,
        estimatesWithin20Percent: 8,
        estimatesWithin40Percent: 15,
        estimatesWithin60Percent: 18,
        totalTasksAnalyzed: 20,
        byTaskType: [
            TaskTypeAccuracy(taskType: "Booth Wall Setup", averageError: 45.2, taskCount: 8),
            TaskTypeAccuracy(taskType: "Carpet Installation", averageError: 18.3, taskCount: 12),
            TaskTypeAccuracy(taskType: "Furniture Assembly", averageError: 12.5, taskCount: 15)
        ]
    )

    return ScrollView {
        AccuracyMetricsCard(
            metrics: metrics,
            dateRangeText: "This Week"
        )
        .padding()
    }
}

#Preview("Empty State") {
    let metrics = EstimateAccuracyMetrics(
        meanAbsoluteError: nil,
        meanAbsolutePercentageError: nil,
        rootMeanSquareError: nil,
        estimatesWithin10Percent: 0,
        estimatesWithin25Percent: 0,
        estimatesWithin20Percent: 0,
        estimatesWithin40Percent: 0,
        estimatesWithin60Percent: 0,
        totalTasksAnalyzed: 0,
        byTaskType: []
    )

    return AccuracyMetricsCard(
        metrics: metrics,
        dateRangeText: "This Week"
    )
    .padding()
}
