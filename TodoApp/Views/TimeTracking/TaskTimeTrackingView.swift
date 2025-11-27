import SwiftUI
import SwiftData
internal import Combine

struct TaskTimeTrackingView: View {
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

    @State private var currentTime = Date()
    
    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Estimate Section (conditional - only if has estimate)
            if let estimate = task.effectiveEstimate {
                EstimateSectionRefactored(
                    actualSeconds: displayedTotalTimeSeconds,
                    estimateSeconds: estimate,
                    progress: liveTimeProgress,
                    status: liveEstimateStatus,
                    isCalculated: task.isUsingCalculatedEstimate,
                    hasActiveTimer: hasAnyTimerRunning,
                    expectedPersonnelCount: task.expectedPersonnelCount
                )
            }

            // Total Time Section (always shown)
            TotalTimeSection(
                totalTimeSeconds: displayedTotalTimeSeconds,
                directTimeSeconds: displayedDirectTimeSeconds,
                hasSubtaskTime: task.directTimeSpent > 0 && displayedTotalTimeSeconds != displayedDirectTimeSeconds,
                totalPersonHours: displayedTotalPersonHours,
                directPersonHours: displayedDirectPersonHours,
                hasPersonnelTracking: hasPersonnelTracking
            )

            // Active Session (conditional - only if timer running)
            if hasAnyTimerRunning {
                ActiveSessionSection(
                    sessionSeconds: currentSessionSeconds,
                    pulseOpacity: timerPulseOpacity
                )
            }

            // Timer Button (always shown)
            TimerButton(
                isActive: task.hasActiveTimer,
                isBlocked: task.status == .blocked,
                action: toggleTimer
            )

            // Blocked Warning (conditional - only if blocked and not running)
            if task.status == .blocked && !hasAnyTimerRunning {
                BlockedWarning()
            }
        }
        .detailCardStyle()
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Fast update for smooth countdown when any timer is running
            if hasAnyTimerRunning {
                currentTime = Date()
            }
        }
        .taskActionAlert(alert: alertBinding)
    }

    // MARK: - Computed Properties
    
    private var computedTotalTimeSpent: Int {
        var total = task.directTimeSpent
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return total
    }
    
    private func computeTotalTime(for task: Task) -> Int {
        var total = task.directTimeSpent
        
        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                let minutes = Int(elapsed / 60)
                total += max(0, minutes)
            }
        }
        
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return max(0, total)
    }
    
    private func computeTotalTimeSeconds(for task: Task) -> Int {
        var total = task.directTimeSpent  // Already in seconds!

        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                total += max(0, Int(elapsed))
            }
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }
        return max(0, total)
    }
    
    // MARK: - Timer Status

    /// Check if task or any subtask has active timer (includes parent + all subtasks)
    private var hasAnyTimerRunning: Bool {
        if task.hasActiveTimer {
            return true
        }
        return hasAnySubtaskTimerRunning
    }

    private var hasAnySubtaskTimerRunning: Bool {
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return checkSubtasksForTimer(in: subtasks)
    }

    private func checkSubtasksForTimer(in subtasks: [Task]) -> Bool {
        for subtask in subtasks {
            if subtask.hasActiveTimer {
                return true
            }
            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            if checkSubtasksForTimer(in: nestedSubtasks) {
                return true
            }
        }
        return false
    }

    private var displayedTotalTimeSeconds: Int {
        var total = task.directTimeSpent  // Already in seconds!

        if task.hasActiveTimer {
            total += currentSessionSeconds
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }

        return max(0, total)
    }
    
    private var displayedTotalTime: Int {
        return displayedTotalTimeSeconds / 60
    }

    private var displayedDirectTimeSeconds: Int {
        var totalSeconds = task.directTimeSpent  // Already in seconds!
        if task.hasActiveTimer {
            totalSeconds += currentSessionSeconds
        }
        return totalSeconds
    }

    private var displayedDirectTime: Int {
        return displayedDirectTimeSeconds / 60
    }

    private var currentSessionSeconds: Int {
        guard let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }),
              task.hasActiveTimer else {
            return 0
        }

        let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
        return max(0, Int(elapsed))
    }

    // MARK: - Person-Hours Calculations

    /// Calculate direct person-hours for this task (including active timer)
    private var displayedDirectPersonHours: Double {
        guard let entries = task.timeEntries else { return 0.0 }

        return entries.reduce(0.0) { total, entry in
            let endTime = entry.endTime ?? (entry.endTime == nil && task.hasActiveTimer ? currentTime : nil)
            guard let end = endTime else { return total }

            // Use TimeEntryManager to calculate work hours only
            let durationSeconds = TimeEntryManager.calculateDuration(start: entry.startTime, end: end)
            let personHours = (durationSeconds / 3600.0) * Double(entry.personnelCount)

            return total + personHours
        }
    }

    /// Calculate total person-hours including all subtasks
    private var displayedTotalPersonHours: Double {
        var total = displayedDirectPersonHours

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computePersonHours(for: subtask)
        }

        return total
    }

    /// Recursively calculate person-hours for a task and its subtasks
    private func computePersonHours(for task: Task) -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        var totalPersonHours = entries.reduce(0.0) { total, entry in
            let endTime = entry.endTime ?? (entry.endTime == nil && task.hasActiveTimer ? currentTime : nil)
            guard let end = endTime else { return total }

            // Use TimeEntryManager to calculate work hours only
            let durationSeconds = TimeEntryManager.calculateDuration(start: entry.startTime, end: end)
            let personHours = (durationSeconds / 3600.0) * Double(entry.personnelCount)

            return total + personHours
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            totalPersonHours += computePersonHours(for: subtask)
        }

        return totalPersonHours
    }

    /// Check if any entries have personnel > 1
    private var hasPersonnelTracking: Bool {
        // Check direct entries
        if let entries = task.timeEntries, entries.contains(where: { $0.personnelCount > 1 }) {
            return true
        }

        // Check subtask entries
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return checkSubtasksForPersonnel(in: subtasks)
    }

    private func checkSubtasksForPersonnel(in subtasks: [Task]) -> Bool {
        for subtask in subtasks {
            if let entries = subtask.timeEntries, entries.contains(where: { $0.personnelCount > 1 }) {
                return true
            }
            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            if checkSubtasksForPersonnel(in: nestedSubtasks) {
                return true
            }
        }
        return false
    }

    private var liveTimeProgress: Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        return Double(displayedTotalTimeSeconds) / Double(estimate)  // estimate is already in seconds!
    }
    
    private var liveEstimateStatus: TimeEstimateStatus? {
        guard let progress = liveTimeProgress else { return nil }
        
        if progress >= 1.0 {
            return .over
        } else if progress >= 0.75 {
            return .warning
        } else {
            return .onTrack
        }
    }
    
    private var liveTimeRemaining: Int? {
        guard let estimate = task.effectiveEstimate else { return nil }
        let remainingSeconds = estimate - displayedTotalTimeSeconds  // estimate is already in seconds!
        return remainingSeconds / 60
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
        } else {
            _ = router.performWithExecutor(.startTimer, on: task, context: context) { alert in
                alertBinding.wrappedValue = alert
            }
            currentTime = Date()
        }
    }
}

