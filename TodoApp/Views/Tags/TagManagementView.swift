import SwiftUI
import SwiftData

/// List view for managing tags
struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.order) private var allTags: [Tag]
    @Query private var allTasks: [Task]

    @State private var showingAddTag = false
    @State private var tagToEdit: Tag?
    @State private var tagToDelete: Tag?
    @State private var showingDeleteAlert = false

    var showDismissButton: Bool = false

    var body: some View {
        List {
            // Group tags by category
            ForEach(TagCategory.allCases, id: \.self) { category in
                let categoryTags = tags(for: category)

                if !categoryTags.isEmpty {
                    Section {
                        ForEach(categoryTags) { tag in
                            TagRow(tag: tag, taskCount: taskCount(for: tag))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if !tag.isSystem {
                                        Button(role: .destructive) {
                                            tagToDelete = tag
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }

                                    Button {
                                        tagToEdit = tag
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button {
                                        tagToEdit = tag
                                    } label: {
                                        Label("Edit Tag", systemImage: "pencil")
                                    }

                                    if !tag.isSystem {
                                        Button(role: .destructive) {
                                            tagToDelete = tag
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete Tag", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                    } footer: {
                        if category == .custom {
                            Text("User-created tags for your specific needs")
                        }
                    }
                }
            }

            // Empty state
            if allTags.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No tags yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button {
                            showingAddTag = true
                        } label: {
                            Label("Create Tag", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if showDismissButton {
                    Button("Done") {
                        dismiss()
                    }
                }

                Button {
                    showingAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTag) {
            TagFormView(tag: nil)
        }
        .sheet(item: $tagToEdit) { tag in
            TagFormView(tag: tag)
        }
        .alert("Delete Tag?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTag(tag)
                }
            }
        } message: {
            if let tag = tagToDelete {
                let count = taskCount(for: tag)
                if count > 0 {
                    Text("This tag is used by \(count) task(s). Deleting it will remove the tag from those tasks.")
                } else {
                    Text("Are you sure you want to delete this tag? This action cannot be undone.")
                }
            }
        }
    }

    // MARK: - Computed Properties

    private func tags(for category: TagCategory) -> [Tag] {
        allTags
            .filter { $0.category == category }
            .sorted { $0.orderValue < $1.orderValue }
    }

    private func taskCount(for tag: Tag) -> Int {
        allTasks.filter { task in
            task.tags?.contains(where: { $0.id == tag.id }) ?? false
        }.count
    }

    // MARK: - Actions

    private func deleteTag(_ tag: Tag) {
        HapticManager.warning()
        modelContext.delete(tag)
        try? modelContext.save()
        HapticManager.success()
    }
}

// MARK: - Tag Row

private struct TagRow: View {
    let tag: Tag
    let taskCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Tag icon with color
            Image(systemName: tag.icon)
                .font(.title3)
                .foregroundStyle(tagColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)

                if taskCount > 0 {
                    Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Tag badge preview
            HStack(spacing: 4) {
                Image(systemName: tag.icon)
                    .font(.caption2)
                Text(tag.name)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagColor.opacity(0.15))
            .foregroundStyle(tagColor)
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
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

// MARK: - Preview

#Preview("Tag Management") {
    @Previewable @State var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Tag.self, Task.self, configurations: config)

        // Create sample tags
        let carpetTag = Tag(name: "Carpet", icon: "square.grid.2x2", color: "blue", category: .resource)
        let setupTag = Tag(name: "Setup", icon: "wrench.and.screwdriver", color: "green", category: .phase)
        let hallATag = Tag(name: "Hall A", icon: "building.fill", color: "cyan", category: .location)

        container.mainContext.insert(carpetTag)
        container.mainContext.insert(setupTag)
        container.mainContext.insert(hallATag)

        return container
    }()

    NavigationStack {
        TagManagementView()
            .modelContainer(container)
    }
}
