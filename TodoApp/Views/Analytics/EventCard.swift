import SwiftUI

// MARK: - Event Card

/// Card displaying project/event status and progress
struct EventCard: View {
    let project: Project
    let onTap: () -> Void

    private var healthColor: Color {
        switch project.healthStatus {
        case .onTrack: return DesignSystem.Colors.success
        case .warning: return DesignSystem.Colors.warning
        case .critical: return DesignSystem.Colors.error
        }
    }

    private var healthLabel: String {
        switch project.healthStatus {
        case .onTrack: return "On Track"
        case .warning: return "Attention"
        case .critical: return "Critical"
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header: Project name + health indicator
                HStack {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 12, height: 12)

                    Text(project.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: project.healthStatus.icon)
                            .font(.caption)
                        Text(healthLabel)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(healthColor)
                }

                // Progress metrics
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Task completion
                    HStack {
                        Text("\(project.completedTasks)/\(project.tasks?.count ?? 0) tasks complete")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondary)

                        Spacer()

                        if let count = project.tasks?.count, count > 0 {
                            Text("\(Int((Double(project.completedTasks) / Double(count)) * 100))%")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }

                    // Progress bar
                    if let count = project.tasks?.count, count > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(DesignSystem.Colors.tertiary.opacity(0.2))
                                    .frame(height: 6)

                                Rectangle()
                                    .fill(healthColor)
                                    .frame(
                                        width: geometry.size.width * (Double(project.completedTasks) / Double(count)),
                                        height: 6
                                    )
                            }
                            .cornerRadius(3)
                        }
                        .frame(height: 6)
                    }

                    // Budget tracking - three-tier view
                    if let budget = project.estimatedHours {
                        VStack(alignment: .leading, spacing: 4) {
                            // Budget (contract)
                            HStack {
                                Text("Budget:")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.tertiary)
                                Text("\(String(format: "%.0f", budget))h")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.secondary)

                                Spacer()

                                Text("(contract)")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.tertiary)
                            }

                            // Planned (from tasks)
                            if let planned = project.taskPlannedHours {
                                HStack {
                                    Text("Planned:")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.tertiary)
                                    Text("\(String(format: "%.1f", planned))h")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(DesignSystem.Colors.secondary)

                                    Spacer()

                                    // Show variance if over budget
                                    if let variance = project.planningVariance, variance > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                            Text("+\(String(format: "%.0f", variance))h")
                                                .font(DesignSystem.Typography.caption2)
                                        }
                                        .foregroundStyle(variance > budget * 0.2 ? DesignSystem.Colors.error : DesignSystem.Colors.warning)
                                    } else {
                                        Text("(from tasks)")
                                            .font(DesignSystem.Typography.caption2)
                                            .foregroundStyle(DesignSystem.Colors.tertiary)
                                    }
                                }
                            }

                            // Actual (logged)
                            HStack {
                                Text("Actual:")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.tertiary)
                                Text("\(String(format: "%.1f", project.totalTimeSpentHours))h")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.secondary)

                                Spacer()

                                if let progress = project.timeProgress {
                                    Text("\(Int(progress * 100))%")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(progress > 0.85 ? DesignSystem.Colors.warning : DesignSystem.Colors.tertiary)
                                }
                            }
                        }
                    }

                    // Due date
                    if let dueDate = project.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("Due \(formatDueDate(dueDate))")
                                .font(DesignSystem.Typography.caption)

                            if let days = project.daysUntilDue, days < 7, days >= 0 {
                                Text("• \(days)d")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(days < 3 ? DesignSystem.Colors.error : DesignSystem.Colors.warning)
                            }
                        }
                        .foregroundStyle(DesignSystem.Colors.tertiary)
                    }
                }
            }
            .statCardStyle()
        }
        .buttonStyle(.plain)
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Project Attention Card

/// Card for projects needing attention, grouped by project
struct ProjectAttentionCard: View {
    let projectIssue: ProjectIssue
    let onTap: () -> Void

    private var healthColor: Color {
        switch projectIssue.project.healthStatus {
        case .onTrack: return DesignSystem.Colors.success
        case .warning: return DesignSystem.Colors.warning
        case .critical: return DesignSystem.Colors.error
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap()
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Health indicator
                Image(systemName: projectIssue.project.healthStatus.icon)
                    .font(.title2)
                    .foregroundStyle(healthColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(healthColor.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: projectIssue.project.color))
                            .frame(width: 8, height: 8)

                        Text(projectIssue.project.title)
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }

                    Text(projectIssue.summaryText)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .statCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Event Card

/// Compact card for upcoming events
struct UpcomingEventCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primary)

                if let dueDate = project.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDueDate(dueDate))
                            .font(DesignSystem.Typography.caption)

                        if let days = project.daysUntilDue {
                            Text("• \(days)d away")
                                .font(DesignSystem.Typography.caption)
                        }
                    }
                    .foregroundStyle(DesignSystem.Colors.secondary)
                } else if project.status == .planning {
                    Text("In Planning")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }

            Spacer()
        }
        .statCardStyle()
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
