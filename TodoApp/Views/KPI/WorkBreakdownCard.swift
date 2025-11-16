import SwiftUI
import SwiftData

/// Card showing work volume breakdown by task type with efficiency analysis
struct WorkBreakdownCard: View {
    let tasks: [Task]
    let dateRangeText: String

    @Query private var allTemplates: [TaskTemplate]
    @State private var isExpanded = false

    // MARK: - Data Models

    struct TaskTypeBreakdown: Identifiable {
        let id = UUID()
        let taskType: String
        let unit: UnitType
        let icon: String
        let totalQuantity: Double
        let taskCount: Int
        let totalPersonHours: Double
        let percentOfTasks: Double
        let percentOfHours: Double
        let efficiency: EfficiencyStatus
    }

    enum EfficiencyStatus {
        case efficient      // % hours < % tasks (doing more with less time)
        case balanced       // % hours ≈ % tasks
        case reviewNeeded   // % hours >> % tasks (labor intensive)

        var icon: String {
            switch self {
            case .efficient: return "checkmark.circle.fill"
            case .balanced: return "equal.circle.fill"
            case .reviewNeeded: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .efficient: return DesignSystem.Colors.success
            case .balanced: return DesignSystem.Colors.info
            case .reviewNeeded: return DesignSystem.Colors.warning
            }
        }

        var label: String {
            switch self {
            case .efficient: return "Efficient"
            case .balanced: return "Balanced"
            case .reviewNeeded: return "Review - labor intensive"
            }
        }
    }

    // MARK: - Computed Properties

    private var breakdowns: [TaskTypeBreakdown] {
        // Group completed tasks with quantity by task type
        let completedTasks = tasks.filter { task in
            task.isCompleted && task.quantity != nil && task.quantity! > 0
        }

        guard !completedTasks.isEmpty else { return [] }

        // Calculate totals
        let totalTasks = completedTasks.count
        let totalPersonHours = completedTasks.reduce(0.0) { sum, task in
            sum + (task.totalPersonHours ?? 0)
        }

        // Group by task type and unit
        var grouped: [String: [Task]] = [:]
        for task in completedTasks {
            let key = "\(task.taskType ?? "Unknown")_\(task.unit.displayName)"
            if grouped[key] != nil {
                grouped[key]?.append(task)
            } else {
                grouped[key] = [task]
            }
        }

        // Create breakdowns
        return grouped.map { key, typeTasks in
            let taskType = typeTasks.first?.taskType ?? "Unknown"
            let unit = typeTasks.first?.unit ?? .none
            let icon = unit.icon

            let totalQuantity = typeTasks.reduce(0.0) { $0 + ($1.quantity ?? 0) }
            let taskCount = typeTasks.count
            let typePersonHours = typeTasks.reduce(0.0) { $0 + ($1.totalPersonHours ?? 0) }

            let percentOfTasks = totalTasks > 0 ? (Double(taskCount) / Double(totalTasks)) * 100 : 0
            let percentOfHours = totalPersonHours > 0 ? (typePersonHours / totalPersonHours) * 100 : 0

            // Determine efficiency status
            let hoursDiff = percentOfHours - percentOfTasks
            let efficiency: EfficiencyStatus
            if hoursDiff < -10 {
                efficiency = .efficient  // Using significantly less time than task share
            } else if hoursDiff > 15 {
                efficiency = .reviewNeeded  // Using significantly more time than task share
            } else {
                efficiency = .balanced
            }

            return TaskTypeBreakdown(
                taskType: taskType,
                unit: unit,
                icon: icon,
                totalQuantity: totalQuantity,
                taskCount: taskCount,
                totalPersonHours: typePersonHours,
                percentOfTasks: percentOfTasks,
                percentOfHours: percentOfHours,
                efficiency: efficiency
            )
        }.sorted { $0.percentOfHours > $1.percentOfHours }  // Sort by hours (most resource-intensive first)
    }

    private var totalTasks: Int {
        breakdowns.reduce(0) { $0 + $1.taskCount }
    }

    private var totalPersonHours: Double {
        breakdowns.reduce(0.0) { $0 + $1.totalPersonHours }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header - tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.info)

