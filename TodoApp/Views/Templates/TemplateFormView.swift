import SwiftUI
import SwiftData

/// Form for creating or editing task templates
struct TemplateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TaskTemplate.order) private var existingTemplates: [TaskTemplate]
    @Query(sort: \CustomUnit.order) private var availableUnits: [CustomUnit]

    let template: TaskTemplate? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var selectedUnit: CustomUnit?
    @State private var defaultProductivityRate: String
    @State private var minQuantity: String
    @State private var maxQuantity: String
    @State private var showDuplicateAlert = false

    init(template: TaskTemplate?) {
        self.template = template

        // Initialize state from template or defaults
        _name = State(initialValue: template?.name ?? "")
        _selectedUnit = State(initialValue: template?.customUnit)

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
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selectedUnit != nil
    }

    /// Check if a template with this name + unit combination already exists
    private func isDuplicate(name: String, unit: CustomUnit) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        return existingTemplates.contains { existing in
            // Skip the template we're currently editing
            if let currentTemplate = template, existing.id == currentTemplate.id {
                return false
            }

            // Check for exact name + unit match
            return existing.name.lowercased() == trimmedName.lowercased() &&
                   existing.customUnit?.id == unit.id
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
                    if availableUnits.isEmpty {
                        Text("No units available")
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            UnitsListView()
                        } label: {
                            Label("Create Units", systemImage: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Picker("Unit Type", selection: $selectedUnit) {
                            ForEach(availableUnits) { unit in
                                HStack {
                                    Image(systemName: unit.icon)
                                    Text(unit.name)
                                }
                                .tag(unit as CustomUnit?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Unit")
                } footer: {
                    if availableUnits.isEmpty {
                        Text("No units found. System units should have been seeded automatically. Go to Settings → Custom Units to create units.")
                    } else {
                        Text("The unit of measurement for quantity tracking. Each name + unit combination must be unique. Create custom units in Settings → Custom Units.")
                    }
                }
                .onAppear {
                    print("🔍 TemplateFormView: Available units count: \(availableUnits.count)")
                    for unit in availableUnits {
                        print("  - \(unit.name) (\(unit.isSystem ? "system" : "custom"))")
                    }
                }

                // Expected Productivity Rate (only for quantifiable units)
                if selectedUnit?.isQuantifiable == true {
                    Section {
                        HStack {
                            TextField("e.g., 10.0", text: $defaultProductivityRate)
                                .keyboardType(.decimalPad)

                            Text("\(selectedUnit?.name ?? "unit")/person-hr")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Expected Productivity Rate")
                    } footer: {
                        Text("Optional. Set your expected productivity rate. This will be used until you build historical data from completed tasks.")
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

                            Text(selectedUnit?.name ?? "unit")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Max")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .leading)

                            TextField("e.g., 1000", text: $maxQuantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)

                            Text(selectedUnit?.name ?? "unit")
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
                Text("A template with the name \"\(name)\" and unit \"\(selectedUnit?.name ?? "")\" already exists. Each template must have a unique name + unit combination for accurate productivity tracking.")
            }
        }
    }

    // MARK: - Actions

    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let unit = selectedUnit else { return }

        // Check for duplicate name + unit combination
        if isDuplicate(name: trimmedName, unit: unit) {
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
            existing.customUnit = unit
            // Keep defaultUnit for backward compatibility (set to .none as placeholder)
            existing.defaultUnit = .none
            existing.defaultProductivityRate = productivityRate
            existing.minQuantity = parsedMinQuantity
            existing.maxQuantity = parsedMaxQuantity
        } else {
            // Create new template
            let newTemplate = TaskTemplate(
                name: trimmedName,
                defaultUnit: .none, // Legacy field, set placeholder
                defaultProductivityRate: productivityRate,
                minQuantity: parsedMinQuantity,
                maxQuantity: parsedMaxQuantity,
                customUnit: unit
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
