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
    let onAddSubtask: (() -> Void)?

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

                    // Set Priority (submenu)
                    Menu {
                        ForEach(Priority.allCases, id: \.self) { level in
                            Button {
                                _ = router.performWithExecutor(.setPriority(level.rawValue), on: task, context: ctx) { a in
                                    alert?.wrappedValue = a
                                }
                            } label: {
                                Label(level.label, systemImage: level.icon)
                            }
                        }
                    } label: {
                        Label("Set Priority", systemImage: "flag")
                    }

                    // Set Due Date (submenu with presets)
                    Menu {
                        Button {
                            task.dueDate = Calendar.current.startOfDay(for: Date())
                        } label: {
                            Label("Today", systemImage: "calendar")
                        }

                        Button {
                            task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                        } label: {
                            Label("Tomorrow", systemImage: "calendar")
                        }

                        Button {
                            task.dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))
                        } label: {
                            Label("Next Week", systemImage: "calendar")
                        }

                        if task.dueDate != nil {
                            Button(role: .destructive) {
                                task.dueDate = nil
                            } label: {
                                Label("Clear Due Date", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Set Due Date", systemImage: "calendar")
                    }

                    // Set Estimate (submenu with presets)
                    Menu {
                        Button {
                            task.estimatedSeconds = 30 * 60 // 30 minutes in seconds
                            task.hasCustomEstimate = true
                        } label: {
                            Label("30 minutes", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 60 * 60 // 1 hour
                            task.hasCustomEstimate = true
                        } label: {
                            Label("1 hour", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 2 * 60 * 60 // 2 hours
                            task.hasCustomEstimate = true
                        } label: {
                            Label("2 hours", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 4 * 60 * 60 // 4 hours
                            task.hasCustomEstimate = true
                        } label: {
                            Label("4 hours", systemImage: "clock")
                        }

                        if task.estimatedSeconds != nil {
                            Button(role: .destructive) {
                                task.estimatedSeconds = nil
                                task.hasCustomEstimate = false
                            } label: {
                                Label("Clear Estimate", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Set Estimate", systemImage: "clock")
                    }

                    // Add Subtask (only for parent tasks)
                    if task.parentTask == nil, let onAddSubtask {
                        Button {
                            onAddSubtask()
                        } label: {
                            Label("Add Subtask", systemImage: "plus.circle")
                        }
                        .accessibilityLabel("Add Subtask")
                    }

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
        onAddSubtask: (() -> Void)? = nil,
        alert: Binding<TaskActionAlert?> // NEW
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                onAddSubtask: onAddSubtask,
                                alert: alert))
    }

    /// Back-compat shim (no alerts).
    func rowContextMenu(
        task: Task,
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onMore: (() -> Void)? = nil,
        onAddSubtask: (() -> Void)? = nil
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                onAddSubtask: onAddSubtask,
                                alert: nil))
    }
}
