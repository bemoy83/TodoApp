import SwiftUI
import SwiftData

/// Form for creating or editing custom units
struct UnitFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let unit: CustomUnit? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var icon: String
    @State private var isQuantifiable: Bool
    @State private var showingIconPicker = false

    init(unit: CustomUnit?) {
        self.unit = unit

        // Initialize state from unit or defaults
        _name = State(initialValue: unit?.name ?? "")
        _icon = State(initialValue: unit?.icon ?? "cube.box")
        _isQuantifiable = State(initialValue: unit?.isQuantifiable ?? true)
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

        if let existing = unit {
            // Update existing unit
            existing.name = trimmedName
            existing.icon = icon
            existing.isQuantifiable = isQuantifiable
        } else {
            // Create new unit
            let newUnit = CustomUnit(
                name: trimmedName,
                icon: icon,
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

    @State private var searchText = ""
    @State private var selectedCategory: IconCategory = .all

    private let columns = [
        GridItem(.adaptive(minimum: 60))
    ]

    enum IconCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case tools = "Tools"
        case materials = "Materials"
        case transport = "Transport"
        case shapes = "Shapes"
        case measurement = "Measurement"
        case misc = "Misc"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .all: return "🔄"
            case .tools: return "🔨"
            case .materials: return "📦"
            case .transport: return "🚚"
            case .shapes: return "⬡"
            case .measurement: return "📏"
            case .misc: return "📂"
            }
        }

        var icons: [String] {
            switch self {
            case .all:
                return IconCategory.allCases.filter { $0 != .all }.flatMap { $0.icons }
            case .tools:
                return [
                    "hammer", "hammer.fill", "wrench", "wrench.fill",
                    "screwdriver", "screwdriver.fill", "paintbrush", "paintbrush.fill",
                    "ladder", "toolbox", "toolbox.fill",
                    "scissors", "tray", "tray.fill"
                ]
            case .materials:
                return [
                    "cube", "cube.fill", "cube.box", "cube.box.fill",
                    "shippingbox", "shippingbox.fill", "box", "box.fill",
                    "bag", "bag.fill", "cart", "cart.fill",
                    "basket", "basket.fill", "archivebox", "archivebox.fill"
                ]
            case .transport:
                return [
                    "truck.box", "truck.box.fill", "car", "car.fill",
                    "bus", "bus.fill", "bicycle", "scooter",
                    "cart.fill.badge.plus", "cart.fill.badge.minus",
                    "shippingbox.circle", "shippingbox.circle.fill"
                ]
            case .shapes:
                return [
                    "circle", "circle.fill", "square", "square.fill",
                    "triangle", "triangle.fill", "diamond", "diamond.fill",
                    "hexagon", "hexagon.fill", "octagon", "octagon.fill",
                    "cylinder", "cylinder.fill", "cone", "cone.fill",
                    "pyramid", "pyramid.fill"
                ]
            case .measurement:
                return [
                    "ruler", "ruler.fill", "level", "level.fill",
                    "gauge", "gauge.with.dots.needle.bottom.50percent",
                    "scalemass", "scalemass.fill",
                    "thermometer", "thermometer.medium",
                    "drop", "drop.fill", "flame", "flame.fill",
                    "bolt", "bolt.fill", "leaf", "leaf.fill"
                ]
            case .misc:
                return [
                    "doc.text", "doc.text.fill", "folder", "folder.fill",
                    "square.grid.2x2", "square.grid.2x2.fill",
                    "square.grid.3x3", "square.grid.3x3.fill",
                    "building", "building.fill", "building.2", "building.2.fill",
                    "house", "house.fill", "person.2", "person.2.fill",
                    "person.3", "person.3.fill"
                ]
            }
        }
    }

    private var filteredIcons: [String] {
        let categoryIcons = selectedCategory.icons

        if searchText.isEmpty {
            return categoryIcons
        }

        return categoryIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search icons", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(IconCategory.allCases) { category in
                            CategoryPill(
                                category: category,
                                isSelected: selectedCategory == category,
                                onTap: {
                                    selectedCategory = category
                                    HapticManager.light()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Icon grid
                ScrollView {
                    if filteredIcons.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredIcons, id: \.self) { icon in
                                IconButton(
                                    icon: icon,
                                    isSelected: selectedIcon == icon,
                                    onTap: {
                                        selectedIcon = icon
                                        HapticManager.light()
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No icons found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: IconPickerView.IconCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.body)

                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.purple : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .purple)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.purple : Color.secondary.opacity(0.1))
                    )
            }
        }
        .buttonStyle(.plain)
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
        icon: "cart"
    )
    container.mainContext.insert(unit)

    return UnitFormView(unit: unit)
        .modelContainer(container)
}
