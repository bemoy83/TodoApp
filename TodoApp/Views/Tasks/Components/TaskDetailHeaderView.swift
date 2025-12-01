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

    @State private var notesExpanded: Bool
    @State private var isEditingTitle = false
    @State private var editedTitle: String

    private var parentTask: Task? {
        guard let parentId = task.parentTask?.id else { return nil }
        return allTasks.first { $0.id == parentId }
    }

    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
        let notesLength = task.notes?.count ?? 0
        _notesExpanded = State(initialValue: notesLength > 0 && notesLength <= 100)
        _editedTitle = State(initialValue: task.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Parent breadcrumb (conditional - only if subtask)
            if let parent = parentTask {
                NavigationLink(destination: TaskDetailView(task: parent)) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Subtask of")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "arrow.turn.up.left")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text(parent.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Spacer()

                            /*Image(systemName: "chevron.right")
                                .font(.body)
                                .foregroundStyle(.tertiary)*/
                        }
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .detailCardStyle()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Title (always shown, editable)
                SharedTitleSection(
                    item: task,
                    isEditing: $isEditingTitle,
                    editedTitle: $editedTitle,
                    placeholder: "Task title"
                )

                // Status Section (always shown)
                StatusSection(
                    task: task,
                    alertBinding: alertBinding,
                    modelContext: modelContext
                )

                // Schedule Section (conditional - shows working window with start/due)
                if hasScheduleInfo {
                    ScheduleSection(task: task)
                }

                // Date Conflict Warning (Phase 3: Hybrid Date Constraints)
                if task.hasDateConflicts {
                    DateConflictWarningSection(task: task)
                }

                // Organization Section (always shown - priority is always relevant)
                OrganizationSection(task: task)

                // Basic Dates Section (shows Created/Completed only)
                BasicDatesSection(task: task)

                // Notes Section (conditional - only if has notes)
                if let notes = task.notes, !notes.isEmpty {
                    SharedNotesSection(notes: notes, isExpanded: $notesExpanded)
                }
            }
            .detailCardStyle()
        }
        .taskActionAlert(alert: alertBinding)
    }

    // Conditional logic
    private var hasScheduleInfo: Bool {
        task.startDate != nil || task.endDate != nil
    }
}

// MARK: - Status Section