                    Text("Work Breakdown")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if !breakdowns.isEmpty {
                        Text("\(totalTasks) task\(totalTasks == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            if breakdowns.isEmpty {
                // Empty state
                Text("Complete tasks with quantity tracking to see work breakdown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                // Collapsed view: Summary only
                if !isExpanded {
                    collapsedSummary
                }

                // Expanded view: Full breakdown
                if isExpanded {
                    Divider()

                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(breakdowns) { breakdown in
                            taskTypeRow(breakdown)
                        }
                    }

                    Divider()

                    // Total summary
                    HStack {
                        Text("Total")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(totalTasks) tasks · \(formatHours(totalPersonHours)) hrs")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .statCardStyle()
    }

    // MARK: - Helper Views

    private var collapsedSummary: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Show top 2 task types
            ForEach(breakdowns.prefix(2)) { breakdown in
                HStack(spacing: 4) {
                    Image(systemName: breakdown.icon)
                        .font(.caption2)

                    Text(breakdown.taskType)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }

            if breakdowns.count > 2 {
                Text("+\(breakdowns.count - 2) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private func taskTypeRow(_ breakdown: TaskTypeBreakdown) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Header row
            HStack {
                Image(systemName: breakdown.icon)
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.info)

                Text(breakdown.taskType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: breakdown.efficiency.icon)
                    .font(.caption)
                    .foregroundStyle(breakdown.efficiency.color)
            }

            // Quantity and task count
            HStack(spacing: 4) {
                Text(formatQuantity(breakdown.totalQuantity, unit: breakdown.unit))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text("\(breakdown.taskCount) task\(breakdown.taskCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Percentage breakdown
            HStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: 4) {
                    Text("\(Int(breakdown.percentOfTasks))% of tasks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    Text("\(Int(breakdown.percentOfHours))% of hours")
                        .font(.caption)
                        .foregroundStyle(breakdown.efficiency.color)
                        .fontWeight(.medium)
                }
            }

            // Efficiency status
            HStack(spacing: 4) {
                Image(systemName: breakdown.efficiency.icon)
                    .font(.caption2)
                    .foregroundStyle(breakdown.efficiency.color)

                Text(breakdown.efficiency.label)
                    .font(.caption)
                    .foregroundStyle(breakdown.efficiency.color)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(breakdown.efficiency.color.opacity(0.1))
            )
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Formatting Helpers

    private func formatQuantity(_ value: Double, unit: UnitType) -> String {
        let formatted = String(format: "%.1f", value)
        return "\(formatted) \(unit.displayName)"
    }

    private func formatHours(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview("With Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    // Create sample tasks
    let tasks = [
        createSampleTaskWithQuantity(
            title: "Install carpet section 1",
            taskType: "Carpet Installation",
            quantity: 45.5,
            unit: .squareMeters,
            personHours: 8.0,
            container: container
        ),
        createSampleTaskWithQuantity(
            title: "Install carpet section 2",
            taskType: "Carpet Installation",
            quantity: 52.0,
            unit: .squareMeters,
            personHours: 10.0,
            container: container
        ),
        createSampleTaskWithQuantity(
            title: "Setup booth wall A",
            taskType: "Booth Wall Setup",
            quantity: 25.0,
            unit: .meters,
            personHours: 15.0,
            container: container
        ),
        createSampleTaskWithQuantity(
            title: "Assemble chairs",
            taskType: "Furniture Assembly",
            quantity: 30.0,
            unit: .pieces,
            personHours: 4.0,
            container: container
        )
    ]

    ScrollView {
        WorkBreakdownCard(
            tasks: tasks,
            dateRangeText: "This Week"
        )
        .padding()
    }
    .modelContainer(container)
}

#Preview("Empty State") {
    WorkBreakdownCard(
        tasks: [],
        dateRangeText: "This Week"
    )
    .padding()
}

// Helper function for preview
private func createSampleTaskWithQuantity(
    title: String,
    taskType: String,
    quantity: Double,
    unit: UnitType,
    personHours: Double,
    container: ModelContainer
) -> Task {
    let task = Task(
        title: title,
        completedDate: Date(),
        quantity: quantity,
        unit: unit,
        taskType: taskType
    )

    let entry = TimeEntry(
        startTime: Date().addingTimeInterval(-personHours * 3600),
        endTime: Date(),
        personnelCount: 2,
        task: task
    )

    container.mainContext.insert(task)
    container.mainContext.insert(entry)

    return task
}
