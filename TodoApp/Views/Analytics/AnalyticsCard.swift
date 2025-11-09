import SwiftUI

/// Reusable analytics card for displaying metrics
struct AnalyticsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let onTap: (() -> Void)?

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            if let onTap = onTap {
                HapticManager.light()
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(color.opacity(0.15))
                        )

                    Spacer()

                    if onTap != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Value
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primary)

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(Color(UIColor.systemBackground))
            )
            .designShadow(DesignSystem.Shadow.sm)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

/// Small compact analytics card for grid layouts
struct CompactAnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.systemBackground))
        )
        .designShadow(DesignSystem.Shadow.sm)
    }
}

// MARK: - Preview

#Preview("Analytics Card") {
    VStack(spacing: 16) {
        AnalyticsCard(
            title: "Active Timers",
            value: "3",
            subtitle: "5 people working",
            icon: "timer",
            color: .blue,
            onTap: { print("Tapped") }
        )

        AnalyticsCard(
            title: "Hours Today",
            value: "12.5",
            icon: "clock.fill",
            color: .indigo
        )

        CompactAnalyticsCard(
            title: "Tasks Completed",
            value: "8",
            icon: "checkmark.circle.fill",
            color: .green
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
