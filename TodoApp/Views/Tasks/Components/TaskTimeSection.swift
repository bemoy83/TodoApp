import SwiftUI
import SwiftData
internal import Combine

/// Consolidated Time section combining Time Tracking + Time Entries
/// Part of the TaskDetailView mini-sections architecture
struct TaskTimeSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    // Alert handling
    private let externalAlert: Binding<TaskActionAlert?>?
    @State private var localAlert: TaskActionAlert?
    private var alertBinding: Binding<TaskActionAlert?> {
        externalAlert ?? $localAlert
    }

    // Timer state
    @State private var currentTime = Date()
    @StateObject private var aggregator = SubtaskAggregator()

    // Entry management
    @State private var showingManualEntrySheet = false
    @State private var editingEntry: TimeEntry?

    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
    }

    // MARK: - Computed Properties

    private var stats: SubtaskAggregator.AggregatedStats {
        aggregator.getStats(for: task, allTasks: allTasks, currentTime: currentTime)
    }

    private var sortedEntries: [TimeEntry] {
        (task.timeEntries ?? []).sorted { $0.startTime > $1.startTime }
    }

    private var hasEntries: Bool {
        !(task.timeEntries ?? []).isEmpty
    }

    private var entryCount: Int {
        task.timeEntries?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // MARK: - Tracking Subsection
            trackingSubsection

            Divider()
                .padding(.horizontal)

            // MARK: - Entries Subsection
            entriesSubsection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if hasAnyTimerRunning {
                currentTime = Date()
            }
        }
        .taskActionAlert(alert: alertBinding)
        .sheet(isPresented: $showingManualEntrySheet) {
            ManualTimeEntrySheet(task: task)
        }
        .sheet(item: $editingEntry) { entry in
            EditTimeEntrySheet(entry: entry)
        }
    }

    // MARK: - Tracking Subsection

    @ViewBuilder
    private var trackingSubsection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Subsection header
            HStack {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal)

            // Estimate Section (conditional)
            if let estimate = task.effectiveEstimate {
                EstimateSection(
                    actualSeconds: displayedTotalTimeSeconds,
                    estimateSeconds: estimate,
                    progress: liveTimeProgress,
                    status: liveEstimateStatus,
                    isCalculated: task.isUsingCalculatedEstimate,
                    hasActiveTimer: hasAnyTimerRunning,
                    expectedPersonnelCount: task.expectedPersonnelCount
                )
            }

            // Total Time Section
            TotalTimeDisplay(
                totalTimeSeconds: displayedTotalTimeSeconds,
                directTimeSeconds: displayedDirectTimeSeconds,
                hasSubtaskTime: task.directTimeSpent > 0 && displayedTotalTimeSeconds != displayedDirectTimeSeconds,
                totalPersonHours: displayedTotalPersonHours,
                directPersonHours: displayedDirectPersonHours,
                hasPersonnelTracking: hasPersonnelTracking
            )

            // Active Session (conditional)
            if hasAnyTimerRunning {
                ActiveSessionDisplay(
                    sessionSeconds: currentSessionSeconds,
                    pulseOpacity: timerPulseOpacity
                )
            }

            // Timer Button
            TimerActionButton(
                isActive: task.hasActiveTimer,
                isBlocked: task.status == .blocked,
                action: toggleTimer
            )

            // Blocked Warning (conditional)
            if task.status == .blocked && !hasAnyTimerRunning {
                BlockedWarningDisplay()
            }
        }
    }

    // MARK: - Entries Subsection

    @ViewBuilder
    private var entriesSubsection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Subsection header with Add button
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if hasEntries {
                    Text("(\(entryCount))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    showingManualEntrySheet = true
                    HapticManager.selection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Entries list with menu actions
            if hasEntries {
                LazyVStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(sortedEntries) { entry in
                        TimeEntryListRow(
                            entry: entry,
                            task: task,
                            onEdit: { editingEntry = entry },
                            onDelete: { deleteEntry(entry) }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                }
            } else {
                EmptyEntriesDisplay()
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Timer Logic

    private var hasAnyTimerRunning: Bool {
        if task.hasActiveTimer { return true }
        return hasAnySubtaskTimerRunning
    }

    private var hasAnySubtaskTimerRunning: Bool {
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return checkSubtasksForTimer(in: subtasks)
    }

    private func checkSubtasksForTimer(in subtasks: [Task]) -> Bool {
        for subtask in subtasks {
            if subtask.hasActiveTimer { return true }
            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            if checkSubtasksForTimer(in: nestedSubtasks) { return true }
        }
        return false
    }

    private var displayedTotalTimeSeconds: Int { stats.totalTimeSeconds }
    private var displayedDirectTimeSeconds: Int { stats.directTimeSeconds }
    private var displayedTotalPersonHours: Double { stats.totalPersonHours }
    private var displayedDirectPersonHours: Double { stats.directPersonHours }
    private var hasPersonnelTracking: Bool { stats.hasPersonnelTracking }

    private var currentSessionSeconds: Int {
        guard let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }),
              task.hasActiveTimer else { return 0 }
        return max(0, Int(currentTime.timeIntervalSince(activeEntry.startTime)))
    }

    private var liveTimeProgress: Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        return Double(displayedTotalTimeSeconds) / Double(estimate)
    }

    private var liveEstimateStatus: TimeEstimateStatus? {
        guard let progress = liveTimeProgress else { return nil }
        if progress >= 1.0 { return .over }
        else if progress >= 0.75 { return .warning }
        else { return .onTrack }
    }

    private var timerPulseOpacity: Double {
        let deciseconds = Int(currentTime.timeIntervalSinceReferenceDate * 10) % 10
        return deciseconds < 5 ? 1.0 : 0.3
    }

    // MARK: - Actions

    private func toggleTimer() {
        let router = TaskActionRouter()
        let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        if task.hasActiveTimer {
            _ = router.performWithExecutor(.stopTimer, on: task, context: context) { alert in
                alertBinding.wrappedValue = alert
            }
            aggregator.invalidate(taskId: task.id)
        } else {
            _ = router.performWithExecutor(.startTimer, on: task, context: context) { alert in
                alertBinding.wrappedValue = alert
            }
            currentTime = Date()
            aggregator.invalidate(taskId: task.id)
        }
    }

    private func deleteEntry(_ entry: TimeEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
        HapticManager.success()
    }
}

