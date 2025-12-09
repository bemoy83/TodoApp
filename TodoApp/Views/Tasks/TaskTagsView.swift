import SwiftUI
import SwiftData

/// Interactive tags view for task organization and filtering
struct TaskTagsView: View {
    @Bindable var task: Task
    @Query(sort: \Tag.order) private var allTags: [Tag]

    @State private var showingTagPicker = false

    // Get task tags using @Query pattern for fresh data
    private var taskTags: [Tag] {
        guard let taskTagIds = task.tags?.map({ $0.id }) else { return [] }
        return allTags.filter { taskTagIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header
            Text("Tags")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if !taskTags.isEmpty {
                    // Display current tags
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // Tags flow layout
                        FlowLayout(spacing: 8) {
                            ForEach(taskTags) { tag in
                                TagBadge(tag: tag)
                            }
                        }
                        .padding(.horizontal)

                        Divider()
                            .padding(.horizontal)
                    }
                } else {
                    // Empty state
                    HStack {
                        Image(systemName: "tag")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No tags")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Add tags to organize and filter tasks")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Action button
                Button {
                    showingTagPicker = true
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: buttonIcon)
                            .font(.body)
                            .foregroundStyle(.blue)

                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(task: task)
        }
    }

    // MARK: - Helper Properties

    private var buttonText: String {
        if taskTags.isEmpty {
            return "Add Tags"
        } else {
            return "Edit Tags"
        }
    }

    private var buttonIcon: String {
        if taskTags.isEmpty {
            return "plus.circle.fill"
        } else {
            return "pencil.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview("With Tags") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Tag.self, configurations: config)

    let carpetTag = Tag(name: "Carpet", icon: "square.grid.2x2", color: "blue", category: .resource)
    let setupTag = Tag(name: "Setup", icon: "wrench.and.screwdriver", color: "green", category: .phase)
    let hallATag = Tag(name: "Hall A", icon: "building.fill", color: "cyan", category: .location)

    let task = Task(title: "Install carpet")
    task.tags = [carpetTag, setupTag, hallATag]

    container.mainContext.insert(carpetTag)
    container.mainContext.insert(setupTag)
    container.mainContext.insert(hallATag)
    container.mainContext.insert(task)

    return TaskTagsView(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("No Tags") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Tag.self, configurations: config)

    let task = Task(title: "Install carpet")
    container.mainContext.insert(task)

    return TaskTagsView(task: task)
        .modelContainer(container)
        .padding()
}
