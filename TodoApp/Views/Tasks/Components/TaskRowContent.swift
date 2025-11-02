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
                    
                    // Time estimate badge (auto-switches to countdown mode at 90%+)
                    if let estimate = task.effectiveEstimate {
                        TimeEstimateBadge(
                            actual: calculations.totalTimeSpent * 60, // Convert minutes to seconds
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
                TimeProgressBar(
                    progress: progress,
                    status: calculations.liveEstimateStatus,
                    height: DesignSystem.Spacing.xs
                )
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
