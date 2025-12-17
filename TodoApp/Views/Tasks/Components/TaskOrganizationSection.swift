import SwiftUI
import SwiftData

/// Organization section content for TaskDetailView
/// Shows project assignment and priority
struct TaskOrganizationSection: View {
    @Bindable var task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Project (conditional)
            if let project = task.project {
                projectRow(project: project)
            }

            // Priority (always shown)
            priorityRow
        }
        .padding(.horizontal)
    }

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(project: Project) -> some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.body)
                    .foregroundStyle(Color(hex: project.color))
                    .frame(width: 28)

                Text("Project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(project.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Priority Row

    private var priorityRow: some View {
        Menu {
            ForEach([Priority.urgent, .high, .medium, .low], id: \.self) { priority in
                Button {
                    task.priority = priority.rawValue
                    HapticManager.selection()
                } label: {
                    Label(priority.label, systemImage: priority.icon)
                }
            }
        } label: {
            HStack {
                Image(systemName: Priority(rawValue: task.priority)?.icon ?? "")
                    .font(.body)
                    .foregroundStyle(Priority(rawValue: task.priority)?.color ?? .gray)
                    .frame(width: 28)

                Text("Priority")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Priority(rawValue: task.priority)?.label ?? "Medium")
                    .font(.subheadline)
                    .foregroundStyle(Priority(rawValue: task.priority)?.color ?? .gray)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Badge Helper

extension TaskOrganizationSection {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        let priority = Priority(rawValue: task.priority) ?? .medium
        let priorityText = priority == .medium ? "" : priority.label

        if let project = task.project {
            if priorityText.isEmpty {
                return project.title
            } else {
                return "\(project.title) • \(priorityText)"
            }
        } else {
            return priorityText.isEmpty ? "No project" : priorityText
        }
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        let priority = Priority(rawValue: task.priority) ?? .medium
        if priority == .urgent || priority == .high {
            return priority.color
        }
        return .secondary
    }
}

// MARK: - Preview

#Preview("With Project") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)

    let project = Project(title: "Event Setup", color: "#FF6B6B")
    let task = Task(title: "Install Carpet")
    task.project = project
    task.priority = Priority.high.rawValue

    container.mainContext.insert(project)
    container.mainContext.insert(task)

    return TaskOrganizationSection(task: task)
        .padding()
}

#Preview("No Project") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install Carpet")
    task.priority = Priority.urgent.rawValue

    container.mainContext.insert(task)

    return TaskOrganizationSection(task: task)
        .padding()
}
