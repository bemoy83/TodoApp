import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var project: Project

    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    // ✅ Add expansion state
    @StateObject private var expansionState = TaskExpansionState.shared

    @State private var showingEditSheet = false
    @State private var showingAddTask = false
    @State private var showingDeleteAlert = false

    // MARK: - Computed Properties (query-based)
    private var projectTasks: [Task] {
        allTasks.filter { $0.project?.id == project.id && $0.parentTask == nil && !$0.isArchived }
    }
    
    private var activeTasks: [Task] {
        projectTasks
            .filter { !$0.isCompleted }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    private var completedTasks: [Task] {
        projectTasks
            .filter { $0.isCompleted }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    private var totalTimeSpent: Int {
        projectTasks.reduce(0) { total, task in
            total + computeTotalTime(for: task)
        }
    }

    private var totalPersonHours: Double {
        projectTasks.reduce(0.0) { total, task in
            total + computePersonHours(for: task)
        }
    }

    private func computeTotalTime(for task: Task) -> Int {
        var total = task.directTimeSpent
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return total
    }

    private func computePersonHours(for task: Task) -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        var totalPersonSeconds = 0.0

        for entry in entries {
            guard let endTime = entry.endTime else { continue }
            let duration = endTime.timeIntervalSince(entry.startTime)
            totalPersonSeconds += duration * Double(entry.personnelCount)
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            totalPersonSeconds += computePersonHours(for: subtask) * 3600  // Convert back to seconds
        }

        return totalPersonSeconds / 3600  // Convert to hours
    }
    
    private var activeTimerCount: Int {
        projectTasks.filter { $0.hasActiveTimer }.count
    }
    
    private var hasSubtasks: Bool {
        allTasks.contains { task in
            task.project?.id == project.id && task.parentTask != nil
        }
    }

    // MARK: - Body
    var body: some View {
        List {
            // Header
            Section {
                ProjectHeaderView(
                    project: project,
                    totalTasks: projectTasks.count,
                    completedTasks: completedTasks.count,
                    totalTimeSpent: totalTimeSpent,
                    totalPersonHours: totalPersonHours
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            // Crew planning card
            if ProjectCrewPlanningCard(project: project, allTasks: allTasks).shouldShow {
                Section {
                    ProjectCrewPlanningCard(project: project, allTasks: allTasks)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
            }

            // Subtasks hint
            if hasSubtasks {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(DesignSystem.Typography.caption)
                        Text("Tap subtask badge or chevron to expand")  // ✅ Updated text
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.sm, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.sm, trailing: DesignSystem.Spacing.lg))
                .listRowSeparator(.hidden)
            }

            // Empty state
            if projectTasks.isEmpty {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // Active tasks (with expansion)
            if !activeTasks.isEmpty {
                Section {
                    ForEach(activeTasks) { task in
                        ProjectTaskRow(
                            expansionState: expansionState,
                            task: task,
                            allTasks: allTasks
                        )
                    }
                } header: {
                    TaskSectionHeader(
                        title: "Active Tasks",
                        count: activeTasks.count,
                        icon: "circle.fill",
                        iconColor: DesignSystem.Colors.taskInProgress
                    )
                }
            }

            // Completed tasks (with expansion)
            if !completedTasks.isEmpty {
                Section {
                    ForEach(completedTasks) { task in
                        ProjectTaskRow(
                            expansionState: expansionState,
                            task: task,
                            allTasks: allTasks
                        )
                    }
                } header: {
                    TaskSectionHeader(
                        title: "Completed",
                        count: completedTasks.count,
                        icon: "checkmark.circle.fill",
                        iconColor: DesignSystem.Colors.taskCompleted
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [Color(hex: project.color).opacity(0.15),
                         DesignSystem.Colors.groupedBackground],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingEditSheet = true } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                    Button { showingAddTask = true } label: {
                        Label("Add Task", systemImage: "plus.circle")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteAlert = true } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProjectSheet(project: project)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskToProjectSheet(project: project)
        }
        .alert("Delete Project?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteProject() }
        } message: {
            Text("This will delete the project and all its tasks. This action cannot be undone.")
        }
        .environmentObject(expansionState)  // ✅ Provide expansion state
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(hex: project.color))
            }
            Text("No Tasks Yet")
                .font(DesignSystem.Typography.title3)
            Text("Add tasks to this project to get started")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddTask = true
            } label: {
                Label("Add Task", systemImage: "plus").fontWeight(.semibold)
            }
            .primaryButtonStyle(color: Color(hex: project.color))
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .emptyStateStyle()
    }

    // MARK: - Actions
    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }
}

