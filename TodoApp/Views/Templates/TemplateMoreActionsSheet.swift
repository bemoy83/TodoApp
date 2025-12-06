import SwiftUI

/// Bottom sheet for template import/export actions
struct TemplateMoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let hasTemplates: Bool
    let onExport: () -> Void
    let onImport: () -> Void
    let onManageUnits: () -> Void

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
    TemplateMoreActionsSheet(
        hasTemplates: true,
        onExport: { print("Export") },
        onImport: { print("Import") },
        onManageUnits: { print("Manage Units") }
    )
}
