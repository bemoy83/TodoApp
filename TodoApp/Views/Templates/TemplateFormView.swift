import SwiftUI
import SwiftData

/// Form for creating or editing task templates
struct TemplateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let template: TaskTemplate? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var taskType: String
    @State private var defaultUnit: UnitType
    @State private var hasEstimateDefault: Bool
    @State private var estimateHours: Int
    @State private var estimateMinutes: Int

    init(template: TaskTemplate?) {
        self.template = template

        // Initialize state from template or defaults
        _name = State(initialValue: template?.name ?? "")
        _taskType = State(initialValue: template?.taskType ?? "")
        _defaultUnit = State(initialValue: template?.defaultUnit ?? .none)

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
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !taskType.trimmingCharacters(in: .whitespaces).isEmpty
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

                // Task Type Section
                Section {
                    TextField("Task type", text: $taskType)
                } header: {
                    Text("Task Type")
                } footer: {
                    Text("Used to group productivity metrics (e.g., \"Carpet Installation\")")
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
        let trimmedTaskType = taskType.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty && !trimmedTaskType.isEmpty else { return }

        if let existing = template {
            // Update existing template
            existing.name = trimmedName
            existing.taskType = trimmedTaskType
            existing.defaultUnit = defaultUnit

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
                taskType: trimmedTaskType,
                defaultUnit: defaultUnit,
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
        taskType: "Carpet Installation",
        defaultUnit: .squareMeters,
        defaultEstimateSeconds: 7200 // 2 hours
    )
    container.mainContext.insert(template)

    return TemplateFormView(template: template)
        .modelContainer(container)
}