private struct StatusSection: View {
    @Bindable var task: Task
    let alertBinding: Binding<TaskActionAlert?>
    let modelContext: ModelContext
    
    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Status")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Button {
                let router = TaskActionRouter()
                let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
                let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                _ = router.performWithExecutor(action, on: task, context: context) { alert in
                    alertBinding.wrappedValue = alert
                }
            } label: {
                HStack {
                    Image(systemName: task.status.icon)
                        .font(.body)
                        .foregroundStyle(statusColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(task.status.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)
                    }
                    
                    Spacer()
                    
                    Text(task.isCompleted ? "Tap to mark incomplete" : "Tap to complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)
            
            // Blocking dependencies (conditional - only if blocked)
            if task.status == .blocked {
                Divider()
                BlockingDependenciesInfo(task: task)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Basic Dates Section

private struct BasicDatesSection: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Info")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Created date (always shown)
                SharedDateRow(
                    icon: "clock",
                    label: "Created",
                    date: task.createdDate,
                    color: .secondary
                )

                // Completed date (conditional)
                if let completedDate = task.completedDate {
                    SharedDateRow(
                        icon: "checkmark.circle.fill",
                        label: "Completed",
                        date: completedDate,
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Schedule Section

private struct ScheduleSection: View {
    @Bindable var task: Task

    @State private var dateEditItem: DateEditItem?

    // Identifiable wrapper to fix sheet state capture bug
    private struct DateEditItem: Identifiable {
        let id = UUID()
        let dateType: DateEditSheet.DateEditType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DesignSystem.Spacing.md) {
                // Start date
                if let startDate = task.startDate {
                    SharedDateRow(
                        icon: "play.circle.fill",
                        label: "Start",
                        date: startDate,
                        color: .blue,
                        isActionable: true,
                        showTime: true,
                        onTap: {
                            dateEditItem = DateEditItem(dateType: .start)
                            HapticManager.light()
                        }
                    )
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // End date (labeled as "Due" - no redundancy with old dueDate field)
                if let endDate = task.endDate {
                    SharedDateRow(
                        icon: "flag.fill",
                        label: "Due",
                        date: endDate,
                        color: endDate < Date() && !task.isCompleted ? .red : .orange,
                        isActionable: true,
                        showTime: true,
                        onTap: {
                            dateEditItem = DateEditItem(dateType: .end)
                            HapticManager.light()
                        }
                    )
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // Working window summary (when both dates exist)
                if let startDate = task.startDate, let endDate = task.endDate {
                    let availableHours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
                    workingWindowSummary(hours: availableHours)

                    // Schedule vs Estimate comparison (when estimate exists)
                    if let estimateSeconds = task.effectiveEstimate {
                        scheduleEstimateComparison(availableHours: availableHours, estimateSeconds: estimateSeconds)
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(item: $dateEditItem) { item in
            DateEditSheet(task: task, dateType: item.dateType)
        }
    }

    @ViewBuilder
    private func workingWindowSummary(hours: Double) -> some View {
        // Calculate work days based on actual work hours (not calendar days)
        let workDays = hours / WorkHoursCalculator.workdayHours

        // Format work days nicely (show 1 decimal place if not a whole number)
        let daysText = workDays.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
            : String(format: "%.1f work days", workDays)

        TaskRowIconValueLabel(
            icon: "clock.arrow.2.circlepath",
            label: "\(daysText) • \(String(format: "%.1f", hours)) work hours available",
            value: "Working Window",
            tint: .green
        )
        .padding(.top, DesignSystem.Spacing.xs)
    }

    private func scheduleEstimateComparison(availableHours: Double, estimateSeconds: Int) -> some View {
        let estimateHours = Double(estimateSeconds) / 3600.0
        let ratio = estimateHours / availableHours

        // Determine status based on ratio
        let status: ScheduleEstimateStatus = {
            if estimateHours > availableHours {
                return .insufficient  // Need more time than available
            } else if ratio >= 0.75 {
                return .tight  // 75-100% utilized, tight schedule
            } else {
                return .comfortable  // < 75% utilized, good margin
            }
        }()

        let (icon, color, message): (String, Color, String) = {
            switch status {
            case .insufficient:
                return (
                    "exclamationmark.triangle.fill",
                    .red,
                    "Insufficient time: Need \(String(format: "%.1f", estimateHours)) hrs, only \(String(format: "%.1f", availableHours)) hrs available"
                )
            case .tight:
                return (
                    "exclamationmark.triangle.fill",
                    .orange,
                    "Tight schedule: Need \(String(format: "%.1f", estimateHours)) hrs, have \(String(format: "%.1f", availableHours)) hrs available"
                )
            case .comfortable:
                let margin = availableHours - estimateHours
                return (
                    "checkmark.circle.fill",
                    .green,
                    "Comfortable margin: Need \(String(format: "%.1f", estimateHours)) hrs, \(String(format: "%.1f", margin)) hrs buffer"
                )
            }
        }()

        return TaskRowIconValueLabel(
            icon: icon,
            label: message,
            value: "Time Planning",
            tint: color
        )
        .padding(.top, DesignSystem.Spacing.xs)
    }
}

// MARK: - Schedule Estimate Status

private enum ScheduleEstimateStatus {
    case insufficient  // Estimate exceeds available time
    case tight         // Estimate is 75-100% of available time
    case comfortable   // Estimate is < 75% of available time
}


// MARK: - Organization Section

private struct OrganizationSection: View {
    @Bindable var task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Organization")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Project (conditional - only if task has project)
                if let project = task.project {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.body)
                            .foregroundStyle(Color(hex: project.color))
                            .frame(width: 28)

                        Text("Project")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(project.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }

                // Priority (always shown)
                Menu {
                    ForEach([Priority.urgent, .high, .medium, .low], id: \.self) { priority in
                        Button {
                            task.priority = priority.rawValue
                            HapticManager.selection()
                        } label: {
                            Label(priority.label, systemImage: priority.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: Priority(rawValue: task.priority)?.icon ?? "")
                            .font(.body)
                            .foregroundStyle(Priority(rawValue: task.priority)?.color ?? .gray)
                            .frame(width: 28)

                        Text("Priority")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(Priority(rawValue: task.priority)?.label ?? "Medium")
                            .font(.subheadline)
                            .foregroundStyle(Priority(rawValue: task.priority)?.color ?? .gray)

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Blocking Dependencies Info

private struct BlockingDependenciesInfo: View {
    let task: Task
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    
                    Text("Dependencies")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    let ownBlocks = task.blockingDependencies
                    if !ownBlocks.isEmpty {
                        ForEach(ownBlocks.prefix(5)) { dep in
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.warning)
                                Text(dep.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 28)
                        }
                        
                        if ownBlocks.count > 5 {
                            Text("+ \(ownBlocks.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                    
                    let subtaskBlocks = task.blockingSubtaskDependencies
                    if !subtaskBlocks.isEmpty {
                        Text("Subtask dependencies:")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .padding(.leading, 28)
                        
                        ForEach(Array(subtaskBlocks.prefix(3).enumerated()), id: \.offset) { index, block in
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Text("\(block.subtask.title) → \(block.dependency.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 28)
                        }
                        
                        if subtaskBlocks.count > 3 {
                            Text("+ \(subtaskBlocks.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
    }
}

// MARK: - Date Conflict Warning Section (Phase 3: Hybrid Date Constraints)

private struct DateConflictWarningSection: View {
    let task: Task
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Timeline Warning")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date Conflict Detected")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.warning)

                        if let message = task.dateConflictMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.secondary)
                                .lineLimit(isExpanded ? nil : 2)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.Colors.warning.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("This task's dates fall outside the project timeline. This may indicate prep work (before event) or cleanup work (after event).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, DesignSystem.Spacing.xs)

                    // Project dates for reference
                    if let project = task.project {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Project Timeline:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            if let projectStart = project.startDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                    Text("Starts: \(projectStart.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let projectDue = project.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                    Text("Ends: \(projectDue.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.tertiaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    // Quick Fix Actions (Phase 5)
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Quick Fixes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DesignSystem.Spacing.xs)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            // Adjust task to project dates
                            Button {
                                withAnimation {
                                    task.adjustToProjectDates()
                                    HapticManager.success()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.caption)
                                    Text("Fit to Project")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.info)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                            }

                            // Expand project to include task
                            Button {
                                withAnimation {
                                    task.expandProjectToIncludeTask()
                                    HapticManager.success()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption)
                                    Text("Expand Project")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.warning)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
