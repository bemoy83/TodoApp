import SwiftUI
import SwiftData
import Charts

/// Comprehensive statistics view for template usage and productivity
struct TemplateStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query private var allTasks: [Task]

    private var statistics: TemplateManager.TemplateStatistics {
        TemplateManager.calculateStatistics(for: templates)
    }

    private var templateUsageData: [TemplateUsageData] {
        templates.map { template in
            let taskCount = template.tasks?.count ?? 0
            let analytics = TemplateManager.calculateAnalytics(for: template, from: allTasks)
            return TemplateUsageData(
                template: template,
                taskCount: taskCount,
                analytics: analytics
            )
        }
        .sorted { $0.taskCount > $1.taskCount }
    }

    var body: some View {
        NavigationStack {
            List {
                // Overview Section
                Section {
                    OverviewCard(statistics: statistics)
                } header: {
                    Text("Overview")
                }

                // Usage Breakdown
                if !templates.isEmpty {
                    Section {
                        ForEach(templateUsageData) { data in
                            TemplateUsageRow(data: data)
                        }
                    } header: {
                        Text("Usage by Template")
                    }
                }

                // Top Performers
                Section {
                    TopPerformersCard(data: templateUsageData)
                } header: {
                    Text("Most Used Templates")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Template Statistics")
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

// MARK: - Supporting Types

struct TemplateUsageData: Identifiable {
    let id = UUID()
    let template: TaskTemplate
    let taskCount: Int
    let analytics: TemplateManager.TemplateAnalytics

    var isUsed: Bool {
        taskCount > 0
    }

    var hasProductivity: Bool {
        analytics.hasHistoricalData
    }
}

// MARK: - Overview Card

private struct OverviewCard: View {
    let statistics: TemplateManager.TemplateStatistics

    var body: some View {
        VStack(spacing: 0) {
            // Total Templates
            StatisticRow(
                icon: "doc.text.fill",
                iconColor: .blue,
                label: "Total Templates",
                value: "\(statistics.totalTemplates)"
            )

            Divider()
                .padding(.leading, 56)

            // Used Templates
            StatisticRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                label: "In Use",
                value: "\(statistics.usedTemplates)"
            )

            Divider()
                .padding(.leading, 56)

            // Unused Templates
            StatisticRow(
                icon: "circle",
                iconColor: .orange,
                label: "Unused",
                value: "\(statistics.unusedTemplates)"
            )

            // Usage Percentage
            if statistics.totalTemplates > 0 {
                Divider()
                    .padding(.leading, 56)

                HStack(spacing: 16) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.purple)
                        .font(.title2)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Usage Rate")
                                .font(.body)
                            Spacer()
                            Text("\(Int((Double(statistics.usedTemplates) / Double(statistics.totalTemplates)) * 100))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)

                                Rectangle()
                                    .fill(Color.purple)
                                    .frame(
                                        width: geometry.size.width * (Double(statistics.usedTemplates) / Double(statistics.totalTemplates)),
                                        height: 8
                                    )
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Statistic Row

private struct StatisticRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.title2)
                .frame(width: 40)

            Text(label)
                .font(.body)

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Template Usage Row

private struct TemplateUsageRow: View {
    let data: TemplateUsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: data.template.unitIcon)
                    .foregroundStyle(data.isUsed ? .blue : .secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.template.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(data.template.unitDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(data.taskCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(data.isUsed ? .primary : .secondary)

                    Text(data.taskCount == 1 ? "task" : "tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Productivity info
            if data.hasProductivity, let productivity = data.analytics.formattedProductivity {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                    Text("Avg: \(productivity)")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Top Performers Card

private struct TopPerformersCard: View {
    let data: [TemplateUsageData]

    private var topThree: [TemplateUsageData] {
        Array(data.filter { $0.isUsed }.prefix(3))
    }

    var body: some View {
        if topThree.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("No templates have been used yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(Array(topThree.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        // Rank
                        ZStack {
                            Circle()
                                .fill(rankColor(index))
                                .frame(width: 32, height: 32)

                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        // Template info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.template.name)
                                .font(.body)
                                .fontWeight(.medium)

                            if item.hasProductivity, let productivity = item.analytics.formattedProductivity {
                                Text(productivity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Task count
                        Text("\(item.taskCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    if index < topThree.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, Task.self, configurations: config)

    // Insert templates
    for template in TaskTemplate.defaultTemplates {
        container.mainContext.insert(template)
    }

    // Create some tasks
    let carpet = TaskTemplate.defaultTemplates[0]
    for i in 0..<5 {
        let task = Task(
            title: "Carpet Task \(i)",
            completedDate: Date(),
            quantity: 35.0,
            unit: .squareMeters,
            taskTemplate: carpet
        )
        container.mainContext.insert(task)
    }

    return TemplateStatisticsView()
        .modelContainer(container)
}

#Preview("Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, Task.self, configurations: config)

    return TemplateStatisticsView()
        .modelContainer(container)
}
