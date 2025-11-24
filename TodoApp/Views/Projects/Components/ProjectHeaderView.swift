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

        return messages.isEmpty ? nil : messages.joined(separator: " • ")
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

                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Editable Title
                    if isEditingTitle {
                        HStack {
                            TextField("Project title", text: $editedTitle)
                                .font(DesignSystem.Typography.title2)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.plain)

                            Button("Done") {
                                project.title = editedTitle
                                isEditingTitle = false
                                HapticManager.success()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        Button {
                            isEditingTitle = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(project.title)
                                    .font(DesignSystem.Typography.title2)
                                    .multilineTextAlignment(.center)

                                Image(systemName: "pencil.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Status Badge
                    Button {
                        showingStatusSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon)
                                .font(.caption)
                            Text(project.status.rawValue)
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    // Date Range (if exists)
                    if let startDate = project.startDate, let dueDate = project.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                            Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) → \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    } else if let dueDate = project.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                            Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }

                    // Health Indicator (if not on track)
                    if project.healthStatus != .onTrack, let message = healthMessage {
                        HStack(spacing: 6) {
                            Image(systemName: project.healthStatus.icon)
                                .font(.caption)
                            Text(message)
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(healthColor)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(healthColor.opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    if totalTasks > 0 {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("\(completedTasks) of \(totalTasks) completed")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                                Spacer()
                                Text("\(Int(completionPercentage * 100))%")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color(hex: project.color))
                            }
                            ProgressView(value: completionPercentage)
                                .tint(Color(hex: project.color))
                                .scaleEffect(y: 1.5)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xxxl)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

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
