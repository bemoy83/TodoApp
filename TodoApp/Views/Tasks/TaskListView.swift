import SwiftUI
import SwiftData
internal import Combine

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }) private var tasks: [Task]
    @Query(sort: \Tag.order) private var allTags: [Tag]

    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingAddTask = false
    @State private var selectedTask: Task?
    @State private var editMode: EditMode = .inactive
    @State private var isSearchPresented = false

    // Tag filtering state
    @State private var selectedTagIds: Set<UUID> = []
    @State private var showingTagFilter = false

    // Bulk archive state
    @State private var selectedTasksForArchive: Set<Task.ID> = []
    @State private var showingBulkArchiveAlert: TaskActionAlert?

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

        // Tag filtering (show tasks with ANY of the selected tags)
        if !selectedTagIds.isEmpty {
            result = result.filter { task in
                guard let taskTags = task.tags else { return false }
                return taskTags.contains { selectedTagIds.contains($0.id) }
            }
        }

        return result
    }

    private var selectedTags: [Tag] {
        allTags.filter { selectedTagIds.contains($0.id) }
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
                                isEditMode: editMode == .active,
                                isSelected: selectedTasksForArchive.contains(task.id),
                                onToggleSelection: {
                                    toggleSelection(for: task)
                                }
                            )
                        }
                        .onMove { source, destination in
                            reorderTasks(completedTasks, from: source, to: destination)
                        }
                    } header: {
                        completedSectionHeader
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
            .safeAreaInset(edge: .bottom) {
                if editMode == .active && !selectedTasksForArchive.isEmpty {
                    bulkArchiveToolbar
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !selectedTagIds.isEmpty {
                    tagFilterChips
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarItems
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailingToolbarItems
                }
            }
            .sheet(isPresented: $showingAddTask) { AddTaskView() }
            .sheet(isPresented: $showingTagFilter) {
                TagFilterSheet(
                    selectedTagIds: $selectedTagIds,
                    allTags: allTags
                )
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
        }
        .environmentObject(expansionState)
        .taskActionAlert(alert: $showingBulkArchiveAlert)
        .onChange(of: editMode) { oldValue, newValue in
            if newValue == .inactive {
                selectedTasksForArchive.removeAll()
            }
        }
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

    @ViewBuilder
    private var completedSectionHeader: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.taskCompleted)
            Text("Completed")
                .font(DesignSystem.Typography.headline)

            Spacer()

            // Select All / Deselect All in edit mode
            if editMode == .active && !completedTasks.isEmpty {
                Button {
                    toggleSelectAll()
                } label: {
                    Text(allCompletedTasksSelected ? "Deselect All" : "Select All")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    @ViewBuilder
    private var bulkArchiveToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(selectedTasksForArchive.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    performBulkArchive()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var tagFilterChips: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedTags) { tag in
                        TagFilterChip(
                            tag: tag,
                            onRemove: {
                                selectedTagIds.remove(tag.id)
                                HapticManager.light()
                            }
                        )
                    }

                    // Clear all button
                    Button {
                        selectedTagIds.removeAll()
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                            Text("Clear All")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)

            Divider()
        }
    }

    @ViewBuilder
    private var leadingToolbarItems: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TaskFilterMenu(selectedFilter: $selectedFilter)
            tagFilterButton
        }
    }

    @ViewBuilder
    private var tagFilterButton: some View {
        Button {
            showingTagFilter = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(selectedTagIds.isEmpty ? Color.primary : Color.blue)

                if !selectedTagIds.isEmpty {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
    }

    @ViewBuilder
    private var trailingToolbarItems: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
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

            Button {
                showingAddTask = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var allCompletedTasksSelected: Bool {
        !completedTasks.isEmpty && selectedTasksForArchive.count == completedTasks.count
    }

    private func toggleSelection(for task: Task) {
        if selectedTasksForArchive.contains(task.id) {
            selectedTasksForArchive.remove(task.id)
        } else {
            selectedTasksForArchive.insert(task.id)
        }
        HapticManager.selection()
    }

    private func toggleSelectAll() {
        if allCompletedTasksSelected {
            selectedTasksForArchive.removeAll()
        } else {
            selectedTasksForArchive = Set(completedTasks.map { $0.id })
        }
        HapticManager.selection()
    }

    private func performBulkArchive() {
        let tasksToArchive = completedTasks.filter { selectedTasksForArchive.contains($0.id) }

        guard !tasksToArchive.isEmpty else { return }

        // Validate each task
        var canArchiveCount = 0
        var hasWarningsCount = 0
        var blockingCount = 0

        for task in tasksToArchive {
            let validation = ArchiveManager.validateArchive(task: task, allTasks: tasks)
            if validation.canArchive {
                if validation.hasWarnings {
                    hasWarningsCount += 1
                } else {
                    canArchiveCount += 1
                }
            } else {
                blockingCount += 1
            }
        }

        // Show appropriate alert
        if blockingCount > 0 {
            showingBulkArchiveAlert = TaskActionAlert(
                title: "Cannot Archive All Tasks",
                message: "\(blockingCount) task\(blockingCount == 1 ? "" : "s") cannot be archived due to incomplete subtasks.\n\nOnly \(canArchiveCount + hasWarningsCount) task\(canArchiveCount + hasWarningsCount == 1 ? "" : "s") can be archived.",
                actions: [
                    AlertAction(title: "Cancel", role: .cancel, action: {}),
                    AlertAction(title: "Archive Valid Tasks", role: .none, action: {
                        executeBulkArchive(tasksToArchive.filter { task in
                            let validation = ArchiveManager.validateArchive(task: task, allTasks: tasks)
                            return validation.canArchive
                        })
                    })
                ]
            )
        } else if hasWarningsCount > 0 {
            showingBulkArchiveAlert = TaskActionAlert(
                title: "Archive \(tasksToArchive.count) Tasks?",
                message: "\(hasWarningsCount) task\(hasWarningsCount == 1 ? " has" : "s have") dependent tasks that will be affected.\n\nArchive anyway?",
                actions: [
                    AlertAction(title: "Cancel", role: .cancel, action: {}),
                    AlertAction(title: "Archive All", role: .none, action: {
                        executeBulkArchive(tasksToArchive)
                    })
                ]
            )
        } else {
            showingBulkArchiveAlert = TaskActionAlert(
                title: "Archive \(tasksToArchive.count) Tasks?",
                message: "These tasks will be moved to the archive.",
                actions: [
                    AlertAction(title: "Cancel", role: .cancel, action: {}),
                    AlertAction(title: "Archive", role: .none, action: {
                        executeBulkArchive(tasksToArchive)
                    })
                ]
            )
        }
    }

    private func executeBulkArchive(_ tasksToArchive: [Task]) {
        for task in tasksToArchive {
            ArchiveManager.archive(task: task, allTasks: tasks, modelContext: modelContext)
        }

        selectedTasksForArchive.removeAll()
        editMode = .inactive
        HapticManager.success()
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
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)? = nil

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    private var hasSubtasks: Bool {
        allTasks.contains { $0.parentTask?.id == task.id }
    }

    private var showSelectionUI: Bool {
        isEditMode && task.isCompleted && onToggleSelection != nil
    }

    var body: some View {
        Group {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Selection checkbox for completed tasks in edit mode
                if showSelectionUI {
                    Button {
                        onToggleSelection?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    TaskDetailView(task: task)
                } label: {
                    TaskRowView(task: task, onOpen: { })
                }
                .disabled(isEditMode)
            }

            if expansionState.isExpanded(task.id), hasSubtasks {
                TaskExpandedSubtasksView(parentTask: task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
