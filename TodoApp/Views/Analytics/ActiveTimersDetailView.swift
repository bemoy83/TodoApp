import SwiftUI
import SwiftData
internal import Combine

/// Detail view showing all active timers with live elapsed time
struct ActiveTimersDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [Task]

    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Active Timers",
                        systemImage: "timer",
                        description: Text("Start a timer on a task to see it here")
                    )
                } else {
                    ForEach(tasks) { task in
                        ActiveTimerRow(task: task, currentTime: currentTime)
                    }
                }
            }
            .navigationTitle("Active Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onReceive(timer) { _ in
                currentTime = Date()
            }
        }
    }
}

struct ActiveTimerRow: View {
    let task: Task
    let currentTime: Date

    private var activeEntry: TimeEntry? {
        task.timeEntries?.first { $0.endTime == nil }
    }

    private var elapsedTime: String {
        guard let entry = activeEntry else { return "0:00" }
        let elapsed = Int(currentTime.timeIntervalSince(entry.startTime))
        return elapsed.formattedStopwatch()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Task title
            Text(task.title)
                .font(DesignSystem.Typography.headline)

            // Project badge
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

            Divider()

            // Timer info
            HStack {
                // Elapsed time
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(DesignSystem.Colors.info)
                    Text(elapsedTime)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                }

                Spacer()

                // Personnel count
                if let entry = activeEntry, entry.personnelCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(entry.personnelCount)")
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.info)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Project.self, TimeEntry.self, configurations: config)

    let project = Project(title: "Test Project", color: "#FF6B6B")
    let task1 = Task(title: "Active Task 1", project: project)
    let task2 = Task(title: "Active Task 2", project: project)

    let entry1 = TimeEntry(startTime: Date().addingTimeInterval(-3600), endTime: nil, task: task1)
    let entry2 = TimeEntry(startTime: Date().addingTimeInterval(-1800), endTime: nil, personnelCount: 3, task: task2)

    task1.timeEntries = [entry1]
    task2.timeEntries = [entry2]

    container.mainContext.insert(project)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)
    container.mainContext.insert(entry1)
    container.mainContext.insert(entry2)

    return ActiveTimersDetailView(tasks: [task1, task2])
        .modelContainer(container)
}
