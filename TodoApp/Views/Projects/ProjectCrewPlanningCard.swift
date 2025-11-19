import SwiftUI

/// Displays project-level crew planning recommendations based on total effort and deadline.
/// Shows strategic resource planning for entire project scope with historical learning.
struct ProjectCrewPlanningCard: View {
    let project: Project
    let allTasks: [Task] // For historical analytics

    // MARK: - Computed Properties

    /// Total effort from all ACTIVE task estimates (person-hours)
    /// Only counts tasks that still need to be done (not completed or archived)
    private var totalEffortHours: Double {
        guard let tasks = project.tasks else { return 0 }

        let activeTasks = tasks.filter { !$0.isCompleted && !$0.isArchived }
        let totalSeconds = activeTasks.reduce(0) { sum, task in
            sum + (task.effectiveEstimate ?? 0)
        }

        return totalSeconds > 0 ? Double(totalSeconds) / 3600.0 : 0
    }

    /// Available work hours from now until project deadline
    private var availableHours: Double {
        guard let deadline = project.dueDate else { return 0 }
        return WorkHoursCalculator.calculateAvailableHours(from: Date(), to: deadline)
    }

    /// Task type breakdown for this project
    private var taskTypeBreakdown: [(taskType: String, hours: Double, analytics: TaskTypeAnalytics?)] {
        guard let tasks = project.tasks else { return [] }

        let activeTasks = tasks.filter { !$0.isCompleted && !$0.isArchived }
        let tasksByType = Dictionary(grouping: activeTasks, by: { $0.taskType })

        return tasksByType.compactMap { (taskType, typeTasks) -> (String, Double, TaskTypeAnalytics?)? in
            guard let taskType = taskType else { return nil }

            let hours = typeTasks.reduce(0.0) { sum, task in
                sum + (Double(task.effectiveEstimate ?? 0) / 3600.0) // effectiveEstimate is in SECONDS
            }

            let analytics = TaskTypeAnalytics.calculate(for: taskType, from: allTasks)

            return (taskType, hours, analytics)
        }.sorted(by: { $0.hours > $1.hours })
    }

    /// Adjusted effort accounting for historical variance
    private var adjustedEffortHours: Double {
        guard !taskTypeBreakdown.isEmpty else { return totalEffortHours }

        // Sum adjusted effort for tasks WITH task types
        let adjustedFromBreakdown = taskTypeBreakdown.reduce(0.0) { total, breakdown in
            if let analytics = breakdown.analytics, analytics.isSignificant {
                return total + analytics.adjustedEffort(from: breakdown.hours)
            } else {
                return total + breakdown.hours
            }
        }

        // Add effort from tasks WITHOUT task types (can't adjust without type data)
        let breakdownTotal = taskTypeBreakdown.reduce(0.0) { $0 + $1.hours }
        let untypedTasksEffort = totalEffortHours - breakdownTotal

        return adjustedFromBreakdown + untypedTasksEffort
    }

    /// Whether historical adjustment was applied
    private var usesHistoricalAdjustment: Bool {
        taskTypeBreakdown.contains { $0.analytics?.isSignificant ?? false }
    }

    /// Minimum crew size needed (using adjusted effort if available)
    private var minimumPersonnel: Int {
        WorkHoursCalculator.calculateMinimumPersonnel(
            effortHours: usesHistoricalAdjustment ? adjustedEffortHours : totalEffortHours,
            availableHours: availableHours
        )
    }

    /// Crew size scenarios
    private var scenarios: [(people: Int, hoursPerPerson: Double, status: String, icon: String)] {
        guard totalEffortHours > 0, minimumPersonnel > 0 else { return [] }

        let effort = usesHistoricalAdjustment ? adjustedEffortHours : totalEffortHours

        return [
            (minimumPersonnel, effort / Double(minimumPersonnel), "Recommended", "checkmark.circle.fill"),
            (minimumPersonnel + 1, effort / Double(minimumPersonnel + 1), "Safe", "checkmark.circle.fill"),
            (minimumPersonnel + 2, effort / Double(minimumPersonnel + 2), "Buffer", "checkmark.circle.fill")
        ]
    }

