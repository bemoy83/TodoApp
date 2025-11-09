import SwiftUI
import SwiftData

/// Detail view showing today's completed tasks
struct CompletedTasksDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [Task]

    private var todayCompletedTasks: [Task] {
        let today = Date()
        return tasks.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return Calendar.current.isDate(completedDate, inSameDayAs: today)
        }
        .sorted { ($0.completedDate ?? Date()) > ($1.completedDate ?? Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                if todayCompletedTasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Completed Today",
                        systemImage: "checkmark.circle",
                        description: Text("Complete a task to see it here")
                    )
                } else {
                    Section {
                        ForEach(todayCompletedTasks) { task in
                            CompletedTaskRow(task: task)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("\(todayCompletedTasks.count) \(todayCompletedTasks.count == 1 ? "Task" : "Tasks") Completed Today")
                        }
                        .foregroundStyle(DesignSystem.Colors.success)
                    }
                }
            }
            .navigationTitle("Completed Today")
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

struct CompletedTaskRow: View {
    let task: Task

    private var completedTime: String {
        guard let completedDate = task.completedDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: completedDate)
    }

    private var totalHours: String {
        let hours = Double(task.totalTimeSpent) / 3600
        if hours == 0 {
            return "No time logged"
        }
        return String(format: "%.1f hrs", hours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Task title with checkmark
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignSystem.Colors.success)

                Text(task.title)
                    .font(DesignSystem.Typography.body)

                Spacer()

                if task.priority == 0 {
                    Image(systemName: "exclamationmark.3")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.error)
                }
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

            // Completion info
            HStack(spacing: DesignSystem.Spacing.md) {
                Label(completedTime, systemImage: "clock")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Text("•")
                    .foregroundStyle(DesignSystem.Colors.tertiary)

                Text(totalHours)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)

    let project = Project(title: "Test Project", color: "#FF6B6B")
    let task1 = Task(title: "Completed Task 1", completedDate: Date(), project: project)
    let task2 = Task(title: "Completed Task 2", priority: 0, completedDate: Date(), project: project)

    container.mainContext.insert(project)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)

    return CompletedTasksDetailView(tasks: [task1, task2])
        .modelContainer(container)
}
