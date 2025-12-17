import SwiftUI
import SwiftData

/// Notes section content for TaskDetailView
/// Shows task notes with full text display
struct TaskNotesSection: View {
    @Bindable var task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptyState
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(width: 28)

            Text("No notes")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Summary Badge Helper

extension TaskNotesSection {
    /// Returns summary text for collapsed state (truncated preview)
    static func summaryText(for task: Task, maxLength: Int = 30) -> String {
        guard let notes = task.notes, !notes.isEmpty else {
            return "No notes"
        }

        // Clean up whitespace and truncate
        let cleanedNotes = notes
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        if cleanedNotes.count <= maxLength {
            return cleanedNotes
        } else {
            let truncated = String(cleanedNotes.prefix(maxLength))
            return truncated + "..."
        }
    }

    /// Returns whether task has notes
    static func hasNotes(_ task: Task) -> Bool {
        guard let notes = task.notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#Preview("With Notes") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install Carpet")
    task.notes = "Remember to check the floor surface before installation. Coordinate with electrical team to ensure all cables are properly covered. Extra padding may be needed near entrance areas."

    container.mainContext.insert(task)

    return TaskNotesSection(task: task)
        .padding()
}

#Preview("No Notes") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install Carpet")
    container.mainContext.insert(task)

    return TaskNotesSection(task: task)
        .padding()
}
