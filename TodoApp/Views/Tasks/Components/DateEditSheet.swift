//
//  DateEditSheet.swift
//  TodoApp
//
//  Reusable sheet modal for editing task dates with smart defaults
//

import SwiftUI
import SwiftData

/// Reusable sheet modal for editing task start/end dates
/// Applies smart defaults and validation automatically
struct DateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // The task being edited
    let task: Task

    // Which date we're editing
    let dateType: DateEditType

    // State for the date being edited
    @State private var editedDate: Date
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    enum DateEditType {
        case start
        case end

        var title: String {
            switch self {
            case .start: return "Edit Start Date"
            case .end: return "Edit Due Date"
            }
        }

        var icon: String {
            switch self {
            case .start: return "calendar.badge.clock"
            case .end: return "calendar.badge.exclamationmark"
            }
        }
    }

    init(task: Task, dateType: DateEditType) {
        self.task = task
        self.dateType = dateType

        // Initialize with current value or smart default
        let initialDate: Date
        switch dateType {
        case .start:
            initialDate = task.startDate ?? DateTimeHelper.smartStartDate(for: Date())
        case .end:
            initialDate = task.endDate ?? DateTimeHelper.smartDueDate(for: Date().addingTimeInterval(86400))
        }
        _editedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Date Picker with smart defaults and parent-subtask constraints
                    datePickerWithConstraints

                } header: {
                    Label(
                        dateType == .start ? "Start Date & Time" : "Due Date & Time",
                        systemImage: dateType.icon
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        // Smart defaults explanation
                        let defaultTime = dateType == .start
                            ? WorkHoursCalculator.workdayStart
                            : WorkHoursCalculator.workdayEnd
                        let timeDescription = dateType == .start ? "start of workday" : "end of workday"

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.info)
                            Text("\(dateType == .start ? "Start dates" : "Due dates") automatically default to \(formatHour(defaultTime)) (\(timeDescription))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                        }

                        if showValidationError {
                            Text(validationMessage)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                    }
                }

                // Quick actions section
                Section {
                    quickActionButton(title: "Today", icon: "calendar", date: {
                        dateType == .start
                            ? DateTimeHelper.smartStartDate(for: Date())
                            : DateTimeHelper.smartDueDate(for: Date())
                    }())

                    quickActionButton(title: "Tomorrow", icon: "calendar.badge.plus", date: {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        return dateType == .start
                            ? DateTimeHelper.smartStartDate(for: tomorrow)
                            : DateTimeHelper.smartDueDate(for: tomorrow)
                    }())

                    quickActionButton(title: "Next Week", icon: "calendar.badge.clock", date: {
                        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        return dateType == .start
                            ? DateTimeHelper.smartStartDate(for: nextWeek)
                            : DateTimeHelper.smartDueDate(for: nextWeek)
                    }())

                } header: {
                    Label("Quick Actions", systemImage: "bolt.fill")
                }
            }
            .navigationTitle(dateType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.light()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDate()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var datePickerWithConstraints: some View {
        let parentTask = task.parentTask
        let isSubtask = parentTask != nil

        switch dateType {
        case .start:
            // Subtask start date: constrained by parent start...parent end
            if isSubtask,
               let parentStart = parentTask?.startDate,
               let parentEnd = parentTask?.effectiveDeadline {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartStartDate(for: $0) }
                    ),
                    in: parentStart...parentEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // Subtask with only parent start: constrained by parent start...task end
            else if isSubtask,
                    let parentStart = parentTask?.startDate,
                    let taskEnd = task.endDate {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartStartDate(for: $0) }
                    ),
                    in: parentStart...taskEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // Regular task or subtask without constraints: just constrained by task end
            else if let taskEnd = task.endDate {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartStartDate(for: $0) }
                    ),
                    in: ...taskEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // No constraints
            else {
                DatePicker(
                    "Start Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartStartDate(for: $0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }

        case .end:
            // Subtask end date: constrained by parent start...parent end
            if isSubtask,
               let parentStart = parentTask?.startDate,
               let parentEnd = parentTask?.effectiveDeadline {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartDueDate(for: $0) }
                    ),
                    in: parentStart...parentEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // Subtask with only parent end: constrained by task start...parent end
            else if isSubtask,
                    let parentEnd = parentTask?.effectiveDeadline,
                    let taskStart = task.startDate {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartDueDate(for: $0) }
                    ),
                    in: taskStart...parentEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // Subtask with only parent end (no task start): constrained by parent end
            else if isSubtask, let parentEnd = parentTask?.effectiveDeadline {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartDueDate(for: $0) }
                    ),
                    in: ...parentEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // Regular task: constrained by task start if exists
            else if let taskStart = task.startDate {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartDueDate(for: $0) }
                    ),
                    in: taskStart...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
            // No constraints
            else {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { editedDate },
                        set: { editedDate = DateTimeHelper.smartDueDate(for: $0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
            }
        }
    }

    private func quickActionButton(title: String, icon: String, date: Date) -> some View {
        Button {
            editedDate = date
            HapticManager.light()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(DesignSystem.Colors.secondary)
                Text(title)
                Spacer()
                Text(formatDate(date))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
    }

    // MARK: - Actions

    private func saveDate() {
        // Validate before saving
        if !validateDate() {
            showValidationError = true
            HapticManager.error()
            return
        }

        // Update the task
        switch dateType {
        case .start:
            task.startDate = editedDate
        case .end:
            task.endDate = editedDate
            task.dueDate = editedDate
        }

        // Save context
        do {
            try modelContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            validationMessage = "Failed to save: \(error.localizedDescription)"
            showValidationError = true
            HapticManager.error()
        }
    }

    private func validateDate() -> Bool {
        showValidationError = false

        // Get parent task for subtask validation
        let parentTask = task.parentTask
        let isSubtask = parentTask != nil

        switch dateType {
        case .start:
            // If end date exists, start must be before it
            if let endDate = task.endDate, editedDate >= endDate {
                validationMessage = "Start date must be before due date"
                return false
            }

            // SUBTASK VALIDATION: Start date must be on or after parent's start date
            if isSubtask, let parentStart = parentTask?.startDate, editedDate < parentStart {
                validationMessage = "Subtask cannot start before parent's start date (\(formatDate(parentStart)))"
                return false
            }

            // SUBTASK VALIDATION: Start date must be on or before parent's end date
            if isSubtask, let parentEnd = parentTask?.effectiveDeadline, editedDate > parentEnd {
                validationMessage = "Subtask start must be before parent's deadline (\(formatDate(parentEnd)))"
                return false
            }

        case .end:
            // If start date exists, end must be after it
            if let startDate = task.startDate, editedDate <= startDate {
                validationMessage = "Due date must be after start date"
                return false
            }

            // SUBTASK VALIDATION: End date must be on or before parent's end date
            if isSubtask, let parentEnd = parentTask?.effectiveDeadline, editedDate > parentEnd {
                validationMessage = "Subtask cannot end after parent's deadline (\(formatDate(parentEnd)))"
                return false
            }

            // CRITICAL SUBTASK VALIDATION: End date must be on or after parent's start date
            // This prevents the fatal error when adding a start date later
            if isSubtask, let parentStart = parentTask?.startDate, editedDate < parentStart {
                validationMessage = "Subtask cannot end before parent's start date (\(formatDate(parentStart)))"
                return false
            }
        }

        return true
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    DateEditSheet(
        task: Task(
            title: "Sample Task",
            priority: 1,
            endDate: Date().addingTimeInterval(86400),
            notes: "Test task for date editing"
        ),
        dateType: .end
    )
    .modelContainer(
        for: [Task.self, Project.self, TimeEntry.self],
        inMemory: true
    )
}
