import SwiftUI
import SwiftData

/// Form for creating or editing task templates
struct TemplateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TaskTemplate.order) private var existingTemplates: [TaskTemplate]

    let template: TaskTemplate? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var defaultUnit: UnitType
    @State private var showDuplicateAlert = false

    init(template: TaskTemplate?) {
        self.template = template

        // Initialize state from template or defaults
        _name = State(initialValue: template?.name ?? "")
        _defaultUnit = State(initialValue: template?.defaultUnit ?? .none)
    }

    private var isEditing: Bool {
        template != nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if a template with this name + unit combination already exists
    private func isDuplicate(name: String, unit: UnitType) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        return existingTemplates.contains { existing in
            // Skip the template we're currently editing
            if let currentTemplate = template, existing.id == currentTemplate.id {
                return false
            }

            // Check for exact name + unit match
            return existing.name.lowercased() == trimmedName.lowercased() &&
                   existing.defaultUnit == unit
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Template name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("E.g., \"Carpet Installation\", \"Booth Wall Setup\"")
                }

                // Unit Section
                Section {
                    Picker("Unit Type", selection: $defaultUnit) {
                        ForEach(UnitType.allCases, id: \.self) { unit in
                            HStack {
                                Image(systemName: unit.icon)
                                Text(unit.displayName)
                            }
                            .tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Default Unit")
                } footer: {
                    Text("The unit of measurement for quantity tracking. Each name + unit combination must be unique for accurate productivity tracking.")
                }
            }
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTemplate()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Duplicate Template", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A template with the name \"\(name)\" and unit \"\(defaultUnit.displayName)\" already exists. Each template must have a unique name + unit combination for accurate productivity tracking.")
            }
        }
    }

    // MARK: - Actions

    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Check for duplicate name + unit combination
        if isDuplicate(name: trimmedName, unit: defaultUnit) {
            showDuplicateAlert = true
            HapticManager.error()
            return
        }

        if let existing = template {
            // Update existing template
            existing.name = trimmedName
            existing.defaultUnit = defaultUnit
        } else {
            // Create new template
            let newTemplate = TaskTemplate(
                name: trimmedName,
                defaultUnit: defaultUnit
            )
            modelContext.insert(newTemplate)
        }

        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview("New Template") {
    TemplateFormView(template: nil)
        .modelContainer(for: [TaskTemplate.self], inMemory: true)
}

#Preview("Edit Template") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskTemplate.self, configurations: config)

    let template = TaskTemplate(
        name: "Carpet Installation",
        defaultUnit: .squareMeters
    )
    container.mainContext.insert(template)

    return TemplateFormView(template: template)
        .modelContainer(container)
}
