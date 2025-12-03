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
    @State private var defaultProductivityRate: String
    @State private var minQuantity: String
    @State private var maxQuantity: String
    @State private var showDuplicateAlert = false

    init(template: TaskTemplate?) {
        self.template = template

        // Initialize state from template or defaults
        _name = State(initialValue: template?.name ?? "")
        _defaultUnit = State(initialValue: template?.defaultUnit ?? .none)

        // Initialize productivity rate as string for TextField
        if let rate = template?.defaultProductivityRate {
            _defaultProductivityRate = State(initialValue: String(format: "%.1f", rate))
        } else {
            _defaultProductivityRate = State(initialValue: "")
        }

        // Initialize quantity limits as strings for TextField
        if let min = template?.minQuantity {
            _minQuantity = State(initialValue: String(format: "%.0f", min))
        } else {
            _minQuantity = State(initialValue: "")
        }

        if let max = template?.maxQuantity {
            _maxQuantity = State(initialValue: String(format: "%.0f", max))
        } else {
            _maxQuantity = State(initialValue: "")
        }
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

                // Expected Productivity Rate (only for quantifiable units)
                if defaultUnit.isQuantifiable {
                    Section {
                        HStack {
                            TextField("e.g., 10.0", text: $defaultProductivityRate)
                                .keyboardType(.decimalPad)

                            Text("\(defaultUnit.displayName)/person-hr")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Expected Productivity Rate")
                    } footer: {
                        Text("Optional. Set your expected productivity rate. This will be used until you build historical data from completed tasks. Leave empty to use system default.")
                    }

                    // Quantity Limits (only for quantifiable units)
                    Section {
                        HStack {
                            Text("Min")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)

                            TextField("e.g., 1", text: $minQuantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)

                            Text(defaultUnit.displayName)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Max")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)

                            TextField("e.g., 1000", text: $maxQuantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)

                            Text(defaultUnit.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Quantity Limits")
                    } footer: {
                        Text("Optional. Set realistic minimum and maximum quantity bounds for this task type. Helps catch data entry errors and guides users with meaningful validation messages.")
                    }
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

        // Parse productivity rate (optional)
        let productivityRate: Double? = {
            let trimmed = defaultProductivityRate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
                return nil
            }
            return value
        }()

        // Parse min quantity (optional)
        let parsedMinQuantity: Double? = {
            let trimmed = minQuantity.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
                return nil
            }
            return value
        }()

        // Parse max quantity (optional)
        let parsedMaxQuantity: Double? = {
            let trimmed = maxQuantity.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
                return nil
            }
            return value
        }()

        if let existing = template {
            // Update existing template
            existing.name = trimmedName
            existing.defaultUnit = defaultUnit
            existing.defaultProductivityRate = productivityRate
            existing.minQuantity = parsedMinQuantity
            existing.maxQuantity = parsedMaxQuantity
        } else {
            // Create new template
            let newTemplate = TaskTemplate(
                name: trimmedName,
                defaultUnit: defaultUnit,
                defaultProductivityRate: productivityRate,
                minQuantity: parsedMinQuantity,
                maxQuantity: parsedMaxQuantity
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
