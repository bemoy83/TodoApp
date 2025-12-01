//
//  ProjectHeaderView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


import SwiftUI

struct ProjectHeaderView: View {
    @Bindable var project: Project
    let totalTasks: Int
    let completedTasks: Int
    let totalTimeSpent: Int
    let totalPersonHours: Double

    @State private var isEditingTitle = false
    @State private var editedTitle: String
    @State private var showingStatusSheet = false
    @State private var showingIssuesDetail = false
    @State private var dateEditItem: DateEditItem?

    // Identifiable wrapper to fix sheet state capture bug
    private struct DateEditItem: Identifiable {
        let id = UUID()
        let dateType: ProjectDateEditSheet.DateEditType
    }

    init(project: Project, totalTasks: Int, completedTasks: Int, totalTimeSpent: Int, totalPersonHours: Double) {
        self._project = Bindable(wrappedValue: project)
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.totalTimeSpent = totalTimeSpent
        self.totalPersonHours = totalPersonHours
        self._editedTitle = State(initialValue: project.title)
    }

    private var completionPercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    private var formattedPersonHours: String {
        if totalPersonHours == 0 {
            return "0"
        }
        return String(format: "%.1f", totalPersonHours)
    }

    private var statusColor: Color {
        switch project.status {
        case .planning: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.success
        case .completed: return DesignSystem.Colors.taskCompleted
        case .onHold: return DesignSystem.Colors.warning
        }
    }

