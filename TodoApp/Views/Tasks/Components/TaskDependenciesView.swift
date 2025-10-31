import SwiftUI
import SwiftData

struct TaskDependenciesView: View {
    @Bindable var task: Task
    let allTasks: [Task]
    
    @State private var showingDependencyPicker = false
    @AppStorage private var enableDependencies: Bool // Changed to @AppStorage
    @State private var isEditingDependencies = false
    
    // Use task ID as storage key for per-task persistence
    init(task: Task, allTasks: [Task]) {
        self.task = task
        self.allTasks = allTasks
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
        VStack(spacing: 16) {
            // Main Dependencies Section
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with edit button
                    HStack {
                        Text("Dependencies")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !isSubtask || enableDependencies {
                            if let deps = task.dependsOn, !deps.isEmpty {
                                Button(isEditingDependencies ? "Done" : "Edit") {
                                    isEditingDependencies.toggle()
                                }
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    // Toggle for subtasks (now persisted)
                    if isSubtask {
                        Toggle("Enable Dependencies", isOn: $enableDependencies)
                            .font(.subheadline)
                        
                        if !enableDependencies {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                Text("Advanced feature - enable to add dependencies")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Show dependencies section if not a subtask OR toggle is enabled
                    if !isSubtask || enableDependencies {
                        // Depends On Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This task depends on:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if let dependencies = task.dependsOn, !dependencies.isEmpty {
                                ForEach(dependencies) { dependency in
                                    HStack(spacing: 12) {
                                        // Delete button in edit mode
                                        if isEditingDependencies {
                                            Button {
                                                withAnimation {
                                                    removeDependency(dependency)
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Image(systemName: dependency.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(dependency.isCompleted ? .green : .gray)
                                            .font(.caption)
                                        
                                        Text(dependency.title)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        // Contextual delete button (always visible)
                                        if !isEditingDependencies {
                                            Button {
                                                withAnimation {
                                                    removeDependency(dependency)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                            } else {
                                Text("No dependencies")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                showingDependencyPicker = true
                            } label: {
                                Label("Add Dependency", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                            .padding(.top, 4)
                        }
                        
                        Divider()
                        
                        // Blocked By Section (reverse relationship)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tasks waiting for this:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if !blockedByTasks.isEmpty {
                                ForEach(blockedByTasks) { blockedTask in
                                    NavigationLink(destination: TaskDetailView(task: blockedTask)) {
                                        HStack {
                                            Image(systemName: "arrow.left.circle")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text(blockedTask.title)
                                                .font(.subheadline)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("No tasks waiting")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            // Subtask Dependencies Section (only for parent tasks)
            if !isSubtask && !subtasksWithDependencies.isEmpty {
                GroupBox("Subtask Dependencies") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(subtasksWithDependencies, id: \.subtask.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                // Subtask name
                                NavigationLink(destination: TaskDetailView(task: item.subtask)) {
                                    HStack {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.caption2)
                                        Text(item.subtask.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                // Dependencies
                                ForEach(item.dependencies) { dependency in
                                    NavigationLink(destination: TaskDetailView(task: dependency)) {
                                        HStack(spacing: 8) {
                                            Text("  ↳")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                            Text("blocked by:")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(dependency.title)
                                                .font(.caption)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Text("Tap subtask to manage its dependencies")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
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
            TaskDependenciesView(task: parent, allTasks: [parent, subtask1, subtask2, blocker, dep1, dep2])
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
            TaskDependenciesView(task: subtask, allTasks: [parent, subtask])
        }
    }
    .modelContainer(for: [Task.self, Project.self, TimeEntry.self])
}
