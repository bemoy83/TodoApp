import SwiftUI

/// Displays project-level crew planning recommendations based on total effort and deadline.
/// Shows strategic resource planning for entire project scope.
struct ProjectCrewPlanningCard: View {
    let project: Project

    // MARK: - Computed Properties

    /// Total effort from all task estimates (person-hours)
    private var totalEffortHours: Double {
        project.taskPlannedHours ?? 0
    }

    /// Available work hours from now until project deadline
    private var availableHours: Double {
        guard let deadline = project.dueDate else { return 0 }
        return WorkHoursCalculator.calculateAvailableHours(from: Date(), to: deadline)
    }

    /// Minimum crew size needed to complete project
    private var minimumPersonnel: Int {
        WorkHoursCalculator.calculateMinimumPersonnel(
            effortHours: totalEffortHours,
            availableHours: availableHours
        )
    }

    /// Crew size scenarios (Minimum, Recommended, Safe)
    private var scenarios: [(people: Int, hoursPerPerson: Double, status: String, icon: String)] {
        guard totalEffortHours > 0, minimumPersonnel > 0 else { return [] }

        return [
            (minimumPersonnel, totalEffortHours / Double(minimumPersonnel), "Minimum", "exclamationmark.triangle.fill"),
            (minimumPersonnel + 1, totalEffortHours / Double(minimumPersonnel + 1), "Recommended", "checkmark.circle.fill"),
            (minimumPersonnel + 2, totalEffortHours / Double(minimumPersonnel + 2), "Safe", "checkmark.circle.fill")
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

            Divider()

            // Minimum crew callout
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.warning)

                Text("Minimum crew size:")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()

                Text("\(minimumPersonnel) \(minimumPersonnel == 1 ? "person" : "people")")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.warning)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.warning.opacity(0.1))
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
