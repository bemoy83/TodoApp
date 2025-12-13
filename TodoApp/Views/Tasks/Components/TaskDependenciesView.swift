import SwiftUI
import SwiftData

struct TaskDependenciesView: View {
    @Bindable var task: Task

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @State private var showingDependencyPicker = false
    @AppStorage private var enableDependencies: Bool // Changed to @AppStorage

    // Use task ID as storage key for per-task persistence
    init(task: Task) {
        self.task = task
        self._enableDependencies = AppStorage(
            wrappedValue: false,
            "dependencies_enabled_\(task.id.uuidString)"
        )
    }
    
    var blockedByTasks: [Task] {
        TaskService.blockedByTasks(for: task, from: allTasks)
    }
    
    private var isSubtask: Bool {
        task.parentTask != nil
    }
    
    private var subtasksWithDependencies: [(subtask: Task, dependencies: [Task])] {
        guard let subtasks = task.subtasks else { return [] }
        
        return subtasks.compactMap { subtask in
            guard let deps = subtask.dependsOn, !deps.isEmpty else { return nil }
            return (subtask, deps.filter { !$0.isCompleted })
        }.filter { !$0.dependencies.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Toggle for subtasks (now persisted)
                if isSubtask {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Toggle("Enable Dependencies", isOn: $enableDependencies)
                            .font(.subheadline)
                            .tint(.blue)

                        if !enableDependencies {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Advanced feature - enable to add dependencies")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Show dependencies section if not a subtask OR toggle is enabled
                if !isSubtask || enableDependencies {
                    // Depends On Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("This task depends on")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        if let dependencies = task.dependsOn, !dependencies.isEmpty {
                            List {
                                ForEach(dependencies) { dependency in
                                    DependencyRow(
                                        dependency: dependency,
                                        onRemove: { removeDependency(dependency) }
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.Spacing.lg, bottom: 0, trailing: DesignSystem.Spacing.lg))
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(height: CGFloat(dependencies.count) * 52) // Approximate row height with padding

                            Divider()
                                .padding(.horizontal)
                        } else {
                            Text("No dependencies")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }

                        // Add button
                        Button {
                            showingDependencyPicker = true
                            HapticManager.selection()
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.blue)

                                Text("Add Dependency")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }

                    // Subtask Dependencies Section (only for parent tasks)
                    if !isSubtask && !subtasksWithDependencies.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Subtask Dependencies")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(subtasksWithDependencies, id: \.subtask.id) { item in
                                    SubtaskDependencyRow(
                                        subtask: item.subtask,
                                        dependencies: item.dependencies
                                    )
                                    .padding(.horizontal)
                                }

                                Text("Tap subtask to manage its dependencies")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // Blocked By Section (reverse relationship)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Tasks waiting for this")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        VStack(spacing: DesignSystem.Spacing.xs) {
                            if !blockedByTasks.isEmpty {
                                ForEach(blockedByTasks) { blockedTask in
                                    NavigationLink(destination: TaskDetailView(task: blockedTask)) {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            Image(systemName: "arrow.left.circle")
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 28)

                                            Text(blockedTask.title)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            } else {
                                Text("No tasks waiting")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingDependencyPicker) {
            DependencyPickerView(
                task: task,
                allTasks: TaskService.availableDependencies(for: task, from: allTasks)
            )
        }
    }
    
    private func removeDependency(_ dependency: Task) {
        TaskService.removeDependency(from: task, to: dependency)
    }
}

// MARK: - Dependency Row

private struct DependencyRow: View {
    let dependency: Task
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status icon
            Image(systemName: dependency.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(dependency.isCompleted ? .green : .gray)
                .frame(width: 28)

            // Content navigation
            NavigationLink(destination: TaskDetailView(task: dependency)) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Title
                    Text(dependency.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation {
                    onRemove()
                    HapticManager.medium()
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Subtask Dependency Row

private struct SubtaskDependencyRow: View {
    let subtask: Task
    let dependencies: [Task]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Subtask link - larger tap target
            NavigationLink(destination: TaskDetailView(task: subtask)) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    Text(subtask.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)

            // Dependencies list - nested under subtask
            ForEach(dependencies) { dependency in
                NavigationLink(destination: TaskDetailView(task: dependency)) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("↳")
                            .font(.body)
                            .foregroundStyle(.orange)
                            .frame(width: 28, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("blocked by:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(dependency.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview("Parent Task with Subtask Dependencies") {
    let container = try! ModelContainer(
        for: Task.self, Project.self, TimeEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let parent = Task(title: "Parent Task", priority: 1, createdDate: Date())
    let subtask1 = Task(title: "Subtask 1", priority: 2, createdDate: Date(), parentTask: parent)
    let subtask2 = Task(title: "Subtask 2", priority: 2, createdDate: Date(), parentTask: parent)
    let blocker = Task(title: "Blocker Task", priority: 1, createdDate: Date())
    let dep1 = Task(title: "Dependency 1", priority: 1, createdDate: Date())
    let dep2 = Task(title: "Dependency 2", priority: 1, createdDate: Date())
    
    parent.dependsOn = [dep1, dep2]
    subtask1.dependsOn = [blocker]
    subtask2.dependsOn = [blocker]
    parent.subtasks = [subtask1, subtask2]
    
    container.mainContext.insert(parent)
    container.mainContext.insert(subtask1)
    container.mainContext.insert(subtask2)
    container.mainContext.insert(blocker)
    container.mainContext.insert(dep1)
    container.mainContext.insert(dep2)
    
    return NavigationStack {
        ScrollView {
            TaskDependenciesView(task: parent)
        }
    }
    .modelContainer(container)
}

#Preview("Subtask Trying to Add Parent") {
    let parent = Task(title: "Parent Task", priority: 1, createdDate: Date())
    let subtask = Task(title: "Subtask", priority: 2, createdDate: Date(), parentTask: parent)
    
    // This should NOT be possible - parent shouldn't appear in available dependencies
    return NavigationStack {
        ScrollView {
            TaskDependenciesView(task: subtask)
        }
    }
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}