    private var statusIcon: String {
        switch project.status {
        case .planning: return "lightbulb.fill"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }

    private var healthColor: Color {
        switch project.healthStatus {
        case .onTrack: return Color.green
        case .warning: return Color.orange
        case .critical: return Color.red
        }
    }

    private var healthMessage: String? {
        var messages: [String] = []

        if project.overdueTasks > 0 {
            messages.append("\(project.overdueTasks) overdue")
        }
        if project.blockedTasks > 0 {
            messages.append("\(project.blockedTasks) blocked")
        }
        if project.tasksWithMissingEstimates > 0 {
            messages.append("\(project.tasksWithMissingEstimates) need estimates")
        }
        // Phase 3: Date conflict warning
        if project.tasksWithDateConflicts > 0 {
            messages.append("\(project.tasksWithDateConflicts) date \(project.tasksWithDateConflicts == 1 ? "conflict" : "conflicts")")
        }

        return messages.isEmpty ? nil : messages.joined(separator: " • ")
    }

    private var hasTimelineInfo: Bool {
        project.startDate != nil || project.dueDate != nil
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Color + Title + Status + Progress
            VStack(spacing: DesignSystem.Spacing.lg) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 80, height: 80)
                    .designShadow(
                        ShadowStyle(
                            color: Color(hex: project.color).opacity(0.3),
                            radius: 12, x: 0, y: 4
                        )
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Title Section
                    SharedTitleSection(
                        item: project,
                        isEditing: $isEditingTitle,
                        editedTitle: $editedTitle,
                        placeholder: "Project title"
                    )

                    // Status Section
                    StatusSection(
                        project: project,
                        showingStatusSheet: $showingStatusSheet
                    )

                    // Timeline Section (conditional)
                    if hasTimelineInfo {
                        TimelineSection(
                            project: project,
                            dateEditItem: $dateEditItem
                        )
                    }

                    // Health Section (conditional) - tappable to show issues detail
                    if project.healthStatus != .onTrack, let message = healthMessage {
                        Button {
                            showingIssuesDetail = true
                        } label: {
                            HealthSection(
                                healthStatus: project.healthStatus,
                                message: message
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Progress Section (conditional)
                    if totalTasks > 0 {
                        ProgressSection(
                            completedTasks: completedTasks,
                            totalTasks: totalTasks,
                            completionPercentage: completionPercentage,
                            projectColor: project.color
                        )
                    }
                }
                .detailCardStyle()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // 2x2 stats grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                ],
                spacing: DesignSystem.Spacing.md
            ) {
                ProjectStatCard(icon: "checklist",
                                value: "\(totalTasks)",
                                label: "Tasks",
                                color: DesignSystem.Colors.info)
                ProjectStatCard(icon: "checkmark.circle.fill",
                                value: "\(completedTasks)",
                                label: "Done",
                                color: DesignSystem.Colors.success)
                ProjectStatCard(icon: "clock.fill",
                                value: totalTimeSpent.formattedTime(),
                                label: "Time",
                                color: DesignSystem.Colors.warning)
                ProjectStatCard(icon: "person.2.fill",
                                value: formattedPersonHours,
                                label: "Person-Hrs",
                                color: DesignSystem.Colors.info)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
        .sheet(isPresented: $showingStatusSheet) {
            ProjectStatusSheet(project: project)
        }
        .sheet(isPresented: $showingIssuesDetail) {
            ProjectIssuesDetailView(projectIssue: createProjectIssue())
        }
        .sheet(item: $dateEditItem) { item in
            ProjectDateEditSheet(project: project, dateType: item.dateType)
        }
    }

    // Helper to create ProjectIssue for navigation
    private func createProjectIssue() -> ProjectIssue {
        let tasks = project.tasks ?? []
        let incompleteTasks = tasks.filter { !$0.isCompleted && !$0.isArchived }

        let now = Date()
        let overdueCount = incompleteTasks.filter { task in
            guard let dueDate = task.endDate else { return false }
            return dueDate < now
        }.count

        let blockedCount = incompleteTasks.filter { $0.status == .blocked }.count

        let missingEstimates = project.status != .planning
            ? incompleteTasks.filter { $0.effectiveEstimate == nil && $0.priority < 3 }.count
            : 0

        let dateConflictsCount = incompleteTasks.filter { $0.hasDateConflicts }.count

        var issues: [String] = []
        if overdueCount > 0 { issues.append("\(overdueCount) overdue") }
        if blockedCount > 0 { issues.append("\(blockedCount) blocked") }
        if missingEstimates > 0 { issues.append("\(missingEstimates) missing estimates") }
        if dateConflictsCount > 0 { issues.append("\(dateConflictsCount) date \(dateConflictsCount == 1 ? "conflict" : "conflicts")") }

        return ProjectIssue(
            project: project,
            issueDescriptions: issues,
            overdueCount: overdueCount,
            blockedCount: blockedCount,
            missingEstimatesCount: missingEstimates,
            dateConflictsCount: dateConflictsCount,
            nearingBudget: (project.timeProgress ?? 0) >= 0.85,
            overPlanned: project.isOverPlanned
        )
    }

    // Helper function for status icons
    private func getIcon(for status: ProjectStatus) -> String {
        switch status {
        case .planning: return "lightbulb.fill"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }
}

// MARK: - Status Section

private struct StatusSection: View {
    @Bindable var project: Project
    @Binding var showingStatusSheet: Bool

    private var statusColor: Color {
        switch project.status {
        case .planning: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.success
        case .completed: return DesignSystem.Colors.taskCompleted
        case .onHold: return DesignSystem.Colors.warning
        }
    }

    private var statusIcon: String {
        switch project.status {
        case .planning: return "lightbulb.fill"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Status")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Button {
                showingStatusSheet = true
            } label: {
                HStack {
                    Image(systemName: statusIcon)
                        .font(.body)
                        .foregroundStyle(statusColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(project.status.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)
                    }

                    Spacer()

                    Text("Tap to change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}

// MARK: - Timeline Section

private struct TimelineSection: View {
    @Bindable var project: Project
    @Binding var dateEditItem: ProjectHeaderView.DateEditItem?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Timeline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DesignSystem.Spacing.md) {
                // Start date - now editable with SharedDateRow
                if let startDate = project.startDate {
                    SharedDateRow(
                        icon: "play.circle.fill",
                        label: "Start",
                        date: startDate,
                        color: .blue,
                        isActionable: true,
                        showTime: true,
                        onTap: {
                            dateEditItem = ProjectHeaderView.DateEditItem(dateType: .start)
                            HapticManager.light()
                        }
                    )
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // Due date - now editable with SharedDateRow
                if let dueDate = project.dueDate {
                    SharedDateRow(
                        icon: "flag.fill",
                        label: "Due",
                        date: dueDate,
                        color: dueDate < Date() && project.status != .completed ? .red : .orange,
                        isActionable: true,
                        showTime: true,
                        onTap: {
                            dateEditItem = ProjectHeaderView.DateEditItem(dateType: .due)
                            HapticManager.light()
                        }
                    )
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // Enhanced working window summary (when both dates exist)
                if let startDate = project.startDate, let dueDate = project.dueDate {
                    let availableHours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: dueDate)
                    workingWindowSummary(hours: availableHours)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func workingWindowSummary(hours: Double) -> some View {
        // Calculate work days based on actual work hours (not calendar days)
        let workDays = hours / WorkHoursCalculator.workdayHours

        // Format work days nicely (show 1 decimal place if not a whole number)
        let daysText = workDays.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
            : String(format: "%.1f work days", workDays)

        HStack {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 28)

            Text("Duration")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(daysText) • \(String(format: "%.1f", hours)) work hrs")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
        .padding(.top, DesignSystem.Spacing.xs)
    }
}

// MARK: - Health Section

private struct HealthSection: View {
    let healthStatus: ProjectHealthStatus
    let message: String

    private var healthColor: Color {
        switch healthStatus {
        case .onTrack: return Color.green
        case .warning: return Color.orange
        case .critical: return Color.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Health")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Image(systemName: healthStatus.icon)
                    .font(.body)
                    .foregroundStyle(healthColor)

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(healthColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Progress Section

private struct ProgressSection: View {
    let completedTasks: Int
    let totalTasks: Int
    let completionPercentage: Double
    let projectColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("\(completedTasks) of \(totalTasks) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(completionPercentage * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: projectColor))
                }

                ProgressView(value: completionPercentage)
                    .tint(Color(hex: projectColor))
                    .scaleEffect(y: 1.5)
            }
        }
        .padding(.horizontal)
    }
}
