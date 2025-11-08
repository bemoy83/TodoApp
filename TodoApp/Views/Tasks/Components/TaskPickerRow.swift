import SwiftUI

/// Shared task row component for pickers (DependencyPicker, MoveToTaskPicker, etc.)
/// Provides consistent styling across all task selection interfaces
struct TaskPickerRow: View {
    let task: Task

    // Customization options
    var showPriority: Bool = false
    var showStatus: Bool = false
    var showSubtaskCount: Bool = false

    private var isSubtask: Bool {
        task.parentTask != nil
    }

    private var priority: Priority {
        Priority(rawValue: task.priority) ?? .medium
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Project color bar (consistent with TaskListView)
            if let project = task.project {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: project.color))
                    .frame(width: 3, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 3, height: 32)
            }

            // Task icon - different for tasks vs subtasks
            Image(systemName: isSubtask ? "arrow.turn.down.right" : "doc.text")
                .font(.body)
                .foregroundStyle(isSubtask ? .secondary : .primary)
                .frame(width: 24)

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Hierarchy info: parent task for subtasks, project for top-level
                if isSubtask {
                    if let parent = task.parentTask {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption2)
                            Text(parent.title)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                } else if let project = task.project {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 6, height: 6)
                        Text(project.title)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Trailing indicators (customizable)
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Priority indicator
                if showPriority && priority != .medium {
                    Image(systemName: priority.icon)
                        .font(.caption)
                        .foregroundStyle(priority.color)
                }

                // Subtask count badge
                if showSubtaskCount && task.subtaskCount > 0 {
                    Text("\(task.subtaskCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                        )
                }

                // Status indicator
                if showStatus {
                    Image(systemName: task.status.icon)
                        .font(.caption)
                        .foregroundStyle(Color(task.status.color))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
