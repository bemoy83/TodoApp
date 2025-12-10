import SwiftUI
import SwiftData

/// Session 3: Unified Actions rollout â€” coordinator-only detail view
/// - Keeps your existing components:
///   TaskDetailHeaderView, TaskTimeTrackingView, TaskSubtasksView, TaskDependenciesView
/// - Routes toolbar & sheet actions through TaskActionRouter (no duplicate business logic here).
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: Task

    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false

    // NEW: central alert state for executor-backed alerts
    @State private var currentAlert: TaskActionAlert?

    // Collapsible section states with smart defaults
    @State private var isTimeTrackingExpanded: Bool
    @State private var isPersonnelExpanded: Bool
    @State private var isQuantityExpanded: Bool
    @State private var isTagsExpanded: Bool
    @State private var isEntriesExpanded: Bool
    @State private var isSubtasksExpanded: Bool
    @State private var isDependenciesExpanded: Bool

    private let router = TaskActionRouter()

    init(task: Task) {
        self.task = task

        // Smart defaults based on task state
        if task.hasActiveTimer {
            // Execution mode - focus on time tracking
            _isTimeTrackingExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: false)
            _isTagsExpanded = State(initialValue: false)
            _isEntriesExpanded = State(initialValue: true) // Show accumulating entries
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
        } else if task.isCompleted {
            // Review mode - show results
            _isTimeTrackingExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: false)
            _isQuantityExpanded = State(initialValue: false)
            _isTagsExpanded = State(initialValue: false)
            _isEntriesExpanded = State(initialValue: (task.timeEntries?.count ?? 0) > 0) // Show if has entries
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
        } else if (task.subtasks?.count ?? 0) > 0 || (task.dependsOn?.count ?? 0) > 0 {
            // Planning mode with structure - show work breakdown
            _isTimeTrackingExpanded = State(initialValue: false)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isTagsExpanded = State(initialValue: false)
            _isEntriesExpanded = State(initialValue: false)
            _isSubtasksExpanded = State(initialValue: true) // Show work structure
            _isDependenciesExpanded = State(initialValue: (task.dependsOn?.count ?? 0) > 0)
        } else {
            // Default mode - show essentials
            _isTimeTrackingExpanded = State(initialValue: true)
            _isPersonnelExpanded = State(initialValue: task.expectedPersonnelCount != nil)
            _isQuantityExpanded = State(initialValue: task.unit != .none)
            _isTagsExpanded = State(initialValue: false)
            _isEntriesExpanded = State(initialValue: false)
            _isSubtasksExpanded = State(initialValue: false)
            _isDependenciesExpanded = State(initialValue: false)
        }
    }

    var body: some View {
        let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TaskDetailHeaderView(task: task)

                // Time tracking remains the canonical place for timer controls
                DetailSectionDisclosure(
                    title: "Time Tracking",
                    icon: "clock",
                    isExpanded: $isTimeTrackingExpanded,
                    summary: { timeTrackingSummary },
                    content: { TaskTimeTrackingView(task: task) }
                )

                // Personnel planning and tracking
                DetailSectionDisclosure(
                    title: "Personnel",
                    icon: "person.2.fill",
                    isExpanded: $isPersonnelExpanded,
                    summary: { personnelSummary },
                    content: { TaskPersonnelView(task: task) }
                )

                // Quantity tracking for productivity measurement
                DetailSectionDisclosure(
                    title: "Quantity",
                    icon: "number",
                    isExpanded: $isQuantityExpanded,
                    summary: { quantitySummary },
                    content: { TaskQuantityView(task: task) }
                )

                // Tags for organization and filtering
                DetailSectionDisclosure(
                    title: "Tags",
                    icon: "tag",
                    isExpanded: $isTagsExpanded,
                    summary: { tagsSummary },
                    content: { TaskTagsView(task: task) }
                )

                // Time entries management
                DetailSectionDisclosure(
                    title: "Time Entries",
                    icon: "list.bullet.clipboard",
                    isExpanded: $isEntriesExpanded,
                    summary: { entriesSummary },
                    content: { TimeEntriesView(task: task) }
                )

                // Subtasks
                DetailSectionDisclosure(
                    title: "Subtasks",
                    icon: "list.bullet.indent",
                    isExpanded: $isSubtasksExpanded,
                    summary: { subtasksSummary },
                    content: { TaskSubtasksView(task: task) }
                )

                // Dependencies
                DetailSectionDisclosure(
                    title: "Dependencies",
                    icon: "link",
                    isExpanded: $isDependenciesExpanded,
                    summary: { dependenciesSummary },
                    content: { TaskDependenciesView(task: task) }
                )
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit â€” now routed via executor; if no alert, open editor
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

                // More â€” shared Quick Actions sheet (already executor-backed)
                Button {
                    showingMoreSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // Edit sheet (form-only)
        .sheet(isPresented: $showingEditSheet) {
            TaskEditView(task: task)
        }
        // Quick Actions / More sheet (routes via router internally)
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: task,
                onEdit: { showingEditSheet = true },
                onAddSubtask: {
                    // If you still have a dedicated add-subtask flow, trigger it here.
                    // The router has already emitted `.addSubtask`.
                    showingMoreSheet = false
                }
            )
        }
        // Present any alerts triggered from this view (e.g., edit intent if it ever alerts)
        .taskActionAlert(alert: $currentAlert)
    }

    // MARK: - Summary Badge Helpers

    @ViewBuilder
    private var timeTrackingSummary: some View {
        let summaryText: String = {
            var text = ""

            // Add time spent
            if let totalTime = task.totalTimeSpent, totalTime > 0 {
                text = totalTime.formattedTime
            } else {
                text = "No time tracked"
            }

            // Add progress if has estimate
            if let estimate = task.effectiveEstimate {
                let progress = Double(task.totalTimeSpent ?? 0) / Double(estimate)
                text += " • \(Int(progress * 100))%"
            }

            return text
        }()

        Text(summaryText)
            .font(.caption)
            .foregroundStyle(.secondary)
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
        if task.unit != .none, let quantity = task.quantity {
            Text("\(Int(quantity)) \(task.unit.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Not set")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var tagsSummary: some View {
        let tagCount = task.tags?.count ?? 0
        if tagCount > 0 {
            HStack(spacing: 4) {
                ForEach(task.tags?.prefix(2) ?? [], id: \.self) { tag in
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: tag.color).opacity(0.2))
                        .foregroundStyle(Color(hex: tag.color))
                        .cornerRadius(4)
                }
                if tagCount > 2 {
                    Text("+\(tagCount - 2)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            Text("No tags")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var entriesSummary: some View {
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
            let summaryText: String = {
                let entryWord = entryCount == 1 ? "entry" : "entries"
                var text = "\(entryCount) \(entryWord)"

                // Add last entry time if available
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
            }()

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("No entries")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
}
