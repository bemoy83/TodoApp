import SwiftUI
import SwiftData

/// A reusable, stateless form that mirrors TaskEditView's options.
/// It binds to "draft" fields supplied by a caller (Add or Edit screens).
struct TaskComposerForm: View {
    // Draft bindings
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedProject: Project?
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var priority: Int
    
    // NEW: Time estimate bindings
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasCustomEstimate: Bool

    // Personnel bindings
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    // Effort-based estimation bindings
    @Binding var estimateByEffort: Bool
    @Binding var effortHours: Double

    // Context
    let isSubtask: Bool
    let parentTask: Task?
    let editingTask: Task? // NEW: The task being edited (for checking its subtasks)
    
    // Project list for the picker (when not a subtask)
    @Query(sort: \Project.title) private var projects: [Project]
    
    // Query all tasks to calculate subtask estimates without accessing relationships
    @Query(sort: \Task.order) private var allTasks: [Task]
    
    @State private var showingDateValidationAlert = false
    @State private var showingEstimateValidationAlert = false
    @State private var estimateValidationMessage = ""
    
    private var inheritedProject: Project? {
        parentTask?.project
    }
    
    private var parentDueDate: Date? {
        parentTask?.dueDate
    }
    
    // Calculate subtask estimate total using @Query (avoids accessing relationships)
    // Returns total in MINUTES for display purposes
    private var taskSubtaskEstimateTotal: Int? {
        guard let task = editingTask else { return nil }
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        guard !subtasks.isEmpty else { return nil }

        let totalSeconds = subtasks.compactMap { $0.estimatedSeconds }.reduce(0, +)
        return totalSeconds / 60 // Convert to minutes for display
    }

    // For subtasks: show parent's total using @Query
    // Returns total in MINUTES for display purposes
    private var parentSubtaskEstimateTotal: Int? {
        guard let parent = parentTask else { return nil }
        let subtasks = allTasks.filter { $0.parentTask?.id == parent.id }
        guard !subtasks.isEmpty else { return nil }

        let totalSeconds = subtasks.compactMap { $0.estimatedSeconds }.reduce(0, +)
        return totalSeconds / 60 // Convert to minutes for display
    }
    
