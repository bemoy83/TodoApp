import SwiftUI

struct EditProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

    @State private var title: String
    @State private var selectedColor: String
    @State private var startDate: Date?
    @State private var dueDate: Date?
    @State private var estimatedHours: String
    @State private var status: ProjectStatus

    @State private var hasStartDate: Bool
    @State private var hasDueDate: Bool

    // If you had ColorButton in the old file, it still works from here.
    private let predefinedColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00",
        "#8E8E93", "#00C7BE"
    ]

    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _selectedColor = State(initialValue: project.color)
        _startDate = State(initialValue: project.startDate)
        _dueDate = State(initialValue: project.dueDate)
        _estimatedHours = State(initialValue: project.estimatedHours != nil ? String(format: "%.0f", project.estimatedHours!) : "")
        _status = State(initialValue: project.status)
        _hasStartDate = State(initialValue: project.startDate != nil)
        _hasDueDate = State(initialValue: project.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $title)

                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                Section("Event Scheduling") {
                    // Start Date
                    Toggle("Set Start Date", isOn: $hasStartDate)
                        .onChange(of: hasStartDate) { oldValue, newValue in
                            if newValue && startDate == nil {
                                startDate = DateTimeHelper.smartStartDate(for: Date())
                            }
                        }

                    if hasStartDate {
                        DatePicker(
                            "Start Date",
                            selection: Binding(
                                get: { startDate ?? DateTimeHelper.smartStartDate(for: Date()) },
                                set: { newValue in
                                    startDate = DateTimeHelper.smartStartDate(for: newValue)
                                }
                            ),
                            displayedComponents: [.date]
                        )
                    }

                    // Due Date
                    Toggle("Set Due Date", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { oldValue, newValue in
                            if newValue && dueDate == nil {
                                dueDate = DateTimeHelper.smartDueDate(for: Date())
                            }
                        }

                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { dueDate ?? DateTimeHelper.smartDueDate(for: Date()) },
                                set: { newValue in
                                    dueDate = DateTimeHelper.smartDueDate(for: newValue)
                                }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Budget") {
                    HStack {
                        TextField("Estimated Hours", text: $estimatedHours)
                            .keyboardType(.decimalPad)

                        Text("hours")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))],
                              spacing: DesignSystem.Spacing.lg) {
                        ForEach(predefinedColors, id: \.self) { color in
                            ColorButton(color: color,
                                        isSelected: selectedColor == color) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        project.title = title
        project.color = selectedColor
        project.status = status

        // Save dates
        project.startDate = hasStartDate ? startDate : nil
        project.dueDate = hasDueDate ? dueDate : nil

        // Save estimated hours
        if let hours = Double(estimatedHours), hours > 0 {
            project.estimatedHours = hours
        } else {
            project.estimatedHours = nil
        }

        dismiss()
    }
}
