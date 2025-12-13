import SwiftUI
import SwiftData

struct TaskDetailHeaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    private let externalAlert: Binding<TaskActionAlert?>?
    @State private var localAlert: TaskActionAlert?
    private var alertBinding: Binding<TaskActionAlert?> {
        externalAlert ?? $localAlert
    }

    private var parentTask: Task? {
        guard let parentId = task.parentTask?.id else { return nil }
        return allTasks.first { $0.id == parentId }
    }

    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // MARK: - Title & Context Row
            TitleContextRow(task: task, project: task.project, parentTask: parentTask)

            // MARK: - Status & Priority Strip
            StatusPriorityRow(task: task, modelContext: modelContext, alertBinding: alertBinding)

            // MARK: - Schedule Summary Row
            if hasScheduleInfo {
                ScheduleSummaryRow(task: task)
            }

            // MARK: - Quantity Overview
            if hasQuantityInfo {
                QuantitySummaryRow(task: task)
            }

            // MARK: - Time / Effort Summary
            if hasTimeInfo {
                TimeSummaryRow(task: task, allTasks: allTasks)
            }

            // MARK: - Subtasks Progress
            if hasSubtasks {
                SubtasksSummaryRow(task: task)
            }

            // MARK: - Dependencies / Blockers
            if hasDependencies {
                DependenciesSummaryRow(task: task)
            }

            // MARK: - Tags Row
            if hasTags {
                TagsSummaryRow(tags: Array(task.tags ?? []))
            }

            // MARK: - Notes Preview
            if hasNotes {
                NotesPreviewRow(notes: task.notes!)
            }

            // MARK: - Quick Actions Row
            QuickActionsRow(task: task, modelContext: modelContext, alertBinding: alertBinding)
        }
        .padding(DesignSystem.Spacing.lg)
        .detailCardStyle()
        .taskActionAlert(alert: alertBinding)
    }

    // MARK: - Visibility Helpers

    private var hasScheduleInfo: Bool {
        task.startDate != nil || task.endDate != nil
    }

    private var hasQuantityInfo: Bool {
        task.isUnitQuantifiable && (task.expectedQuantity != nil || task.quantity != nil)
    }

    private var hasTimeInfo: Bool {
        task.totalTimeSpent > 0 || task.effectiveEstimate != nil || task.hasActiveTimer
    }

    private var hasSubtasks: Bool {
        (task.subtasks?.count ?? 0) > 0
    }

    private var hasDependencies: Bool {
        let dependsOnCount = task.dependsOn?.count ?? 0
        let blockedByCount = TaskService.blockedByTasks(for: task, from: allTasks).count
        return dependsOnCount > 0 || blockedByCount > 0
    }

    private var hasTags: Bool {
        (task.tags?.count ?? 0) > 0
    }

    private var hasNotes: Bool {
        if let notes = task.notes, !notes.isEmpty {
            return true
        }
        return false
    }
}

// MARK: - Title & Context Row

