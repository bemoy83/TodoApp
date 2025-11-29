import SwiftUI
import SwiftData

/// Generic detail view for displaying a filtered list of tasks
struct TaskListDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let tasks: [Task]
    let icon: String
    let color: Color

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: icon,
                        description: Text("No tasks match this criteria")
                    )
                } else {
                    Section {
                        ForEach(tasks) { task in
                            TaskDetailRow(task: task, showReason: title == "Blocked Tasks")
                        }
                    } header: {
                        HStack {
                            Image(systemName: icon)
                            Text("\(tasks.count) \(tasks.count == 1 ? "Task" : "Tasks")")
                        }
                        .foregroundStyle(color)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TaskDetailRow: View {
    let task: Task
    let showReason: Bool

    private var daysOverdue: Int? {
        guard let dueDate = task.effectiveDeadline, !task.isCompleted else { return nil }
        let days = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day
        return days
    }

    private var estimateProgress: Double? {
        task.timeProgress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Task title with priority
            HStack(spacing: 6) {
                if task.priority == 0 {
                    Image(systemName: "exclamationmark.3")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.error)
                }

                Text(task.title)
                    .font(DesignSystem.Typography.body)

                Spacer()

                // Status badge
                Text(task.status.displayName)
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(task.status.color).opacity(0.2))
                    )
                    .foregroundStyle(Color(task.status.color))
            }

            // Project
            if let project = task.project {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 8, height: 8)
                    Text(project.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }

            // Contextual info based on type
            if let days = daysOverdue, days > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(DesignSystem.Colors.error)
                    Text("\(days) \(days == 1 ? "day" : "days") overdue")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.error)
                }
            }

            if let progress = estimateProgress {
                HStack(spacing: 8) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress >= 1.0 ? DesignSystem.Colors.error :
                              progress >= 0.8 ? DesignSystem.Colors.warning :
                              DesignSystem.Colors.success)

                    Text("\(Int(progress * 100))%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }

            // Show blocking dependencies for blocked tasks
            if showReason && !task.blockingDependencies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked by:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)

                    ForEach(task.blockingDependencies.prefix(3)) { dep in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(dep.title)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.warning)
                    }

                    if task.blockingDependencies.count > 3 {
                        Text("+\(task.blockingDependencies.count - 3) more")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)

    let project = Project(title: "Test Project", color: "#FF6B6B")
    let task1 = Task(title: "Overdue Task", priority: 0, dueDate: Date().addingTimeInterval(-86400 * 3), project: project)
    let task2 = Task(title: "Blocked Task", project: project)

    container.mainContext.insert(project)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)

    return TaskListDetailView(
        title: "Overdue Tasks",
        tasks: [task1, task2],
        icon: "exclamationmark.triangle.fill",
        color: DesignSystem.Colors.error
    )
    .modelContainer(container)
}
