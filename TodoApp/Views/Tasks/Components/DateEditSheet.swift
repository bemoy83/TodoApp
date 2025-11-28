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
                    // Date Picker with smart defaults
                    DatePicker(
                        dateType == .start ? "Start Date" : "Due Date",
                        selection: Binding(
                            get: { editedDate },
                            set: { newValue in
                                // Apply smart defaults based on date type
                                editedDate = dateType == .start
                                    ? DateTimeHelper.smartStartDate(for: newValue)
                                    : DateTimeHelper.smartDueDate(for: newValue)
                            }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)

                } header: {
                    Label(
                        dateType == .start ? "Start Date & Time" : "Due Date & Time",
                        systemImage: dateType.icon
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if DateTimeHelper.isFutureDate(editedDate) {
                            let defaultTime = dateType == .start
                                ? WorkHoursCalculator.workdayStart
                                : WorkHoursCalculator.workdayEnd
                            Text("Future dates default to \(formatHour(defaultTime))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.info)
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

        switch dateType {
        case .start:
            // If end date exists, start must be before it
            if let endDate = task.endDate, editedDate >= endDate {
                validationMessage = "Start date must be before due date"
                return false
            }

        case .end:
            // If start date exists, end must be after it
            if let startDate = task.startDate, editedDate <= startDate {
                validationMessage = "Due date must be after start date"
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let context = container.mainContext

    let task = Task(
        title: "Sample Task",
        priority: 1,
        notes: "Test task for date editing"
    )
    task.endDate = Date().addingTimeInterval(86400)
    context.insert(task)

    DateEditSheet(task: task, dateType: .end)
        .modelContainer(container)
}