// MARK: - Helper Row with Expansion Support

private struct ProjectTaskRow: View {
    @ObservedObject var expansionState: TaskExpansionState
    let task: Task
    let allTasks: [Task]  // Pass in the already-queried tasks

    private var hasSubtasks: Bool {
        allTasks.contains { $0.parentTask?.id == task.id }
    }

    var body: some View {
        Group {
            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                LightweightTaskRow(task: task, hasSubtasks: hasSubtasks)
            }

            if expansionState.isExpanded(task.id), hasSubtasks {
                TaskExpandedSubtasksView(parentTask: task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Lightweight Task Row (no @Query)

private struct LightweightTaskRow: View {
    @Bindable var task: Task
    let hasSubtasks: Bool

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status indicator
            Image(systemName: task.status.icon)
                .font(.body)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(task.isCompleted ? DesignSystem.Colors.secondary : DesignSystem.Colors.primary)
                    .strikethrough(task.isCompleted)

                // Metadata row
                HStack(spacing: 8) {
                    // Priority
                    if task.priority < 2 {
                        HStack(spacing: 2) {
                            Image(systemName: Priority(rawValue: task.priority)?.icon ?? "minus")
                                .font(.caption2)
                            Text(Priority(rawValue: task.priority)?.label ?? "")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(Priority(rawValue: task.priority)?.color ?? Color.gray)
                    }

                    // Subtasks count
                    if hasSubtasks {
                        HStack(spacing: 2) {
                            Image(systemName: "list.bullet.indent")
                                .font(.caption2)
                            Text("subtasks")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.info)
                    }

                    // Due date (if urgent)
                    if let dueDate = task.effectiveDeadline {
                        let isOverdue = dueDate < Date()
                        let isToday = Calendar.current.isDateInToday(dueDate)

                        if isOverdue || isToday {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(isOverdue ? "Overdue" : "Today")
                                    .font(DesignSystem.Typography.caption2)
                            }
                            .foregroundStyle(isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.warning)
                        }
                    }

                    // Active timer
                    if task.hasActiveTimer {
                        HStack(spacing: 2) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("Active")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.success)
                    }

                    // Date conflict indicator (Improvement #1)
                    if task.hasDateConflicts {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Dates")
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundStyle(DesignSystem.Colors.warning)
                    }
                }
                .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}


// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Project.self, Task.self, TimeEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let project = Project(title: "Work Project", color: "#007AFF")
    let task1 = Task(title: "Task 1", priority: 1, createdDate: Date(), project: project, order: 0)
    let task2 = Task(title: "Task 2", priority: 2, completedDate: Date(), createdDate: Date(), project: project, order: 1)
    let task3 = Task(title: "Task 3", priority: 0, dueDate: Date(), createdDate: Date(), project: project, order: 2)

    let parent = Task(title: "Parent Task", priority: 1, createdDate: Date(), project: project, order: 3)
    let sub = Task(title: "Subtask", priority: 2, createdDate: Date(), parentTask: parent, project: project)
    parent.subtasks = [sub]

    container.mainContext.insert(project)
    [task1, task2, task3, parent, sub].forEach { container.mainContext.insert($0) }

    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}
