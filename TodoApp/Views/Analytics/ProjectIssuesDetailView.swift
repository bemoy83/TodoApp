import SwiftUI
import SwiftData

/// Detail view showing categorized problematic tasks for a project
struct ProjectIssuesDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let projectIssue: ProjectIssue

    @State private var selectedTask: Task?

    private var healthColor: Color {
        switch projectIssue.project.healthStatus {
        case .onTrack: return DesignSystem.Colors.success
        case .warning: return DesignSystem.Colors.warning
        case .critical: return DesignSystem.Colors.error
        }
    }

    // Get tasks for each issue category
    private var overdueTasks: [Task] {
        let now = Date()
        return (projectIssue.project.tasks ?? []).filter { task in
            !task.isCompleted && !task.isArchived && task.dueDate != nil && task.dueDate! < now
        }
    }

    private var blockedTasks: [Task] {
        return (projectIssue.project.tasks ?? []).filter { task in
            !task.isCompleted && !task.isArchived && task.status == .blocked
        }
    }

    private var tasksWithMissingEstimates: [Task] {
        guard projectIssue.project.status != .planning else { return [] }
        return (projectIssue.project.tasks ?? []).filter { task in
            !task.isCompleted && !task.isArchived && task.effectiveEstimate == nil && task.priority < 3
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Project header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Circle()
                                .fill(Color(hex: projectIssue.project.color))
                                .frame(width: 12, height: 12)

                            Text(projectIssue.project.title)
                                .font(DesignSystem.Typography.title2)
                                .fontWeight(.bold)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: projectIssue.project.healthStatus.icon)
                                    .font(.caption)
                                Text(projectIssue.project.healthStatus == .critical ? "Critical" : "Warning")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundStyle(healthColor)
                        }

                        Text(projectIssue.summaryText)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Overdue tasks section
                    if !overdueTasks.isEmpty {
                        issueSection(
                            title: "Overdue Tasks",
                            count: overdueTasks.count,
                            icon: "exclamationmark.triangle.fill",
                            color: DesignSystem.Colors.error,
                            tasks: overdueTasks
                        )
                    }

                    // Blocked tasks section
                    if !blockedTasks.isEmpty {
                        issueSection(
                            title: "Blocked Tasks",
                            count: blockedTasks.count,
                            icon: "hand.raised.fill",
                            color: DesignSystem.Colors.warning,
                            tasks: blockedTasks
                        )
                    }

                    // Missing estimates section
                    if !tasksWithMissingEstimates.isEmpty {
                        issueSection(
                            title: "Missing Estimates",
                            count: tasksWithMissingEstimates.count,
                            icon: "questionmark.circle.fill",
                            color: Color(hex: "#FF9500"),
                            tasks: tasksWithMissingEstimates
                        )
                    }

                    // Budget warnings section
                    if projectIssue.overPlanned || projectIssue.nearingBudget {
                        budgetWarningSection()
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Needs Attention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
        }
    }

    // MARK: - Issue Section

    @ViewBuilder
    private func issueSection(
        title: String,
        count: Int,
        icon: String,
        color: Color,
        tasks: [Task]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)

                Text("(\(count))")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(tasks) { task in
                    Button {
                        selectedTask = task
                    } label: {
                        IssueTaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Budget Warning Section

    @ViewBuilder
    private func budgetWarningSection() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignSystem.Colors.warning)

                Text("Budget Warnings")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: DesignSystem.Spacing.xs) {
                if projectIssue.overPlanned {
                    if let variance = projectIssue.project.planningVariance {
                        BudgetWarningCard(
                            title: "Over-Planned",
                            message: "Task estimates exceed budget by \(String(format: "%.0f", variance))h",
                            suggestion: "Reduce scope, add more people, or negotiate budget increase"
                        )
                    }
                }

                if projectIssue.nearingBudget {
                    if let budget = projectIssue.project.estimatedHours,
                       let progress = projectIssue.project.timeProgress {
                        BudgetWarningCard(
                            title: "Nearing Budget",
                            message: "\(String(format: "%.0f", projectIssue.project.totalTimeSpentHours))h of \(String(format: "%.0f", budget))h used (\(Int(progress * 100))%)",
                            suggestion: "Monitor remaining tasks and adjust timeline if needed"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Issue Task Row

struct IssueTaskRow: View {
    let task: Task

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status icon
            Image(systemName: task.status.icon)
                .font(.body)
                .foregroundStyle(Color(task.status.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Priority
                    if task.priority < 2 {
                        HStack(spacing: 2) {
                            Image(systemName: Priority(rawValue: task.priority)?.icon ?? "minus")
                                .font(.caption2)
                            Text(Priority(rawValue: task.priority)?.label ?? "")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(Priority(rawValue: task.priority)?.color ?? .gray)
                    }

                    // Due date if overdue
                    if let dueDate = task.dueDate, dueDate < Date() {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("Due \(formatDate(dueDate))")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.error)
                    }

                    // Blocking info
                    if task.status == .blocked {
                        let blockingCount = task.blockingDependencies.count
                        if blockingCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text("\(blockingCount) blocking")
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .foregroundStyle(DesignSystem.Colors.warning)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color(UIColor.systemBackground))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Budget Warning Card

struct BudgetWarningCard: View {
    let title: String
    let message: String
    let suggestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(DesignSystem.Colors.primary)

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.info)

                Text(suggestion)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
            .padding(.top, 2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.systemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Task.self, configurations: config)

    let project = Project(title: "Exhibition A", color: "#FF6B6B")
    let task1 = Task(title: "Install lighting", priority: 1, project: project)
    let task2 = Task(title: "Hang artwork", priority: 0, dueDate: Date().addingTimeInterval(-86400), project: project)

    container.mainContext.insert(project)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)

    let issue = ProjectIssue(
        project: project,
        issueDescriptions: ["2 overdue", "1 blocked"],
        overdueCount: 2,
        blockedCount: 1,
        missingEstimatesCount: 0,
        nearingBudget: false,
        overPlanned: false
    )

    return ProjectIssuesDetailView(projectIssue: issue)
        .modelContainer(container)
}
