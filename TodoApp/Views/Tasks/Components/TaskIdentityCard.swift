import SwiftUI
import SwiftData

/// Always-visible identity card showing task title, status, and blocking warnings
/// Part of the TaskDetailView mini-sections architecture
struct TaskIdentityCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    let alertBinding: Binding<TaskActionAlert?>
    let onBlockingDepsTapped: () -> Void

    @State private var isEditingTitle = false
    @State private var editedTitle: String

    init(
        task: Task,
        alert: Binding<TaskActionAlert?>,
        onBlockingDepsTapped: @escaping () -> Void
    ) {
        self._task = Bindable(wrappedValue: task)
        self.alertBinding = alert
        self.onBlockingDepsTapped = onBlockingDepsTapped
        _editedTitle = State(initialValue: task.title)
    }

    private var statusColor: Color {
        switch task.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Title (always shown, editable)
            SharedTitleSection(
                item: task,
                isEditing: $isEditingTitle,
                editedTitle: $editedTitle,
                placeholder: "Task title"
            )

            // Status row with tap-to-complete
            statusRow

            // Blocking dependencies warning (conditional)
            if task.status == .blocked {
                blockingWarning
            }
        }
        .detailCardStyle()
    }

    // MARK: - Status Row

    private var statusRow: some View {
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

                Text(task.status.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor)

                Spacer()

                Text(task.isCompleted ? "Tap to reopen" : "Tap to complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(statusColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Blocking Warning

    private var blockingWarning: some View {
        Button {
            onBlockingDepsTapped()
            HapticManager.light()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.warning)

                let blockingCount = task.blockingDependencies.count + task.blockingSubtaskDependencies.count
                Text("\(blockingCount) blocking \(blockingCount == 1 ? "dependency" : "dependencies")")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.warning)

                Spacer()

                Text("View")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.warning.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Ready Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let task = Task(title: "Install Carpet Tiles")
    container.mainContext.insert(task)

    return TaskIdentityCard(
        task: task,
        alert: .constant(nil),
        onBlockingDepsTapped: {}
    )
    .padding()
}

#Preview("Blocked Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let blocker = Task(title: "Prepare Floor Surface")
    let task = Task(title: "Install Carpet Tiles")
    task.dependsOn = [blocker]

    container.mainContext.insert(blocker)
    container.mainContext.insert(task)

    return TaskIdentityCard(
        task: task,
        alert: .constant(nil),
        onBlockingDepsTapped: { print("Jump to dependencies") }
    )
    .padding()
}
