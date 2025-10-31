import SwiftUI
import SwiftData

/// Mail-style swipes backed by the new Executor + Alerts router path.
/// Leading (full swipe): Complete/Uncomplete; secondary: Start/Stop Timer (when relevant)
/// Trailing (no full swipe): Delete (confirm alert), More (sheet entry)
struct RowSwipeActions: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: Task
    let isEnabled: Bool
    let onMore: (() -> Void)?
    let alert: Binding<TaskActionAlert?>?

    // ✅ NEW: State to hold pending action until swipe completes
    @State private var pendingAction: TaskAction?
    @State private var isSwipeActive = false

    func body(content: Content) -> some View {
        Group {
            if isEnabled {
                let profile = TaskActionAvailability.profile(for: .init(
                    isCompleted: task.isCompleted,
                    isSubtask: task.parentTask != nil,
                    hasActiveTimer: task.hasActiveTimer,
                    inProjectDetail: false
                ))
                let router = TaskActionRouter()
                let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

                content
                    // Leading swipes
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        ForEach(Array(profile.swipeLeading.enumerated()), id: \.offset) { _, action in
                            let meta = action.metadata
                            Button(role: meta.isDestructive ? .destructive : nil) {
                                if case .edit = action {
                                    onMore?()
                                } else {
                                    // ✅ Store action and execute after delay
                                    pendingAction = action
                                }
                            } label: {
                                Label(meta.label, systemImage: meta.systemImage)
                            }
                            .tint(meta.preferredTint)
                        }
                    }
                    // Trailing swipes
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ForEach(Array(profile.swipeTrailing.enumerated()), id: \.offset) { _, action in
                            let meta = action.metadata
                            Button(role: meta.isDestructive ? .destructive : nil) {
                                if case .edit = action {
                                    _ = router.performWithExecutor(.edit, on: task, context: ctx) { a in
                                        alert?.wrappedValue = a
                                    }
                                    onMore?()
                                } else {
                                    // ✅ Store action and execute after delay
                                    pendingAction = action
                                }
                            } label: {
                                Label("More", systemImage: "ellipsis")
                            }
                            .tint(meta.preferredTint ?? (meta.isDestructive ? DesignSystem.Colors.error : .gray))
                        }
                    }
                    // ✅ Execute pending action after swipe completes
                    .onChange(of: pendingAction) { oldValue, newValue in
                        guard let action = newValue else { return }
                        
                        // Wait for swipe to fully dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            _ = router.performWithExecutor(action, on: task, context: ctx) { a in
                                alert?.wrappedValue = a
                            }
                            // Clear pending action
                            pendingAction = nil
                        }
                    }
            } else {
                content // edit mode: disable swipes
            }
        }
    }
}

// MARK: - Convenience sugar
extension View {
    /// Preferred: alert-enabled swipe actions. Pass a Binding<TaskActionAlert?> to surface router alerts.
    func rowSwipeActions(
        task: Task,
        isEnabled: Bool,
        onMore: (() -> Void)? = nil,
        alert: Binding<TaskActionAlert?> // NEW
    ) -> some View {
        modifier(RowSwipeActions(task: task, isEnabled: isEnabled, onMore: onMore, alert: alert))
    }

    /// Back-compat shim (no alerts). Consider migrating to the alert-enabled overload.
    func rowSwipeActions(
        task: Task,
        isEnabled: Bool,
        onMore: (() -> Void)? = nil
    ) -> some View {
        modifier(RowSwipeActions(task: task, isEnabled: isEnabled, onMore: onMore, alert: nil))
    }
}
