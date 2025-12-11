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
    @State private var isNotesExpanded: Bool = true // Phase 3: Notes in Plan tab

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

        // Phase 2: Smart default tab selection
        let defaultTab: TaskDetailTab
        if task.hasActiveTimer {
            defaultTab = .execute  // Running timer → Execute tab
        } else if task.isCompleted {
            defaultTab = .review   // Completed → Review tab (will implement in Phase 3)
        } else {
            defaultTab = .plan     // Default to Plan (primary workspace)
        }
        _selectedTab = State(initialValue: defaultTab)

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
            // Native iOS segmented picker for tab selection
            Picker("Tab", selection: $selectedTab) {
                Label("Plan", systemImage: "checklist")
                    .tag(TaskDetailTab.plan)

                Label("Execute", systemImage: "bolt.fill")
                    .tag(TaskDetailTab.execute)

                Label("Review", systemImage: "chart.bar.fill")
                    .tag(TaskDetailTab.review)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Scrollable content below tab bar
            ScrollView {
                tabContent(context: ctx)
            }
        }
        .navigationTitle(task.title)
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

    // MARK: - Tab Content (Phase 2: Conservative split between Plan/Execute)
    @ViewBuilder
    private func tabContent(context: TaskActionRouter.Context) -> some View {
        switch selectedTab {
        case .all:
            // Phase 1 fallback (not used in Phase 2+)
            allTabContent

        case .plan:
            planTabContent

        case .execute:
            executeTabContent

        case .review:
            // Phase 3: Review tab (for now, show plan content as fallback)
            planTabContent
        }
    }

    // MARK: - Plan Tab Content (Phase 3: Grouped collapsibles + header details)
    @ViewBuilder
    private var planTabContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Task header details (moved from top-level header)
            TaskDetailHeaderView(task: task, alert: $currentAlert)

            // Group 1: Estimates & Resources
            DetailSectionDisclosure(
                title: "Estimates & Resources",
                icon: "chart.bar.fill",
                isExpanded: $isTimeTrackingExpanded,
                summary: { estimatesResourcesSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Time estimation
                        TaskTimeTrackingView(task: task)

                        Divider()

                        // Personnel planning
                        TaskPersonnelView(task: task)

                        Divider()

                        // Quantity target
                        TaskQuantityView(task: task)
                    }
                }
            )

            // Group 2: Structure & Dependencies
            DetailSectionDisclosure(
                title: "Structure & Dependencies",
                icon: "diagram.split.2x2",
                isExpanded: $isSubtasksExpanded,
                summary: { structureSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Subtasks
                        TaskSubtasksView(task: task)

                        Divider()

                        // Dependencies
                        TaskDependenciesView(task: task)
                    }
                }
            )

            // Group 3: Metadata (Tags + Notes)
            DetailSectionDisclosure(
                title: "Metadata",
                icon: "tag.fill",
                isExpanded: $isTagsExpanded,
                summary: { metadataSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Tags
                        TaskTagsView(task: task)

                        // Notes (Phase 3: Now editable in Plan tab only)
                        if let notes = task.notes, !notes.isEmpty {
                            Divider()

                            SharedNotesSection(notes: notes, isExpanded: $isNotesExpanded)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                    }
                }
            )
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // Summary for Estimates & Resources group
    @ViewBuilder
    private var estimatesResourcesSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let estimate = task.effectiveEstimate {
                Text(estimate.formattedTime())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let personnel = task.expectedPersonnelCount {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(personnel)p")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if task.hasQuantityProgress {
                Text("•")
                    .foregroundStyle(.tertiary)
                let progress = Int((task.quantityProgress ?? 0) * 100)
                Text("\(progress)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Summary for Structure group
    @ViewBuilder
    private var structureSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if task.subtaskCount > 0 {
                Text("\(task.completedDirectSubtaskCount)/\(task.subtaskCount) subtasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if (task.dependsOn?.count ?? 0) > 0 {
                if task.subtaskCount > 0 {
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                let depCount = task.dependsOn?.count ?? 0
                Text("\(depCount) \(depCount == 1 ? "dependency" : "dependencies")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Summary for Metadata group
    @ViewBuilder
    private var metadataSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let tags = task.tags, !tags.isEmpty {
                Text("\(tags.count) \(tags.count == 1 ? "tag" : "tags")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = task.notes, !notes.isEmpty {
                if let tags = task.tags, !tags.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                Text("Has notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Execute Tab Content (Phase 3: Streamlined, zero distractions)
    @ViewBuilder
    private var executeTabContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Blocking banner (if blocked)
            if !task.canStartWork {
                BlockingBanner(task: task)
            }

            // Timer controls (always expanded in Execute)
            TaskTimeTrackingView(task: task)
                .detailCardStyle()

            // Today's progress summary
            if task.todayHours > 0 || task.hasActiveTimer {
                TodayProgressCard(task: task)
            }

            // Quantity progress (if tracking quantity)
            if task.hasQuantityProgress || task.quantity != nil {
                TaskQuantityView(task: task)
                    .detailCardStyle()
            }

            // Today's time entries (always expanded)
            TimeEntriesView(task: task)
                .detailCardStyle()

            // Subtask summary badge (read-only, just status)
            if task.subtaskCount > 0 {
                SubtaskSummaryCard(task: task)
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - All Tab Content (Phase 1 fallback)
    @ViewBuilder
    private var allTabContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // All sections (Phase 1 behavior)
            DetailSectionDisclosure(
                title: "Time Tracking",
                icon: "clock",
                isExpanded: $isTimeTrackingExpanded,
                summary: { timeTrackingSummary },
                content: { TaskTimeTrackingView(task: task) }
            )

            DetailSectionDisclosure(
                title: "Personnel",
                icon: "person.2.fill",
                isExpanded: $isPersonnelExpanded,
                summary: { personnelSummary },
                content: { TaskPersonnelView(task: task) }
            )

            DetailSectionDisclosure(
                title: "Quantity",
                icon: "number",
                isExpanded: $isQuantityExpanded,
                summary: { quantitySummary },
                content: { TaskQuantityView(task: task) }
            )

            DetailSectionDisclosure(
                title: "Tags",
                icon: "tag",
                isExpanded: $isTagsExpanded,
                summary: { tagsSummary },
                content: { TaskTagsView(task: task) }
            )

            DetailSectionDisclosure(
                title: "Time Entries",
                icon: "list.bullet.clipboard",
                isExpanded: $isEntriesExpanded,
                summary: { entriesSummary },
                content: { TimeEntriesView(task: task) }
            )

            DetailSectionDisclosure(
                title: "Subtasks",
                icon: "list.bullet.indent",
                isExpanded: $isSubtasksExpanded,
                summary: { subtasksSummary },
                content: { TaskSubtasksView(task: task) }
            )

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

// MARK: - Execute Tab Supporting Components

/// Blocking banner for Execute tab - prominent warning when task is blocked
private struct BlockingBanner: View {
    let task: Task
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
                HapticManager.light()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text("BLOCKED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        if !isExpanded, let firstReason = task.blockingReasons.first {
                            Text(firstReason)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(task.blockingReasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                            Text("•")
                                .foregroundStyle(.white)
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.error)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

/// Today's progress summary card for Execute tab
private struct TodayProgressCard: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Today's Progress")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignSystem.Spacing.lg) {
                // Hours tracked today
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(String(format: "%.1fh", task.todayHours))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Hours Tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                // Person-hours today
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(String(format: "%.1f", task.todayPersonHours))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Person-Hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .detailCardStyle()
    }
}

/// Subtask summary card for Execute tab - read-only status
private struct SubtaskSummaryCard: View {
    let task: Task

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "list.bullet.indent")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Subtasks")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("\(task.completedDirectSubtaskCount)/\(task.subtaskCount) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress indicator
            let progress = task.subtaskCount > 0
                ? Double(task.completedDirectSubtaskCount) / Double(task.subtaskCount)
                : 0.0
            CircularProgressView(progress: progress)
                .frame(width: 32, height: 32)
        }
        .padding(DesignSystem.Spacing.md)
        .detailCardStyle()
    }
}

/// Simple circular progress indicator
private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 3)
                .opacity(0.3)
                .foregroundStyle(DesignSystem.Colors.secondary)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(progress >= 1.0 ? DesignSystem.Colors.success : DesignSystem.Colors.info)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

