import SwiftUI
import SwiftData

/// View for resolving template import conflicts
struct TemplateImportConflictView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let preview: TemplateImporter.ImportPreview
    @State private var conflicts: [TemplateImporter.TemplateConflict]
    let onComplete: (TemplateImporter.ImportResult) -> Void

    @State private var isImporting = false

    init(
        preview: TemplateImporter.ImportPreview,
        onComplete: @escaping (TemplateImporter.ImportResult) -> Void
    ) {
        self.preview = preview
        self._conflicts = State(initialValue: preview.conflicts)
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                summaryHeader

                // Content
                if preview.hasConflicts {
                    conflictList
                } else {
                    noConflictsView
                }
            }
            .navigationTitle("Import Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        executeImport()
                    }
                    .disabled(isImporting)
                }
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Total count
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(DesignSystem.Colors.info)
                Text("\(preview.totalCount) template\(preview.totalCount == 1 ? "" : "s") found")
                    .font(.headline)
            }

            // Breakdown
            HStack(spacing: DesignSystem.Spacing.lg) {
                if preview.newTemplates.count > 0 {
                    Label("\(preview.newTemplates.count) new", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.success)
                }

                if preview.conflicts.count > 0 {
                    Label("\(preview.conflicts.count) conflict\(preview.conflicts.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.warning)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - No Conflicts View

    private var noConflictsView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.success)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Ready to Import")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("All templates are new and can be imported without conflicts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conflict List

    private var conflictList: some View {
        List {
            Section {
                Text("Choose how to handle duplicate templates")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(conflicts.indices, id: \.self) { index in
                ConflictRow(
                    conflict: conflicts[index],
                    strategy: conflicts[index].strategy,
                    onStrategyChange: { newStrategy in
                        conflicts[index].strategy = newStrategy
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func executeImport() {
        isImporting = true

        // Execute import
        let result = TemplateImporter.executeImport(
            preview: preview,
            conflicts: conflicts,
            context: modelContext
        )

        // Notify completion
        onComplete(result)

        // Dismiss
        dismiss()
    }
}

// MARK: - Conflict Row

private struct ConflictRow: View {
    let conflict: TemplateImporter.TemplateConflict
    let strategy: TemplateImporter.ConflictStrategy
    let onStrategyChange: (TemplateImporter.ConflictStrategy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Template info
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignSystem.Colors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.importedTemplate.name)
                        .font(.headline)

                    Text(unitDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Strategy picker
            Picker("Action", selection: Binding(
                get: { strategy },
                set: { onStrategyChange($0) }
            )) {
                Label("Skip", systemImage: "xmark.circle")
                    .tag(TemplateImporter.ConflictStrategy.skip)

                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    .tag(TemplateImporter.ConflictStrategy.replace)

                Label("Keep Both", systemImage: "plus.circle")
                    .tag(TemplateImporter.ConflictStrategy.keepBoth)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var unitDisplayName: String {
        if let customUnit = conflict.importedTemplate.customUnit {
            return customUnit.name
        } else {
            return conflict.importedTemplate.defaultUnit
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, CustomUnit.self, configurations: config)

    // Create existing template
    let existingTemplate = TaskTemplate(
        name: "Carpet Installation",
        defaultUnit: .squareMeters,
        order: 0
    )
    container.mainContext.insert(existingTemplate)

    // Create mock preview with conflicts
    let importedTemplate = TemplateExporter.ExportableTemplate(
        name: "Carpet Installation",
        defaultUnit: "m²",
        defaultProductivityRate: 12.0,
        minQuantity: 5,
        maxQuantity: 5000,
        customUnit: nil
    )

    let conflict = TemplateImporter.TemplateConflict(
        importedTemplate: importedTemplate,
        existingTemplate: existingTemplate
    )

    let preview = TemplateImporter.ImportPreview(
        templates: [importedTemplate],
        conflicts: [conflict],
        newTemplates: []
    )

    return TemplateImportConflictView(preview: preview) { result in
        print("Import completed: \(result.message)")
    }
    .modelContainer(container)
}
