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

    // Unified calculator bindings
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode
    @Binding var effortHours: Double
    @Binding var quantity: String // String for text field input
    @Binding var unit: UnitType
    @Binding var taskType: String?
    @Binding var quantityCalculationMode: TaskEstimator.QuantityCalculationMode
    @Binding var productivityRate: Double?

    // Context
    let isSubtask: Bool
    let parentTask: Task?
    let editingTask: Task? // NEW: The task being edited (for checking its subtasks)

    // Project list for the picker (when not a subtask)
    @Query(sort: \Project.title) private var projects: [Project]

    // Query all tasks to calculate subtask estimates without accessing relationships
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    // Query templates for task type selection
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]

    @State private var showingDateValidationAlert = false
    @State private var showingEstimateValidationAlert = false
    @State private var estimateValidationMessage = ""

    // Calculator state
    @State private var historicalProductivity: Double?

    // MARK: - Computed Properties

    private var inheritedProject: Project? {
        parentTask?.project
    }

    /// Personnel is auto-calculated (read-only) when in certain modes
    private var personnelIsAutoCalculated: Bool {
        switch unifiedEstimationMode {
        case .duration:
            return false // Manual mode
        case .effort:
            return false // Effort mode uses manual personnel input
        case .quantity:
            return quantityCalculationMode == .calculatePersonnel
        }
    }

    /// Whether quantity tracking is active
    private var hasQuantity: Bool {
        unifiedEstimationMode == .quantity
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

    // MARK: - Helper Methods

    /// Update duration fields from effort calculation
    private func updateDurationFromEffort() {
        guard unifiedEstimationMode == .effort,
              effortHours > 0,
              let personnel = expectedPersonnelCount, personnel > 0 else {
            return
        }

        // Calculate duration: effort / personnel
        let durationHours = effortHours / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        // Update duration fields
        estimateHours = totalSeconds / 3600
        estimateMinutes = (totalSeconds % 3600) / 60
        hasEstimate = true
    }

    /// Update fields from quantity calculation
    private func updateFromQuantityCalculation() {
        guard unifiedEstimationMode == .quantity,
              let qty = Double(quantity), qty > 0,
              let rate = productivityRate, rate > 0 else {
            return
        }

        switch quantityCalculationMode {
        case .calculateDuration:
            // Calculate duration from quantity + personnel
            guard let personnel = expectedPersonnelCount, personnel > 0 else { return }
            let durationHours = (qty / rate) / Double(personnel)
            let totalSeconds = Int(durationHours * 3600)

            estimateHours = totalSeconds / 3600
            estimateMinutes = (totalSeconds % 3600) / 60
            hasEstimate = true
            hasPersonnel = true

        case .calculatePersonnel:
            // Calculate personnel from quantity + duration
            let totalDurationHours = Double(estimateHours) + (Double(estimateMinutes) / 60.0)
            guard totalDurationHours > 0 else { return }

            let personnel = Int(ceil((qty / rate) / totalDurationHours))
            expectedPersonnelCount = max(1, personnel)
            hasPersonnel = true
            hasEstimate = true

        case .manualEntry:
            // No automatic calculation - productivity calculated on completion
            break
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var quantityCalculatorView: some View {
        // Task Type picker (templates)
        Picker("Task Type", selection: $taskType) {
            Text("None").tag(nil as String?)
            ForEach(templates) { template in
                HStack {
                    Image(systemName: template.defaultUnit.icon)
                    Text(template.name)
                }
                .tag(template.name as String?)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: taskType) { oldValue, newValue in
            // Auto-populate unit when template is selected
            if let selectedTaskType = newValue,
               let template = templates.first(where: { $0.name == selectedTaskType }) {
                unit = template.defaultUnit

                // Fetch historical productivity
                historicalProductivity = TemplateManager.getHistoricalProductivity(
                    for: selectedTaskType,
                    unit: template.defaultUnit,
                    from: allTasks
                ) ?? template.defaultUnit.defaultProductivityRate

                productivityRate = historicalProductivity
            }
        }

        // Show unit (read-only if from template)
        if taskType != nil {
            HStack {
                Text("Unit")
                Spacer()
                HStack {
                    Image(systemName: unit.icon)
                    Text(unit.displayName)
                }
                .foregroundStyle(.secondary)
            }

            // Show historical productivity if available
            if let productivity = historicalProductivity {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Historical avg: \(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        // Quantity input (only if quantifiable unit)
        if unit.isQuantifiable {
            HStack {
                TextField("Quantity", text: $quantity)
                    .keyboardType(.decimalPad)

                Text(unit.displayName)
                    .foregroundStyle(.secondary)
            }

            // Calculation mode picker
            Picker("Calculator Mode", selection: $quantityCalculationMode) {
                ForEach(TaskEstimator.QuantityCalculationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            // Mode-specific inputs and results
            switch quantityCalculationMode {
            case .calculateDuration:
                calculateDurationInputs

            case .calculatePersonnel:
                calculatePersonnelInputs

            case .manualEntry:
                manualEntryInfo
            }

            // Override productivity rate
            if productivityRate != nil {
                DisclosureGroup {
                    HStack {
                        Text("Productivity Rate")
                        Spacer()
                        TextField("Rate", value: Binding(
                            get: { productivityRate ?? 0 },
                            set: { productivityRate = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("\(unit.displayName)/person-hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                        Text("Override Rate")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
        } else if taskType != nil {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption2)
                Text("Select a task type with a quantifiable unit")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var calculateDurationInputs: some View {
        // Input: Personnel → Calculate: Duration
        Stepper(value: Binding(
            get: { expectedPersonnelCount ?? 1 },
            set: {
                expectedPersonnelCount = $0
                hasPersonnel = true
                updateFromQuantityCalculation()
            }
        ), in: 1...20) {
            HStack {
                Text("Personnel")
                Spacer()
                Text("\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")")
                    .foregroundStyle(.secondary)
            }
        }

        // Show calculated result
        if hasEstimate {
            let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
            if totalSeconds > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Estimated Duration:")
                    Spacer()
                    Text(totalSeconds.formattedTime())
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    @ViewBuilder
    private var calculatePersonnelInputs: some View {
        // Input: Duration → Calculate: Personnel
        HStack {
            Text("Duration (hours)")
            Spacer()
            Picker("Hours", selection: Binding(
                get: { estimateHours },
                set: {
                    estimateHours = $0
                    hasEstimate = true
                    updateFromQuantityCalculation()
                }
            )) {
                ForEach(0..<100, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }

        HStack {
            Text("Minutes")
            Spacer()
            Picker("Minutes", selection: Binding(
                get: { estimateMinutes },
                set: {
                    estimateMinutes = $0
                    hasEstimate = true
                    updateFromQuantityCalculation()
                }
            )) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text("\(minute)").tag(minute)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }

        // Show calculated result
        if hasPersonnel, let personnel = expectedPersonnelCount {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Required Personnel:")
                Spacer()
                Text("\(personnel) \(personnel == 1 ? "person" : "people")")
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var manualEntryInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Manual Entry Mode")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            Text("Track quantity and set time/personnel manually. Productivity rate will be calculated when the task is completed.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
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
            
            // Unified Time Estimation & Calculator Section
            Section("Time Estimation & Calculator") {
                // Main mode picker
                Picker("Estimation Method", selection: $unifiedEstimationMode) {
                    ForEach(TaskEstimator.UnifiedEstimationMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                // Show parent's auto-calculated estimate if subtask (duration mode only)
                if unifiedEstimationMode == .duration && isSubtask, let parentTotal = parentSubtaskEstimateTotal, parentTotal > 0 {
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

                // MODE 1: DURATION (Manual Entry)
                if unifiedEstimationMode == .duration {
                    // Contextual toggle based on whether task has subtasks with estimates
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

                // MODE 2: EFFORT (Person-Hours Based)
                else if unifiedEstimationMode == .effort {
                    EffortInputSection(
                        effortHours: $effortHours,
                        hasPersonnel: $hasPersonnel,
                        expectedPersonnelCount: $expectedPersonnelCount,
                        hasDueDate: $hasDueDate,
                        dueDate: dueDate
                    )
                    .onChange(of: effortHours) { _, newValue in
                        updateDurationFromEffort()
                    }
                    .onChange(of: expectedPersonnelCount) { _, newValue in
                        updateDurationFromEffort()
                    }
                } // End Effort Mode

                // MODE 3: QUANTITY (Productivity-Based Calculator)
                else if unifiedEstimationMode == .quantity {
                    quantityCalculatorView
                } // End Quantity Mode

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
                if personnelIsAutoCalculated {
                    // Read-only display when auto-calculated
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text("Auto-calculated from estimation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Expected Personnel")
                        Spacer()
                        Text("\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }

                    Button("Switch to Manual Mode") {
                        // Switch to duration mode to allow manual entry
                        unifiedEstimationMode = .duration
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                } else {
                    // Editable mode
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
        let result = TaskFormValidator.validateSubtaskDueDate(
            subtaskDate: newDate,
            parentDate: parentDueDate,
            isSubtask: isSubtask
        )

        if !result.isValid {
            showingDateValidationAlert = true
        }
    }

    private func validateEstimate() {
        let result = TaskFormValidator.validateCustomEstimate(
            estimateHours: estimateHours,
            estimateMinutes: estimateMinutes,
            subtaskTotalMinutes: taskSubtaskEstimateTotal,
            hasCustomEstimate: hasCustomEstimate,
            isSubtask: isSubtask
        )

        if !result.isValid, let message = result.errorMessage {
            estimateValidationMessage = message
            showingEstimateValidationAlert = true
        }
    }
}
