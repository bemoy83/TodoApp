import SwiftUI
import SwiftData

/// Session 3: Unified Actions rollout â€” coordinator-only detail view
/// - Keeps your existing components:
///   TaskDetailHeaderView, TaskTimeTrackingView, TaskSubtasksView, TaskDependenciesView
/// - Routes toolbar & sheet actions through TaskActionRouter (no duplicate business logic here).
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: Task

    @State private var showingEditSheet = false
    @State private var showingMoreSheet = false

    // NEW: central alert state for executor-backed alerts
    @State private var currentAlert: TaskActionAlert?

    private let router = TaskActionRouter()

    init(task: Task) {
        self.task = task
    }

    var body: some View {
        let ctx = TaskActionRouter.Context(modelContext: modelContext, hapticsEnabled: true)

        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TaskDetailHeaderView(task: task)

                // Time tracking remains the canonical place for timer controls
                TaskTimeTrackingView(task: task)

                // Personnel planning and tracking
                TaskPersonnelView(task: task)

                // Quantity tracking for productivity measurement
                TaskQuantityView(task: task)

                // Tags for organization and filtering
                TaskTagsView(task: task)

                // Time entries management
                TimeEntriesView(task: task)

                TaskSubtasksView(task: task)

                TaskDependenciesView(task: task)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit â€” now routed via executor; if no alert, open editor
                Button {
                    var presentedAlert = false
                    _ = router.performWithExecutor(.edit, on: task, context: ctx) { alert in
                        presentedAlert = true
                        currentAlert = alert
                    }
                    if !presentedAlert {
                        showingEditSheet = true
                    }
                } label: {
                    Image(systemName: "pencil")
                }

                // More â€” shared Quick Actions sheet (already executor-backed)
                Button {
                    showingMoreSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // Edit sheet (form-only)
        .sheet(isPresented: $showingEditSheet) {
            TaskEditView(task: task)
        }
        // Quick Actions / More sheet (routes via router internally)
        .sheet(isPresented: $showingMoreSheet) {
            TaskMoreActionsSheet(
                task: task,
                onEdit: { showingEditSheet = true },
                onAddSubtask: {
                    // If you still have a dedicated add-subtask flow, trigger it here.
                    // The router has already emitted `.addSubtask`.
                    showingMoreSheet = false
                }
            )
        }
        // Present any alerts triggered from this view (e.g., edit intent if it ever alerts)
        .taskActionAlert(alert: $currentAlert)
    }
}
