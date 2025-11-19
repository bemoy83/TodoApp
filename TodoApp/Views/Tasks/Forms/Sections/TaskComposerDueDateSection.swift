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

            // Info about scheduling
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Set deadline and optionally schedule when work will be performed",
                style: .info
            )

            Divider()
                .padding(.vertical, 4)

            // End Date (primary deadline)
            Toggle(isSubtask ? "Set Custom Deadline" : "Set Deadline", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, isEnabled in
                    // Sync with hasDueDate for backward compatibility
                    hasDueDate = isEnabled
                    if isEnabled {
                        // Default to current dueDate or reasonable default
                        if dueDate < Date() {
                            endDate = Date().addingTimeInterval(86400) // Tomorrow
                            dueDate = endDate
                        } else {
                            endDate = dueDate
                        }
                    }
                }

            if hasEndDate {
                DatePicker(
                    "Deadline",
                    selection: Binding(
                        get: { endDate },
                        set: { newValue in
                            endDate = newValue
                            dueDate = newValue // Keep in sync for backward compatibility
                            onDateChange(newValue)

                            // Auto-adjust start date if it's after deadline
                            if hasStartDate && startDate > newValue {
                                startDate = newValue.addingTimeInterval(-86400) // 1 day before
                            }
                        }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )

                if isSubtask, parentDueDate != nil {
                    TaskInlineInfoRow(
                        icon: "exclamationmark.triangle",
                        message: "Must be on or before parent's deadline",
                        style: .warning
                    )
                    .padding(.top, 4)
                }
            } else if isSubtask, parentDueDate != nil {
                TaskInlineInfoRow(
                    icon: "checkmark.circle",
                    message: "Will inherit parent's deadline",
                    style: .success
                )
            }

            // Start Date (optional - for scheduled work)
            if hasEndDate {
                Divider()
                    .padding(.vertical, 4)

                Toggle("Schedule Start Date", isOn: $hasStartDate)
                    .onChange(of: hasStartDate) { _, isEnabled in
                        if isEnabled {
                            // Default to 1 day before deadline or now
                            startDate = min(Date(), endDate.addingTimeInterval(-86400))
                        }
                    }

                if hasStartDate {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        in: ...endDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: startDate) { _, newValue in
                        // Ensure start is before end
                        if newValue >= endDate {
                            startDate = endDate.addingTimeInterval(-3600) // 1 hour before
                        }
                    }

                    TaskInlineInfoRow(
                        icon: "info.circle",
                        message: "For scheduled work periods with accurate crew planning",
                        style: .info
                    )
                    .padding(.top, 4)
                }

                // Show working window summary if both dates set
                if hasStartDate && hasEndDate {
                    Divider()
                        .padding(.vertical, 4)

                    workingWindowSummary
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var parentDueDateView: some View {
        if let parentDue = parentDueDate {
            TaskRowIconValueLabel(
                icon: "calendar.badge.clock",
                label: "Parent Deadline",
                value: parentDue.formatted(date: .abbreviated, time: .shortened),
                tint: .blue
            )
        } else {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Parent has no deadline set",
                style: .info
            )
        }
    }

    @ViewBuilder
    private var workingWindowSummary: some View {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0

        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.2.circlepath")
                .foregroundStyle(.green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Working Window")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Text("\(days) \(days == 1 ? "day" : "days") • \(String(format: "%.1f", hours)) work hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
