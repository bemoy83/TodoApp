import SwiftUI
import SwiftData

struct AddProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var projects: [Project]
    
    @State private var title = ""
    @State private var selectedColor = "#007AFF"
    @State private var startDate = DateTimeHelper.smartStartDate(for: Date())
    @State private var dueDate = DateTimeHelper.smartDueDate(for: Date())
    @State private var estimatedHours = ""
    @State private var status: ProjectStatus = .inProgress

    @State private var hasStartDate = false
    @State private var hasDueDate = false

    private let predefinedColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00",
        "#8E8E93", "#00C7BE"
    ]
    
    // Next order value for new project
    private var nextOrder: Int {
        let maxOrder = projects.map { $0.order ?? 0 }.max() ?? -1
        return maxOrder + 1
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
                            if newValue {
                                startDate = DateTimeHelper.smartStartDate(for: startDate)
                            }
                        }

                    if hasStartDate {
                        DatePicker(
                            "Start Date",
                            selection: Binding(
                                get: { startDate },
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
                            if newValue {
                                dueDate = DateTimeHelper.smartDueDate(for: dueDate)
                            }
                        }

                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { dueDate },
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DesignSystem.Spacing.lg) {
                        ForEach(predefinedColors, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: selectedColor == color
                            ) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addProject() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addProject() {
        let newProject = Project(
            title: title,
            color: selectedColor,
            order: nextOrder,
            startDate: hasStartDate ? startDate : nil,
            dueDate: hasDueDate ? dueDate : nil,
            estimatedHours: Double(estimatedHours),
            status: status
        )
        modelContext.insert(newProject)
        HapticManager.success()
        dismiss()
    }
}

#Preview("Project List with Projects") {
    // Show the sheet form in a preview-friendly wrapper
    struct Host: View {
        @State private var show = true
        var body: some View {
            NavigationStack {
                List { Text("Projects") }
                    .navigationTitle("Projects")
            }
            .sheet(isPresented: $show) { AddProjectSheet() }
            .onAppear { show = true }
        }
    }
    return Host()
        .modelContainer(for: [Project.self, Task.self, TimeEntry.self])
}
