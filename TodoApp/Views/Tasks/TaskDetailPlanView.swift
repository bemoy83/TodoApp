import SwiftUI
import SwiftData

/// Plan tab view - "Set everything up" workspace for task planning and configuration
struct TaskDetailPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @Binding var currentAlert: TaskActionAlert?

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    // Collapsible section states
    @Binding var isTimeTrackingExpanded: Bool
    @Binding var isPersonnelExpanded: Bool
    @Binding var isQuantityExpanded: Bool
    @Binding var isTagsExpanded: Bool
    @Binding var isSubtasksExpanded: Bool
    @Binding var isDependenciesExpanded: Bool

    private var parentTask: Task? {
        guard let parentId = task.parentTask?.id else { return nil }
        return allTasks.first { $0.id == parentId }
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
                        }
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .detailCardStyle()
            }

            // Title + Status Card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                SharedTitleSection(
                    item: task,
                    isEditing: .constant(false),
                    editedTitle: .constant(task.title),
                    placeholder: "Task title"
                )

                StatusSection(
                    task: task,
                    alertBinding: $currentAlert,
                    modelContext: modelContext
                )
            }
            .detailCardStyle()

            // 1️⃣ Schedule & Scope Card
            ScheduleScopeSection(task: task, alert: $currentAlert)
                .detailCardStyle()

            // Date Conflict Warning Card (if applicable)
            if task.hasDateConflicts {
                DateConflictWarningSection(task: task)
                    .detailCardStyle()
            }

            // 2️⃣ Resources Card
            ResourcesSection(
                task: task,
                isPersonnelExpanded: $isPersonnelExpanded,
                isQuantityExpanded: $isQuantityExpanded
            )
            .detailCardStyle()

            // 3️⃣ Structure Card
            StructureSection(
                task: task,
                isSubtasksExpanded: $isSubtasksExpanded,
                isDependenciesExpanded: $isDependenciesExpanded
            )
            .detailCardStyle()

            // 4️⃣ Organization Card
            OrganizationClassificationSection(
                task: task,
                isTagsExpanded: $isTagsExpanded
            )
            .detailCardStyle()

            // 5️⃣ Details Card (Dates)
            DetailsSection(task: task)
            .detailCardStyle()

            // 6️⃣ Notes Card
            NotesSection(task: task)
            .detailCardStyle()
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - 1️⃣ Schedule & Scope Section

private struct ScheduleScopeSection: View {
    @Bindable var task: Task
    @Binding var alert: TaskActionAlert?

    @State private var dateEditItem: DateEditItem?

    // Identifiable wrapper for sheet
    private struct DateEditItem: Identifiable {
        let id = UUID()
        let dateType: DateEditSheet.DateEditType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Schedule & Scope")
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

                // End date (labeled as "Due")
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

                // Working window summary
                if let startDate = task.startDate, let endDate = task.endDate {
                    let availableHours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
                    workingWindowSummary(hours: availableHours)

                    // Schedule vs Estimate comparison
                    if let estimateSeconds = task.effectiveEstimate {
                        scheduleEstimateComparison(availableHours: availableHours, estimateSeconds: estimateSeconds)
                    }
                }

