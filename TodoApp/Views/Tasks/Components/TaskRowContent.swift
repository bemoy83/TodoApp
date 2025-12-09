import SwiftUI
import SwiftData

// MARK: - Title Section
struct TaskRowTitleSection: View {
    let task: Task
    let shouldShowPriority: Bool
    let taskPriority: Priority

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if shouldShowPriority {
                Image(systemName: taskPriority.icon)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(taskPriority.color)
            }
            Text(task.title)
                .font(DesignSystem.Typography.body)
                .fontWeight(task.isCompleted ? .regular : .semibold)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? DesignSystem.Colors.secondary : DesignSystem.Colors.primary)
                .lineLimit(2)
        }
    }
}

// MARK: - Metadata Section (Badges)
struct TaskRowMetadataSection: View {
    let task: Task
    let calculations: TaskRowCalculations
    let shouldShowDueDate: Bool
    let effectiveDueDate: Date?
    let isDueDateInherited: Bool

    @Query(sort: \Tag.order) private var allTags: [Tag]

    // Get task tags using @Query pattern for fresh data
    private var taskTags: [Tag] {
        guard let taskTagIds = task.tags?.map({ $0.id }) else { return [] }
        return allTags.filter { taskTagIds.contains($0.id) }
    }

    // Check if there's any content to show
    var hasContent: Bool {
        (shouldShowDueDate && effectiveDueDate != nil) || task.effectiveEstimate != nil || task.hasDateConflicts || !taskTags.isEmpty
    }

    var body: some View {
        if hasContent {
            HStack(alignment: .top, spacing: 0) {
                // Left side: badges that can wrap
                FlowLayout(spacing: DesignSystem.Spacing.sm) {
                    if shouldShowDueDate, let dueDate = effectiveDueDate {
                        DueDateBadge(
                            date: dueDate,
                            isCompleted: task.isCompleted,
                            isInherited: isDueDateInherited,
                            estimatedSeconds: task.effectiveEstimate,
                            hasActiveTimer: calculations.hasAnyTimerRunning
                        )
                    }

                    // Time estimate badge (auto-switches to countdown mode at 90%+)
                    if let estimate = task.effectiveEstimate {
                        TimeEstimateBadge(
                            actual: calculations.totalTimeSpentSeconds,
                            estimated: estimate,
                            isCalculated: task.isUsingCalculatedEstimate,
                            hasActiveTimer: calculations.hasAnyTimerRunning
                        )
                    }

                    // Date conflict badge (Improvement #1)
                    if task.hasDateConflicts {
                        DateConflictBadge()
                    }

                    // Tags (compact summary with colored dots)
                    if !taskTags.isEmpty {
                        CompactTagSummary(tags: taskTags)
                    }
                }
            }
        }
    }
}

// MARK: - Progress Bar Section
struct TaskRowProgressBar: View {
    let task: Task
    let calculations: TaskRowCalculations
    let subtaskBadge: SubtaskBadgeData?

    struct SubtaskBadgeData {
        let completed: Int
        let total: Int
    }

    var body: some View {
        Group {
            if calculations.shouldShowTimeProgress {
                timeProgressBar
            } else if calculations.shouldShowSubtaskProgress {
                subtaskProgressBar
            }
        }
    }

    private var timeProgressBar: some View {
        Group {
            if let _ = task.effectiveEstimate, let progress = calculations.liveTimeProgress {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    TimeProgressBar(
                        progress: progress,
                        status: calculations.liveEstimateStatus,
                        height: DesignSystem.Spacing.xs
                    )

                    // Subtask badge (shows even during time tracking)
                    if let badge = subtaskBadge {
                        SubtasksBadge(
                            completed: badge.completed,
                            total: badge.total
                        )
                    }
                }
            }
        }
    }

    private var subtaskProgressBar: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: DesignSystem.Spacing.xs)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(calculations.subtaskProgressColor(isCompleted: task.isCompleted))
                        .frame(
                            width: geometry.size.width * calculations.subtaskProgressPercentage,
                            height: DesignSystem.Spacing.xs
                        )
                        .animation(.easeInOut(duration: 0.3), value: calculations.subtaskProgressPercentage)
                }
            }
            .frame(height: DesignSystem.Spacing.xs)

            Text("\(Int(calculations.subtaskProgressPercentage * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)

            // Subtask badge next to percentage
            if let badge = subtaskBadge {
                SubtasksBadge(
                    completed: badge.completed,
                    total: badge.total
                )
            }
        }
    }
}

// MARK: - Remaining Time Badge
/// Compact badge showing remaining time or overtime when timer is running
struct RemainingTimeBadge: View {
    let remaining: Int
    let status: TimeEstimateStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: remaining >= 0 ? "clock" : "exclamationmark.triangle.fill")
                .font(.caption2)
            
            Text(formatRemainingTime())
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(remaining >= 0 ? status.color : .red)
    }
    
    private func formatRemainingTime() -> String {
        let absRemaining = abs(remaining)
        let hours = absRemaining / 60
        let mins = absRemaining % 60
        
        var timeStr: String
        if hours > 0 {
            timeStr = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            timeStr = "\(mins)m"
        }
        
        return remaining >= 0 ? "\(timeStr) left" : "\(timeStr) over"
    }
}
