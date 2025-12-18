import SwiftUI
import SwiftData

/// Organization section content for TaskDetailView
/// Shows project assignment and priority
struct TaskOrganizationSection: View {
    @Bindable var task: Task

    @State private var showingProjectPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Project row (with inline editing)
            projectSection

            // Priority (always shown, inline editable via Menu)
            priorityRow
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingProjectPicker) {
            ProjectPickerSheet(task: task)
        }
    }

    // MARK: - Project Section

    @ViewBuilder
    private var projectSection: some View {
        if let project = task.project {
            // Has project - show with options to view or change
            HStack(spacing: 0) {
                // Navigate to project detail
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
            .contextMenu {
                Button {
                    showingProjectPicker = true
                } label: {
                    Label("Change Project", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    task.project = nil
                    HapticManager.medium()
                } label: {
                    Label("Remove from Project", systemImage: "folder.badge.minus")
                }
            }
        } else {
            // No project - show add button
            Button {
                showingProjectPicker = true
                HapticManager.selection()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 28)

                    Text("Assign to Project")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)

                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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

// MARK: - Project Picker Sheet

private struct ProjectPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.title) private var projects: [Project]

    let task: Task

    var body: some View {
        NavigationStack {
            List {
                // No Project option
                Button {
                    task.project = nil
                    saveAndDismiss()
                } label: {
                    HStack {
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        Text("No Project")
                            .foregroundStyle(.primary)

                        Spacer()

                        if task.project == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Project list
                ForEach(projects) { project in
                    Button {
                        task.project = project
                        saveAndDismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 12, height: 12)

                            Text(project.title)
                                .foregroundStyle(.primary)

                            Spacer()

                            if task.project?.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Assign to Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
            HapticManager.success()
        } catch {
            HapticManager.error()
        }
        dismiss()
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
