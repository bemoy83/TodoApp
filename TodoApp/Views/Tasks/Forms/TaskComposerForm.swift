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
    @State private var isProductivityOverrideExpanded = false

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

    // MARK: - Reusable UI Components

    /// A card-style container for displaying calculated results
    @ViewBuilder
    private func resultCard(icon: String, title: String, value: String, color: Color = .green) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    /// A standardized info/warning/success message box
    @ViewBuilder
    private func infoMessage(icon: String, text: String, style: InfoMessageStyle = .info) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(style.color)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(style.color)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(style.color.opacity(0.08))
        .cornerRadius(6)
    }

    private enum InfoMessageStyle {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var quantityCalculatorView: some View {
        // STEP 1: Task Type Selection
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

        // STEP 2: Unit Display (only if task type selected)
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
        }

        // STEP 3: Quantity Input (only if quantifiable unit)
        if unit.isQuantifiable {
            HStack {
                TextField("Quantity", text: $quantity)
                    .keyboardType(.decimalPad)

                Text(unit.displayName)
                    .foregroundStyle(.secondary)
            }

            // STEP 4: Calculation Strategy
            Text("Calculation Strategy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, DesignSystem.Spacing.md)

            Text("Choose what to calculate from quantity and productivity rate")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Calculator Mode", selection: $quantityCalculationMode) {
                Text("Duration").tag(TaskEstimator.QuantityCalculationMode.calculateDuration)
                Text("Personnel").tag(TaskEstimator.QuantityCalculationMode.calculatePersonnel)
                Text("Manual").tag(TaskEstimator.QuantityCalculationMode.manualEntry)
            }
            .pickerStyle(.segmented)
            .onChange(of: quantityCalculationMode) { _, _ in
                isProductivityOverrideExpanded = false
            }

            // STEP 5: Mode-Specific Container
            switch quantityCalculationMode {
            case .calculateDuration:
                calculateDurationModeContainer

            case .calculatePersonnel:
                calculatePersonnelModeContainer

            case .manualEntry:
                manualEntryModeContainer
            }

        } else if taskType != nil {
            infoMessage(
                icon: "exclamationmark.triangle.fill",
                text: "Select a task type with a quantifiable unit to enable quantity tracking",
                style: .warning
            )
        }
    }

    // MARK: - Quantity Mode Containers

    @ViewBuilder
    private var calculateDurationModeContainer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Historical productivity
            if let productivity = historicalProductivity {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.success)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Historical Average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Tap to override
                    Button {
                        withAnimation {
                            isProductivityOverrideExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isProductivityOverrideExpanded ? "pencil.circle.fill" : "pencil.circle")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
            }

            // Personnel input
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

            // Productivity rate override
            if productivityRate != nil && isProductivityOverrideExpanded {
                Divider()

                HStack {
                    Text("Custom Rate")
                    Spacer()
                    TextField("Rate", value: Binding(
                        get: { productivityRate ?? 0 },
                        set: {
                            productivityRate = $0
                            updateFromQuantityCalculation()
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("\(unit.displayName)/person-hr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Calculated result
            if hasEstimate {
                let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
                if totalSeconds > 0 {
                    Divider()

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(totalSeconds.formattedTime())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)

                            Text("Estimated Duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var calculatePersonnelModeContainer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Historical productivity
            if let productivity = historicalProductivity {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.success)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Historical Average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Tap to override
                    Button {
                        withAnimation {
                            isProductivityOverrideExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isProductivityOverrideExpanded ? "pencil.circle.fill" : "pencil.circle")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
            }

            // Duration inputs
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

            // Productivity rate override
            if productivityRate != nil && isProductivityOverrideExpanded {
                Divider()

                HStack {
                    Text("Custom Rate")
                    Spacer()
                    TextField("Rate", value: Binding(
                        get: { productivityRate ?? 0 },
                        set: {
                            productivityRate = $0
                            updateFromQuantityCalculation()
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("\(unit.displayName)/person-hr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Calculated result
            if hasPersonnel, let personnel = expectedPersonnelCount {
                Divider()

                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(personnel) \(personnel == 1 ? "person" : "people")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)

                        Text("Required Personnel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var manualEntryModeContainer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                Text("Track quantity and set time/personnel manually. Productivity rate will be calculated when the task is completed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            // Reference productivity rate (read-only)
            if let rate = productivityRate {
                Divider()

                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Reference Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
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
                    if let project = inheritedProject {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "folder.fill")
                                .font(.body)
                                .foregroundStyle(Color(hex: project.color))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Inherited from Parent")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    } else {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text("No project (inherited from parent)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
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
                    if let p = parentDueDate {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.body)
                                .foregroundStyle(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Parent Due Date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(p.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(6)
                        .padding(.bottom, 8)
                    } else {
                        infoMessage(
                            icon: "calendar.badge.exclamationmark",
                            text: "Parent has no due date set",
                            style: .info
                        )
                        .padding(.bottom, 8)
                    }
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
                        infoMessage(
                            icon: "info.circle.fill",
                            text: "Must be on or before parent's due date",
                            style: .warning
                        )
                        .padding(.top, 8)
                    }
                } else if isSubtask, parentDueDate != nil {
                    infoMessage(
                        icon: "checkmark.circle.fill",
                        text: "Will inherit parent's due date",
                        style: .success
                    )
                    .padding(.top, 8)
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
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent's Estimate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text((parentTotal * 60).formattedTime())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                    .padding(.bottom, 8)
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
                        resultCard(
                            icon: "sum",
                            title: "Auto-Calculated from Subtasks",
                            value: ((taskSubtaskEstimateTotal ?? 0) * 60).formattedTime(),
                            color: .green
                        )
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
                        resultCard(
                            icon: "clock.fill",
                            title: "Estimated Duration",
                            value: (totalMinutes * 60).formattedTime(),
                            color: .blue
                        )
                        .padding(.top, 4)
                    } else {
                        infoMessage(
                            icon: "exclamationmark.triangle",
                            text: "Setting 0 time will remove the estimate",
                            style: .warning
                        )
                        .padding(.top, 4)
                    }

                    // Show override warning when parent overriding subtasks
                    if hasSubtasksWithEstimates {
                        infoMessage(
                            icon: "info.circle.fill",
                            text: "Custom estimate will be used instead of auto-calculated \(((taskSubtaskEstimateTotal ?? 0) * 60).formattedTime()) from subtasks",
                            style: .warning
                        )
                        .padding(.top, 4)
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
                    infoMessage(
                        icon: "lock.fill",
                        text: "Personnel count is auto-calculated from the estimation calculator above",
                        style: .info
                    )

                    resultCard(
                        icon: "person.2.fill",
                        title: "Expected Personnel",
                        value: "\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")",
                        color: .blue
                    )
                    .padding(.top, 8)

                    Button {
                        unifiedEstimationMode = .duration
                    } label: {
                        Label("Switch to Manual Mode", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
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

                        infoMessage(
                            icon: "info.circle.fill",
                            text: "Pre-fills time entry forms with this count",
                            style: .info
                        )
                        .padding(.top, 8)
                    } else {
                        infoMessage(
                            icon: "info.circle.fill",
                            text: "Defaults to 1 person if not set",
                            style: .info
                        )
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
