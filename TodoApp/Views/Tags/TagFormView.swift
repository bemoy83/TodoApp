import SwiftUI
import SwiftData

/// Form for creating or editing tags
struct TagFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tag: Tag? // nil = creating new, non-nil = editing

    @State private var name: String
    @State private var icon: String
    @State private var color: String
    @State private var category: TagCategory
    @State private var showingIconPicker = false

    // Color options for tags
    private let colorOptions: [(name: String, value: String)] = [
        ("Blue", "blue"),
        ("Purple", "purple"),
        ("Orange", "orange"),
        ("Yellow", "yellow"),
        ("Green", "green"),
        ("Red", "red"),
        ("Cyan", "cyan"),
        ("Teal", "teal"),
        ("Brown", "brown"),
        ("Indigo", "indigo")
    ]

    init(tag: Tag?) {
        self.tag = tag

        // Initialize state from tag or defaults
        _name = State(initialValue: tag?.name ?? "")
        _icon = State(initialValue: tag?.icon ?? "tag.fill")
        _color = State(initialValue: tag?.color ?? "blue")
        _category = State(initialValue: tag?.category ?? .custom)
    }

    private var isEditing: Bool {
        tag != nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Tag name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("E.g., \"Carpet\", \"Setup\", \"Hall A\"")
                }

                // Category Section
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(TagCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.displayName)
                            }
                            .tag(cat)
                        }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    Text("Organize tags by type")
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
                                .foregroundStyle(selectedColor)
                                .frame(width: 30, height: 30)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                // Color Section
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.value) { colorOption in
                                ColorCircle(
                                    colorName: colorOption.value,
                                    isSelected: color == colorOption.value,
                                    onTap: {
                                        color = colorOption.value
                                        HapticManager.light()
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Color")
                }

                // Preview Section
                Section {
                    HStack {
                        Text("Preview")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.caption2)
                            Text(name.isEmpty ? "Tag" : name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedColor.opacity(0.15))
                        .foregroundStyle(selectedColor)
                        .clipShape(Capsule())
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTag()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }

    // MARK: - Helpers

    private var selectedColor: Color {
        switch color {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "teal": return .teal
        case "brown": return .brown
        case "indigo": return .indigo
        default: return .gray
        }
    }

    // MARK: - Actions

    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = tag {
            // Update existing tag
            existing.name = trimmedName
            existing.icon = icon
            existing.color = color
            existing.category = category
        } else {
            // Create new tag
            let newTag = Tag(
                name: trimmedName,
                icon: icon,
                color: color,
                category: category,
                isSystem: false
            )
            modelContext.insert(newTag)
        }

        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Color Circle

private struct ColorCircle: View {
    let colorName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(displayColor)
                    .frame(width: 40, height: 40)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var displayColor: Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "teal": return .teal
        case "brown": return .brown
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("New Tag") {
    TagFormView(tag: nil)
        .modelContainer(for: [Tag.self], inMemory: true)
}
