import SwiftUI
import SwiftData

/// View showing personnel planning and actual usage statistics for a task
struct TaskPersonnelView: View {
    @Bindable var task: Task

    @Query(sort: \Task.order) private var allTasks: [Task]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Expected Personnel Section
            ExpectedPersonnelSection(
                expectedCount: task.expectedPersonnelCount
            )

            // Actual Usage Section (conditional - only if has time entries)
            if let actualStats = computeActualPersonnelStats() {
                ActualPersonnelSection(
                    stats: actualStats,
                    hasSubtasks: hasSubtasks
                )
            }

            // Total Person-Hours Section (conditional - only if has time entries)
            if hasTimeEntries {
                PersonHoursSection(
                    totalPersonHours: computeTotalPersonHours(),
                    directPersonHours: computeDirectPersonHours(),
                    hasSubtasks: hasSubtasks
                )
            }
        }
        .detailCardStyle()
    }

    // MARK: - Computed Properties

    private var hasSubtasks: Bool {
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return !subtasks.isEmpty
    }

    private var hasTimeEntries: Bool {
        if let entries = task.timeEntries, !entries.isEmpty {
            return true
        }

        // Check subtasks
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return checkSubtasksForEntries(in: subtasks)
    }

    private func checkSubtasksForEntries(in subtasks: [Task]) -> Bool {
        for subtask in subtasks {
            if let entries = subtask.timeEntries, !entries.isEmpty {
                return true
            }
            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            if checkSubtasksForEntries(in: nestedSubtasks) {
                return true
            }
        }
        return false
    }

    // MARK: - Personnel Statistics

    private func computeActualPersonnelStats() -> PersonnelStats? {
        let directCounts = getDirectPersonnelCounts()
        let subtaskCounts = getSubtaskPersonnelCounts()
        let allCounts = directCounts + subtaskCounts

        guard !allCounts.isEmpty else { return nil }

        let min = allCounts.min() ?? 1
        let max = allCounts.max() ?? 1
        let mostCommon = mostFrequent(in: allCounts)
        let average = Double(allCounts.reduce(0, +)) / Double(allCounts.count)

        return PersonnelStats(
            min: min,
            max: max,
            mostCommon: mostCommon,
            average: average,
            hasDirectEntries: !directCounts.isEmpty,
            hasSubtaskEntries: !subtaskCounts.isEmpty
        )
    }

    private func getDirectPersonnelCounts() -> [Int] {
        guard let entries = task.timeEntries else { return [] }
        return entries.map { $0.personnelCount }
    }

    private func getSubtaskPersonnelCounts() -> [Int] {
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return collectPersonnelCounts(from: subtasks)
    }

    private func collectPersonnelCounts(from subtasks: [Task]) -> [Int] {
        var counts: [Int] = []

        for subtask in subtasks {
            if let entries = subtask.timeEntries {
                counts.append(contentsOf: entries.map { $0.personnelCount })
            }

            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            counts.append(contentsOf: collectPersonnelCounts(from: nestedSubtasks))
        }

        return counts
    }

    private func mostFrequent(in numbers: [Int]) -> Int {
        let counts = numbers.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? 1
    }

    // MARK: - Person-Hours Calculations

    private func computeDirectPersonHours() -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        var totalPersonSeconds = 0.0

        for entry in entries {
            guard let end = entry.endTime else { continue }
            let duration = end.timeIntervalSince(entry.startTime)
            totalPersonSeconds += duration * Double(entry.personnelCount)
        }

        return totalPersonSeconds / 3600  // Convert to hours
    }

    private func computeTotalPersonHours() -> Double {
        var total = computeDirectPersonHours()

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computePersonHours(for: subtask)
        }

        return total
    }

    private func computePersonHours(for task: Task) -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        var totalPersonSeconds = 0.0

        for entry in entries {
            guard let end = entry.endTime else { continue }
            let duration = end.timeIntervalSince(entry.startTime)
            totalPersonSeconds += duration * Double(entry.personnelCount)
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            totalPersonSeconds += computePersonHours(for: subtask) * 3600  // Convert back to seconds
        }

        return totalPersonSeconds / 3600  // Convert to hours
    }
}

// MARK: - Supporting Types

struct PersonnelStats {
    let min: Int
    let max: Int
    let mostCommon: Int
    let average: Double
    let hasDirectEntries: Bool
    let hasSubtaskEntries: Bool
}

// MARK: - Expected Personnel Section

private struct ExpectedPersonnelSection: View {
    let expectedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Expected Personnel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.info)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(expectedCount) \(expectedCount == 1 ? "person" : "people")")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Planned crew size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Actual Personnel Section

private struct ActualPersonnelSection: View {
    let stats: PersonnelStats
    let hasSubtasks: Bool

    private var mostCommonText: String {
        if stats.min == stats.max {
            return "Consistent crew size"
        } else {
            return "Most common: \(stats.mostCommon)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Actual Usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    if stats.min == stats.max {
                        Text("\(stats.min) \(stats.min == 1 ? "person" : "people")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(stats.min)-\(stats.max) people")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(mostCommonText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Breakdown if has both direct and subtask entries
            if hasSubtasks && stats.hasDirectEntries && stats.hasSubtaskEntries {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)

                    Text("Includes data from subtasks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Person-Hours Section

private struct PersonHoursSection: View {
    let totalPersonHours: Double
    let directPersonHours: Double
    let hasSubtasks: Bool

    private var formattedTotalPersonHours: String {
        String(format: "%.1f hrs", totalPersonHours)
    }

    private var formattedDirectPersonHours: String {
        String(format: "%.1f", directPersonHours)
    }

    private var formattedSubtaskPersonHours: String {
        let subtask = totalPersonHours - directPersonHours
        return String(format: "%.1f", subtask)
    }

    private var hasSubtaskPersonHours: Bool {
        totalPersonHours > directPersonHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Total Person-Hours")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.info)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedTotalPersonHours)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.info)

                    // Breakdown if has subtask person-hours
                    if hasSubtaskPersonHours {
                        Text("\(formattedDirectPersonHours) direct, \(formattedSubtaskPersonHours) from subtasks")
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

#Preview("With Personnel Tracking") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Test Task", expectedPersonnelCount: 3)

    let entry1 = TimeEntry(
        startTime: Date().addingTimeInterval(-7200),
        endTime: Date().addingTimeInterval(-3600),
        personnelCount: 3,
        task: task
    )
    let entry2 = TimeEntry(
        startTime: Date().addingTimeInterval(-1800),
        endTime: Date(),
        personnelCount: 2,
        task: task
    )

    container.mainContext.insert(task)
    container.mainContext.insert(entry1)
    container.mainContext.insert(entry2)

    return TaskPersonnelView(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("Expected Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Test Task", expectedPersonnelCount: 5)
    container.mainContext.insert(task)

    return TaskPersonnelView(task: task)
        .modelContainer(container)
        .padding()
}