    var body: some View {
        Form {
            // Title
            Section("Task Details") {
                TextField("Title", text: $title)
                    .font(DesignSystem.Typography.body)
            }
            
            // Notes Section
            Section("Notes") {
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if notes.isEmpty {
                        Text("Add notes...")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.secondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    TextEditor(text: $notes)
                        .font(DesignSystem.Typography.body)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .opacity(notes.isEmpty ? 0.25 : 1)
                }
                .frame(height: 100)
            }
            
            // Project
            if isSubtask {
                Section("Project") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        
                        if let project = inheritedProject {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: project.color))
                                    .frame(width: 10, height: 10)
                                Text("\(project.title) (inherited from parent)")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("No project (inherited from parent)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Section("Project") {
                    Picker("Assign to Project", selection: $selectedProject) {
                        // No Project
                        HStack {
                            Circle()
                                .fill(.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                            Text("No Project")
                        }
                        .tag(nil as Project?)
                        
                        // Projects
                        ForEach(projects) { project in
                            HStack {
                                Circle()
                                    .fill(Color(hex: project.color))
                                    .frame(width: 12, height: 12)
                                Text(project.title)
                            }
                            .tag(project as Project?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            
            // Due date
            Section("Due Date") {
                if isSubtask {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let p = parentDueDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Parent due date:")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(p.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Parent has no due date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Toggle(isSubtask ? "Set Custom Due Date" : "Set Due Date", isOn: $hasDueDate)
                
                if hasDueDate {
                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: dueDate) { _, newValue in
                        validateSubtaskDueDate(newValue)
                    }
                    
                    if isSubtask, parentDueDate != nil {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text("Must be on or before parent's due date")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                } else if isSubtask, parentDueDate != nil {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("Will inherit parent's due date")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                }
            }
            
            // Time Estimate Section
            Section("Time Estimate") {
                // Estimation mode selector
                Picker("Estimation Mode", selection: $estimateByEffort) {
                    Text("By Duration").tag(false)
                    Text("By Effort").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                // Show parent's auto-calculated estimate if subtask (duration mode only)
                if !estimateByEffort && isSubtask, let parentTotal = parentSubtaskEstimateTotal, parentTotal > 0 {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent's estimate (from subtasks):")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text((parentTotal * 60).formattedTime())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // DURATION MODE
                if !estimateByEffort {
                    // UPDATED: Contextual toggle based on whether task has subtasks with estimates
                    // If parent with subtask estimates → "Override Subtask Estimates"
                    // Otherwise → "Set Time Estimate"
                    let hasSubtasksWithEstimates = !isSubtask && (taskSubtaskEstimateTotal ?? 0) > 0
                
                if hasSubtasksWithEstimates {
                    // Parent task with subtasks - show override toggle
                    Toggle("Override Subtask Estimates", isOn: $hasEstimate)
                        .onChange(of: hasEstimate) { _, newValue in
                            hasCustomEstimate = newValue
                            if newValue {
                                validateEstimate()
                            }
                        }
                    
                    if !hasEstimate {
                        // Show auto-calculated info when NOT overriding
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .padding(.top, 2)
                            Text("Auto-calculated from subtasks: \(((taskSubtaskEstimateTotal ?? 0) * 60).formattedTime())")
                                .font(.caption2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.green)
                    }
                } else {
                    // Regular task or parent without subtask estimates - standard toggle
                    Toggle("Set Time Estimate", isOn: $hasEstimate)
                        .onChange(of: hasEstimate) { _, newValue in
                            hasCustomEstimate = false // Regular tasks don't use custom flag
                        }
                }
                
                // Show pickers when estimate is enabled
                if hasEstimate {
                    // Native iOS-style time picker (like the Clock app)
                    DatePicker(
                        "Set Time Estimate",
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    from: DateComponents(
                                        hour: estimateHours,
                                        minute: estimateMinutes
                                    )
                                ) ?? Date()
                            },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                estimateHours = components.hour ?? 0
                                estimateMinutes = components.minute ?? 0
                                validateEstimate()
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onAppear {
                        // Clamp to safe range
                        estimateHours = min(max(estimateHours, 0), 99)
                        estimateMinutes = min(max(estimateMinutes, 0), 59)
                    }

                    // Show calculated total below
                    let totalMinutes = (estimateHours * 60) + estimateMinutes
                    if totalMinutes > 0 {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Total: \((totalMinutes * 60).formattedTime())")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption2)
                            Text("Setting 0 time will remove the estimate")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }

                    // Show override warning when parent overriding subtasks
                    if hasSubtasksWithEstimates {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .padding(.top, 2)
                            Text("Custom estimate will be used instead of auto-calculated \(((taskSubtaskEstimateTotal ?? 0) * 60).formattedTime()) from subtasks")
                                .font(.caption2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.orange)
                    }
                }
                } // End Duration Mode

                // EFFORT MODE
                else {
                    EffortInputSection(
                        effortHours: $effortHours,
                        hasPersonnel: $hasPersonnel,
                        expectedPersonnelCount: $expectedPersonnelCount,
                        hasDueDate: $hasDueDate,
                        dueDate: dueDate
                    )
                }

            }

            // Priority
            Section("Priority") {
                Picker("Priority Level", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        HStack {
                            Circle()
                                .fill(p.color)
                                .frame(width: 12, height: 12)
                            Text(p.label)
                        }
                        .tag(p.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            // Personnel
            Section("Personnel") {
                Toggle("Set Expected Personnel", isOn: $hasPersonnel)

                // Show picker when personnel is enabled
                if hasPersonnel {
                    Picker("Expected crew size", selection: Binding(
                        get: { expectedPersonnelCount ?? 1 },
                        set: { expectedPersonnelCount = $0 }
                    )) {
                        ForEach(1...20, id: \.self) { count in
                            Text("\(count) \(count == 1 ? "person" : "people")")
                                .tag(count)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)

                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("Pre-fills time entry forms with this count")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("Defaults to 1 person if not set")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Invalid Due Date", isPresented: $showingDateValidationAlert) {
            Button("OK") {
                if let parentDue = parentDueDate {
                    dueDate = parentDue
                }
            }
        } message: {
            if let parentDue = parentDueDate {
                Text("Subtask due date cannot be later than parent's due date (\(parentDue.formatted(date: .abbreviated, time: .shortened))).")
            }
        }
        .alert("Invalid Time Estimate", isPresented: $showingEstimateValidationAlert) {
            Button("OK") {
                // Reset to subtask total
                if let total = taskSubtaskEstimateTotal {
                    estimateHours = total / 60
                    estimateMinutes = (total % 60)
                    // Round minutes to nearest 15
                    let roundedMinutes = ((estimateMinutes + 7) / 15) * 15
                    estimateMinutes = roundedMinutes
                    if roundedMinutes >= 60 {
                        estimateHours += 1
                        estimateMinutes = 0
                    }
                }
            }
        } message: {
            Text(estimateValidationMessage)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func validateSubtaskDueDate(_ newDate: Date) {
        guard isSubtask, let parentDue = parentDueDate else { return }
        if newDate > parentDue {
            showingDateValidationAlert = true
        }
    }
    
    private func validateEstimate() {
        guard !isSubtask, hasCustomEstimate else { return }
        guard let subtaskTotal = taskSubtaskEstimateTotal, subtaskTotal > 0 else { return }
        
        let totalMinutes = (estimateHours * 60) + estimateMinutes

        if totalMinutes > 0 && totalMinutes < subtaskTotal {
            estimateValidationMessage = "Custom estimate (\((totalMinutes * 60).formattedTime())) cannot be less than subtask estimates total (\((subtaskTotal * 60).formattedTime()))."
            showingEstimateValidationAlert = true
        }
    }
}
