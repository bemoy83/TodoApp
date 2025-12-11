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

    // MARK: - Tab Navigation (Phase 1)
    @State private var selectedTab: TaskDetailTab = .all

    // Collapsible section states with smart defaults
    @State private var isTimeTrackingExpanded: Bool
    @State private var isPersonnelExpanded: Bool
    @State private var isQuantityExpanded: Bool
    @State private var isTagsExpanded: Bool
    @State private var isEntriesExpanded: Bool
    @State private var isSubtasksExpanded: Bool
    @State private var isDependenciesExpanded: Bool

    private let router = TaskActionRouter()

    // MARK: - Tab Type Definition
    fileprivate enum TaskDetailTab: Hashable, CaseIterable {
        case all    // Phase 1: Temporary placeholder that shows current behavior
        case plan   // Phase 2+: Planning and structure
        case execute // Phase 2+: Timer controls and progress tracking
        case review  // Phase 3+: Analytics and metrics

        var title: String {
            switch self {
            case .all: return "All"
            case .plan: return "Plan"
            case .execute: return "Execute"
            case .review: return "Review"
            }
        }

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .plan: return "checklist"
            case .execute: return "bolt.fill"
            case .review: return "chart.bar.fill"
            }
        }
    }

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

        VStack(spacing: 0) {
            // Tab bar (Phase 1: only showing .all for now)
            TaskDetailTabBar(selectedTab: $selectedTab)
                .padding(DesignSystem.Spacing.md)

            // Tab content
            ScrollView {
                tabContent(context: ctx)
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit – now routed via executor; if no alert, open editor
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

                // More – shared Quick Actions sheet (already executor-backed)
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

    // MARK: - Tab Content (Phase 1: All content in .all tab)
    @ViewBuilder
    private func tabContent(context: TaskActionRouter.Context) -> some View {
        // Phase 1: All tabs show the same existing content
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

    // MARK: - Summary Badge Helpers

    private var timeTrackingSummaryText: String {
        var text = ""

        // Add time spent
        let totalTime = task.totalTimeSpent
        if totalTime > 0 {
            text = totalTime.formattedTime()
        } else {
            text = "No time tracked"
        }

        // Add progress if has estimate
        if let estimate = task.effectiveEstimate {
            let progress = Double(task.totalTimeSpent) / Double(estimate)
            text += " • \(Int(progress * 100))%"
        }

        return text
    }

    @ViewBuilder
    private var timeTrackingSummary: some View {
        Text(timeTrackingSummaryText)
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
        if task.hasQuantityProgress {
            // Show progress: "45.5/60 m² (76%)"
            let completed = task.quantity ?? 0
            let expected = task.expectedQuantity!
            let progress = task.quantityProgress!
            let progressPercent = Int(progress * 100)

            Text("\(formatQuantity(completed))/\(formatQuantity(expected)) \(task.unitDisplayName) (\(progressPercent)%)")
                .font(.caption)
                .foregroundStyle(progress >= 1.0 ? .green : .secondary)
        } else if task.unit != .none, let quantity = task.quantity {
            // Fallback: only completed quantity (no expected)
            Text("\(formatQuantity(quantity)) \(task.unitDisplayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if task.expectedQuantity != nil {
            // Only expected quantity set (no progress yet)
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
    private var tagsSummary: some View {
        if let tags = task.tags, !tags.isEmpty {
            CompactTagSummary(tags: Array(tags))
        } else {
            Text("No tags")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var entriesSummaryText: String {
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
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
        } else {
            return "No entries"
        }
    }

    @ViewBuilder
    private var entriesSummary: some View {
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
            Text(entriesSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(entriesSummaryText)
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

// MARK: - Tab Bar Component

/// Simple tab bar for TaskDetailView
/// Phase 1: Only shows "All" tab
/// Phase 2+: Will show Plan, Execute, Review tabs
private struct TaskDetailTabBar: View {
    @Binding var selectedTab: TaskDetailView.TaskDetailTab

    var body: some View {
        // Phase 1: Simple single tab indicator
        // Phase 2+: Will become proper segmented control
        HStack {
            Text("All")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