private struct TitleContextRow: View {
    let task: Task
    let project: Project?
    let parentTask: Task?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Project / Context line
            if let project = project {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 6, height: 6)
                    Text(project.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Title
            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Parent task indicator
            if let parent = parentTask {
                NavigationLink(destination: TaskDetailView(task: parent)) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.up.left")
                            .font(.caption2)
                        Text("Part of: \(parent.title)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Status & Priority Row

private struct StatusPriorityRow: View {
    @Bindable var task: Task
    let modelContext: ModelContext
    let alertBinding: Binding<TaskActionAlert?>

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }

    private var priorityColor: Color {
        Priority(rawValue: task.priority)?.color ?? .gray
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status pill
            StatusPill(
                status: task.status,
                color: statusColor,
                onTap: {
                    let router = TaskActionRouter()
                    let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
                    let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                    _ = router.performWithExecutor(action, on: task, context: context) { alert in
                        alertBinding.wrappedValue = alert
                    }
                }
            )

            // Priority pill
            PriorityPill(priority: Priority(rawValue: task.priority) ?? .medium, color: priorityColor)
        }
    }
}

private struct StatusPill: View {
    let status: TaskStatus
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.caption2)
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct PriorityPill: View {
    let priority: Priority
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
                .font(.caption2)
            Text(priority.label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Schedule Summary Row

private struct ScheduleSummaryRow: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Schedule")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if let startDate = task.startDate, let endDate = task.endDate {
                // Full schedule with working window
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(formatDateRange(start: startDate, end: endDate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let daysLeft = calculateDaysLeft(to: endDate), !task.isCompleted {
                            Text("• \(daysLeft)")
                                .font(.caption)
                                .foregroundStyle(daysLeft.contains("overdue") ? .red : .secondary)
                        }
                    }

                    if task.isCompleted, let completedDate = task.completedDate {
                        Text("Completed \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            } else if let startDate = task.startDate {
                // Start date only
                Text("Start: \(startDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            } else if let endDate = task.endDate {
                // Due date only
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Due: \(endDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let daysLeft = calculateDaysLeft(to: endDate), !task.isCompleted {
                            Text("• \(daysLeft)")
                                .font(.caption)
                                .foregroundStyle(daysLeft.contains("overdue") ? .red : .secondary)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let startStr = start.formatted(date: .abbreviated, time: .omitted)
        let endStr = end.formatted(date: .abbreviated, time: .omitted)
        return "\(startStr) – \(endStr)"
    }

    private func calculateDaysLeft(to date: Date) -> String? {
        let now = Date()
        let timeInterval = date.timeIntervalSince(now)
        let days = Int(timeInterval / 86400)

        if days < 0 {
            return "\(abs(days)) days overdue"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }
}

// MARK: - Quantity Summary Row

private struct QuantitySummaryRow: View {
    let task: Task

    private var progressColor: Color {
        guard let progress = task.quantityProgress else { return .secondary }
        if progress >= 1.0 {
            return DesignSystem.Colors.success
        } else if progress >= 0.75 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.info
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: task.unitIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Quantity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if let expected = task.expectedQuantity, let completed = task.quantity {
                // Progress tracking
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: 4) {
                        Text("\(formatQuantity(completed)) of \(formatQuantity(expected)) \(task.unitDisplayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let progress = task.quantityProgress {
                            Text("(\(Int(progress * 100))%)")
                                .font(.caption)
                                .foregroundStyle(progressColor)
                        }
                    }

                    // Progress bar
                    if let progress = task.quantityProgress {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            } else if let expected = task.expectedQuantity {
                // Planned but not started
                Text("Target: \(formatQuantity(expected)) \(task.unitDisplayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            } else if let completed = task.quantity {
                // Completed without plan
                Text("\(formatQuantity(completed)) \(task.unitDisplayName) completed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Time Summary Row

private struct TimeSummaryRow: View {
    let task: Task
    let allTasks: [Task]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Time Tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Time spent
                if task.totalTimeSpent > 0 {
                    HStack(spacing: 4) {
                        Text("Logged: \(task.totalTimeSpent.formattedTime())")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let estimate = task.effectiveEstimate {
                            let progress = Double(task.totalTimeSpent) / Double(estimate)
                            Text("of \(estimate.formattedTime()) (\(Int(progress * 100))%)")
                                .font(.caption)
                                .foregroundStyle(progress > 1.0 ? .red : .secondary)
                        }
                    }
                } else if let estimate = task.effectiveEstimate {
                    Text("Estimate: \(estimate.formattedTime())")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                // Active timer indicator
                if task.hasActiveTimer {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .pulsingAnimation(active: true)
                        Text("Timer running")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Subtasks Summary Row

private struct SubtasksSummaryRow: View {
    let task: Task

    private var completedCount: Int {
        task.completedDirectSubtaskCount
    }

    private var totalCount: Int {
        task.subtaskCount
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.indent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Subtasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            HStack(spacing: 4) {
                Text("\(completedCount) of \(totalCount) completed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("(\(Int(progress * 100))%)")
                    .font(.caption)
                    .foregroundStyle(progress >= 1.0 ? .green : .secondary)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Dependencies Summary Row

private struct DependenciesSummaryRow: View {
    let task: Task

    private var blockingCount: Int {
        task.blockingDependencies.count
    }

    private var dependsOnCount: Int {
        task.dependsOn?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Dependencies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if blockingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Blocked by \(blockingCount) \(blockingCount == 1 ? "task" : "tasks")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            } else if dependsOnCount > 0 {
                Text("Depends on \(dependsOnCount) \(dependsOnCount == 1 ? "task" : "tasks") (all completed)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockingCount > 0 ? DesignSystem.Colors.warning.opacity(0.1) : DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Tags Summary Row

private struct TagsSummaryRow: View {
    let tags: [Tag]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            FlowLayout(spacing: 6) {
                ForEach(tags.prefix(5)) { tag in
                    TagBadge(tag: tag)
                }

                if tags.count > 5 {
                    Text("+\(tags.count - 5)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Notes Preview Row

private struct NotesPreviewRow: View {
    let notes: String

    private var preview: String {
        let maxLength = 100
        if notes.count > maxLength {
            return String(notes.prefix(maxLength)) + "…"
        } else {
            return notes
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text(preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Quick Actions Row

private struct QuickActionsRow: View {
    @Bindable var task: Task
    let modelContext: ModelContext
    let alertBinding: Binding<TaskActionAlert?>

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Timer button (if time tracking is relevant)
            if task.status != .completed {
                Button {
                    toggleTimer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: task.hasActiveTimer ? "stop.circle.fill" : "play.circle.fill")
                            .font(.caption)
                        Text(task.hasActiveTimer ? "Stop Timer" : "Start Timer")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(task.hasActiveTimer ? Color.red : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(task.status == .blocked && !task.hasActiveTimer)
            }

            Spacer()

            // Complete/Reopen toggle
            Button {
                toggleComplete()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: task.isCompleted ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                    Text(task.isCompleted ? "Reopen" : "Complete")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(task.isCompleted ? Color.orange : Color.green)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleTimer() {
        let router = TaskActionRouter()
        let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        if task.hasActiveTimer {
            _ = router.performWithExecutor(.stopTimer, on: task, context: context) { alert in
                alertBinding.wrappedValue = alert
            }
        } else {
            _ = router.performWithExecutor(.startTimer, on: task, context: context) { alert in
                alertBinding.wrappedValue = alert
            }
        }
    }

    private func toggleComplete() {
        let router = TaskActionRouter()
        let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
        let action: TaskAction = task.isCompleted ? .uncomplete : .complete
        _ = router.performWithExecutor(action, on: task, context: context) { alert in
            alertBinding.wrappedValue = alert
        }
    }
}
