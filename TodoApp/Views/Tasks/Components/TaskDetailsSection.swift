import SwiftUI
import SwiftData

/// Consolidated details section combining Tags, Notes, and Info
/// Part of the TaskDetailView mini-sections architecture
struct TaskDetailsSection: View {
    @Bindable var task: Task
    @Query(sort: \Tag.order) private var allTags: [Tag]

    @State private var showingTagPicker = false
    @State private var showingNotesEditor = false

    // Get task tags using @Query pattern for fresh data
    private var taskTags: [Tag] {
        guard let taskTagIds = task.tags?.map({ $0.id }) else { return [] }
        return allTags.filter { taskTagIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // MARK: - Tags Subsection
            tagsSubsection

            Divider()
                .padding(.horizontal)

            // MARK: - Notes Subsection
            notesSubsection

            Divider()
                .padding(.horizontal)

            // MARK: - Info Subsection
            infoSubsection
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(task: task)
        }
        .sheet(isPresented: $showingNotesEditor) {
            NotesEditorSheet(task: task)
        }
    }

    // MARK: - Tags Subsection

    @ViewBuilder
    private var tagsSubsection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Subsection header
            HStack {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()

                // Edit button
                Button {
                    showingTagPicker = true
                    HapticManager.selection()
                } label: {
                    Text(taskTags.isEmpty ? "Add" : "Edit")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Tags content
            if !taskTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(taskTags) { tag in
                        TagBadge(tag: tag)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No tags assigned")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Notes Subsection

    @ViewBuilder
    private var notesSubsection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Subsection header
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()

                // Edit button
                Button {
                    showingNotesEditor = true
                    HapticManager.selection()
                } label: {
                    Text(hasNotes ? "Edit" : "Add")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Notes content (tappable to edit)
            if let notes = task.notes, !notes.isEmpty {
                Button {
                    showingNotesEditor = true
                    HapticManager.selection()
                } label: {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                Button {
                    showingNotesEditor = true
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        Text("Add Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)

                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private var hasNotes: Bool {
        guard let notes = task.notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Info Subsection

    @ViewBuilder
    private var infoSubsection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Subsection header
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Info")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal)

            // Info content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Created date
                HStack {
                    Text("Created")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(task.createdDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Completed date (conditional)
                if let completedDate = task.completedDate {
                    HStack {
                        Text("Completed")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Spacer()
                        Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Notes Editor Sheet

private struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: Task

    @State private var editedNotes: String
    @FocusState private var isTextEditorFocused: Bool

    init(task: Task) {
        self.task = task
        self._editedNotes = State(initialValue: task.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $editedNotes)
                    .focused($isTextEditorFocused)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNotes()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTextEditorFocused = false
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasExistingNotes {
                    Button(role: .destructive) {
                        deleteNotes()
                    } label: {
                        Label("Delete Notes", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding()
                }
            }
            .onAppear {
                // Auto-focus the text editor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextEditorFocused = true
                }
            }
        }
    }

    private var hasExistingNotes: Bool {
        guard let notes = task.notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveNotes() {
        let trimmed = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = trimmed.isEmpty ? nil : trimmed

        do {
            try modelContext.save()
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
        dismiss()
    }

    private func deleteNotes() {
        task.notes = nil

        do {
            try modelContext.save()
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
        dismiss()
    }
}

// MARK: - Summary Badge Helper

extension TaskDetailsSection {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        var parts: [String] = []

        // Tags count
        let tagCount = task.tags?.count ?? 0
        if tagCount > 0 {
            parts.append("\(tagCount) \(tagCount == 1 ? "tag" : "tags")")
        }

        // Notes indicator
        if let notes = task.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Has notes")
        }

        // Created/Completed info
        if task.completedDate != nil {
            parts.append("Completed")
        } else {
            parts.append("Created \(relativeDate(task.createdDate))")
        }

        return parts.joined(separator: " • ")
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        if task.completedDate != nil {
            return .green
        }
        return .secondary
    }

    /// Formats date as relative string
    private static func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "today"
        }

        if calendar.isDateInYesterday(date) {
            return "yesterday"
        }

        let components = calendar.dateComponents([.day], from: date, to: now)
        if let days = components.day {
            if days > 0 && days < 7 {
                return "\(days)d ago"
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("With All Details") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Tag.self, configurations: config)

    let carpetTag = Tag(name: "Carpet", icon: "square.grid.2x2", color: "blue", category: .resource)
    let setupTag = Tag(name: "Setup", icon: "wrench.and.screwdriver", color: "green", category: .phase)

    let task = Task(title: "Install Carpet")
    task.tags = [carpetTag, setupTag]
    task.notes = "Remember to check the floor surface before installation."

    container.mainContext.insert(carpetTag)
    container.mainContext.insert(setupTag)
    container.mainContext.insert(task)

    return TaskDetailsSection(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("Minimal Details") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Tag.self, configurations: config)

    let task = Task(title: "Install Carpet")
    container.mainContext.insert(task)

    return TaskDetailsSection(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("Completed Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Tag.self, configurations: config)

    let task = Task(title: "Install Carpet")
    task.completedDate = Date()
    task.notes = "Finished ahead of schedule."

    container.mainContext.insert(task)

    return TaskDetailsSection(task: task)
        .modelContainer(container)
        .padding()
}
