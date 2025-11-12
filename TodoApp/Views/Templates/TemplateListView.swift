import SwiftUI
import SwiftData

/// Management view for task templates
struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query private var allTasks: [Task]

    @State private var showingAddTemplate = false
    @State private var editingTemplate: TaskTemplate?

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyStateView
                } else {
                    templateList
                }
            }
            .navigationTitle("Task Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateFormView(template: nil)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateFormView(template: template)
            }
        }
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                TemplateRow(
                    template: template,
                    analytics: TemplateManager.calculateAnalytics(
                        for: template,
                        from: allTasks
                    ),
                    onTap: {
                        editingTemplate = template
                    }
                )
            }
            .onDelete(perform: deleteTemplates)
            .onMove(perform: moveTemplates)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Templates")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create templates for common work types to speed up task creation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    showingAddTemplate = true
                } label: {
                    Label("Create Template", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    insertDefaultTemplates()
                } label: {
                    Text("Use Default Templates")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }

    private func moveTemplates(from source: IndexSet, to destination: Int) {
        var updatedTemplates = templates
        updatedTemplates.move(fromOffsets: source, toOffset: destination)

        // Update order values
        for (index, template) in updatedTemplates.enumerated() {
            template.order = index
        }

        try? modelContext.save()
    }

    private func insertDefaultTemplates() {
        TemplateManager.insertDefaultTemplates(into: modelContext)
        HapticManager.success()
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    let template: TaskTemplate
    let analytics: TemplateManager.TemplateAnalytics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Unit icon
                Image(systemName: template.defaultUnit.icon)
                    .font(.title2)
                    .foregroundStyle(template.defaultUnit.isQuantifiable ? DesignSystem.Colors.info : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // Template name
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Details
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Unit
                        Label(template.defaultUnit.displayName, systemImage: template.defaultUnit.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let personnel = template.defaultPersonnelCount {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Label("\(personnel) \(personnel == 1 ? "person" : "people")", systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Historical productivity
                    if let productivity = analytics.formattedProductivity {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text("Avg: \(productivity)")
                                .font(.caption)
                            Text("(\(analytics.historicalTaskCount) tasks)")
                                .font(.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.success)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("With Templates") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, Task.self, configurations: config)

    // Insert default templates
    for template in TaskTemplate.defaultTemplates {
        container.mainContext.insert(template)
    }

    // Create some sample completed tasks for historical data
    let carpetTask1 = Task(
        title: "Booth A12 Carpet",
        completedDate: Date().addingTimeInterval(-86400 * 5),
        quantity: 35.0,
        unit: .squareMeters
    )
    let carpetEntry1 = TimeEntry(
        startTime: carpetTask1.completedDate!.addingTimeInterval(-7200),
        endTime: carpetTask1.completedDate,
        personnelCount: 2,
        task: carpetTask1
    )
    container.mainContext.insert(carpetTask1)
    container.mainContext.insert(carpetEntry1)

    return TemplateListView()
        .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, configurations: config)

    return TemplateListView()
        .modelContainer(container)
}
