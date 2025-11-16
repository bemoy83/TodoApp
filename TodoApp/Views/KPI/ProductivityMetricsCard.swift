import SwiftUI
import SwiftData

/// iOS Health app-style productivity chart card showing individual task productivity
struct ProductivityMetricsCard: View {
    let taskType: String?
    let unit: UnitType
    let tasks: [Task]
    let dateRangeText: String

    @Query private var allTemplates: [TaskTemplate]

    @State private var showAllTasks = false
    @State private var isExpanded = false

    private let defaultTaskLimit = 5

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

    /// Tasks to display (limited or all)
    private var displayedTasks: [ProductivityDataPoint] {
        if showAllTasks || productivityData.count <= defaultTaskLimit {
            return productivityData
        }
        return Array(productivityData.prefix(defaultTaskLimit))
    }

    /// Number of hidden tasks
    private var hiddenTaskCount: Int {
        max(0, productivityData.count - defaultTaskLimit)
    }

    /// Check if we should show "consider updating target" alert
    /// Shows if 70%+ of tasks are below target
    private var shouldShowTargetAlert: Bool {
        guard let _ = targetProductivityRate,
              tasksBelowTarget > 0,
              productivityData.count >= 3 else { return false }

        let belowPercentage = Double(tasksBelowTarget) / Double(productivityData.count)
        return belowPercentage >= 0.7
    }

    /// Suggested new target based on current average
    private var suggestedTarget: Double {
        averageProductivity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with task type and count - tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
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

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if !productivityData.isEmpty {
                // Collapsed view: Show only badges
                if !isExpanded {
                    compactSummaryBadges
                }

                // Expanded view: Show all details
                if isExpanded {
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

                    // Target adjustment alert (if consistently missing target)
                    if shouldShowTargetAlert {
                        Divider()
                        targetAdjustmentAlert
                    }

                    Divider()

                    // Compact task list with horizontal bars
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(displayedTasks) { point in
                            compactTaskRow(for: point)
                        }
                    }

                    // Show more button
                    if hiddenTaskCount > 0 && !showAllTasks {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllTasks = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                Text("Show \(hiddenTaskCount) more task\(hiddenTaskCount == 1 ? "" : "s")")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    // Show less button
                    if showAllTasks && productivityData.count > defaultTaskLimit {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllTasks = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                                Text("Show less")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                        .buttonStyle(.plain)
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

    /// Compact badges showing target and average when collapsed
    private var compactSummaryBadges: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Target badge (if available)
            if let target = targetProductivityRate {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text("Target: \(formatProductivity(target)) \(unit.displayName)/hr")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }

            // Average badge with variance
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text("Avg: \(formatProductivity(averageProductivity)) \(unit.displayName)/hr")
                    .font(.caption)

                // Show variance if target is set
                if let target = targetProductivityRate {
                    let avgVariance = ((averageProductivity - target) / target) * 100
                    let varianceColor = avgVariance >= 0 ? DesignSystem.Colors.success : DesignSystem.Colors.error
                    let sign = avgVariance >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.0f", avgVariance))%")
                        .font(.caption2)
                        .foregroundStyle(varianceColor)
                }
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var targetAdjustmentAlert: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Consider Adjusting Target")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("70%+ tasks below target. Current average: \(formatProductivity(suggestedTarget)) \(unit.displayName)/hr")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .strokeBorder(DesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
        )
    }

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
