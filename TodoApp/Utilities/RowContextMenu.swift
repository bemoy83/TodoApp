import SwiftUI
import SwiftData

/// Router-backed context menu using the new Executor + Alerts path.
/// - Edit/More are navigation intents (caller handles presentation).
/// - Delete confirms via alert (surfaced through the provided binding).
struct RowContextMenu: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: Task
    let isEnabled: Bool
    let onEdit: () -> Void
    let onMore: (() -> Void)?

    /// Optional alert binding for router-driven alerts.
    let alert: Binding<TaskActionAlert?>?

    private let router = TaskActionRouter()

    func body(content: Content) -> some View {
        Group {
            if isEnabled {
                content.contextMenu {
                    // Edit (navigation intent - just show sheet)
                    Button {
                        onEdit()  // ✅ Simplified
                    } label: { Label("Edit", systemImage: "pencil") }
                    .accessibilityLabel("Edit Task")

                    // Complete / Uncomplete (uses router)
                    Button {
                        let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                        _ = router.performWithExecutor(action, on: task, context: ctx) { a in
                            alert?.wrappedValue = a
                        }
                    } label: {
                        Label(task.isCompleted ? "Uncomplete" : "Complete",
                              systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                    }
                    .accessibilityLabel(task.isCompleted ? "Uncomplete Task" : "Complete Task")

                    // More (navigation intent - just show sheet)
                    if let onMore {
                        Button {
                            onMore()  // ✅ Simplified
                        } label: { Label("More", systemImage: "ellipsis.circle") }
                        .accessibilityLabel("More Actions")
                    }

                    // Delete (uses router with confirmation)
                    Button(role: .destructive) {
                        _ = router.performWithExecutor(.delete, on: task, context: ctx) { a in
                            alert?.wrappedValue = a
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(DesignSystem.Colors.error)
                    .accessibilityLabel("Delete Task")
                }
            } else {
                content
            }
        }
    }

    private var ctx: TaskActionRouter.Context {
        .init(modelContext: modelContext, hapticsEnabled: true)
    }
}

// MARK: - Convenience helpers
extension View {
    /// Preferred: alert-enabled context menu.
    func rowContextMenu(
        task: Task,
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onMore: (() -> Void)? = nil,
        alert: Binding<TaskActionAlert?> // NEW
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                alert: alert))
    }

    /// Back-compat shim (no alerts).
    func rowContextMenu(
        task: Task,
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onMore: (() -> Void)? = nil
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                alert: nil))
    }
}
