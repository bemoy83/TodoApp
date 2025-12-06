import SwiftUI

/// Bottom sheet for template import/export actions
struct TemplateMoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let hasTemplates: Bool
    let statistics: TemplateManager.TemplateStatistics
    let onExport: () -> Void
    let onImport: () -> Void
    let onManageUnits: () -> Void
    let onViewStatistics: () -> Void
    let onRestoreDefaults: () -> Void
    let onDeleteUnused: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("File Actions") {
                    // Export Templates
                    Button {
                        dismiss()
                        onExport()
                    } label: {
                        Label("Export Templates", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!hasTemplates)
                    .accessibilityLabel("Export Templates")

                    // Import Templates
                    Button {
                        dismiss()
                        onImport()
                    } label: {
                        Label("Import Templates", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Templates")
                }

                Section("Management") {
                    // Manage Custom Units
                    Button {
                        dismiss()
                        onManageUnits()
                    } label: {
                        Label("Manage Custom Units", systemImage: "ruler")
                    }
                    .accessibilityLabel("Manage Custom Units")

                    // View Template Statistics
                    Button {
                        dismiss()
                        onViewStatistics()
                    } label: {
                        Label("View Template Statistics", systemImage: "chart.bar.fill")
                    }
                    .disabled(!hasTemplates)
                    .accessibilityLabel("View Template Statistics")
                }

                Section("Quick Actions") {
                    // Restore Default Templates
                    Button {
                        dismiss()
                        onRestoreDefaults()
                    } label: {
                        Label("Restore Default Templates", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Restore Default Templates")
                }

                // Destructive Actions
                if hasTemplates {
                    Section {
                        // Delete Unused Templates
                        Button(role: .destructive) {
                            dismiss()
                            onDeleteUnused()
                        } label: {
                            HStack {
                                Label("Delete Unused Templates", systemImage: "trash")
                                Spacer()
                                if statistics.hasUnusedTemplates {
                                    Text("\(statistics.unusedTemplates)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .disabled(!statistics.hasUnusedTemplates)
                        .accessibilityLabel("Delete Unused Templates")

                        // Clear All Templates
                        Button(role: .destructive) {
                            dismiss()
                            onClearAll()
                        } label: {
                            Label("Clear All Templates", systemImage: "trash.fill")
                        }
                        .accessibilityLabel("Clear All Templates")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    let stats = TemplateManager.TemplateStatistics(
        totalTemplates: 10,
        usedTemplates: 7,
        unusedTemplates: 3
    )

    return TemplateMoreActionsSheet(
        hasTemplates: true,
        statistics: stats,
        onExport: { print("Export") },
        onImport: { print("Import") },
        onManageUnits: { print("Manage Units") },
        onViewStatistics: { print("View Statistics") },
        onRestoreDefaults: { print("Restore Defaults") },
        onDeleteUnused: { print("Delete Unused") },
        onClearAll: { print("Clear All") }
    )
}
