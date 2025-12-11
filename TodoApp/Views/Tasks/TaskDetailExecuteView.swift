import SwiftUI
import SwiftData

/// Execute tab view - streamlined, zero-distraction execution interface
struct TaskDetailExecuteView: View {
    @Bindable var task: Task

    var body: some View {
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