                // Time Estimate (from planning perspective)
                if let estimate = task.effectiveEstimate {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "clock.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text("Time Estimate")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(estimate.formattedTime())
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                if task.isUsingCalculatedEstimate {
                                    Text("Calculated from subtasks")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()
                        }
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
        let workDays = hours / WorkHoursCalculator.workdayHours
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

        let status: ScheduleEstimateStatus = {
            if estimateHours > availableHours {
                return .insufficient
            } else if ratio >= 0.75 {
                return .tight
            } else {
                return .comfortable
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

private enum ScheduleEstimateStatus {
    case insufficient
    case tight
    case comfortable
}

// MARK: - 2️⃣ Resources Section

private struct ResourcesSection: View {
    @Bindable var task: Task
    @Binding var isPersonnelExpanded: Bool
    @Binding var isQuantityExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Resources")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                // Personnel planning
                SubsectionDisclosure(
                    title: "Personnel",
                    icon: "person.2.fill",
                    isExpanded: $isPersonnelExpanded,
                    summary: personnelSummary,
                    content: {
                        TaskPersonnelView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                )

                Divider()
                    .padding(.leading, 44) // Align with content after icon

                // Quantity tracking
                SubsectionDisclosure(
                    title: "Quantity",
                    icon: "number",
                    isExpanded: $isQuantityExpanded,
                    summary: quantitySummary,
                    content: {
                        TaskQuantityView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                )
            }
        }
    }

    private var personnelSummary: String {
        if let count = task.expectedPersonnelCount {
            let personWord = count == 1 ? "person" : "people"
            return "\(count) \(personWord)"
        } else {
            return "Not set"
        }
    }

    private var quantitySummary: String {
        if task.hasQuantityProgress {
            let completed = task.quantity ?? 0
            let expected = task.expectedQuantity!
            let progress = task.quantityProgress!
            let progressPercent = Int(progress * 100)
            return "\(formatQuantity(completed))/\(formatQuantity(expected)) \(task.unitDisplayName) (\(progressPercent)%)"
        } else if task.unit != .none, let quantity = task.quantity {
            return "\(formatQuantity(quantity)) \(task.unitDisplayName)"
        } else if task.expectedQuantity != nil {
            return "0/\(formatQuantity(task.expectedQuantity!)) \(task.unitDisplayName) (0%)"
        } else {
            return "Not set"
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - 3️⃣ Structure Section

private struct StructureSection: View {
    @Bindable var task: Task
    @Binding var isSubtasksExpanded: Bool
    @Binding var isDependenciesExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Structure")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                // Subtasks
                SubsectionDisclosure(
                    title: "Subtasks",
                    icon: "list.bullet.indent",
                    isExpanded: $isSubtasksExpanded,
                    summary: subtasksSummary,
                    content: {
                        TaskSubtasksView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                )

                Divider()
                    .padding(.leading, 44)

                // Dependencies
                SubsectionDisclosure(
                    title: "Dependencies",
                    icon: "link",
                    isExpanded: $isDependenciesExpanded,
                    summary: dependenciesSummary,
                    content: {
                        TaskDependenciesView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                )
            }
        }
    }

    private var subtasksSummary: String {
        let subtaskCount = task.subtasks?.count ?? 0
        if subtaskCount > 0 {
            let completedCount = task.subtasks?.filter { $0.isCompleted }.count ?? 0
            return "\(completedCount)/\(subtaskCount) completed"
        } else {
            return "No subtasks"
        }
    }

    private var dependenciesSummary: String {
        let blockingCount = task.blockingDependencies.count
        if blockingCount > 0 {
            return "\(blockingCount) blocking"
        } else {
            let totalDeps = (task.dependsOn?.count ?? 0) + (task.blockedBy?.count ?? 0)
            if totalDeps > 0 {
                let depWord = totalDeps == 1 ? "dependency" : "dependencies"
                return "\(totalDeps) \(depWord)"
            } else {
                return "None"
            }
        }
    }
}

// MARK: - 4️⃣ Organization Section

private struct OrganizationClassificationSection: View {
    @Bindable var task: Task
    @Binding var isTagsExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Organization")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                // Project (conditional)
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
                    .padding(.horizontal)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                    Divider()
                        .padding(.leading, 44)
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
                    .padding(.horizontal)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 44)

                // Tags
                SubsectionDisclosure(
                    title: "Tags",
                    icon: "tag",
                    isExpanded: $isTagsExpanded,
                    summary: tagsSummary,
                    content: {
                        TaskTagsView(task: task)
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                )
            }
        }
    }

    private var tagsSummary: String {
        if let tags = task.tags, !tags.isEmpty {
            let tagNames = tags.map { $0.name }.joined(separator: ", ")
            return tagNames
        } else {
            return "No tags"
        }
    }
}

// MARK: - 5️⃣ Details Section (Dates)

private struct DetailsSection: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Details")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            BasicDatesSection(task: task)
        }
        .padding(.horizontal)
    }
}

// MARK: - 6️⃣ Notes Section

private struct NotesSection: View {
    @Bindable var task: Task
    @State private var showingNoteEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if let notes = task.notes, !notes.isEmpty {
                    // Display note content
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                } else {
                    // Empty state
                    Text("No notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Add/Edit button
                UnifiedAddButton(
                    title: task.notes?.isEmpty == false ? "Edit Note" : "Add Note",
                    action: {
                        showingNoteEditor = true
                        HapticManager.selection()
                    }
                )
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingNoteEditor) {
            TaskEditView(task: task)
        }
    }
}

// MARK: - Unified Add Button Component

/// Standardized add button used across all list-based sections
/// Provides consistent visual treatment and interaction pattern
private struct UnifiedAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Components (moved from TaskDetailHeaderView)

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

            // Blocking dependencies (conditional)
            if task.status == .blocked {
                Divider()
                BlockingDependenciesInfo(task: task)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(.horizontal)
    }
}

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

private struct BasicDatesSection: View {
    let task: Task

    var body: some View {
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
}

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

                    // Quick Fix Actions
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Quick Fixes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, DesignSystem.Spacing.xs)

                        HStack(spacing: DesignSystem.Spacing.sm) {
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

// MARK: - Subsection Disclosure Component

/// Lightweight disclosure component for subsections within cards
/// Uses dividers instead of nested cards for cleaner visual hierarchy
private struct SubsectionDisclosure<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let summary: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (tappable)
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
                HapticManager.light()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Summary text (when collapsed)
                    if !isExpanded {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            // Content (when expanded)
            if isExpanded {
                content()
            }
        }
    }
}
