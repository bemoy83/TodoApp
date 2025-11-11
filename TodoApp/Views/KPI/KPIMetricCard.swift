import SwiftUI

// MARK: - KPI Metric Card

/// Specialized card for displaying KPI metrics with percentage scores
struct KPIMetricCard: View {
    let icon: String
    let title: String
    let score: Double
    let detail: String
    let color: Color
    let onTap: (() -> Void)?

    init(
        icon: String,
        title: String,
        score: Double,
        detail: String,
        color: Color,
        onTap: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.score = score
        self.detail = detail
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if let onTap = onTap {
                // Tappable version
                Button(action: {
                    HapticManager.light()
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                // Non-tappable version
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Header with icon
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.tertiary)
                }
            }

            // Score with circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                // Progress circle
                Circle()
                    .trim(from: 0, to: min(score / 100.0, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xs)

            // Title and detail
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Text(detail)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .statCardStyle()
    }
}

// MARK: - KPI Health Card

/// Large card displaying overall KPI health status
struct KPIHealthCard: View {
    let healthStatus: HealthStatus
    let overallScore: Double
    let dateRangeText: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Health icon
            Image(systemName: healthStatus.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: healthStatus.color))

            // Health status - colored to match health level
            Text(healthStatus.rawValue)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: healthStatus.color))

            // Score
            Text("\(Int(overallScore))/100")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.secondary)

            // Date range
            Text(dateRangeText)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .fill(Color(hex: healthStatus.color).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .stroke(Color(hex: healthStatus.color).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - KPI Summary Row

/// Compact row for displaying KPI summary info
struct KPISummaryRow: View {
    let title: String
    let value: String
    let icon: String?
    let color: Color?

    init(
        title: String,
        value: String,
        icon: String? = nil,
        color: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color ?? DesignSystem.Colors.secondary)
                    .frame(width: 20)
            }

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(color ?? DesignSystem.Colors.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Preview

#Preview("KPI Metric Card") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            KPIMetricCard(
                icon: "gauge.with.dots.needle.67percent",
                title: "Efficiency",
                score: 85,
                detail: "12 under estimate",
                color: .blue
            )

            KPIMetricCard(
                icon: "target",
                title: "Accuracy",
                score: 72,
                detail: "18 within 25%",
                color: .green
            )
        }

        HStack(spacing: 16) {
            KPIMetricCard(
                icon: "person.2.fill",
                title: "Utilization",
                score: 68,
                detail: "120.5 hrs tracked",
                color: .purple,
                onTap: {
                    print("Tapped utilization")
                }
            )

            KPIMetricCard(
                icon: "checkmark.circle.fill",
                title: "Tasks",
                score: 90,
                detail: "45 of 50 total",
                color: .orange
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("KPI Health Card") {
    VStack(spacing: 20) {
        KPIHealthCard(
            healthStatus: .excellent,
            overallScore: 87,
            dateRangeText: "This Week"
        )

        KPIHealthCard(
            healthStatus: .good,
            overallScore: 72,
            dateRangeText: "Last 30 Days"
        )

        KPIHealthCard(
            healthStatus: .fair,
            overallScore: 55,
            dateRangeText: "This Month"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
