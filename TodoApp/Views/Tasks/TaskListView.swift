import SwiftUI
import SwiftData
internal import Combine

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }) private var tasks: [Task]
    
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingAddTask = false
    @State private var selectedTask: Task?
    @State private var editMode: EditMode = .inactive
    @State private var isSearchPresented = false
    
    @StateObject private var expansionState = TaskExpansionState.shared
    
    // MARK: - Filtering (top-level tasks only)
    private var filteredTasks: [Task] {
        var result = tasks.filter { $0.parentTask == nil }
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .blocked:
            result = result.filter { $0.status == .blocked }
        }
        return result
    }
    
    private var activeTasks: [Task] {
        filteredTasks
            .filter { !$0.isCompleted }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    private var completedTasks: [Task] {
        filteredTasks
            .filter { $0.isCompleted }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !activeTasks.isEmpty {
                    Section {
                        ForEach(activeTasks) { task in
                            TaskListRow(
                                expansionState: expansionState,
                                task: task,
                                isEditMode: editMode == .active
                            )
                        }
                        .onMove { source, destination in
                            reorderTasks(activeTasks, from: source, to: destination)
                        }
                    } header: {
                        sectionHeader(
                            icon: "circle.fill",
                            title: "Active",
                            color: DesignSystem.Colors.taskInProgress
                        )
                    }
                }
                
                if !completedTasks.isEmpty {
                    Section {
                        ForEach(completedTasks) { task in
                            TaskListRow(
                                expansionState: expansionState,
                                task: task,
                                isEditMode: editMode == .active
                            )
                        }
                        .onMove { source, destination in
                            reorderTasks(completedTasks, from: source, to: destination)
                        }
                    } header: {
                        sectionHeader(
                            icon: "checkmark.circle.fill",
                            title: "Completed",
                            color: DesignSystem.Colors.taskCompleted
                        )
                    }
                }
            }
            .overlay(alignment: .center) {
                if activeTasks.isEmpty && completedTasks.isEmpty {
                    TaskEmptyStateView(
                        filter: selectedFilter,
                        searchText: searchText,
                        onAddTask: { showingAddTask = true }
                    )
                    .padding(.horizontal, DesignSystem.Spacing.xxxl)
                    .transition(.opacity)
                    .allowsHitTesting(true)
                }
            }
            .environment(\.editMode, $editMode)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search tasks"
            )
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TaskFilterMenu(selectedFilter: $selectedFilter)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Search button
                        Button {
                            isSearchPresented = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Button {
                            withAnimation(DesignSystem.Animation.standard) {
                                editMode = editMode == .active ? .inactive : .active
                                HapticManager.selection()
                            }
                        } label: {
                            Label(
                                editMode == .active ? "Done" : "Reorder",
                                systemImage: editMode == .active ? "checkmark" : "line.3.horizontal"
                            )
                        }
                        Button { showingAddTask = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) { AddTaskView() }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
        }
        .environmentObject(expansionState)
    }
    
    @ViewBuilder
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(title)
                .font(DesignSystem.Typography.headline)
        }
    }
    
    private func reorderTasks(_ tasks: [Task], from source: IndexSet, to destination: Int) {
        Reorderer.reorder(
            items: tasks,
            currentOrder: { $0.order ?? Int.max },
            setOrder: { task, index in task.order = index },
            from: source,
            to: destination,
            save: { try modelContext.save() }
        )
    }
}

// MARK: - Helper Views

private struct TaskListRow: View {
    @ObservedObject var expansionState: TaskExpansionState
    let task: Task
    let isEditMode: Bool

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]
    
    private var hasSubtasks: Bool {
        allTasks.contains { $0.parentTask?.id == task.id }
    }
    
    var body: some View {
        Group {
            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                TaskRowView(task: task, onOpen: { })
            }
            .disabled(isEditMode)
            
            if expansionState.isExpanded(task.id), hasSubtasks {
                TaskExpandedSubtasksView(parentTask: task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
