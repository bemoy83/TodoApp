import SwiftUI
import SwiftData

/// TaskDetailView - Unified one-pager with collapsible mini-sections
/// All critical info visible at a glance via summary badges when sections are collapsed
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @Bindable var task: Task

    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false

    // Central alert state for executor-backed alerts
    @State private var currentAlert: TaskActionAlert?

    // MARK: - Section Expansion States

    // New header mini-sections
    @State private var isScheduleExpanded: Bool
    @State private var isOrganizationExpanded: Bool

    // Core tracking sections
    @State private var isTimeTrackingExpanded: Bool
    @State private var isEntriesExpanded: Bool
    @State private var isPersonnelExpanded: Bool
    @State private var isQuantityExpanded: Bool

    // Structure sections
    @State private var isSubtasksExpanded: Bool
    @State private var isDependenciesExpanded: Bool

    // Metadata sections
    @State private var isTagsExpanded: Bool
    @State private var isNotesExpanded: Bool
    @State private var isInfoExpanded: Bool

    private let router = TaskActionRouter()

    private var parentTask: Task? {
        guard let parentId = task.parentTask?.id else { return nil }
        return allTasks.first { $0.id == parentId }
    }

    init(task: Task) {
        self.task = task

        // Smart defaults based on task state
        if task.hasActiveTimer {
            // Execution mode - focus on time tracking
            _isScheduleExpanded = State(initialValue: false)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeTrackingExpanded = State(initialValue: true)
            _isEntriesExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: false)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isTagsExpanded = State(initialValue: false)
            _isNotesExpanded = State(initialValue: false)
            _isInfoExpanded = State(initialValue: false)
        } else if task.isCompleted {
            // Review mode - show results
            _isScheduleExpanded = State(initialValue: false)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeTrackingExpanded = State(initialValue: true)
            _isEntriesExpanded = State(initialValue: (task.timeEntries?.count ?? 0) > 0)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: task.hasQuantityProgress)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isTagsExpanded = State(initialValue: false)
            _isNotesExpanded = State(initialValue: false)
            _isInfoExpanded = State(initialValue: true) // Show completion date
        } else if (task.subtasks?.count ?? 0) > 0 || (task.dependsOn?.count ?? 0) > 0 {
            // Planning mode with structure - show work breakdown
            _isScheduleExpanded = State(initialValue: task.startDate != nil || task.endDate != nil)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeTrackingExpanded = State(initialValue: false)
            _isEntriesExpanded = State(initialValue: false)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isSubtasksExpanded = State(initialValue: true)
            _isDependenciesExpanded = State(initialValue: (task.dependsOn?.count ?? 0) > 0)
            _isTagsExpanded = State(initialValue: false)
            _isNotesExpanded = State(initialValue: false)
            _isInfoExpanded = State(initialValue: false)
        } else {
            // Default mode - show essentials
            _isScheduleExpanded = State(initialValue: task.startDate != nil || task.endDate != nil)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeTrackingExpanded = State(initialValue: true)
            _isEntriesExpanded = State(initialValue: false)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isTagsExpanded = State(initialValue: false)
            _isNotesExpanded = State(initialValue: TaskNotesSection.hasNotes(task))
            _isInfoExpanded = State(initialValue: false)
        }
    }

    var body: some View {
        let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Parent breadcrumb (outside Identity card)
                if let parent = parentTask {
                    TaskParentBreadcrumb(parentTask: parent)
                }

                // Identity Card (always visible)
                TaskIdentityCard(
                    task: task,
                    alert: $currentAlert,
                    onBlockingDepsTapped: {
                        // Jump to dependencies section
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isDependenciesExpanded = true
                        }
                    }
                )

                // Schedule section
                DetailSectionDisclosure(
                    title: "Schedule",
                    icon: "calendar",
                    isExpanded: $isScheduleExpanded,
                    summary: { scheduleSummary },
                    content: { TaskScheduleSection(task: task) }
                )

                // Organization section
                DetailSectionDisclosure(
                    title: "Organization",
                    icon: "folder",
                    isExpanded: $isOrganizationExpanded,
                    summary: { organizationSummary },
                    content: { TaskOrganizationSection(task: task) }
                )

                // Time Tracking section
                DetailSectionDisclosure(
                    title: "Time Tracking",
                    icon: "clock",
                    isExpanded: $isTimeTrackingExpanded,
                    summary: { timeTrackingSummary },
                    content: { TaskTimeTrackingView(task: task) }
                )

                // Time Entries section
                DetailSectionDisclosure(
                    title: "Time Entries",
                    icon: "list.bullet.clipboard",
                    isExpanded: $isEntriesExpanded,
                    summary: { entriesSummary },
                    content: { TimeEntriesView(task: task) }
                )

                // Personnel section
                DetailSectionDisclosure(
                    title: "Personnel",
                    icon: "person.2.fill",
                    isExpanded: $isPersonnelExpanded,
                    summary: { personnelSummary },
                    content: { TaskPersonnelView(task: task) }
                )

                // Quantity section
                DetailSectionDisclosure(
                    title: "Quantity",
                    icon: "number",
                    isExpanded: $isQuantityExpanded,
                    summary: { quantitySummary },
                    content: { TaskQuantityView(task: task) }
                )

                // TODO: Productivity section (add later)

                // Subtasks section
                DetailSectionDisclosure(
                    title: "Subtasks",
                    icon: "list.bullet.indent",
                    isExpanded: $isSubtasksExpanded,
                    summary: { subtasksSummary },
                    content: { TaskSubtasksView(task: task) }
                )

                // Dependencies section
                DetailSectionDisclosure(
                    title: "Dependencies",
                    icon: "link",
                    isExpanded: $isDependenciesExpanded,
                    summary: { dependenciesSummary },
                    content: { TaskDependenciesView(task: task) }
                )

                // Tags section
                DetailSectionDisclosure(
                    title: "Tags",
                    icon: "tag",
                    isExpanded: $isTagsExpanded,
                    summary: { tagsSummary },
                    content: { TaskTagsView(task: task) }
                )

                // Notes section
                DetailSectionDisclosure(
                    title: "Notes",
                    icon: "note.text",
                    isExpanded: $isNotesExpanded,
                    summary: { notesSummary },
                    content: { TaskNotesSection(task: task) }
                )

                // Info section
                DetailSectionDisclosure(
                    title: "Info",
                    icon: "info.circle",
                    isExpanded: $isInfoExpanded,
                    summary: { infoSummary },
                    content: { TaskInfoSection(task: task) }
                )
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    var presentedAlert = false
                    _ = router.performWithExecutor(.edit, on: task, context: ctx) { alert in
                        presentedAlert = true
                        currentAlert = alert
                    }
                    if !presentedAlert {
                        showingEditSheet = true
                    }
                } label: {
                    Image(systemName: "pencil")
                }

                Button {
                    showingMoreSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskEditView(task: task)
        }
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: task,
                onEdit: { showingEditSheet = true },
                onAddSubtask: {
                    showingMoreSheet = false
                }
            )
        }
        .taskActionAlert(alert: $currentAlert)
    }

    // MARK: - Summary Badge Views

    @ViewBuilder
    private var scheduleSummary: some View {
        Text(TaskScheduleSection.summaryText(for: task))
            .font(.caption)
            .foregroundStyle(TaskScheduleSection.summaryColor(for: task))
    }

    @ViewBuilder
    private var organizationSummary: some View {
        Text(TaskOrganizationSection.summaryText(for: task))
            .font(.caption)
            .foregroundStyle(TaskOrganizationSection.summaryColor(for: task))
    }

    @ViewBuilder
    private var timeTrackingSummary: some View {
        Text(timeTrackingSummaryText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var timeTrackingSummaryText: String {
        var text = ""

        let totalTime = task.totalTimeSpent
        if totalTime > 0 {
            text = totalTime.formattedTime()
        } else {
            text = "No time tracked"
        }

        if let estimate = task.effectiveEstimate {
            let progress = Double(task.totalTimeSpent) / Double(estimate)
            text += " • \(Int(progress * 100))%"
        }

        return text
    }

    @ViewBuilder
    private var entriesSummary: some View {
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
            Text(entriesSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("No entries")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var entriesSummaryText: String {
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
            let entryWord = entryCount == 1 ? "entry" : "entries"
            var text = "\(entryCount) \(entryWord)"

            if let lastEntry = task.timeEntries?.sorted(by: { $0.startTime > $1.startTime }).first {
                let timeAgo = Date().timeIntervalSince(lastEntry.startTime)
                if timeAgo < 3600 {
                    text += " • \(Int(timeAgo / 60))m ago"
                } else if timeAgo < 86400 {
                    text += " • \(Int(timeAgo / 3600))h ago"
                } else {
                    text += " • \(Int(timeAgo / 86400))d ago"
                }
            }
            return text
        } else {
            return "No entries"
        }
    }

    @ViewBuilder
    private var personnelSummary: some View {
        if let count = task.expectedPersonnelCount {
            let personWord = count == 1 ? "person" : "people"
            Text("\(count) \(personWord)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Not set")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var quantitySummary: some View {
        if task.hasQuantityProgress {
            let completed = task.quantity ?? 0
            let expected = task.expectedQuantity!
            let progress = task.quantityProgress!
            let progressPercent = Int(progress * 100)

            Text("\(formatQuantity(completed))/\(formatQuantity(expected)) \(task.unitDisplayName) (\(progressPercent)%)")
                .font(.caption)
                .foregroundStyle(progress >= 1.0 ? .green : .secondary)
        } else if task.unit != .none, let quantity = task.quantity {
            Text("\(formatQuantity(quantity)) \(task.unitDisplayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if task.expectedQuantity != nil {
            Text("0/\(formatQuantity(task.expectedQuantity!)) \(task.unitDisplayName) (0%)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text("Not set")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    @ViewBuilder
    private var subtasksSummary: some View {
        let subtaskCount = task.subtasks?.count ?? 0
        if subtaskCount > 0 {
            let completedCount = task.subtasks?.filter { $0.isCompleted }.count ?? 0
            Text("\(completedCount)/\(subtaskCount) completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("No subtasks")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var dependenciesSummary: some View {
        let blockingCount = task.blockingDependencies.count
        if blockingCount > 0 {
            Text("\(blockingCount) blocking")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            let totalDeps = (task.dependsOn?.count ?? 0) + (task.blockedBy?.count ?? 0)
            if totalDeps > 0 {
                let depWord = totalDeps == 1 ? "dependency" : "dependencies"
                Text("\(totalDeps) \(depWord)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var tagsSummary: some View {
        if let tags = task.tags, !tags.isEmpty {
            CompactTagSummary(tags: Array(tags))
        } else {
            Text("No tags")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var notesSummary: some View {
        Text(TaskNotesSection.summaryText(for: task))
            .font(.caption)
            .foregroundStyle(TaskNotesSection.hasNotes(task) ? .secondary : .tertiary)
    }

    @ViewBuilder
    private var infoSummary: some View {
        Text(TaskInfoSection.summaryText(for: task))
            .font(.caption)
            .foregroundStyle(TaskInfoSection.summaryColor(for: task))
    }
}
