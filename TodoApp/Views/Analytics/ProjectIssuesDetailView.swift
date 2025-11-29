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
            !task.isCompleted && !task.isArchived && task.endDate != nil && task.endDate! < now
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

    private var dateConflictTasks: [Task] {
        return (projectIssue.project.tasks ?? []).filter { task in
            !task.isCompleted && !task.isArchived && task.hasDateConflicts
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Project header
                Section {
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
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // Overdue tasks section
                if !overdueTasks.isEmpty {
                    Section {
                        ForEach(overdueTasks) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                IssueTaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignSystem.Colors.error)

                            Text("Overdue Tasks")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.semibold)

                            Text("(\(overdueTasks.count))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }

                // Blocked tasks section
                if !blockedTasks.isEmpty {
                    Section {
                        ForEach(blockedTasks) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                IssueTaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(DesignSystem.Colors.warning)

                            Text("Blocked Tasks")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.semibold)

                            Text("(\(blockedTasks.count))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }

                // Missing estimates section
                if !tasksWithMissingEstimates.isEmpty {
                    Section {
                        ForEach(tasksWithMissingEstimates) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                IssueTaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(Color(hex: "#FF9500"))

                            Text("Missing Estimates")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.semibold)

                            Text("(\(tasksWithMissingEstimates.count))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }

                // Date conflicts section
                if !dateConflictTasks.isEmpty {
                    Section {
                        ForEach(dateConflictTasks) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                DateConflictTaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignSystem.Colors.warning)

                            Text("Date Conflicts")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.semibold)

                            Text("(\(dateConflictTasks.count))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                        }
                    }
                }

                // Budget warnings section
                if projectIssue.overPlanned || projectIssue.nearingBudget {
                    Section {
                        if projectIssue.overPlanned {
                            if let variance = projectIssue.project.planningVariance {
                                BudgetWarningCard(
                                    title: "Over-Planned",
                                    message: "Task estimates exceed budget by \(String(format: "%.0f", variance))h",
                                    suggestion: "Reduce scope, add more people, or negotiate budget increase"
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignSystem.Colors.warning)

                            Text("Budget Warnings")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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

}

// MARK: - Issue Task Row

struct IssueTaskRow: View {
    let task: Task

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.error
        case .ready: return DesignSystem.Colors.secondary
        case .inProgress: return DesignSystem.Colors.info
        case .completed: return DesignSystem.Colors.success
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status icon
            Image(systemName: task.status.icon)
                .font(.body)
                .foregroundStyle(statusColor)
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
                        .foregroundStyle(Priority(rawValue: task.priority)?.color ?? Color.gray)
                    }

                    // Due date if overdue
                    if let dueDate = task.effectiveDeadline, dueDate < Date() {
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
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Date Conflict Task Row

struct DateConflictTaskRow: View {
    let task: Task

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.error
        case .ready: return DesignSystem.Colors.secondary
        case .inProgress: return DesignSystem.Colors.info
        case .completed: return DesignSystem.Colors.success
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status icon
            Image(systemName: task.status.icon)
                .font(.body)
                .foregroundStyle(statusColor)
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
                        .foregroundStyle(Priority(rawValue: task.priority)?.color ?? Color.gray)
                    }

                    // Date conflict info
                    if let message = task.dateConflictMessage {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(message)
                                .font(DesignSystem.Typography.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(DesignSystem.Colors.warning)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.tertiary)
        }
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
        .background(DesignSystem.Colors.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
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
        dateConflictsCount: 0,
        nearingBudget: false,
        overPlanned: false
    )

    return ProjectIssuesDetailView(projectIssue: issue)
        .modelContainer(container)
}
