import SwiftUI

/// Due date and working window section for TaskComposerForm
/// Handles parent due date inheritance for subtasks and validation
/// Supports start date and end date for scheduled work periods
struct TaskComposerDueDateSection: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date
    @Binding var showingValidationAlert: Bool

    let isSubtask: Bool
    let parentDueDate: Date?
    let onDateChange: (Date) -> Void

    var body: some View {
        Section("Schedule") {
            if isSubtask {
                parentDueDateView
                if parentDueDate != nil {
                    Divider()
                }
            }

            // Due Date toggle and picker
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

            // Working window section (only show when not a subtask or has custom due date)
            if !isSubtask || hasDueDate {
                Divider()
                    .padding(.vertical, 4)

                workingWindowSection
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

    // MARK: - Working Window

    private var workingWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Info about working windows
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Schedule when work will be performed for accurate crew planning",
                style: .info
            )

            // Start Date
            Toggle("Set Start Date", isOn: $hasStartDate)

            if hasStartDate {
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: startDate) { oldValue, newValue in
                    // Auto-adjust end date if it's before start date
                    if hasEndDate && endDate < newValue {
                        endDate = newValue.addingTimeInterval(3600) // 1 hour later
                    }
                }
            }

            // End Date
            Toggle("Set End Date", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, isEnabled in
                    if isEnabled {
                        // Default end date to due date if available, otherwise 1 day from start
                        if hasDueDate {
                            endDate = dueDate
                        } else if hasStartDate {
                            endDate = startDate.addingTimeInterval(86400) // 24 hours
                        } else {
                            endDate = Date().addingTimeInterval(86400)
                        }
                    }
                }

            if hasEndDate {
                DatePicker(
                    "End Date",
                    selection: $endDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: endDate) { oldValue, newValue in
                    // Validate end > start
                    if hasStartDate && newValue < startDate {
                        endDate = startDate.addingTimeInterval(3600) // Reset to 1 hour after start
                    }
                }
            }

            // Show working window summary if both dates set
            if hasStartDate && hasEndDate {
                workingWindowSummary
            }

            // Validation hints
            if hasStartDate || hasEndDate {
                TaskInlineInfoRow(
                    icon: hasStartDate && hasEndDate ? "checkmark.circle" : "exclamationmark.triangle",
                    message: hasStartDate && hasEndDate
                        ? "Working window defined for crew planning"
                        : "Set both dates to use working window for calculations",
                    style: hasStartDate && hasEndDate ? .success : .warning
                )
            }
        }
    }

    @ViewBuilder
    private var workingWindowSummary: some View {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0

        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Working Window")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("\(days) \(days == 1 ? "day" : "days") • \(String(format: "%.1f", hours)) work hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
