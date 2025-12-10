import SwiftUI
import SwiftData

/// List view for managing tags
struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
    @Query(sort: \Tag.order) private var allTags: [Tag]

    @State private var showingAddTag = false
    @State private var tagToEdit: Tag?
    @State private var tagToDelete: Tag?
    @State private var showingDeleteAlert = false
    @State private var showingRestoreAlert = false

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
                                    Button(role: .destructive) {
                                        tagToDelete = tag
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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

                                    Button(role: .destructive) {
                                        tagToDelete = tag
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete Tag", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove { indices, newOffset in
                            moveTag(in: category, from: indices, to: newOffset)
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
            ToolbarItem(placement: .cancellationAction) {
                if !allTags.isEmpty {
                    EditButton()
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        showingRestoreAlert = true
                    } label: {
                        Label("Restore System Tags", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

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
                if tag.isSystem {
                    if count > 0 {
                        Text("This is a system tag used by \(count) task(s). You can restore it later using 'Restore System Tags'.")
                    } else {
                        Text("This is a system tag. You can restore it later using 'Restore System Tags'.")
                    }
                } else {
                    if count > 0 {
                        Text("This tag is used by \(count) task(s). Deleting it will remove the tag from those tasks.")
                    } else {
                        Text("Are you sure you want to delete this tag? This action cannot be undone.")
                    }
                }
            }
        }
        .alert("Restore System Tags?", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                restoreSystemTags()
            }
        } message: {
            Text("This will restore any missing system tags for event management. Existing tags will not be affected.")
        }
    }

    // MARK: - Computed Properties

    private func tags(for category: TagCategory) -> [Tag] {
        allTags
            .filter { $0.category == category }
            .sorted { $0.orderValue < $1.orderValue }
    }

    private func taskCount(for tag: Tag) -> Int {
        // Use SwiftData relationship for O(1) access instead of O(n) iteration
        tag.tasks?.count ?? 0
    }

    // MARK: - Actions

    private func deleteTag(_ tag: Tag) {
        HapticManager.warning()
        modelContext.delete(tag)
        try? modelContext.save()
        HapticManager.success()
    }

    private func moveTag(in category: TagCategory, from source: IndexSet, to destination: Int) {
        // Get mutable copy of tags in this category
        var categoryTags = tags(for: category)

        // Perform the move
        categoryTags.move(fromOffsets: source, toOffset: destination)

        // Update order values to reflect new positions
        for (index, tag) in categoryTags.enumerated() {
            tag.order = index
        }

        // Save changes
        do {
            try modelContext.save()
            HapticManager.light()
        } catch {
            print("Error saving tag order: \(error)")
        }
    }

    private func restoreSystemTags() {
        // Get existing tag names
        let existingTagNames = Set(allTags.map { $0.name })

        // Find missing system tags
        let missingTags = Tag.systemTags.filter { !existingTagNames.contains($0.name) }

        guard !missingTags.isEmpty else {
            print("No missing system tags to restore")
            return
        }

        // Insert missing tags
        for systemTag in missingTags {
            let newTag = Tag(
                name: systemTag.name,
                icon: systemTag.icon,
                color: systemTag.color,
                category: systemTag.category,
                isSystem: true,
                order: systemTag.order
            )
            modelContext.insert(newTag)
        }

        // Save changes
        do {
            try modelContext.save()
            HapticManager.success()
            print("✅ Restored \(missingTags.count) system tag(s)")
        } catch {
            print("❌ Error restoring system tags: \(error)")
        }
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
        tag.colorValue
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
