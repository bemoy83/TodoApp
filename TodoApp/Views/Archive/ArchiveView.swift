//
//  ArchiveView.swift
//  TodoApp
//
//  Archive view for completed tasks

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext

    // Query for archived tasks only
    @Query(filter: #Predicate<Task> { task in
        task.isArchived
    }, sort: \Task.archivedDate, order: .reverse) private var archivedTasks: [Task]

    @State private var searchText = ""
    @State private var selectedFilter: ArchiveFilter = .all
    @State private var currentAlert: TaskActionAlert?

    private enum ArchiveFilter {
        case all
        case withProject
        case withoutProject
        case withSubtasks
    }

    // Filter archived tasks based on search and selected filter
    private var filteredTasks: [Task] {
        var result = archivedTasks.filter { $0.parentTask == nil } // Only top-level tasks

        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all:
            break
        case .withProject:
            result = result.filter { $0.project != nil }
        case .withoutProject:
            result = result.filter { $0.project == nil }
        case .withSubtasks:
            result = result.filter { ($0.subtasks?.count ?? 0) > 0 }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTasks) { task in
                        ArchiveTaskRow(task: task, alert: $currentAlert)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search archived tasks")
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $selectedFilter) {
                            Label("All Tasks", systemImage: "square.stack.3d.up").tag(ArchiveFilter.all)
                            Label("With Project", systemImage: "folder").tag(ArchiveFilter.withProject)
                            Label("Without Project", systemImage: "folder.badge.minus").tag(ArchiveFilter.withoutProject)
                            Label("With Subtasks", systemImage: "list.bullet.indent").tag(ArchiveFilter.withSubtasks)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if archivedTasks.isEmpty {
                    ContentUnavailableView(
                        "No Archived Tasks",
                        systemImage: "archivebox",
                        description: Text("Tasks you archive will appear here")
                    )
                }
            }
        }
        .taskActionAlert(alert: $currentAlert)
    }

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            // This shouldn't show because of the overlay, but keep for safety
            EmptyView()
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

// MARK: - Archive Task Row

private struct ArchiveTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    @Binding var alert: TaskActionAlert?

    private let router = TaskActionRouter()

    private var archivedDateText: String {
        if let archivedDate = task.archivedDate {
            return "Archived " + archivedDate.formatted(.relative(presentation: .named))
        }
        return "Archived"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Task title and project
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                // Status icon (always completed for archived tasks)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.taskCompleted)

                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Project badge
                    if let project = task.project {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Archived date
                    Text(archivedDateText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // Subtasks count if any
                    if let subtasks = task.subtasks, !subtasks.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.indent")
                                .font(.caption2)
                            Text("\(subtasks.count) subtask\(subtasks.count == 1 ? "" : "s")")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                _ = router.performWithExecutor(.unarchive, on: task, context: context) { a in
                    alert = a
                }
            } label: {
                Label("Unarchive", systemImage: "tray.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                _ = router.performWithExecutor(.delete, on: task, context: context) { a in
                    alert = a
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                _ = router.performWithExecutor(.unarchive, on: task, context: context) { a in
                    alert = a
                }
            } label: {
                Label("Unarchive", systemImage: "tray.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                _ = router.performWithExecutor(.delete, on: task, context: context) { a in
                    alert = a
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var context: TaskActionRouter.Context {
        .init(modelContext: modelContext, hapticsEnabled: true)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, Project.self, TimeEntry.self, configurations: config)

    let project = Project(title: "Work", color: "#007AFF")
    let task1 = Task(title: "Archived Task 1", completedDate: Date(), createdDate: Date(), project: project)
    task1.isArchived = true
    task1.archivedDate = Date().addingTimeInterval(-86400) // 1 day ago

    let task2 = Task(title: "Archived Task 2", completedDate: Date(), createdDate: Date())
    task2.isArchived = true
    task2.archivedDate = Date().addingTimeInterval(-172800) // 2 days ago

    let task3 = Task(title: "Parent with Subtasks", completedDate: Date(), createdDate: Date())
    task3.isArchived = true
    task3.archivedDate = Date().addingTimeInterval(-3600) // 1 hour ago
    let sub1 = Task(title: "Subtask 1", completedDate: Date(), createdDate: Date(), parentTask: task3)
    let sub2 = Task(title: "Subtask 2", completedDate: Date(), createdDate: Date(), parentTask: task3)
    task3.subtasks = [sub1, sub2]

    container.mainContext.insert(project)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)
    container.mainContext.insert(task3)
    container.mainContext.insert(sub1)
    container.mainContext.insert(sub2)

    return ArchiveView()
        .modelContainer(container)
}
