import SwiftUI

/// Unified date input section for both Projects and Tasks
/// Provides consistent "button to add, swipe to delete" UX pattern
struct SharedDateSection: View {
    // MARK: - Bindings
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date

    // MARK: - Configuration
    let sectionTitle: String
    let includeTime: Bool  // false = date only (projects), true = date + time (tasks)
    let showWorkingWindow: Bool
    let validationContext: ValidationContext?
    let onEndDateChange: ((Date) -> Void)?

    // MARK: - Validation Context
    struct ValidationContext {
        let isSubtask: Bool
        let parentDueDate: Date?
        let selectedProject: Project?
    }

    // MARK: - State
    @State private var showingValidationAlert = false

    // MARK: - Calendar Helpers
    private var calendar: Calendar { Calendar.current }

    private func tomorrow() -> Date {
        calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private func oneDayBefore(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    // MARK: - DatePicker Components
    private var dateComponents: DatePickerComponents {
        includeTime ? [.date, .hourAndMinute] : [.date]
    }

    // MARK: - Project Date Conflict Detection
    private var startsBeforeProject: Bool {
        guard let context = validationContext,
              let project = context.selectedProject,
              let projectStart = project.startDate,
              hasStartDate else { return false }
        return startDate < projectStart
    }

    private var startsAfterProject: Bool {
        guard let context = validationContext,
              let project = context.selectedProject,
              let projectDue = project.dueDate,
              hasStartDate else { return false }
        return startDate > projectDue
    }

    private var endsBeforeProject: Bool {
        guard let context = validationContext,
              let project = context.selectedProject,
              let projectStart = project.startDate,
              hasEndDate else { return false }
        return endDate < projectStart
    }

    private var endsAfterProject: Bool {
        guard let context = validationContext,
              let project = context.selectedProject,
              let projectDue = project.dueDate,
              hasEndDate else { return false }
        return endDate > projectDue
    }

    // MARK: - Body
    var body: some View {
        Section(sectionTitle) {
            // Parent deadline info (for subtasks only)
            if let context = validationContext, context.isSubtask {
                parentDueDateView
            }

            // End date / Deadline
            if hasEndDate {
                endDateRow
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            hasEndDate = false
                            hasStartDate = false
                            HapticManager.light()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    }
            } else {
                setEndDateButton
            }

            // Start date (only shown when end date is set)
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

            // Working window summary
            if showWorkingWindow && hasStartDate && hasEndDate {
                workingWindowSummary
            }
        }
        .alert("Invalid Due Date", isPresented: $showingValidationAlert) {
            Button("OK") {
                if let context = validationContext, let parentDue = context.parentDueDate {
                    endDate = parentDue
                }
            }
        } message: {
            if let context = validationContext, let parentDue = context.parentDueDate {
                Text("Subtask due date cannot be later than parent's due date (\(parentDue.formatted(date: .abbreviated, time: .shortened))).")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var parentDueDateView: some View {
        if let context = validationContext, let parentDue = context.parentDueDate {
            TaskRowIconValueLabel(
                icon: "calendar.badge.clock",
                label: "Parent Deadline",
                value: parentDue.formatted(date: .abbreviated, time: .shortened),
                tint: .blue
            )
        } else if let context = validationContext, context.isSubtask {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Parent has no deadline set",
                style: .info
            )
        }
    }

    private var setEndDateButton: some View {
        Button {
            hasEndDate = true
            if endDate < Date() {
                endDate = includeTime
                    ? DateTimeHelper.smartDueDate(for: tomorrow())
                    : DateTimeHelper.smartDueDate(for: Date())
            } else {
                endDate = includeTime
                    ? DateTimeHelper.smartDueDate(for: endDate)
                    : endDate
            }
            HapticManager.light()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text(validationContext?.isSubtask == true ? "Set Custom Deadline" : "Set Deadline")
                    .foregroundStyle(.blue)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var endDateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                includeTime ? "Deadline" : "Due Date",
                selection: Binding(
                    get: { endDate },
                    set: { newValue in
                        let smartValue = includeTime
                            ? DateTimeHelper.smartDueDate(for: newValue)
                            : newValue
                        endDate = smartValue
                        onEndDateChange?(smartValue)

                        // Auto-adjust start date if it's after end date
                        if hasStartDate && startDate > smartValue {
                            startDate = includeTime
                                ? DateTimeHelper.smartStartDate(for: oneDayBefore(smartValue))
                                : oneDayBefore(smartValue)
                        }
                    }
                ),
                displayedComponents: dateComponents
            )
            .datePickerStyle(.compact)

            // Subtask validation warning
            if let context = validationContext, context.isSubtask, context.parentDueDate != nil {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Must be on or before parent's deadline",
                    style: .warning
                )
            }

            // Project conflict warnings
            if endsBeforeProject, let projectStart = validationContext?.selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Completes before project begins (\(projectStart.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }

            if endsAfterProject, let projectDue = validationContext?.selectedProject?.dueDate {
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
            let defaultDate = min(Date(), oneDayBefore(endDate))
            startDate = includeTime
                ? DateTimeHelper.smartStartDate(for: defaultDate)
                : defaultDate
            HapticManager.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text("Add Start Date")
                    .foregroundStyle(.blue)
                if includeTime {
                    Text("(for scheduled work)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var startDateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                "Start Date",
                selection: Binding(
                    get: { startDate },
                    set: { newValue in
                        let smartValue = includeTime
                            ? DateTimeHelper.smartStartDate(for: newValue)
                            : newValue
                        startDate = smartValue

                        // Ensure start is before end
                        if smartValue >= endDate {
                            startDate = endDate.addingTimeInterval(-3600)
                        }
                    }
                ),
                in: ...endDate,
                displayedComponents: dateComponents
            )
            .datePickerStyle(.compact)

            // Project conflict warnings
            if startsBeforeProject, let projectStart = validationContext?.selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts before project begins (\(projectStart.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }

            if startsAfterProject, let projectDue = validationContext?.selectedProject?.dueDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts after project completes (\(projectDue.formatted(date: .abbreviated, time: .omitted)))",
                    style: .warning
                )
            }
        }
    }

    private var workingWindowSummary: some View {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
        let workDays = hours / WorkHoursCalculator.workdayHours

        let daysText = workDays.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
            : String(format: "%.1f work days", workDays)

        return HStack(spacing: 8) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.caption)
                .foregroundStyle(.green)

            Text("Working Window")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(daysText) • \(String(format: "%.1f", hours)) hrs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
