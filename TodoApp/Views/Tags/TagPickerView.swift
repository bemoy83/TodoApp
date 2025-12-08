import SwiftUI
import SwiftData

/// View for selecting multiple tags for a task
struct TagPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.order) private var allTags: [Tag]

    let task: Task?
    let externalBinding: Binding<Set<UUID>>?
    @State private var selectedTagIds: Set<UUID>
    @State private var searchText = ""
    @State private var showingNewTagForm = false
    @State private var selectedCategory: TagCategory?

    // Edit mode: bound to existing task
    init(task: Task) {
        self.task = task
        self.externalBinding = nil
        _selectedTagIds = State(initialValue: Set(task.tags?.map { $0.id } ?? []))
    }

    // Creation mode: bound to Set<UUID>
    init(selectedTagIds: Binding<Set<UUID>>) {
        self.task = nil
        self.externalBinding = selectedTagIds
        _selectedTagIds = State(initialValue: selectedTagIds.wrappedValue)
    }

    private var filteredTags: [Tag] {
        var tags = allTags

        // Filter by category if selected
        if let category = selectedCategory {
            tags = tags.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            tags = tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return tags
    }

    // Group tags by category for better organization
    private var tagsByCategory: [(category: TagCategory, tags: [Tag])] {
        let grouped = Dictionary(grouping: filteredTags) { $0.category }
        return TagCategory.allCases.compactMap { category in
            guard let tags = grouped[category], !tags.isEmpty else { return nil }
            return (category, tags.sorted { $0.orderValue < $1.orderValue })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search tags", text: $searchText)
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

                // Category filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "All" pill
                        CategoryPill(
                            category: nil,
                            isSelected: selectedCategory == nil,
                            onTap: {
                                selectedCategory = nil
                                HapticManager.light()
                            }
                        )

                        // Category pills
                        ForEach(TagCategory.allCases, id: \.self) { category in
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

                // Tag list
                if filteredTags.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(tagsByCategory, id: \.category) { categoryGroup in
                            Section {
                                ForEach(categoryGroup.tags) { tag in
                                    TagRow(
                                        tag: tag,
                                        isSelected: selectedTagIds.contains(tag.id),
                                        onToggle: {
                                            toggleTag(tag)
                                        }
                                    )
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: categoryGroup.category.icon)
                                    Text(categoryGroup.category.displayName)
                                }
                            }
                        }

                        // Create new tag button
                        Section {
                            Button {
                                showingNewTagForm = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text("Create New Tag")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveTags()
                    }
                }
            }
            .sheet(isPresented: $showingNewTagForm) {
                TagFormView(tag: nil)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No tags found")
                .font(.headline)
                .foregroundStyle(.secondary)

            if searchText.isEmpty {
                Button {
                    showingNewTagForm = true
                } label: {
                    Label("Create Tag", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            } else {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func toggleTag(_ tag: Tag) {
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else {
            selectedTagIds.insert(tag.id)
        }
        HapticManager.light()
    }

    private func saveTags() {
        if let task = task {
            // Edit mode: Update task tags
            let selectedTags = allTags.filter { selectedTagIds.contains($0.id) }
            task.tags = selectedTags
            try? modelContext.save()
        } else if let binding = externalBinding {
            // Creation mode: Update binding
            binding.wrappedValue = selectedTagIds
        }

        HapticManager.success()
        dismiss()
    }
}

// MARK: - Tag Row

private struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Tag badge
                HStack(spacing: 4) {
                    Image(systemName: tag.icon)
                        .font(.caption)
                    Text(tag.name)
                        .font(.body)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tagColor.opacity(0.15))
                .foregroundStyle(tagColor)
                .clipShape(Capsule())

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tagColor: Color {
        switch tag.color {
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
        case "pink": return .pink
        case "mint": return .mint
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: TagCategory?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category?.icon ?? "circle.grid.3x3")
                    .font(.caption)

                Text(category?.displayName ?? "All")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Tag.self, Task.self, configurations: config)

    // Create sample tags
    let carpetTag = Tag(name: "Carpet", icon: "square.grid.2x2", color: "blue", category: .resource)
    let setupTag = Tag(name: "Setup", icon: "wrench.and.screwdriver", color: "green", category: .phase)
    container.mainContext.insert(carpetTag)
    container.mainContext.insert(setupTag)

    // Create sample task
    let task = Task(title: "Install carpet")
    container.mainContext.insert(task)

    return TagPickerView(task: task)
        .modelContainer(container)
}
