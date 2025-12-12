import SwiftUI
import SwiftData

struct TaskDependenciesView: View {
    @Bindable var task: Task

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @State private var showingDependencyPicker = false

    var blockedByTasks: [Task] {
        TaskService.blockedByTasks(for: task, from: allTasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if let dependencies = task.dependsOn, !dependencies.isEmpty {
                    // Dependency list
                    List {
                        ForEach(dependencies) { dependency in
                            DependencyRow(
                                dependency: dependency,
                                onRemove: { removeDependency(dependency) }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .frame(minHeight: 0)
                    .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .padding(.horizontal)
                } else {
                    // Empty state
                    Text("No dependencies")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Add button
                UnifiedAddButton(
                    title: "Add Dependency",
                    action: {
                        showingDependencyPicker = true
                        HapticManager.selection()
                    }
                )

                // Read-only info: Tasks waiting for this (if any)
                if !blockedByTasks.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(blockedByTasks.count) \(blockedByTasks.count == 1 ? "task is" : "tasks are") waiting for this")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
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
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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

#Preview("With Dependencies") {
    let container = try! ModelContainer(
        for: Task.self, Project.self, TimeEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let parent = Task(title: "Parent Task", priority: 1, createdDate: Date())
    let dep1 = Task(title: "Setup environment", priority: 1, createdDate: Date())
    let dep2 = Task(title: "Get materials", priority: 1, createdDate: Date())
    let dep3 = Task(title: "Review plans", priority: 1, completedDate: Date(), createdDate: Date())

    let _ = {
        parent.dependsOn = [dep1, dep2, dep3]
        container.mainContext.insert(parent)
        container.mainContext.insert(dep1)
        container.mainContext.insert(dep2)
        container.mainContext.insert(dep3)
    }()

    return NavigationStack {
        ScrollView {
            TaskDependenciesView(task: parent)
        }
    }
    .modelContainer(container)
}

#Preview("No Dependencies") {
    let task = Task(title: "Task without dependencies", priority: 1, createdDate: Date())

    return NavigationStack {
        ScrollView {
            TaskDependenciesView(task: task)
        }
    }
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}

// MARK: - Unified Add Button Component

/// Standardized add button used across all list-based sections
/// Provides consistent visual treatment and interaction pattern
private struct UnifiedAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}