// MARK: - Estimate Section

private struct EstimateSectionRefactored: View {
    let actualSeconds: Int
    let estimateSeconds: Int
    let progress: Double?
    let status: TimeEstimateStatus?
    let isCalculated: Bool
    let hasActiveTimer: Bool
    let expectedPersonnelCount: Int?

    private var estimatedEffort: Double? {
        guard let personnel = expectedPersonnelCount, personnel > 1 else {
            return nil
        }
        let hours = Double(estimateSeconds) / 3600.0
        return hours * Double(personnel)
    }

    private var formattedEffort: String {
        guard let effort = estimatedEffort else { return "" }
        return String(format: "%.1f person-hours", effort)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Time Estimate")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Image(systemName: "target")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    // TimeEstimateBadge handles display mode automatically (normal vs countdown)
                    TimeEstimateBadge(
                        actual: actualSeconds,
                        estimated: estimateSeconds,
                        isCalculated: isCalculated,
                        hasActiveTimer: hasActiveTimer
                    )
                    .font(.title3)
                    .fontWeight(.semibold)

                    // Show "From subtasks" indicator
                    if isCalculated {
                        Text("From subtasks")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    // Show effort when personnel > 1
                    if estimatedEffort != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(formattedEffort)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Progress bar
            if let progress = progress {
                TimeProgressBar(
                    progress: progress,
                    status: status,
                    height: 8
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Total Time Section

private struct TotalTimeSection: View {
    let totalTimeSeconds: Int
    let directTimeSeconds: Int
    let hasSubtaskTime: Bool
    let totalPersonHours: Double
    let directPersonHours: Double
    let hasPersonnelTracking: Bool

    private var formattedTotalPersonHours: String {
        String(format: "%.1f hrs", totalPersonHours)
    }

    private var formattedDirectPersonHours: String {
        String(format: "%.1f", directPersonHours)
    }

    private var formattedSubtaskPersonHours: String {
        let subtask = totalPersonHours - directPersonHours
        return String(format: "%.1f", subtask)
    }

    private var hasSubtaskPersonHours: Bool {
        totalPersonHours > directPersonHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Total Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(totalTimeSeconds.formattedTime(showSeconds: true))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // Breakdown if has subtask time
                    if hasSubtaskTime {
                        let subtaskTimeSeconds = totalTimeSeconds - directTimeSeconds
                        Text("\(directTimeSeconds.formattedTime(showSeconds: true)) direct, \(subtaskTimeSeconds.formattedTime(showSeconds: true)) from subtasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Person-Hours (only show if personnel tracking is used)
            if hasPersonnelTracking {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedTotalPersonHours)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.info)

                        // Breakdown if has subtask person-hours
                        if hasSubtaskPersonHours {
                            Text("\(formattedDirectPersonHours) direct, \(formattedSubtaskPersonHours) from subtasks")
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

// MARK: - Active Session Section

private struct ActiveSessionSection: View {
    let sessionSeconds: Int
    let pulseOpacity: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Current Session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Stopwatch display
                Text(formatStopwatch(sessionSeconds))
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal)
    }
    
    private func formatStopwatch(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Timer Button

private struct TimerButton: View {
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

// MARK: - Blocked Warning

private struct BlockedWarning: View {
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
