import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Management view for task templates
struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query private var allTasks: [Task]

    @State private var showingAddTemplate = false
    @State private var editingTemplate: TaskTemplate?

    // Import/Export states
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var showingConflictResolution = false
    @State private var importPreview: TemplateImporter.ImportPreview?
    @State private var importResult: TemplateImporter.ImportResult?
    @State private var showingResultAlert = false
    @State private var exportError: Error?

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

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            showingExportPicker = true
                        } label: {
                            Label("Export Templates", systemImage: "square.and.arrow.up")
                        }
                        .disabled(templates.isEmpty)

                        Button {
                            showingImportPicker = true
                        } label: {
                            Label("Import Templates", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateFormView(template: nil)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateFormView(template: template)
            }
            .sheet(isPresented: $showingConflictResolution) {
                if let preview = importPreview {
                    TemplateImportConflictView(preview: preview) { result in
                        importResult = result
                        showingResultAlert = true
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExportPicker,
                document: TemplateExportDocument(templates: templates),
                contentType: .json,
                defaultFilename: TemplateExporter.suggestedFilename()
            ) { result in
                handleExportResult(result)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json, UTType(filenameExtension: "todotemplate") ?? .json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Result", isPresented: $showingResultAlert) {
                Button("OK") {
                    importResult = nil
                }
            } message: {
                if let result = importResult {
                    Text(result.message)
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error.localizedDescription)
                }
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

                Button {
                    showingImportPicker = true
                } label: {
                    Text("Import Templates")
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

    // MARK: - Import/Export Handlers

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            HapticManager.success()
        case .failure(let error):
            exportError = error
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Request access to security-scoped resource (required for file picker on iOS)
            guard url.startAccessingSecurityScopedResource() else {
                importResult = TemplateImporter.ImportResult(
                    imported: 0,
                    skipped: 0,
                    replaced: 0,
                    errors: ["Failed to access file. Please try again."]
                )
                showingResultAlert = true
                return
            }

            // Ensure we stop accessing when done
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                // Preview import and check for conflicts
                let preview = try TemplateImporter.previewImport(from: url, context: modelContext)

                if preview.hasConflicts {
                    // Show conflict resolution UI
                    importPreview = preview
                    showingConflictResolution = true
                } else {
                    // No conflicts - import directly
                    let result = TemplateImporter.executeImport(
                        preview: preview,
                        conflicts: [],
                        context: modelContext
                    )
                    importResult = result
                    showingResultAlert = true

                    if result.success {
                        HapticManager.success()
                    }
                }
            } catch {
                importResult = TemplateImporter.ImportResult(
                    imported: 0,
                    skipped: 0,
                    replaced: 0,
                    errors: [error.localizedDescription]
                )
                showingResultAlert = true
            }

        case .failure(let error):
            importResult = TemplateImporter.ImportResult(
                imported: 0,
                skipped: 0,
                replaced: 0,
                errors: [error.localizedDescription]
            )
            showingResultAlert = true
        }
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
                Image(systemName: template.unitIcon)
                    .font(.title2)
                    .foregroundStyle(template.isQuantifiable ? DesignSystem.Colors.info : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // Template name with unit
                    Text("\(template.name) (\(template.unitDisplayName))")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Expected productivity rate (if set)
                    if let expectedRate = template.defaultProductivityRate {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text("Expected: \(String(format: "%.1f", expectedRate)) \(template.unitDisplayName)/person-hr")
                                .font(.caption)
                        }
                        .foregroundStyle(DesignSystem.Colors.info)
                        .padding(.top, 2)
                    }

                    // Historical productivity (tracked average)
                    if let productivity = analytics.formattedProductivity {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text("Tracked: \(productivity)")
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
