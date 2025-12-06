import SwiftUI
import SwiftData

// MARK: - Tag Filter Chip

struct TagFilterChip: View {
    let tag: Tag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.caption2)
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tagColor.opacity(0.2))
        .foregroundStyle(tagColor)
        .clipShape(Capsule())
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
        default: return .gray
        }
    }
}

// MARK: - Tag Filter Sheet

struct TagFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTagIds: Set<UUID>
    let allTags: [Tag]

    @State private var searchText = ""

    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { tag in
            tag.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group tags by category
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

                // Tag list
                if filteredTags.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(tagsByCategory, id: \.category) { categoryGroup in
                            Section {
                                ForEach(categoryGroup.tags) { tag in
                                    TagFilterRow(
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
                    }
                }
            }
            .navigationTitle("Filter by Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.success()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if !selectedTagIds.isEmpty {
                        Button {
                            selectedTagIds.removeAll()
                            HapticManager.light()
                        } label: {
                            Text("Clear All (\(selectedTagIds.count))")
                                .font(.subheadline)
                        }
                    }
                }
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

            if !searchText.isEmpty {
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
}

// MARK: - Tag Filter Row

private struct TagFilterRow: View {
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
        default: return .gray
        }
    }
}
