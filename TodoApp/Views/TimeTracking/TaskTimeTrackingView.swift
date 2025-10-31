import SwiftUI
import SwiftData
internal import Combine

struct TaskTimeTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    
    @Query(sort: \Task.order) private var allTasks: [Task]

    // Optional shared alert from parent; if nil, we use our own.
    private let externalAlert: Binding<TaskActionAlert?>?
    @State private var localAlert: TaskActionAlert?
    private var alertBinding: Binding<TaskActionAlert?> {
        externalAlert ?? $localAlert
    }

    // Timer state - only active when this view is visible and timer is running
    @State private var currentTime = Date()
    
    private var computedTotalTimeSpent: Int {
        var total = task.directTimeSpent
        
        // Add time from subtasks (from query, not relationship)
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        
        return total
    }
    
    // Recursive helper - includes live timer data for each task
    private func computeTotalTime(for task: Task) -> Int {
        var total = task.directTimeSpent
        
        // NEW: Add live session if this task has active timer
        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                let minutes = Int(elapsed / 60)
                total += max(0, minutes) // Ensure non-negative
            }
        }
        
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return max(0, total) // Ensure non-negative
    }
    
    // NEW: Compute total time in SECONDS (for accurate aggregation)
    private func computeTotalTimeSeconds(for task: Task) -> Int {
        var total = task.directTimeSpent * 60 // Convert stored minutes to seconds
        
        // Add live session if this task has active timer
        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                total += max(0, Int(elapsed)) // Add seconds directly
            }
        }
        
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }
        return max(0, total) // Ensure non-negative
    }
    
    // NEW: Check if any subtask has active timer
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

    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
    }

    var body: some View {
        GroupBox("Time Tracking") {
            VStack(alignment: .leading, spacing: 12) {
                // NEW: Time Estimate Display (if estimate exists)
                if let estimate = task.effectiveEstimate {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Estimated:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatMinutes(estimate))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    if task.isUsingCalculatedEstimate {
                                        Text("(from subtasks)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .italic()
                                    }
                                }
                                
                                // Actual vs Estimate with status
                                HStack(spacing: 6) {
                                    Text("\(formatMinutes(displayedTotalTime)) / \(formatMinutes(estimate))")
                                        .font(.caption)
                                        .monospacedDigit()
                                    
                                    if let status = liveEstimateStatus {
                                        Image(systemName: status.icon)
                                            .font(.caption2)
                                            .foregroundStyle(status.color)
                                    }
                                    
                                    if let progress = liveTimeProgress {
                                        Text("\(Int(progress * 100))%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Remaining time (or over)
                            if let remaining = liveTimeRemaining {
                                VStack(alignment: .trailing, spacing: 2) {
                                    if remaining > 0 {
                                        Text(formatMinutes(remaining))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(liveEstimateStatus?.color ?? .secondary)
                                        Text("left")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Text(formatMinutes(abs(remaining)))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                        Text("over")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(height: 8)
                                
                                // Progress (using live values)
                                if let progress = liveTimeProgress {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(liveEstimateStatus?.color ?? .blue)
                                        .frame(
                                            width: min(geometry.size.width * progress, geometry.size.width),
                                            height: 8
                                        )
                                        .animation(.easeInOut(duration: 0.3), value: progress)
                                }
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.bottom, 4)
                    
                    Divider()
                }
                
                // Total time (including subtasks)
                HStack {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total time: \(formatMinutes(displayedTotalTime))")
                            .fontWeight(.semibold)

                        // Show breakdown if task has subtasks with time
                        if task.directTimeSpent > 0 && displayedTotalTime != displayedDirectTime {
                            Text("(\(formatMinutes(displayedDirectTime)) direct, \(formatMinutes(displayedTotalTime - displayedDirectTime)) from subtasks)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Blocked warning if task is blocked
                if task.status == .blocked && !task.hasActiveTimer {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Task is blocked - resolve dependencies before tracking time")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }

                // Live stopwatch display
                if task.hasActiveTimer {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .opacity(timerPulseOpacity)

                            Text("Current session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Stopwatch-style display
                        Text(formatStopwatch(currentSessionSeconds))
                            .font(.system(size: 34, weight: .medium, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 8)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        toggleTimer()
                    }
                } label: {
                    Label(
                        task.hasActiveTimer ? "Stop Timer" : "Start Timer",
                        systemImage: task.hasActiveTimer ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .scaleEffect(task.hasActiveTimer ? 1.06 : 1.0)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(task.hasActiveTimer ? .red : .green)
                .contentTransition(.symbolEffect(.replace))
                .animation(.easeInOut(duration: 0.25), value: task.hasActiveTimer)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Fast update for stopwatch display (only when main task timer running)
            if task.hasActiveTimer {
                currentTime = Date()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // 1-second refresh for progress bars in focused detail view
            if hasAnySubtaskTimerRunning {
                currentTime = Date()
            }
        }
        .taskActionAlert(alert: alertBinding)
    }

    // MARK: - Computed Properties

    /// Total time including live session (main task + all subtasks) - in SECONDS
    private var displayedTotalTimeSeconds: Int {
        var total = task.directTimeSpent * 60 // Convert stored minutes to seconds
        
        // Add live session for main task (already in seconds)
        if task.hasActiveTimer {
            total += currentSessionSeconds
        }
        
        // Add all subtask time (including their live sessions via computeTotalTime)
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }
        
        return max(0, total) // Ensure non-negative
    }
    
    /// Total time in minutes (for compatibility with existing displays)
    private var displayedTotalTime: Int {
        return displayedTotalTimeSeconds / 60
    }

    /// Direct time including live session (in minutes for display)
    private var displayedDirectTime: Int {
        var totalSeconds = task.directTimeSpent * 60 // Convert to seconds
        if task.hasActiveTimer {
            totalSeconds += currentSessionSeconds
        }
        return totalSeconds / 60 // Convert back to minutes
    }

    /// Seconds elapsed in current timer session
    private var currentSessionSeconds: Int {
        guard let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }),
              task.hasActiveTimer else {
            return 0
        }

        let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
        return max(0, Int(elapsed))
    }

    /// NEW: Live progress calculation (includes running timers)
    private var liveTimeProgress: Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        // Use seconds for accuracy, estimate is in minutes
        return Double(displayedTotalTimeSeconds) / Double(estimate * 60)
    }
    
    /// NEW: Live estimate status (includes running timers)
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
    
    /// NEW: Live remaining time (includes running timers) - in minutes
    private var liveTimeRemaining: Int? {
        guard let estimate = task.effectiveEstimate else { return nil }
        let estimateSeconds = estimate * 60
        let remainingSeconds = estimateSeconds - displayedTotalTimeSeconds
        return remainingSeconds / 60 // Convert to minutes for display
    }

    /// Pulsing opacity for numeric LED dot
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

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    /// Formats seconds as HH:MM:SS stopwatch display
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

// MARK: - Reduce-Motion-aware symbol pulsing
private struct SymbolPulse: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        if isActive && !UIAccessibility.isReduceMotionEnabled {
            content.symbolEffect(.pulse, options: .repeat(.continuous))
        } else {
            content
        }
    }
}
