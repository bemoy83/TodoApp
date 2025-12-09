import SwiftUI

/// Due date and working window section for TaskComposerForm
/// Thin wrapper around SharedDateSection with task-specific configuration
struct TaskComposerDueDateSection: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date
    @Binding var showingValidationAlert: Bool

    let isSubtask: Bool
    let parentStartDate: Date?
    let parentEndDate: Date?
    let selectedProject: Project? // For project date conflict detection
    let onDateChange: (Date) -> Void

    var body: some View {
        SharedDateSection(
            hasStartDate: $hasStartDate,
            startDate: $startDate,
            hasEndDate: $hasEndDate,
            endDate: $endDate,
            sectionTitle: "Schedule",
            includeTime: true,  // Date + time for tasks
            showWorkingWindow: true,
            validationContext: .init(
                isSubtask: isSubtask,
                parentStartDate: parentStartDate,
                parentEndDate: parentEndDate,
                selectedProject: selectedProject
            ),
            onEndDateChange: onDateChange
        )
        .onChange(of: hasEndDate) { _, newValue in
            // Sync legacy hasDueDate binding
            hasDueDate = newValue
        }
        .onChange(of: endDate) { _, newValue in
            // Sync legacy dueDate binding
            dueDate = newValue
        }
    }
}
