import SwiftUI
import SwiftData

/// Template picker sheet for task creation
struct TemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query private var allTasks: [Task]

    let onSelect: (TaskTemplate) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyStateView
                } else {
                    templateList
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            Section {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 40)

                        Text("Blank Task")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Start From Scratch")
            }

            Section {
                ForEach(templates) { template in
                    Button {
                        onSelect(template)
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        TemplatePickerRow(
                            template: template,
                            analytics: TemplateManager.calculateAnalytics(
                                for: template,
                                from: allTasks
                            )
                        )
                    }
                }
            } header: {
                Text("Templates")
            }
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

                Text("Create templates in Settings to speed up task creation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Create Blank Task")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Template Picker Row

private struct TemplatePickerRow: View {
    let template: TaskTemplate
    let analytics: TemplateManager.TemplateAnalytics

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Unit icon
            Image(systemName: template.unitIcon)
                .font(.title3)
                .foregroundStyle(template.isQuantifiable ? DesignSystem.Colors.info : .secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                // Template name
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Quick stats
                Label(template.unitDisplayName, systemImage: template.unitIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Historical productivity hint
                if let productivity = analytics.formattedProductivity {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                        Text("Avg: \(productivity)")
                            .font(.caption2)
                    }
                    .foregroundStyle(DesignSystem.Colors.success)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("With Templates") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, Task.self, configurations: config)

    // Insert templates
    for template in TaskTemplate.defaultTemplates {
        container.mainContext.insert(template)
    }

    return TemplatePickerSheet(
        onSelect: { template in
            print("Selected: \(template.name)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, configurations: config)

    return TemplatePickerSheet(
        onSelect: { _ in },
        onCancel: {}
    )
    .modelContainer(container)
}
