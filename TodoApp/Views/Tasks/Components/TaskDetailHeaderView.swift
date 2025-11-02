import SwiftUI
import SwiftData

struct TaskDetailHeaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task
    
    @Query(sort: \Task.order) private var allTasks: [Task]

    private let externalAlert: Binding<TaskActionAlert?>?
    @State private var localAlert: TaskActionAlert?
    private var alertBinding: Binding<TaskActionAlert?> {
        externalAlert ?? $localAlert
    }

    @State private var notesExpanded: Bool
    @State private var isEditingTitle = false
    @State private var editedTitle: String

    private var parentTask: Task? {
        guard let parentId = task.parentTask?.id else { return nil }
        return allTasks.first { $0.id == parentId }
    }

    private var effectiveDueDate: Date? {
        task.dueDate ?? parentTask?.dueDate
    }

    private var isDueDateInherited: Bool {
        task.dueDate == nil && parentTask?.dueDate != nil
    }

    private var taskPriority: Priority {
        Priority(rawValue: task.priority) ?? .medium
    }

    init(task: Task, alert: Binding<TaskActionAlert?>? = nil) {
        self._task = Bindable(wrappedValue: task)
        self.externalAlert = alert
        let notesLength = task.notes?.count ?? 0
        _notesExpanded = State(initialValue: notesLength > 0 && notesLength <= 100)
        _editedTitle = State(initialValue: task.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Parent breadcrumb (conditional - only if subtask)
            if let parent = parentTask {
                NavigationLink(destination: TaskDetailView(task: parent)) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Subtask of")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "arrow.turn.up.left")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text(parent.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .detailCardStyle()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Title (always shown, editable)
                TitleSection(
                    task: task,
                    isEditing: $isEditingTitle,
                    editedTitle: $editedTitle
                )
                
                // Status Section (always shown)
                StatusSection(
                    task: task,
                    alertBinding: alertBinding,
                    modelContext: modelContext
                )
                
                // Dates Section (conditional - only if has dates)
                if hasDateInfo {
                    DatesSection(
                        task: task,
                        effectiveDueDate: effectiveDueDate,
                        isDueDateInherited: isDueDateInherited
                    )
                }
                
                // Project & Priority Section (conditional - only if has project)
                if task.project != nil {
                    ProjectPrioritySection(task: task)
                }
                
                // Notes Section (conditional - only if has notes)
                if let notes = task.notes, !notes.isEmpty {
                    NotesSection(notes: notes, isExpanded: $notesExpanded)
                }
            }
            .detailCardStyle()
        }
        .taskActionAlert(alert: alertBinding)
    }
    
    // Conditional logic
    private var hasDateInfo: Bool {
        effectiveDueDate != nil || task.completedDate != nil
    }
}

// MARK: - Title Section

private struct TitleSection: View {
    @Bindable var task: Task
    @Binding var isEditing: Bool
    @Binding var editedTitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Title")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            if isEditing {
                HStack {
                    TextField("Task title", text: $editedTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .textFieldStyle(.plain)
                    
                    Button("Done") {
                        task.title = editedTitle
                        isEditing = false
                        HapticManager.success()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            } else {
                Button {
                    isEditing = true
                } label: {
                    HStack {
                        Text(task.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Image(systemName: "pencil.circle.fill")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Status Section

private struct StatusSection: View {
    @Bindable var task: Task
    let alertBinding: Binding<TaskActionAlert?>
    let modelContext: ModelContext
    
    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Status")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Button {
                let router = TaskActionRouter()
                let context = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)
                let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                _ = router.performWithExecutor(action, on: task, context: context) { alert in
                    alertBinding.wrappedValue = alert
                }
            } label: {
                HStack {
                    Image(systemName: task.status.icon)
                        .font(.body)
                        .foregroundStyle(statusColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(task.status.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text(task.isCompleted ? "Tap to mark incomplete" : "Tap to complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)
            
            // Blocking dependencies (conditional - only if blocked)
            if task.status == .blocked {
                Divider()
                BlockingDependenciesInfo(task: task)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Dates Section

private struct DatesSection: View {
    let task: Task
    let effectiveDueDate: Date?
    let isDueDateInherited: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Dates")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Created date (always shown)
                DateRow(
                    icon: "clock",
                    label: "Created",
                    date: task.createdDate,
                    color: .secondary
                )
                
                // Due date (conditional)
                if let dueDate = effectiveDueDate {
                    DateRow(
                        icon: isDueDateInherited ? "calendar.badge.clock" : "calendar",
                        label: isDueDateInherited ? "Due (inherited)" : "Due",
                        date: dueDate,
                        color: dueDate < Date() && !task.isCompleted ? .red : .secondary,
                        isActionable: true
                    )
                }
                
                // Completed date (conditional)
                if let completedDate = task.completedDate {
                    DateRow(
                        icon: "checkmark.circle.fill",
                        label: "Completed",
                        date: completedDate,
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Date Row Component

private struct DateRow: View {
    let icon: String
    let label: String
    let date: Date
    let color: Color
    var isActionable: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.primary)
            
            /*if isActionable {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }*/
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Project & Priority Section

private struct ProjectPrioritySection: View {
    @Bindable var task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Organization")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Project
                if let project = task.project {
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
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                
                // Priority
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
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Notes Section

private struct NotesSection: View {
    let notes: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Blocking Dependencies Info

private struct BlockingDependenciesInfo: View {
    let task: Task
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    
                    Text("Dependencies")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    let ownBlocks = task.blockingDependencies
                    if !ownBlocks.isEmpty {
                        ForEach(ownBlocks.prefix(5)) { dep in
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.warning)
                                Text(dep.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 28)
                        }
                        
                        if ownBlocks.count > 5 {
                            Text("+ \(ownBlocks.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                    
                    let subtaskBlocks = task.blockingSubtaskDependencies
                    if !subtaskBlocks.isEmpty {
                        Text("Subtask dependencies:")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .padding(.leading, 28)
                        
                        ForEach(Array(subtaskBlocks.prefix(3).enumerated()), id: \.offset) { index, block in
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Text("\(block.subtask.title) → \(block.dependency.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 28)
                        }
                        
                        if subtaskBlocks.count > 3 {
                            Text("+ \(subtaskBlocks.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
    }
}
