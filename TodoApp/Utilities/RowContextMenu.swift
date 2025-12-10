import SwiftUI
import SwiftData

/// Router-backed context menu using the new Executor + Alerts path.
/// - Edit/More are navigation intents (caller handles presentation).
/// - Delete confirms via alert (surfaced through the provided binding).
struct RowContextMenu: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: Task
    let isEnabled: Bool
    let onEdit: () -> Void
    let onMore: (() -> Void)?
    let onAddSubtask: (() -> Void)?

    /// Optional alert binding for router-driven alerts.
    let alert: Binding<TaskActionAlert?>?

    private let router = TaskActionRouter()

    // State for custom pickers
    @State private var showingCustomDatePicker = false
    @State private var showingCustomEstimatePicker = false
    @State private var showingTagPicker = false

    func body(content: Content) -> some View {
        Group {
            if isEnabled {
                content.contextMenu {
                    // Edit (navigation intent - just show sheet)
                    Button {
                        onEdit()  // ✅ Simplified
                    } label: { Label("Edit", systemImage: "pencil") }
                    .accessibilityLabel("Edit Task")

                    // Set Priority (submenu)
                    Menu {
                        ForEach(Priority.allCases, id: \.self) { level in
                            Button {
                                _ = router.performWithExecutor(.setPriority(level.rawValue), on: task, context: ctx) { a in
                                    alert?.wrappedValue = a
                                }
                            } label: {
                                Label(level.label, systemImage: level.icon)
                            }
                        }
                    } label: {
                        Label("Set Priority", systemImage: "flag")
                    }

                    // Set Due Date (submenu with presets)
                    Menu {
                        Button {
                            setDueDateIfValid(Calendar.current.startOfDay(for: Date()))
                        } label: {
                            Label("Today", systemImage: "calendar")
                        }

                        Button {
                            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) {
                                setDueDateIfValid(tomorrow)
                            }
                        } label: {
                            Label("Tomorrow", systemImage: "calendar")
                        }

                        Button {
                            if let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) {
                                setDueDateIfValid(nextWeek)
                            }
                        } label: {
                            Label("Next Week", systemImage: "calendar")
                        }

                        Button {
                            showingCustomDatePicker = true
                        } label: {
                            Label("Custom...", systemImage: "calendar.badge.clock")
                        }

                        if task.effectiveDeadline != nil {
                            Button(role: .destructive) {
                                task.endDate = nil
                            } label: {
                                Label("Clear Due Date", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Set Due Date", systemImage: "calendar")
                    }

                    // Set Estimate (submenu with presets)
                    Menu {
                        Button {
                            task.estimatedSeconds = 30 * 60 // 30 minutes in seconds
                            task.hasCustomEstimate = true
                        } label: {
                            Label("30 minutes", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 60 * 60 // 1 hour
                            task.hasCustomEstimate = true
                        } label: {
                            Label("1 hour", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 2 * 60 * 60 // 2 hours
                            task.hasCustomEstimate = true
                        } label: {
                            Label("2 hours", systemImage: "clock")
                        }

                        Button {
                            task.estimatedSeconds = 4 * 60 * 60 // 4 hours
                            task.hasCustomEstimate = true
                        } label: {
                            Label("4 hours", systemImage: "clock")
                        }

                        Button {
                            showingCustomEstimatePicker = true
                        } label: {
                            Label("Custom...", systemImage: "clock.badge.questionmark")
                        }

                        if task.estimatedSeconds != nil {
                            Button(role: .destructive) {
                                task.estimatedSeconds = nil
                                task.hasCustomEstimate = false
                            } label: {
                                Label("Clear Estimate", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Set Estimate", systemImage: "clock")
                    }

                    // Manage Tags
                    Button {
                        showingTagPicker = true
                    } label: {
                        Label("Manage Tags", systemImage: "tag")
                    }

                    // Add Subtask (only for parent tasks)
                    if task.parentTask == nil, let onAddSubtask {
                        Button {
                            onAddSubtask()
                        } label: {
                            Label("Add Subtask", systemImage: "plus.circle")
                        }
                        .accessibilityLabel("Add Subtask")
                    }

                    // Complete / Uncomplete (uses router)
                    Button {
                        let action: TaskAction = task.isCompleted ? .uncomplete : .complete
                        _ = router.performWithExecutor(action, on: task, context: ctx) { a in
                            alert?.wrappedValue = a
                        }
                    } label: {
                        Label(task.isCompleted ? "Uncomplete" : "Complete",
                              systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                    }
                    .accessibilityLabel(task.isCompleted ? "Uncomplete Task" : "Complete Task")

                    // More (navigation intent - just show sheet)
                    if let onMore {
                        Button {
                            onMore()  // ✅ Simplified
                        } label: { Label("More", systemImage: "ellipsis.circle") }
                        .accessibilityLabel("More Actions")
                    }

                    // Archive (only for completed tasks)
                    if task.isCompleted {
                        Button {
                            _ = router.performWithExecutor(.archive, on: task, context: ctx) { a in
                                alert?.wrappedValue = a
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .accessibilityLabel("Archive Task")
                    }

                    // Delete (uses router with confirmation)
                    Button(role: .destructive) {
                        _ = router.performWithExecutor(.delete, on: task, context: ctx) { a in
                            alert?.wrappedValue = a
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(DesignSystem.Colors.error)
                    .accessibilityLabel("Delete Task")
                }
            } else {
                content
            }
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            CustomDatePickerSheet(task: task)
        }
        .sheet(isPresented: $showingCustomEstimatePicker) {
            CustomEstimatePickerSheet(task: task)
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerSheet(task: task)
        }
    }

    private var ctx: TaskActionRouter.Context {
        .init(modelContext: modelContext, hapticsEnabled: true)
    }

    /// Validates and sets due date, respecting parent/subtask relationships
    private func setDueDateIfValid(_ newDate: Date) {
        // If this is a subtask, validate against parent's due date
        if let parentDueDate = task.parentTask?.effectiveDeadline, newDate > parentDueDate {
            // Show alert about validation failure
            alert?.wrappedValue = TaskActionAlert(
                title: "Invalid Due Date",
                message: "Subtask due date must be on or before parent's due date (\(parentDueDate.formatted(date: .abbreviated, time: .shortened))).",
                actions: [
                    AlertAction(title: "OK", role: .cancel, action: {})
                ]
            )
        } else {
            task.endDate = newDate
        }
    }
}

// MARK: - Convenience helpers
extension View {
    /// Preferred: alert-enabled context menu.
    func rowContextMenu(
        task: Task,
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onMore: (() -> Void)? = nil,
        onAddSubtask: (() -> Void)? = nil,
        alert: Binding<TaskActionAlert?> // NEW
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                onAddSubtask: onAddSubtask,
                                alert: alert))
    }

    /// Back-compat shim (no alerts).
    func rowContextMenu(
        task: Task,
        isEnabled: Bool,
        onEdit: @escaping () -> Void,
        onMore: (() -> Void)? = nil,
        onAddSubtask: (() -> Void)? = nil
    ) -> some View {
        modifier(RowContextMenu(task: task,
                                isEnabled: isEnabled,
                                onEdit: onEdit,
                                onMore: onMore,
                                onAddSubtask: onAddSubtask,
                                alert: nil))
    }
}

// MARK: - Custom Picker Sheets

private struct CustomDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task

    @State private var selectedDate: Date
    @State private var showValidationAlert = false

    init(task: Task) {
        self.task = task
        self._selectedDate = State(initialValue: task.effectiveDeadline ?? Date())
    }

    private var parentDueDate: Date? {
        task.parentTask?.effectiveDeadline
    }

    var body: some View {
        NavigationStack {
            Form {
                if let parentDue = parentDueDate {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Parent's due date:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(parentDue.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                Section {
                    DatePicker(
                        "Due Date",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if parentDueDate != nil {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("Must be on or before parent's due date")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Set Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        if let parentDue = parentDueDate, selectedDate > parentDue {
                            showValidationAlert = true
                        } else {
                            task.endDate = selectedDate
                            dismiss()
                        }
                    }
                }
            }
            .alert("Invalid Due Date", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let parentDue = parentDueDate {
                    Text("Subtask due date must be on or before parent's due date (\(parentDue.formatted(date: .abbreviated, time: .shortened))).")
                }
            }
        }
    }
}

private struct CustomEstimatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task

    @State private var hours: Int
    @State private var minutes: Int

    init(task: Task) {
        self.task = task
        let estimateMinutes = (task.estimatedSeconds ?? 0) / 60
        self._hours = State(initialValue: estimateMinutes / 60)
        self._minutes = State(initialValue: estimateMinutes % 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Native iOS-style time picker matching TaskComposerForm
                    DatePicker(
                        "Set Time Estimate",
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    from: DateComponents(
                                        hour: hours,
                                        minute: minutes
                                    )
                                ) ?? Date()
                            },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                hours = components.hour ?? 0
                                minutes = components.minute ?? 0
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Total: \(formatTime())")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .navigationTitle("Set Time Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        let totalMinutes = (hours * 60) + minutes
                        let totalSeconds = totalMinutes * 60
                        task.estimatedSeconds = totalSeconds > 0 ? totalSeconds : nil
                        task.hasCustomEstimate = totalSeconds > 0
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatTime() -> String {
        let totalMinutes = (hours * 60) + minutes
        if totalMinutes == 0 {
            return "0 minutes"
        }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }
}

private struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task

    var body: some View {
        TagPickerView(task: task)
    }
}