// MARK: - Summary Badge Helper

extension TaskTimeSection {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        var parts: [String] = []

        // Time spent
        let totalTime = task.totalTimeSpent
        if totalTime > 0 {
            parts.append(totalTime.formattedTime())
        } else {
            parts.append("No time")
        }

        // Progress percentage (if has estimate)
        if let estimate = task.effectiveEstimate, estimate > 0 {
            let progress = Double(task.totalTimeSpent) / Double(estimate)
            parts.append("\(Int(progress * 100))%")
        }

        // Entry count
        let entryCount = task.timeEntries?.count ?? 0
        if entryCount > 0 {
            parts.append("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
        }

        return parts.joined(separator: " • ")
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        if task.hasActiveTimer {
            return .red
        }
        return .secondary
    }
}

// MARK: - Estimate Section

private struct EstimateSection: View {
    let actualSeconds: Int
    let estimateSeconds: Int
    let progress: Double?
    let status: TimeEstimateStatus?
    let isCalculated: Bool
    let hasActiveTimer: Bool
    let expectedPersonnelCount: Int?

    private var estimatedEffort: Double? {
        guard let personnel = expectedPersonnelCount, personnel > 1 else { return nil }
        return Double(estimateSeconds) / 3600.0 * Double(personnel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Image(systemName: "target")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    TimeEstimateBadge(
                        actual: actualSeconds,
                        estimated: estimateSeconds,
                        isCalculated: isCalculated,
                        hasActiveTimer: hasActiveTimer
                    )
                    .font(.title3)
                    .fontWeight(.semibold)

                    if isCalculated {
                        Text("From subtasks")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    if let effort = estimatedEffort {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(String(format: "%.1f person-hours", effort))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let progress = progress {
                TimeProgressBar(progress: progress, status: status, height: 8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Total Time Display

private struct TotalTimeDisplay: View {
    let totalTimeSeconds: Int
    let directTimeSeconds: Int
    let hasSubtaskTime: Bool
    let totalPersonHours: Double
    let directPersonHours: Double
    let hasPersonnelTracking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(totalTimeSeconds.formattedTime(showSeconds: true))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if hasSubtaskTime {
                        let subtaskTime = totalTimeSeconds - directTimeSeconds
                        Text("\(directTimeSeconds.formattedTime(showSeconds: true)) direct, \(subtaskTime.formattedTime(showSeconds: true)) from subtasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if hasPersonnelTracking {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f hrs", totalPersonHours))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.info)

                        if totalPersonHours > directPersonHours {
                            Text("\(String(format: "%.1f", directPersonHours)) direct, \(String(format: "%.1f", totalPersonHours - directPersonHours)) from subtasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Active Session Display

private struct ActiveSessionDisplay: View {
    let sessionSeconds: Int
    let pulseOpacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(formatStopwatch(sessionSeconds))
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal)
    }

    private func formatStopwatch(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timer Action Button

private struct TimerActionButton: View {
    let isActive: Bool
    let isBlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isActive ? "Stop Timer" : "Start Timer",
                systemImage: isActive ? "stop.circle.fill" : "play.circle.fill"
            )
            .scaleEffect(isActive ? 1.06 : 1.0)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isActive ? .red : .green)
        .disabled(isBlocked && !isActive)
        .contentTransition(.symbolEffect(.replace))
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .padding(.horizontal)
    }
}

// MARK: - Blocked Warning Display

private struct BlockedWarningDisplay: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: 28)

            Text("Resolve dependencies before tracking time")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal)
    }
}

// MARK: - Time Entry List Row

private struct TimeEntryListRow: View {
    let entry: TimeEntry
    let task: Task
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    private var isActiveTimer: Bool {
        TimeEntryManager.isActiveTimer(entry)
    }

    private var formattedDuration: String {
        TimeEntryManager.formatDuration(for: entry, showSeconds: false)
    }

    private var formattedPersonHours: String {
        TimeEntryManager.formatPersonHours(for: entry)
    }

    private var formattedDate: String {
        TimeEntryManager.formatRelativeDate(entry.startTime)
    }

    private var formattedTimeRange: String {
        TimeEntryManager.formatTimeRange(for: entry)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Timer indicator
            Image(systemName: isActiveTimer ? "timer" : "clock.fill")
                .font(.body)
                .foregroundStyle(isActiveTimer ? DesignSystem.Colors.timerActive : .secondary)
                .frame(width: 28)
                .pulsingAnimation(active: isActiveTimer)

            VStack(alignment: .leading, spacing: 2) {
                // Date
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Time range
                Text(formattedTimeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Personnel badge (only show when > 1)
                if entry.personnelCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(entry.personnelCount) people · \(formattedPersonHours)")
                            .font(.caption2)
                    }
                    .foregroundStyle(DesignSystem.Colors.info)
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Duration badge
            Text(formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isActiveTimer ? DesignSystem.Colors.timerActive : .primary)

            // Action menu (always rendered, disabled when active)
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(isActiveTimer)

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(isActiveTimer)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .alert("Delete Time Entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This time entry (\(formattedDuration)) will be permanently deleted.")
        }
    }
}

// MARK: - Empty Entries Display

private struct EmptyEntriesDisplay: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.tertiary)

            Text("No time entries yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start the timer or add an entry manually")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

// MARK: - Preview

#Preview("With Entries") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Install Carpet")
    task.estimatedSeconds = 7200

    let entry1 = TimeEntry(startTime: Date().addingTimeInterval(-7200), personnelCount: 2, task: task)
    entry1.endTime = Date().addingTimeInterval(-3600)

    let entry2 = TimeEntry(startTime: Date().addingTimeInterval(-1800), personnelCount: 2, task: task)
    entry2.endTime = Date()

    container.mainContext.insert(task)
    container.mainContext.insert(entry1)
    container.mainContext.insert(entry2)

    return ScrollView {
        TaskTimeSection(task: task)
    }
    .modelContainer(container)
}

#Preview("No Entries") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Install Carpet")
    container.mainContext.insert(task)

    return ScrollView {
        TaskTimeSection(task: task)
    }
    .modelContainer(container)
}
