import SwiftUI
import SwiftData

/// Detail view showing today's completed time entries
struct TodaysTimeEntriesDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [TimeEntry]

    private var todayEntries: [TimeEntry] {
        let today = Date()
        return entries.filter { entry in
            guard let endTime = entry.endTime else { return false }
            return Calendar.current.isDate(endTime, inSameDayAs: today)
        }
        .sorted { ($0.endTime ?? Date()) > ($1.endTime ?? Date()) }
    }

    private var totalHours: Double {
        todayEntries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            return total + end.timeIntervalSince(entry.startTime) / 3600
        }
    }

    private var totalPersonHours: Double {
        todayEntries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let hours = end.timeIntervalSince(entry.startTime) / 3600
            return total + (hours * Double(entry.personnelCount))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No Time Logged Today",
                        systemImage: "clock",
                        description: Text("Complete a timer to see it here")
                    )
                } else {
                    Section {
                        // Summary stats
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Hours")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                                Text(String(format: "%.1f hrs", totalHours))
                                    .font(DesignSystem.Typography.title3)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Person-Hours")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                                Text(String(format: "%.1f hrs", totalPersonHours))
                                    .font(DesignSystem.Typography.title3)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }

                    Section {
                        ForEach(todayEntries) { entry in
                            TimeEntryRow(entry: entry)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("\(todayEntries.count) \(todayEntries.count == 1 ? "Entry" : "Entries") Today")
                        }
                        .foregroundStyle(DesignSystem.Colors.info)
                    }
                }
            }
            .navigationTitle("Today's Time")
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

private struct TimeEntryRow: View {
    let entry: TimeEntry

    private var taskTitle: String {
        entry.task?.title ?? "Unknown Task"
    }

    private var projectName: String? {
        entry.task?.project?.title
    }

    private var projectColor: String? {
        entry.task?.project?.color
    }

    private var duration: String {
        guard let end = entry.endTime else { return "In Progress" }
        let duration = end.timeIntervalSince(entry.startTime)
        let hours = duration / 3600

        if hours >= 1 {
            return String(format: "%.1f hrs", hours)
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes) min"
        }
    }

    private var personHours: String? {
        guard entry.personnelCount > 1, let end = entry.endTime else { return nil }
        let duration = end.timeIntervalSince(entry.startTime)
        let hours = duration / 3600
        let ph = hours * Double(entry.personnelCount)
        return String(format: "%.1f person-hrs", ph)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: entry.startTime)
        if let end = entry.endTime {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        }
        return "Started at \(start)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Task title
            Text(taskTitle)
                .font(DesignSystem.Typography.body)

            // Project
            if let projectName = projectName, let projectColor = projectColor {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: projectColor))
                        .frame(width: 8, height: 8)
                    Text(projectName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
            }

            // Time info
            HStack(spacing: DesignSystem.Spacing.sm) {
                Label(timeRange, systemImage: "clock")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)

                Text("•")
                    .foregroundStyle(DesignSystem.Colors.tertiary)

                Text(duration)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.info)

                if let personHours = personHours {
                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.tertiary)

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text(personHours)
                    }
                    .font(DesignSystem.Typography.caption)
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
    let task = Task(title: "Test Task", project: project)

    let entry1 = TimeEntry(
        startTime: Date().addingTimeInterval(-7200),
        endTime: Date().addingTimeInterval(-3600),
        task: task
    )
    let entry2 = TimeEntry(
        startTime: Date().addingTimeInterval(-1800),
        endTime: Date(),
        personnelCount: 3,
        task: task
    )

    container.mainContext.insert(project)
    container.mainContext.insert(task)
    container.mainContext.insert(entry1)
    container.mainContext.insert(entry2)

    return TodaysTimeEntriesDetailView(entries: [entry1, entry2])
        .modelContainer(container)
}
