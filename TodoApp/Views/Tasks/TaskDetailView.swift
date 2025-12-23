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
    @State private var isTimeExpanded: Bool
    @State private var isPersonnelExpanded: Bool
    @State private var isQuantityExpanded: Bool

    // Structure sections
    @State private var isSubtasksExpanded: Bool
    @State private var isDependenciesExpanded: Bool

    // Consolidated metadata section
    @State private var isDetailsExpanded: Bool

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
            _isTimeExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: false)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isDetailsExpanded = State(initialValue: false)
        } else if task.isCompleted {
            // Review mode - show results
            _isScheduleExpanded = State(initialValue: false)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: task.hasQuantityProgress)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isDetailsExpanded = State(initialValue: true) // Show completion info
        } else if (task.subtasks?.count ?? 0) > 0 || (task.dependsOn?.count ?? 0) > 0 {
            // Planning mode with structure - show work breakdown
            _isScheduleExpanded = State(initialValue: task.startDate != nil || task.endDate != nil)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeExpanded = State(initialValue: false)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isSubtasksExpanded = State(initialValue: true)
            _isDependenciesExpanded = State(initialValue: (task.dependsOn?.count ?? 0) > 0)
            _isDetailsExpanded = State(initialValue: false)
        } else {
            // Default mode - show essentials
            _isScheduleExpanded = State(initialValue: task.startDate != nil || task.endDate != nil)
            _isOrganizationExpanded = State(initialValue: false)
            _isTimeExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
            _isDetailsExpanded = State(initialValue: false)
        }
    }

    // MARK: - Section IDs for scrolling

    private enum SectionID: Hashable {
        case dependencies
    }

    var body: some View {
        let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        ScrollViewReader { proxy in
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
                            // Expand and scroll to dependencies section
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDependenciesExpanded = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(SectionID.dependencies, anchor: .top)
                                }
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

                // Time section (using original working views)
                DetailSectionDisclosure(
                    title: "Time",
                    icon: "clock",
                    isExpanded: $isTimeExpanded,
                    summary: { timeSummary },
                    content: {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            // Time Tracking (pass allTasks to avoid @Query duplication)
                            TaskTimeTrackingView(task: task, allTasks: allTasks)

                            Divider()
                                .padding(.horizontal)

                            // Time Entries header
                            Text("Time Entries")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            // Time Entries (original working view)
                            TimeEntriesView(task: task)
                        }
                    }
                )

                // Personnel section
                DetailSectionDisclosure(
                    title: "Personnel",
                    icon: "person.2.fill",
                    isExpanded: $isPersonnelExpanded,
                    summary: { personnelSummary },
                    content: { TaskPersonnelView(task: task, allTasks: allTasks) }
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
                    content: { TaskSubtasksView(task: task, allTasks: allTasks) }
                )

                // Dependencies section
                DetailSectionDisclosure(
                    title: "Dependencies",
                    icon: "link",
                    isExpanded: $isDependenciesExpanded,
                    summary: { dependenciesSummary },
                    content: { TaskDependenciesView(task: task, allTasks: allTasks) }
                )
                .id(SectionID.dependencies)

                // Details section (consolidated Tags + Notes + Info)
                DetailSectionDisclosure(
                    title: "Details",
                    icon: "doc.text",
                    isExpanded: $isDetailsExpanded,
                    summary: { detailsSummary },
                    content: { TaskDetailsSection(task: task) }
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
        } // ScrollViewReader
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
    private var timeSummary: some View {
        if timeSummaryIsTertiary {
            Text(timeSummaryText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text(timeSummaryText)
                .font(.caption)
                .foregroundStyle(timeSummaryColor)
        }
    }

    private var timeSummaryText: String {
        // Active timer takes priority
        if task.hasActiveTimer {
            return "Recording..."
        }

        let totalTime = task.totalTimeSpent

        // No time logged
        guard totalTime > 0 else {
            return "Not set"
        }

        // Has estimate - show progress format
        if let estimate = task.effectiveEstimate, estimate > 0 {
            let progress = Double(totalTime) / Double(estimate)
            return "\(totalTime.formattedTime()) / \(estimate.formattedTime()) (\(Int(progress * 100))%)"
        }

        // No estimate - just show time
        return "\(totalTime.formattedTime()) logged"
    }

    private var timeSummaryColor: Color {
        if task.hasActiveTimer {
            return .red
        }
        if let estimate = task.effectiveEstimate, estimate > 0 {
            let progress = Double(task.totalTimeSpent) / Double(estimate)
            return TimeEstimateStatus.from(progress: progress).color
        }
        return .secondary
    }

    private var timeSummaryIsTertiary: Bool {
        !task.hasActiveTimer && task.totalTimeSpent == 0
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
            Text("\(completedCount)/\(subtaskCount) complete")
                .font(.caption)
                .foregroundStyle(completedCount == subtaskCount ? .green : .secondary)
        } else {
            Text("Not set")
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
                Text("Not set")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var detailsSummary: some View {
        Text(TaskDetailsSection.summaryText(for: task))
            .font(.caption)
            .foregroundStyle(TaskDetailsSection.summaryColor(for: task))
    }
}
