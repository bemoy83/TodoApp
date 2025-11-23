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
            // Parent deadline info for subtasks
            if isSubtask {
                parentDueDateView
            }

            // Deadline (always visible or with set option)
            if hasEndDate {
                deadlineRow
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            hasEndDate = false
                            hasDueDate = false
                            hasStartDate = false
                            HapticManager.light()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    }
            } else {
                setDeadlineButton
            }

            // Start date (only shown when deadline is set)
            if hasEndDate && hasStartDate {
                startDateRow
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            hasStartDate = false
                            HapticManager.light()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            } else if hasEndDate {
                addStartDateButton
            }

            // Working window summary at bottom (result of inputs above)
            if hasStartDate && hasEndDate {
                workingWindowSummary
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

    private var setDeadlineButton: some View {
        Button {
            hasEndDate = true
            hasDueDate = true
            if dueDate < Date() {
                endDate = Date().addingTimeInterval(86400) // Tomorrow
                dueDate = endDate
            } else {
                endDate = dueDate
            }
            HapticManager.light()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text(isSubtask ? "Set Custom Deadline" : "Set Deadline")
                    .foregroundStyle(.blue)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var deadlineRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                "Deadline",
                selection: Binding(
                    get: { endDate },
                    set: { newValue in
                        endDate = newValue
                        dueDate = newValue
                        onDateChange(newValue)

                        // Auto-adjust start date if it's after deadline
                        if hasStartDate && startDate > newValue {
                            startDate = newValue.addingTimeInterval(-86400)
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
            }
        }
    }

    private var addStartDateButton: some View {
        Button {
            hasStartDate = true
            startDate = min(Date(), endDate.addingTimeInterval(-86400))
            HapticManager.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text("Add Start Date")
                    .foregroundStyle(.blue)
                Text("(for scheduled work)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var startDateRow: some View {
        DatePicker(
            "Start Date",
            selection: $startDate,
            in: ...endDate,
            displayedComponents: [.date, .hourAndMinute]
        )
        .onChange(of: startDate) { _, newValue in
            if newValue >= endDate {
                startDate = endDate.addingTimeInterval(-3600)
            }
        }
    }

    @ViewBuilder
    private var workingWindowSummary: some View {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)

        // Calculate days: if same calendar day with work hours, count as 1 day
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let isSameDay = calendar.isDate(startDate, inSameDayAs: endDate)
        let days = (isSameDay && hours > 0) ? 1 : max(1, daysDifference)

        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Working Window")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Text("\(days) \(days == 1 ? "day" : "days") • \(String(format: "%.1f", hours)) work hours available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.08))
        )
    }
}
