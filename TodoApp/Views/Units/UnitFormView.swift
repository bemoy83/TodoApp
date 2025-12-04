import SwiftUI
import SwiftData

/// Form for creating or editing custom units
struct UnitFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let unit: CustomUnit? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var icon: String
    @State private var defaultProductivityRate: String
    @State private var isQuantifiable: Bool
    @State private var showingIconPicker = false

    init(unit: CustomUnit?) {
        self.unit = unit

        // Initialize state from unit or defaults
        _name = State(initialValue: unit?.name ?? "")
        _icon = State(initialValue: unit?.icon ?? "cube.box")
        _isQuantifiable = State(initialValue: unit?.isQuantifiable ?? true)

        // Initialize productivity rate as string for TextField
        if let rate = unit?.defaultProductivityRate {
            _defaultProductivityRate = State(initialValue: String(format: "%.1f", rate))
        } else {
            _defaultProductivityRate = State(initialValue: "")
        }
    }

    private var isEditing: Bool {
        unit != nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Unit name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("E.g., \"orders\", \"booths\", \"pallets\"")
                }

                // Icon Section
                Section {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 30, height: 30)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose an SF Symbol icon to represent this unit")
                }

                // Quantifiable Toggle
                Section {
                    Toggle("Requires Quantity", isOn: $isQuantifiable)
                } footer: {
                    Text("Enable if this unit requires quantity input (e.g., orders, pieces). Disable for time-only tasks.")
                }

                // Default Productivity Rate (only for quantifiable units)
                if isQuantifiable {
                    Section {
                        HStack {
                            TextField("e.g., 2.0", text: $defaultProductivityRate)
                                .keyboardType(.decimalPad)

                            Text("\(name.isEmpty ? "unit" : name)/person-hr")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Default Productivity Rate")
                    } footer: {
                        Text("Optional. Set a default productivity rate for templates using this unit.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Unit" : "New Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveUnit()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }

    // MARK: - Actions

    private func saveUnit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Parse productivity rate (optional)
        let productivityRate: Double? = {
            let trimmed = defaultProductivityRate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
                return nil
            }
            return value
        }()

        if let existing = unit {
            // Update existing unit
            existing.name = trimmedName
            existing.icon = icon
            existing.isQuantifiable = isQuantifiable
            existing.defaultProductivityRate = productivityRate
        } else {
            // Create new unit
            let newUnit = CustomUnit(
                name: trimmedName,
                icon: icon,
                defaultProductivityRate: productivityRate,
                isQuantifiable: isQuantifiable,
                isSystem: false
            )
            modelContext.insert(newUnit)
        }

        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Icon Picker

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    // Common SF Symbol icons suitable for units
    private let icons = [
        "cube.box", "shippingbox", "cart", "bag", "doc.text", "folder",
        "square.grid.2x2", "square.grid.3x3", "ruler", "scalemass",
        "drop", "flame", "bolt", "leaf", "circle", "square",
        "triangle", "diamond", "hexagon", "octagon", "cylinder",
        "building.2", "house", "person.2", "person.3"
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            HapticManager.light()
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundStyle(selectedIcon == icon ? .white : .purple)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedIcon == icon ? Color.purple : Color.secondary.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("New Unit") {
    UnitFormView(unit: nil)
        .modelContainer(for: [CustomUnit.self], inMemory: true)
}

#Preview("Edit Unit") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CustomUnit.self, configurations: config)

    let unit = CustomUnit(
        name: "orders",
        icon: "cart",
        defaultProductivityRate: 2.0
    )
    container.mainContext.insert(unit)

    return UnitFormView(unit: unit)
        .modelContainer(container)
}