    /// Whether to show this card (has deadline, tasks with estimates, deadline in future)
    var shouldShow: Bool {
        guard let deadline = project.dueDate else { return false }
        guard deadline > Date() else { return false }
        guard totalEffortHours > 0 else { return false }
        return true
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.info)
                    .frame(width: 20)

                Text("Crew Planning")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            Divider()

            // Project summary
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                summaryRow(
                    icon: "briefcase.fill",
                    label: "Total Planned Work",
                    value: "\(String(format: "%.0f", totalEffortHours)) person-hours"
                )

                if usesHistoricalAdjustment {
                    summaryRow(
                        icon: "brain.head.profile",
                        label: "Adjusted Estimate",
                        value: "\(String(format: "%.0f", adjustedEffortHours)) person-hours"
                    )
                }

                summaryRow(
                    icon: "calendar",
                    label: "Available Time",
                    value: "\(String(format: "%.0f", availableHours)) hours"
                )

                if let deadline = project.dueDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
                    summaryRow(
                        icon: "clock.fill",
                        label: "Deadline",
                        value: "\(days) \(days == 1 ? "day" : "days") away"
                    )
                }
            }

            // Task type breakdown (if historical data available)
            if usesHistoricalAdjustment, !taskTypeBreakdown.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Task Mix Analysis")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                        .textCase(.uppercase)

                    ForEach(taskTypeBreakdown, id: \.taskType) { breakdown in
                        if let analytics = breakdown.analytics, analytics.isSignificant {
                            HStack(spacing: 6) {
                                Image(systemName: abs(analytics.typicalOverrunPercentage) >= 10 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(abs(analytics.typicalOverrunPercentage) >= 10 ? DesignSystem.Colors.warning : DesignSystem.Colors.success)

                                Text("\(breakdown.taskType)")
                                    .font(DesignSystem.Typography.caption)

                                Spacer()

                                Text(analytics.varianceDescription)
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            // Recommended crew callout
            HStack(spacing: 8) {
                Image(systemName: usesHistoricalAdjustment ? "brain.head.profile" : "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(usesHistoricalAdjustment ? DesignSystem.Colors.success : DesignSystem.Colors.warning)

                Text(usesHistoricalAdjustment ? "Recommended crew:" : "Minimum crew size:")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()

                Text("\(minimumPersonnel) \(minimumPersonnel == 1 ? "person" : "people")")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(usesHistoricalAdjustment ? DesignSystem.Colors.success : DesignSystem.Colors.warning)
            }
            .padding(DesignSystem.Spacing.sm)
            .background((usesHistoricalAdjustment ? DesignSystem.Colors.success : DesignSystem.Colors.warning).opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)

            // Scenarios
            Text("Crew Scenarios:")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .padding(.top, DesignSystem.Spacing.xs)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(scenarios, id: \.people) { scenario in
                    scenarioRow(scenario)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryGroupedBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    // MARK: - Subviews

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .frame(width: 16)

            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.primary)
        }
    }

    private func scenarioRow(_ scenario: (people: Int, hoursPerPerson: Double, status: String, icon: String)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: scenario.icon)
                .font(.body)
                .foregroundStyle(scenario.people == minimumPersonnel ? DesignSystem.Colors.warning : DesignSystem.Colors.success)
                .frame(width: 18)

            Text("\(scenario.people) \(scenario.people == 1 ? "person" : "people")")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f hrs/person", scenario.hoursPerPerson))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                Text(scenario.status)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scenario.people == minimumPersonnel ? DesignSystem.Colors.warning : DesignSystem.Colors.success)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.tertiaryBackground)
        )
    }
}
