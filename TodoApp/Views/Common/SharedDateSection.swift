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
        let parentStartDate: Date?
        let parentEndDate: Date?
        let selectedProject: Project?
    }

    // MARK: - State
    @State private var showingValidationAlert = false

    // MARK: - Constants
    private let calendar = Calendar.current

    private enum DateAdjustment {
        static let oneHourInSeconds: TimeInterval = 3600
    }

    private var abbreviatedDateFormatter: Date.FormatStyle {
        .dateTime.day().month(.abbreviated).year()
    }

    // MARK: - Calendar Helpers

    private func tomorrow() -> Date {
        calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private func oneDayBefore(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    // MARK: - Computed Properties
    private var dateComponents: DatePickerComponents {
        includeTime ? [.date, .hourAndMinute] : [.date]
    }

    private var selectedProject: Project? {
        validationContext?.selectedProject
    }

    private var workingWindowData: (hours: Double, daysText: String) {
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
        let workDays = hours / WorkHoursCalculator.workdayHours

        let daysText = workDays.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
            : String(format: "%.1f work days", workDays)

        return (hours, daysText)
    }

    // MARK: - Parent-Subtask Date Conflict Detection (Full Working Window)
    private var startsBeforeParent: Bool {
        guard let context = validationContext,
              context.isSubtask,
              hasStartDate,
              let parentStart = context.parentStartDate else { return false }
        return startDate < parentStart
    }

    private var endsBeforeParent: Bool {
        guard let context = validationContext,
              context.isSubtask,
              hasEndDate,
              let parentStart = context.parentStartDate else { return false }
        return endDate < parentStart
    }

    private var endsAfterParent: Bool {
        guard let context = validationContext,
              context.isSubtask,
              hasEndDate,
              let parentEnd = context.parentEndDate else { return false }
        return endDate > parentEnd
    }

    private var hasParentWorkingWindow: Bool {
        guard let context = validationContext,
              context.isSubtask else { return false }
        return context.parentStartDate != nil && context.parentEndDate != nil
    }

    // MARK: - Project Date Conflict Detection
    private var startsBeforeProject: Bool {
        guard let project = selectedProject,
              let projectStart = project.startDate,
              hasStartDate else { return false }
        return startDate < projectStart
    }

    private var startsAfterProject: Bool {
        guard let project = selectedProject,
              let projectDue = project.dueDate,
              hasStartDate else { return false }
        return startDate > projectDue
    }

    private var endsBeforeProject: Bool {
        guard let project = selectedProject,
              let projectStart = project.startDate,
              hasEndDate else { return false }
        return endDate < projectStart
    }

    private var endsAfterProject: Bool {
        guard let project = selectedProject,
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
        .alert("Invalid Date", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            if let context = validationContext, hasParentWorkingWindow {
                Text("Subtask dates must fall within parent's working window.")
            } else if let context = validationContext, let parentEnd = context.parentEndDate {
                Text("Subtask deadline cannot be later than parent's deadline (\(parentEnd.formatted(date: .abbreviated, time: .shortened))).")
            }
        }
    }

    // MARK: - Date Change Handlers

    /// Handles end date changes with smart defaults and auto-adjustments
    private func handleEndDateChange(_ newValue: Date) {
        let smartValue = includeTime
            ? DateTimeHelper.smartDueDate(for: newValue)
            : newValue

        // Validate against parent working window (for subtasks)
        if let context = validationContext,
           context.isSubtask,
           let parentEnd = context.parentEndDate,
           smartValue > parentEnd {
            // Show validation alert and don't update the date
            showingValidationAlert = true
            HapticManager.error()
            return
        }

        // CRITICAL: Validate that end date is not before parent's start date
        // This prevents fatal error when DatePicker tries to create invalid range (parentStart...endDate)
        if let context = validationContext,
           context.isSubtask,
           let parentStart = context.parentStartDate,
           smartValue < parentStart {
            // Show validation alert and don't update the date
            showingValidationAlert = true
            HapticManager.error()
            return
        }

        // Check if this change would require invalid start date adjustment
        if hasStartDate && startDate > smartValue {
            let proposedStartDate = includeTime
                ? DateTimeHelper.smartStartDate(for: oneDayBefore(smartValue))
                : oneDayBefore(smartValue)

            // For subtasks, ensure auto-adjusted start date would respect parent's start date
            if let context = validationContext,
               context.isSubtask,
               let parentStart = context.parentStartDate {
                // Check if proposed start date would violate parent's start date
                let clampedStartDate = max(proposedStartDate, parentStart)

                // Verify the clamped start date would still be before end date
                if clampedStartDate >= smartValue {
                    // Can't fit within constraints - show error
                    showingValidationAlert = true
                    HapticManager.error()
                    return
                }

                // Apply clamped start date
                startDate = clampedStartDate
            } else {
                // No parent constraint, just apply proposed start date
                startDate = proposedStartDate
            }
        }

        // All validations passed, update end date
        endDate = smartValue
        onEndDateChange?(smartValue)
    }

    /// Handles start date changes ensuring it stays before end date
    private func handleStartDateChange(_ newValue: Date) {
        let smartValue = includeTime
            ? DateTimeHelper.smartStartDate(for: newValue)
            : newValue

        // Validate against parent working window (for subtasks)
        if let context = validationContext,
           context.isSubtask,
           let parentStart = context.parentStartDate,
           smartValue < parentStart {
            // Show validation alert and don't update the date
            showingValidationAlert = true
            HapticManager.error()
            return
        }

        startDate = smartValue

        // Ensure start is before end
        if smartValue >= endDate {
            startDate = endDate.addingTimeInterval(-DateAdjustment.oneHourInSeconds)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var parentDueDateView: some View {
        if let context = validationContext {
            // Show full working window if both dates available
            if let parentStart = context.parentStartDate, let parentEnd = context.parentEndDate {
                VStack(alignment: .leading, spacing: 4) {
                    TaskRowIconValueLabel(
                        icon: "calendar.badge.clock",
                        label: "Parent Working Window",
                        value: "",
                        tint: .blue
                    )
                    HStack(spacing: 8) {
                        Text(parentStart.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(parentEnd.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }
            // Show just end date if only that's available
            else if let parentEnd = context.parentEndDate {
                TaskRowIconValueLabel(
                    icon: "calendar.badge.clock",
                    label: "Parent Deadline",
                    value: parentEnd.formatted(date: .abbreviated, time: .shortened),
                    tint: .blue
                )
            }
            // Show info if parent has no dates
            else if context.isSubtask {
                TaskInlineInfoRow(
                    icon: "info.circle",
                    message: "Parent has no schedule set",
                    style: .info
                )
            }
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
            // DatePicker with optional bounds for subtasks (parent start...parent end)
            if let context = validationContext,
               context.isSubtask,
               let parentStart = context.parentStartDate,
               let parentEnd = context.parentEndDate {
                // Full working window constraint
                DatePicker(
                    includeTime ? "Deadline" : "Due Date",
                    selection: Binding(
                        get: { endDate },
                        set: handleEndDateChange
                    ),
                    in: parentStart...parentEnd,
                    displayedComponents: dateComponents
                )
            } else if let context = validationContext,
                      context.isSubtask,
                      let parentEnd = context.parentEndDate {
                // Only upper bound (no parent start date)
                DatePicker(
                    includeTime ? "Deadline" : "Due Date",
                    selection: Binding(
                        get: { endDate },
                        set: handleEndDateChange
                    ),
                    in: ...parentEnd,
                    displayedComponents: dateComponents
                )
            } else {
                // No constraints
                DatePicker(
                    includeTime ? "Deadline" : "Due Date",
                    selection: Binding(
                        get: { endDate },
                        set: handleEndDateChange
                    ),
                    displayedComponents: dateComponents
                )
            }

            // Subtask validation warnings (only show if actually invalid)
            if endsBeforeParent, let context = validationContext, let parentStart = context.parentStartDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Ends before parent's start date (\(parentStart.formatted(date: .abbreviated, time: .shortened)))",
                    style: .warning
                )
            }

            if endsAfterParent, let context = validationContext, let parentEnd = context.parentEndDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Ends after parent's deadline (\(parentEnd.formatted(date: .abbreviated, time: .shortened)))",
                    style: .warning
                )
            }

            // Project conflict warnings
            if endsBeforeProject, let projectStart = selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Completes before project begins (\(projectStart.formatted(abbreviatedDateFormatter)))",
                    style: .warning
                )
            }

            if endsAfterProject, let projectDue = selectedProject?.dueDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Ends after project completes (\(projectDue.formatted(abbreviatedDateFormatter)))",
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
            // DatePicker with optional bounds for subtasks (parent start...end)
            if let context = validationContext,
               context.isSubtask,
               let parentStart = context.parentStartDate {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { startDate },
                        set: handleStartDateChange
                    ),
                    in: parentStart...endDate,
                    displayedComponents: dateComponents
                )
            } else {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { startDate },
                        set: handleStartDateChange
                    ),
                    in: ...endDate,
                    displayedComponents: dateComponents
                )
            }

            // Subtask validation warning (only show if actually invalid)
            if startsBeforeParent, let context = validationContext, let parentStart = context.parentStartDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts before parent's start date (\(parentStart.formatted(date: .abbreviated, time: .shortened)))",
                    style: .warning
                )
            }

            // Project conflict warnings
            if startsBeforeProject, let projectStart = selectedProject?.startDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts before project begins (\(projectStart.formatted(abbreviatedDateFormatter)))",
                    style: .warning
                )
            }

            if startsAfterProject, let projectDue = selectedProject?.dueDate {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle",
                    message: "Starts after project completes (\(projectDue.formatted(abbreviatedDateFormatter)))",
                    style: .warning
                )
            }
        }
    }

    private var workingWindowSummary: some View {
        let data = workingWindowData

        return HStack(spacing: 8) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.caption)
                .foregroundStyle(.green)

            Text("Working Window")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(data.daysText) • \(String(format: "%.1f", data.hours)) hrs")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
