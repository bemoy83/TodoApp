import SwiftUI

/// Due date section for TaskComposerForm
/// Handles parent due date inheritance for subtasks and validation
struct TaskComposerDueDateSection: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var showingValidationAlert: Bool

    let isSubtask: Bool
    let parentDueDate: Date?
    let onDateChange: (Date) -> Void

    var body: some View {
        Section("Due Date") {
            if isSubtask {
                parentDueDateView
                if parentDueDate != nil {
                    Divider()
                }
            }

            Toggle(isSubtask ? "Set Custom Due Date" : "Set Due Date", isOn: $hasDueDate)

            if hasDueDate {
                dueDatePickerView
                dueDateHintView
            } else if isSubtask, parentDueDate != nil {
                TaskInlineInfoRow(
                    icon: "checkmark.circle",
                    message: "Will inherit parent's due date",
                    style: .success
                )
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var parentDueDateView: some View {
        if let parentDue = parentDueDate {
            TaskRowIconValueLabel(
                icon: "calendar.badge.clock",
                label: "Parent Due Date",
                value: parentDue.formatted(date: .abbreviated, time: .shortened),
                tint: .blue
            )
        } else {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Parent has no due date set",
                style: .info
            )
        }
    }

    private var dueDatePickerView: some View {
        DatePicker(
            "Due Date",
            selection: $dueDate,
            displayedComponents: [.date, .hourAndMinute]
        )
        .onChange(of: dueDate) { _, newValue in
            onDateChange(newValue)
        }
    }

    @ViewBuilder
    private var dueDateHintView: some View {
        if isSubtask, parentDueDate != nil {
            TaskInlineInfoRow(
                icon: "exclamationmark.triangle",
                message: "Must be on or before parent's due date",
                style: .warning
            )
            .padding(.top, 4)
        }
    }
}
