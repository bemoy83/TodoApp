import SwiftUI

// MARK: - Title Section
struct TaskRowTitleSection: View {
    let task: Task
    let shouldShowPriority: Bool
    let taskPriority: Priority
    let subtaskBadge: SubtaskBadgeData?
    
    struct SubtaskBadgeData {
        let completed: Int
        let total: Int
    }
    
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
            
            Spacer()
            
            // Subtask badge on title row
            if let badge = subtaskBadge {
                SubtasksBadge(
                    completed: badge.completed,
                    total: badge.total
                )
            }
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
    
    // Check if there's any content to show
    var hasContent: Bool {
        (shouldShowDueDate && effectiveDueDate != nil) || task.effectiveEstimate != nil
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
                            isInherited: isDueDateInherited
                        )
                    }
                    
                    // Time estimate badge or remaining time badge
                    if let estimate = task.effectiveEstimate {
                        if calculations.shouldShowTimeProgress {
                            RemainingTimeBadge(
                                remaining: calculations.liveTimeRemaining ?? 0,
                                status: calculations.liveEstimateStatus ?? .onTrack
                            )
                        } else {
                            TimeEstimateBadge(
                                actual: calculations.totalTimeSpent,
                                estimated: estimate,
                                isCalculated: task.isUsingCalculatedEstimate,
                                hasActiveTimer: task.hasActiveTimer
                            )
                        }
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
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: DesignSystem.Spacing.xs)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(calculations.liveEstimateStatus?.color ?? .blue)
                                .frame(
                                    width: min(geometry.size.width * progress, geometry.size.width),
                                    height: DesignSystem.Spacing.xs
                                )
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: DesignSystem.Spacing.xs)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(calculations.liveEstimateStatus?.color ?? .secondary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
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
