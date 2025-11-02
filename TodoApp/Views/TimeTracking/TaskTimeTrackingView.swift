import SwiftUI
import SwiftData
internal import Combine

struct TaskTimeTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    
    @Query(sort: \Task.order) private var allTasks: [Task]

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
                EstimateSection(
                    estimate: estimate / 60,  // Convert seconds to minutes for display
                    actualTime: displayedTotalTime,
                    progress: liveTimeProgress,
                    status: liveEstimateStatus,
                    remaining: liveTimeRemaining,
                    isCalculated: task.isUsingCalculatedEstimate
                )
            }
            
            // Total Time Section (always shown)
            TotalTimeSection(
                totalTime: displayedTotalTime,
                directTime: displayedDirectTime,
                hasSubtaskTime: task.directTimeSpent > 0 && displayedTotalTime != displayedDirectTime
            )
            
            // Active Session (conditional - only if timer running)
            if task.hasActiveTimer {
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
            if task.status == .blocked && !task.hasActiveTimer {
                BlockedWarning()
            }
        }
        .detailCardStyle()
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if task.hasActiveTimer {
                currentTime = Date()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if hasAnySubtaskTimerRunning {
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

    private var displayedDirectTime: Int {
        var totalSeconds = task.directTimeSpent  // Already in seconds!
        if task.hasActiveTimer {
            totalSeconds += currentSessionSeconds
        }
        return totalSeconds / 60
    }

    private var currentSessionSeconds: Int {
        guard let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }),
              task.hasActiveTimer else {
            return 0
        }

        let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
        return max(0, Int(elapsed))
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

private struct EstimateSection: View {
    let estimate: Int
    let actualTime: Int
    let progress: Double?
    let status: TimeEstimateStatus?
    let remaining: Int?
    let isCalculated: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Time Estimate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "target")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Progress ratio with status
                    HStack(spacing: 6) {
                        Text("\((actualTime * 60).formattedTime()) / \((estimate * 60).formattedTime())")
                            .font(.subheadline)
                            .monospacedDigit()
                        
                        if let status = status {
                            Image(systemName: status.icon)
                                .font(.caption)
                                .foregroundStyle(status.color)
                        }
                        
                        if let progress = progress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    // Calculated indicator
                    if isCalculated {
                        Text("From subtasks")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                
                Spacer()
                
                // Remaining time
                if let remaining = remaining {
                    VStack(alignment: .trailing, spacing: 2) {
                        if remaining > 0 {
                            Text((remaining * 60).formattedTime())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(status?.color ?? .secondary)
                            Text("left")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text((abs(remaining) * 60).formattedTime())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            Text("over")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            
            // Progress bar
            if let progress = progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(status?.color ?? .blue)
                            .frame(
                                width: min(geometry.size.width * progress, geometry.size.width),
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Total Time Section

private struct TotalTimeSection: View {
    let totalTime: Int
    let directTime: Int
    let hasSubtaskTime: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Total Time")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text((totalTime * 60).formattedTime())
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // Breakdown if has subtask time
                    if hasSubtaskTime {
                        Text("\((directTime * 60).formattedTime()) direct, \(((totalTime - directTime) * 60).formattedTime()) from subtasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulseOpacity)

                    Text("Recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
