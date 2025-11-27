import SwiftUI

/// Due date and working window section for TaskComposerForm
/// Handles parent due date inheritance for subtasks and validation
/// Supports start date and end date for scheduled work periods
/// Real-time warnings for project date conflicts (Improvement #3)
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
    let selectedProject: Project? // For project date conflict detection
    let onDateChange: (Date) -> Void

    // MARK: - Calendar Helpers

    private var calendar: Calendar { Calendar.current }

    private func tomorrow() -> Date {
        calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private func oneDayBefore(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    // MARK: - Project Date Conflict Detection (Real-time Warning)

    /// Check if start date conflicts with project start date
    private var startsBeforeProject: Bool {
        guard let project = selectedProject,
              let projectStart = project.startDate,
              hasStartDate else { return false }
        return startDate < projectStart
    }

    /// Check if start date is after project due date (starts after event ends!)
    private var startsAfterProject: Bool {
        guard let project = selectedProject,
              let projectDue = project.dueDate,
              hasStartDate else { return false }
        return startDate > projectDue
    }

    /// Check if due date is before project start date (completes before event begins!)
    private var endsBeforeProject: Bool {
        guard let project = selectedProject,
              let projectStart = project.startDate,
              hasDueDate || hasEndDate else { return false }
        let taskEnd = hasEndDate ? endDate : dueDate
        return taskEnd < projectStart
    }

    /// Check if due date conflicts with project due date
    private var endsAfterProject: Bool {
        guard let project = selectedProject,
              let projectDue = project.dueDate,
              hasDueDate || hasEndDate else { return false }
        let taskEnd = hasEndDate ? endDate : dueDate
        return taskEnd > projectDue
    }

    /// Has any project date conflicts
    private var hasProjectConflicts: Bool {
        startsBeforeProject || startsAfterProject || endsBeforeProject || endsAfterProject
    }

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
                endDate = tomorrow()
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
                            startDate = oneDayBefore(newValue)
                        }
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            // Subtask validation warning
            if isSubtask, parentDueDate != nil {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Must be on or before parent's deadline",
                    style: .warning
                )
            }

            // Real-time warning: due date before project start
            if endsBeforeProject, let projectStart = selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Completes before project begins (\(projectStart.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }

            // Real-time warning: due date after project end
            if endsAfterProject, let projectDue = selectedProject?.dueDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Ends after project completes (\(projectDue.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }
        }
    }

    private var addStartDateButton: some View {
        Button {
            hasStartDate = true
            startDate = min(Date(), oneDayBefore(endDate))
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
        VStack(alignment: .leading, spacing: 6) {
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

            // Real-time warning: start date before project start
            if startsBeforeProject, let projectStart = selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts before project begins (\(projectStart.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }

            // Real-time warning: start date after project end
            if startsAfterProject, let projectDue = selectedProject?.dueDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts after project ends (\(projectDue.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }
        }
    }

    @ViewBuilder
    private var workingWindowSummary: some View {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)

        // Calculate work days based on actual work hours (not calendar days)
        let workDays = hours / WorkHoursCalculator.workdayHours

        // Format work days nicely (show 1 decimal place if not a whole number)
        let daysText: String
        if workDays.truncatingRemainder(dividingBy: 1) == 0 {
            daysText = "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
        } else {
            daysText = String(format: "%.1f work days", workDays)
        }

        TaskRowIconValueLabel(
            icon: "clock.arrow.2.circlepath",
            label: "\(daysText) • \(String(format: "%.1f", hours)) work hours available",
            value: "Working Window",
            tint: .green
        )
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.08))
        )
    }
}
