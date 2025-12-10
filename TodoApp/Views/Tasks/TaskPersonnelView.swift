import SwiftUI
import SwiftData

/// Interactive personnel planning view that matches the subtasks/dependencies pattern
struct TaskPersonnelView: View {
    @Bindable var task: Task
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @State private var showingPersonnelPicker = false
    @State private var selectedCount: Int = 1
    @State private var saveError: TaskActionAlert?
    @StateObject private var aggregator = SubtaskAggregator()

    // Use aggregated stats for performance
    private var stats: SubtaskAggregator.AggregatedStats {
        aggregator.getStats(for: task, allTasks: allTasks, currentTime: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Three states: direct assignment, calculated from subtasks, or empty
                if let direct = task.expectedPersonnelCount {
                    // State 1: Direct assignment (tappable to edit)
                    Button {
                        selectedCount = direct
                        showingPersonnelPicker = true
                        HapticManager.selection()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.info)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(direct) \(direct == 1 ? "person" : "people")")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("Expected crew size")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Show mismatch warning if subtask personnel differs
                    if hasMismatch, let subtaskRange = subtaskPersonnelRange {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                if subtaskRange.min == subtaskRange.max {
                                    Text("Subtasks: \(subtaskRange.min) \(subtaskRange.min == 1 ? "person" : "people")")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("Subtasks range: \(subtaskRange.min)-\(subtaskRange.max) people")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    Divider()
                        .padding(.horizontal)
                } else if let range = effectivePersonnelRange {
                    // State 2: Calculated from subtasks (tappable to override)
                    Button {
                        selectedCount = range.min
                        showingPersonnelPicker = true
                        HapticManager.selection()
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                if range.min == range.max {
                                    Text("\(range.min) \(range.min == 1 ? "person" : "people")")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("\(range.min)-\(range.max) people")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                }

                                Text("From subtasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal)
                } else {
                    // State 3: Empty state
                    Text("No assigned personnel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // Action area - button text changes based on state
                Button {
                    selectedCount = task.expectedPersonnelCount ?? effectivePersonnelRange?.min ?? 1
                    showingPersonnelPicker = true
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: buttonIcon)
                            .font(.body)
                            .foregroundStyle(.blue)

                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Actual Usage Section (only show if has time entries)
                if let stats = computeActualPersonnelStats() {
                    Divider()
                        .padding(.horizontal)

                    ActualUsageSection(stats: stats, hasSubtasks: hasSubtasks)
                }

                // Person-Hours Section (only show if has time entries)
                if hasTimeEntries {
                    Divider()
                        .padding(.horizontal)

                    PersonHoursSection(
                        totalPersonHours: stats.totalPersonHours,
                        directPersonHours: stats.directPersonHours,
                        hasSubtasks: hasSubtasks
                    )
                }
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingPersonnelPicker) {
            PersonnelPickerSheet(
                selectedCount: $selectedCount,
                onSave: {
                    task.expectedPersonnelCount = selectedCount
                    do {
                        try task.modelContext?.save()
                        aggregator.invalidate(taskId: task.id)
                        HapticManager.success()
                    } catch {
                        saveError = TaskActionAlert(
                            title: "Save Failed",
                            message: "Could not save personnel count: \(error.localizedDescription)",
                            actions: [AlertAction(title: "OK", role: .cancel, action: {})]
                        )
                    }
                },
                onRemove: task.expectedPersonnelCount != nil ? {
                    task.expectedPersonnelCount = nil
                    do {
                        try task.modelContext?.save()
                        aggregator.invalidate(taskId: task.id)
                        HapticManager.success()
                    } catch {
                        saveError = TaskActionAlert(
                            title: "Save Failed",
                            message: "Could not remove personnel assignment: \(error.localizedDescription)",
                            actions: [AlertAction(title: "OK", role: .cancel, action: {})]
                        )
                    }
                } : nil
            )
        }
        .taskActionAlert(alert: $saveError)
    }

    // MARK: - Computed Properties

    /// Calculate personnel range from subtasks (always calculated for comparison)
    private var subtaskPersonnelRange: (min: Int, max: Int)? {
        // Collect all subtask expected personnel counts
        let counts = collectSubtaskExpectedPersonnel()
        guard !counts.isEmpty else { return nil }

        return (min: counts.min() ?? 1, max: counts.max() ?? 1)
    }

    /// Effective range to use when parent not set
    private var effectivePersonnelRange: (min: Int, max: Int)? {
        guard task.expectedPersonnelCount == nil else {
            return nil
        }
        return subtaskPersonnelRange
    }

    /// Check if parent personnel doesn't match subtask breakdown
    private var hasMismatch: Bool {
        guard let parent = task.expectedPersonnelCount,
              let subtaskRange = subtaskPersonnelRange else {
            return false
        }

        // Show warning if subtasks don't all match parent
        // No warning if all subtasks consistently match (e.g., parent=3, all subtasks=3)
        if subtaskRange.min == subtaskRange.max && subtaskRange.min == parent {
            return false
        }

        // Show warning: user broke down work differently than parent estimate
        return true
    }

    /// Button text based on state
    private var buttonText: String {
        if task.expectedPersonnelCount != nil {
            return "Edit Personnel"
        } else if effectivePersonnelRange != nil {
            return "Set Personnel"
        } else {
            return "Add Personnel"
        }
    }

    /// Button icon based on state
    private var buttonIcon: String {
        if task.expectedPersonnelCount != nil {
            return "pencil.circle.fill"
        } else if effectivePersonnelRange != nil {
            return "square.and.pencil"
        } else {
            return "plus.circle.fill"
        }
    }

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

    // MARK: - Expected Personnel from Subtasks

    /// Collect all expectedPersonnelCount values from subtasks recursively
    private func collectSubtaskExpectedPersonnel() -> [Int] {
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        return collectExpectedCounts(from: subtasks)
    }

    /// Recursively collect expected personnel counts from subtasks
    private func collectExpectedCounts(from subtasks: [Task]) -> [Int] {
        var counts: [Int] = []

        for subtask in subtasks {
            if let expected = subtask.expectedPersonnelCount {
                counts.append(expected)
            }

            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            counts.append(contentsOf: collectExpectedCounts(from: nestedSubtasks))
        }

        return counts
    }

    // MARK: - Personnel Statistics

    private func computeActualPersonnelStats() -> PersonnelStats? {
        // Use aggregator for personnel counts (includes all subtasks)
        let allCounts = stats.personnelCounts
        guard !allCounts.isEmpty else { return nil }

        let directCounts = task.timeEntries?.map { $0.personnelCount } ?? []

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
            hasSubtaskEntries: allCounts.count > directCounts.count
        )
    }

    private func mostFrequent(in numbers: [Int]) -> Int {
        let counts = numbers.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key ?? 1
    }

    // Removed recursive personnel calculations - now using SubtaskAggregator for performance
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

// MARK: - Personnel Picker Sheet

private struct PersonnelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCount: Int
    let onSave: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Expected crew size", selection: $selectedCount) {
                    ForEach(1...20, id: \.self) { count in
                        Text("\(count) \(count == 1 ? "person" : "people")")
                            .tag(count)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .navigationTitle("Set Personnel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let onRemove = onRemove {
                    Button(role: .destructive) {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Remove Personnel Assignment", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Actual Usage Section

private struct ActualUsageSection: View {
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
                .padding(.horizontal)

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
            .padding(.horizontal)

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
                .padding(.horizontal)
            }
        }
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
                .padding(.horizontal)

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
            .padding(.horizontal)
        }
    }
}

#Preview("With Personnel Set") {
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

#Preview("From Subtasks") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let parentTask = Task(title: "Parent Task")

    let subtask1 = Task(title: "Subtask 1", expectedPersonnelCount: 3)
    subtask1.parentTask = parentTask

    let subtask2 = Task(title: "Subtask 2", expectedPersonnelCount: 5)
    subtask2.parentTask = parentTask

    container.mainContext.insert(parentTask)
    container.mainContext.insert(subtask1)
    container.mainContext.insert(subtask2)

    return TaskPersonnelView(task: parentTask)
        .modelContainer(container)
        .padding()
}

#Preview("Mismatch - Parent vs Subtasks") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let parentTask = Task(title: "Build Deck", expectedPersonnelCount: 3)

    let subtask1 = Task(title: "Pour foundation", expectedPersonnelCount: 2)
    subtask1.parentTask = parentTask

    let subtask2 = Task(title: "Install boards", expectedPersonnelCount: 5)
    subtask2.parentTask = parentTask

    let subtask3 = Task(title: "Apply finish", expectedPersonnelCount: 1)
    subtask3.parentTask = parentTask

    container.mainContext.insert(parentTask)
    container.mainContext.insert(subtask1)
    container.mainContext.insert(subtask2)
    container.mainContext.insert(subtask3)

    return TaskPersonnelView(task: parentTask)
        .modelContainer(container)
        .padding()
}

#Preview("No Personnel Set") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Test Task")
    container.mainContext.insert(task)

    return TaskPersonnelView(task: task)
        .modelContainer(container)
        .padding()
}
