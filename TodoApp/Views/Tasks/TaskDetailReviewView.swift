import SwiftUI
import SwiftData

/// Review tab view - analytics and metrics (placeholder for future implementation)
struct TaskDetailReviewView: View {
    @Bindable var task: Task
    @Binding var currentAlert: TaskActionAlert?

    // Collapsible section states (passed through for Plan fallback)
    @Binding var isTimeTrackingExpanded: Bool
    @Binding var isPersonnelExpanded: Bool
    @Binding var isQuantityExpanded: Bool
    @Binding var isTagsExpanded: Bool
    @Binding var isSubtasksExpanded: Bool
    @Binding var isDependenciesExpanded: Bool
    @Binding var isNotesExpanded: Bool

    var body: some View {
        // TODO: Implement Review tab with analytics
        // For now, fall back to Plan tab content
        TaskDetailPlanView(
            task: task,
            currentAlert: $currentAlert,
            isTimeTrackingExpanded: $isTimeTrackingExpanded,
            isPersonnelExpanded: $isPersonnelExpanded,
            isQuantityExpanded: $isQuantityExpanded,
            isTagsExpanded: $isTagsExpanded,
            isSubtasksExpanded: $isSubtasksExpanded,
            isDependenciesExpanded: $isDependenciesExpanded,
            isNotesExpanded: $isNotesExpanded
        )
    }
}
