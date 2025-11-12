import SwiftUI
import SwiftData

/// Form for creating or editing task templates
struct TemplateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let template: TaskTemplate? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var defaultUnit: UnitType
    @State private var hasPersonnelDefault: Bool
    @State private var defaultPersonnelCount: Int
    @State private var hasEstimateDefault: Bool
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int

    init(template: TaskTemplate?) {
        self.template = template

        // Initialize state from template or defaults
        _name = State(initialValue: template?.name ?? "")
        _defaultUnit = State(initialValue: template?.defaultUnit ?? .none)
        _hasPersonnelDefault = State(initialValue: template?.defaultPersonnelCount != nil)
        _defaultPersonnelCount = State(initialValue: template?.defaultPersonnelCount ?? 2)

        // Initialize estimate state
        let estimateSeconds = template?.defaultEstimateSeconds ?? 0
        let estimateMinutes = estimateSeconds / 60
        _hasEstimateDefault = State(initialValue: template?.defaultEstimateSeconds != nil)
        _estimateHours = State(initialValue: estimateMinutes / 60)
        _estimateMinutes = State(initialValue: estimateMinutes % 60)
    }

    private var isEditing: Bool {
        template != nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                    Text("The unit of measurement for quantity tracking")
                }

                // Personnel Section
                Section {
                    Toggle("Set default crew size", isOn: $hasPersonnelDefault)

                    if hasPersonnelDefault {
                        Stepper(value: $defaultPersonnelCount, in: 1...20) {
                            HStack {
                                Text("Crew size")
                                Spacer()
                                Text("\(defaultPersonnelCount) \(defaultPersonnelCount == 1 ? "person" : "people")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Personnel")
                } footer: {
                    Text("Expected crew size for this type of work")
                }

                // Time Estimate Section
                Section {
                    Toggle("Set default estimate", isOn: $hasEstimateDefault)

                    if hasEstimateDefault {
                        HStack {
                            Text("Hours")
                            Spacer()
                            Picker("Hours", selection: $estimateHours) {
                                ForEach(0..<100, id: \.self) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                        }

                        HStack {
                            Text("Minutes")
                            Spacer()
                            Picker("Minutes", selection: $estimateMinutes) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                        }
                    }
                } header: {
                    Text("Time Estimate")
                } footer: {
                    Text("Default time estimate for this type of task")
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
        }
    }

    // MARK: - Actions

    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = template {
            // Update existing template
            existing.name = trimmedName
            existing.defaultUnit = defaultUnit
            existing.defaultPersonnelCount = hasPersonnelDefault ? defaultPersonnelCount : nil

            if hasEstimateDefault {
                let totalMinutes = (estimateHours * 60) + estimateMinutes
                existing.defaultEstimateSeconds = totalMinutes * 60
            } else {
                existing.defaultEstimateSeconds = nil
            }
        } else {
            // Create new template
            let totalMinutes = (estimateHours * 60) + estimateMinutes
            let estimateSeconds = hasEstimateDefault ? totalMinutes * 60 : nil

            let newTemplate = TaskTemplate(
                name: trimmedName,
                defaultUnit: defaultUnit,
                defaultPersonnelCount: hasPersonnelDefault ? defaultPersonnelCount : nil,
                defaultEstimateSeconds: estimateSeconds
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
        defaultUnit: .squareMeters,
        defaultPersonnelCount: 2,
        defaultEstimateSeconds: 7200 // 2 hours
    )
    container.mainContext.insert(template)

    return TemplateFormView(template: template)
        .modelContainer(container)
}
