import SwiftUI
import SwiftData

/// Breadcrumb navigation link to parent task (shown only for subtasks)
struct TaskParentBreadcrumb: View {
    let parentTask: Task

    var body: some View {
        NavigationLink(destination: TaskDetailView(task: parentTask)) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Subtask of")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "arrow.turn.up.left")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Text(parentTask.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .detailCardStyle()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let parent = Task(title: "Main Event Setup")
    let subtask = Task(title: "Install Carpet Tiles")
    subtask.parentTask = parent

    container.mainContext.insert(parent)
    container.mainContext.insert(subtask)

    return TaskParentBreadcrumb(parentTask: parent)
        .padding()
}
