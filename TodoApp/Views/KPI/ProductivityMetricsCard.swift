import SwiftUI
import SwiftData

/// iOS Health app-style productivity chart card showing individual task productivity
struct ProductivityMetricsCard: View {
    let taskType: String?
    let unit: UnitType
    let tasks: [Task]
    let dateRangeText: String

    @Query private var allTemplates: [TaskTemplate]

    /// Target productivity rate from template (if set)
    private var targetProductivityRate: Double? {
        guard let taskType = taskType else { return nil }
        return allTemplates.first { $0.name == taskType }?.defaultProductivityRate
    }

    private var productivityData: [ProductivityDataPoint] {
        tasks.compactMap { task in
            guard let productivity = task.unitsPerHour,
                  let completedDate = task.completedDate else { return nil }
            return ProductivityDataPoint(
                taskId: task.id,
                taskTitle: task.title,
                productivity: productivity,
                completedDate: completedDate
            )
        }.sorted { $0.completedDate < $1.completedDate }
    }

    private var averageProductivity: Double {
        guard !productivityData.isEmpty else { return 0 }
        let sum = productivityData.reduce(0.0) { $0 + $1.productivity }
        return sum / Double(productivityData.count)
    }

    private var maxProductivity: Double {
        productivityData.map { $0.productivity }.max() ?? 1.0
    }

    /// Tasks above target/average
    private var tasksAboveTarget: Int {
        guard comparisonValue > 0 else { return 0 }
        return productivityData.filter { $0.productivity >= comparisonValue }.count
    }

    /// Tasks below target/average
    private var tasksBelowTarget: Int {
        guard comparisonValue > 0 else { return 0 }
        return productivityData.filter { $0.productivity < comparisonValue }.count
    }

    /// Use target for comparisons if available, otherwise fall back to average
    private var comparisonValue: Double {
        targetProductivityRate ?? averageProductivity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with task type and count
            HStack {
                Image(systemName: unit.icon)
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.info)

                Text(taskType ?? "Unknown Type")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(productivityData.count) task\(productivityData.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !productivityData.isEmpty {
                Divider()

                // Summary Statistics
                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let target = targetProductivityRate {
                        summaryRow(
                            icon: "target",
                            label: "Target:",
                            value: "\(formatProductivity(target)) \(unit.displayName)/hr",
                            color: .blue
                        )
                    }

                    let avgVariance = targetProductivityRate != nil ? ((averageProductivity - (targetProductivityRate ?? 0)) / (targetProductivityRate ?? 1)) * 100 : 0
                    summaryRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Average:",
                        value: "\(formatProductivity(averageProductivity)) \(unit.displayName)/hr",
                        variance: targetProductivityRate != nil ? avgVariance : nil,
                        color: .secondary
                    )

                    if comparisonValue > 0 {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.success)
                                Text("Above: \(tasksAboveTarget) (\(Int((Double(tasksAboveTarget) / Double(productivityData.count)) * 100))%)")
                                    .font(.subheadline)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.error)
                                Text("Below: \(tasksBelowTarget) (\(Int((Double(tasksBelowTarget) / Double(productivityData.count)) * 100))%)")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Compact task list with horizontal bars
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(productivityData) { point in
                        compactTaskRow(for: point)
                    }
                }
            } else {
                // Empty state
                Text("Complete tasks with quantity tracking to see productivity metrics")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.xl)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .statCardStyle()
    }

    // MARK: - Helper Views

    private func summaryRow(icon: String, label: String, value: String, variance: Double? = nil, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)

            if let variance = variance {
                let varianceColor = variance >= 0 ? DesignSystem.Colors.success : DesignSystem.Colors.error
                let sign = variance >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.0f", variance))%")
                    .font(.caption)
                    .foregroundStyle(varianceColor)
            }
        }
    }

    private func compactTaskRow(for point: ProductivityDataPoint) -> some View {
        let variance = comparisonValue > 0 ? ((point.productivity - comparisonValue) / comparisonValue) * 100 : 0
        let barColor = getBarColor(for: point.productivity)

        return VStack(alignment: .leading, spacing: 4) {
            // Task name and values
            HStack {
                Text(point.taskTitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    Text(formatProductivity(point.productivity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(barColor)

                    if comparisonValue > 0 {
                        let varianceColor = variance >= 0 ? DesignSystem.Colors.success : DesignSystem.Colors.error
                        let sign = variance >= 0 ? "+" : ""
                        Text("\(sign)\(String(format: "%.0f", variance))%")
                            .font(.caption)
                            .foregroundStyle(varianceColor)
                    }
                }
            }

            // Horizontal bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    // Progress bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: min(geometry.size.width * (point.productivity / maxProductivity), geometry.size.width),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private func getBarColor(for productivity: Double) -> Color {
        guard comparisonValue > 0 else { return DesignSystem.Colors.info }
        let ratio = productivity / comparisonValue

        if ratio >= 1.1 {
            return DesignSystem.Colors.success
        } else if ratio >= 0.9 {
            return DesignSystem.Colors.info
        } else if ratio >= 0.75 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.error
        }
    }

    private func formatProductivity(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Data Model

struct ProductivityDataPoint: Identifiable {
    let id = UUID()
    let taskId: UUID
    let taskTitle: String
    let productivity: Double
    let completedDate: Date
}

// MARK: - Preview

#Preview("With Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    // Create sample tasks with productivity data
    let tasks = [
        createSampleTask(title: "Paint living room", quantity: 35.0, personHours: 4.0, daysAgo: 5, container: container),
        createSampleTask(title: "Paint bedroom", quantity: 42.0, personHours: 5.0, daysAgo: 4, container: container),
        createSampleTask(title: "Paint kitchen", quantity: 28.0, personHours: 3.5, daysAgo: 3, container: container),
        createSampleTask(title: "Paint hallway", quantity: 38.0, personHours: 4.5, daysAgo: 2, container: container),
        createSampleTask(title: "Paint bathroom", quantity: 32.0, personHours: 4.0, daysAgo: 1, container: container)
    ]

    return ScrollView {
        ProductivityMetricsCard(
            taskType: "Carpet Installation",
            unit: .squareMeters,
            tasks: tasks,
            dateRangeText: "This Week"
        )
        .padding()
    }
    .modelContainer(container)
}

#Preview("Empty State") {
    ProductivityMetricsCard(
        taskType: "Booth Wall Setup",
        unit: .meters,
        tasks: [],
        dateRangeText: "This Week"
    )
    .padding()
}

// Helper function for preview
private func createSampleTask(title: String, quantity: Double, personHours: Double, daysAgo: Int, container: ModelContainer) -> Task {
    let task = Task(
        title: title,
        completedDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
        quantity: quantity,
        unit: .squareMeters
    )

    let hoursPerPerson = personHours / 2.0 // Simulate 2 people working
    let entry = TimeEntry(
        startTime: task.completedDate!.addingTimeInterval(-hoursPerPerson * 3600),
        endTime: task.completedDate,
        personnelCount: 2,
        task: task
    )

    container.mainContext.insert(task)
    container.mainContext.insert(entry)

    return task
}
