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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: unit.icon)
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.info)

                VStack(alignment: .leading, spacing: 2) {
                    Text(taskType ?? "Unknown Type")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !productivityData.isEmpty {
                        HStack(spacing: 4) {
                            Text("Avg: \(formatProductivity(averageProductivity))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let target = targetProductivityRate {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                Text("Target: \(formatProductivity(target))")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Text("No data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(productivityData.count) task\(productivityData.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !productivityData.isEmpty {
                // Chart
                ProductivityBarChart(
                    data: productivityData,
                    average: averageProductivity,
                    target: targetProductivityRate,
                    maxValue: maxProductivity,
                    unit: unit
                )
                .frame(height: 180)
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

// MARK: - Bar Chart Component

private struct ProductivityBarChart: View {
    let data: [ProductivityDataPoint]
    let average: Double
    let target: Double?
    let maxValue: Double
    let unit: UnitType

    @State private var selectedBar: UUID?

    private var chartHeight: CGFloat { 140 }

    /// Use target for comparisons if available, otherwise fall back to average
    private var comparisonValue: Double {
        target ?? average
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Target line (if available) - more prominent
                if let target = target, target > 0 {
                    let targetY = chartHeight * (1 - target / maxValue)

                    HStack(spacing: 0) {
                        // Line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: targetY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: targetY))
                        }
                        .stroke(
                            Color.blue.opacity(0.8),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                        )
                    }

                    // Target label with icon
                    HStack(spacing: 2) {
                        Image(systemName: "target")
                            .font(.system(size: 8))
                        Text(String(format: "%.1f", target))
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .offset(x: 4, y: targetY - 12)
                }

                // Average line (more subtle if target is shown)
                if average > 0 {
                    let averageY = chartHeight * (1 - average / maxValue)

                    HStack(spacing: 0) {
                        // Line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: averageY))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: averageY))
                        }
                        .stroke(
                            DesignSystem.Colors.secondary.opacity(target != nil ? 0.3 : 0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                    }

                    // Average label (only show if different from target or no target)
                    if target == nil || abs(average - (target ?? 0)) > 0.5 {
                        Text(String(format: "%.1f avg", average))
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignSystem.Colors.secondary.opacity(0.1))
                            )
                            .offset(x: geometry.size.width - 60, y: averageY - 12)
                    }
                }

                // Bars
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(data) { point in
                        VStack(spacing: 4) {
                            // Value label with variance
                            if selectedBar == point.id {
                                VStack(spacing: 2) {
                                    Text(String(format: "%.1f", point.productivity))
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

                                    // Show variance from target/average
                                    if comparisonValue > 0 {
                                        let variance = ((point.productivity - comparisonValue) / comparisonValue) * 100
                                        let varianceColor = variance >= 0 ? DesignSystem.Colors.success : DesignSystem.Colors.error
                                        let sign = variance >= 0 ? "+" : ""

                                        Text("\(sign)\(String(format: "%.0f", variance))%")
                                            .font(.caption2)
                                            .foregroundStyle(varianceColor)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 2)
                                )
                            }

                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: point.productivity))
                                .frame(height: barHeight(for: point.productivity))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            selectedBar == point.id ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedBar = selectedBar == point.id ? nil : point.id
                                    }
                                    HapticManager.light()
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: chartHeight)
        }
    }

    private func barHeight(for productivity: Double) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        let ratio = productivity / maxValue
        return max(chartHeight * ratio, 4) // Minimum 4pt height
    }

    private func barColor(for productivity: Double) -> Color {
        // Color based on relation to target (if available) or average
        guard comparisonValue > 0 else { return DesignSystem.Colors.info }
        let ratio = productivity / comparisonValue

        if ratio >= 1.1 {
            return DesignSystem.Colors.success // 10%+ above target/average
        } else if ratio >= 0.9 {
            return DesignSystem.Colors.info // Within 10% of target/average (good)
        } else if ratio >= 0.75 {
            return DesignSystem.Colors.warning // 11-25% below target/average
        } else {
            return DesignSystem.Colors.error // More than 25% below target/average
        }
    }
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
