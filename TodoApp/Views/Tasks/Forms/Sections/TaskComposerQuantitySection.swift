import SwiftUI

/// Quantity-based estimation calculator section
/// Handles task type selection, unit tracking, and calculation modes
/// Refactored to use ViewModels and reusable components
struct TaskComposerQuantitySection: View {
    @Binding var taskType: String?
    @Binding var unit: UnitType
    @Binding var quantity: String
    @Binding var quantityCalculationMode: TaskEstimator.QuantityCalculationMode
    @Binding var productivityRate: Double?
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var taskTemplate: TaskTemplate?

    // Schedule context (for personnel recommendations)
    let schedule: ScheduleContext

    // Data passed from parent (no @Query)
    let templates: [TaskTemplate]
    let allTasks: [Task]

    // ViewModels for business logic
    @State private var calculationViewModel: QuantityCalculationViewModel
    @State private var productivityViewModel: ProductivityRateViewModel

    @State private var showQuantityPicker = false
    @State private var showPersonnelPicker = false
    @State private var showDurationPicker = false
    @State private var showProductivityRateEditor = false
    @State private var showCalculationModeMenu = false
    @State private var hasInitialized = false
    @State private var quantityValidationError: String?
    @State private var calculationError: String?
    @State private var unitChangeWarning: String?
    @State private var shouldAnimateDuration = false
    @State private var shouldAnimatePersonnel = false
    @FocusState private var isQuantityFieldFocused: Bool

    let onCalculationUpdate: () -> Void

    // MARK: - Initialization

    init(
        taskType: Binding<String?>,
        unit: Binding<UnitType>,
        quantity: Binding<String>,
        quantityCalculationMode: Binding<TaskEstimator.QuantityCalculationMode>,
        productivityRate: Binding<Double?>,
        hasEstimate: Binding<Bool>,
        estimateHours: Binding<Int>,
        estimateMinutes: Binding<Int>,
        hasPersonnel: Binding<Bool>,
        expectedPersonnelCount: Binding<Int?>,
        taskTemplate: Binding<TaskTemplate?>,
        schedule: ScheduleContext,
        templates: [TaskTemplate],
        allTasks: [Task],
        onCalculationUpdate: @escaping () -> Void
    ) {
        self._taskType = taskType
        self._unit = unit
        self._quantity = quantity
        self._quantityCalculationMode = quantityCalculationMode
        self._productivityRate = productivityRate
        self._hasEstimate = hasEstimate
        self._estimateHours = estimateHours
        self._estimateMinutes = estimateMinutes
        self._hasPersonnel = hasPersonnel
        self._expectedPersonnelCount = expectedPersonnelCount
        self._taskTemplate = taskTemplate
        self.schedule = schedule
        self.templates = templates
        self.allTasks = allTasks
        self.onCalculationUpdate = onCalculationUpdate

        // Initialize ViewModels
        let calcVM = QuantityCalculationViewModel(templates: templates, allTasks: allTasks)
        let prodVM = ProductivityRateViewModel()
        self._calculationViewModel = State(initialValue: calcVM)
        self._productivityViewModel = State(initialValue: prodVM)
    }

    // MARK: - Computed Properties

    /// Check if current unit is quantifiable (uses CustomUnit from template if available)
    private var isCurrentUnitQuantifiable: Bool {
        // Try to get quantifiable status from template's CustomUnit
        if let currentTaskType = taskType,
           let template = templates.first(where: { $0.name == currentTaskType }) {
            return template.isQuantifiable
        }
        // Fallback to legacy UnitType check
        return unit.isQuantifiable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            taskTypePickerView

            if isCurrentUnitQuantifiable {
                quantifiableContent
            } else if taskType != nil {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle.fill",
                    message: "Select a task type with a quantifiable unit to enable quantity tracking",
                    style: .warning
                )
            }
        }
        .onAppear {
            // Guard: Only initialize once to prevent side effects on re-appear
            guard !hasInitialized else { return }
            hasInitialized = true

            // Sync ViewModel state with bindings
            syncViewModelState()

            // Initialize productivity rates if task type is already set
            if let currentTaskType = taskType {
                calculationViewModel.initialize(
                    existingTaskType: currentTaskType,
                    existingQuantity: quantity,
                    existingProductivityRate: productivityRate,
                    existingUnit: unit
                )

                // Sync productivity ViewModel
                productivityViewModel.loadProductivityRates(
                    expected: calculationViewModel.expectedProductivity,
                    historical: calculationViewModel.historicalProductivity,
                    existingCustom: productivityRate
                )
            }

            // Initialize required values based on calculation mode
            switch quantityCalculationMode {
            case .calculateDuration:
                // Ensure personnel is set for duration calculation
                if expectedPersonnelCount == nil {
                    expectedPersonnelCount = 1
                }
                hasPersonnel = true
            case .calculatePersonnel:
                // Ensure estimate flag is set for personnel calculation
                hasEstimate = true
            case .manualEntry:
                break
            }
        }
        .onChange(of: expectedPersonnelCount) { _, newValue in
            // Sync with ViewModel
            calculationViewModel.expectedPersonnelCount = newValue
            // Trigger recalculation when personnel count changes (in Calculate Duration mode)
            if quantityCalculationMode == .calculateDuration {
                performCalculation()
            }
        }
        .onChange(of: quantity) { _, newValue in
            calculationViewModel.quantity = newValue
            // Trigger recalculation for any mode that depends on quantity
            if quantityCalculationMode == .calculateDuration || quantityCalculationMode == .calculatePersonnel {
                performCalculation()
            } else {
                onCalculationUpdate()
            }
        }
        .onChange(of: estimateHours) { _, newValue in
            calculationViewModel.estimateHours = newValue
            // Trigger recalculation when duration changes (in Calculate Personnel mode)
            if quantityCalculationMode == .calculatePersonnel {
                performCalculation()
            }
        }
        .onChange(of: estimateMinutes) { _, newValue in
            calculationViewModel.estimateMinutes = newValue
            // Trigger recalculation when duration changes (in Calculate Personnel mode)
            if quantityCalculationMode == .calculatePersonnel {
                performCalculation()
            }
        }
        .onChange(of: productivityRate) { _, newValue in
            calculationViewModel.productivityRate = newValue
            // Trigger recalculation when productivity changes (affects both calculation modes)
            if quantityCalculationMode == .calculateDuration || quantityCalculationMode == .calculatePersonnel {
                performCalculation()
            }
        }
        .onChange(of: unit) { oldUnit, newUnit in
            // When unit changes (e.g., m² → meters), clear quantity to prevent confusion
            guard oldUnit != newUnit, !quantity.isEmpty else { return }

            // Clear quantity and calculated values
            quantity = ""
            calculationViewModel.quantity = ""

            // Reset calculated values to zero (but keep flags so view doesn't collapse)
            estimateHours = 0
            estimateMinutes = 0
            expectedPersonnelCount = 1 // Reset to default instead of nil

            // Show error prompting re-entry (persists until user starts typing)
            calculationError = "Please re-enter quantity for \(newUnit.displayName)"
            unitChangeWarning = "Unit changed from \(oldUnit.displayName) to \(newUnit.displayName) - please re-enter quantity"
        }
        .confirmationDialog("Switch Calculation", isPresented: $showCalculationModeMenu) {
            Button("Calculate Duration") {
                quantityCalculationMode = .calculateDuration
                calculationViewModel.calculationMode = .calculateDuration
                // Ensure personnel is set for duration calculation
                if expectedPersonnelCount == nil {
                    expectedPersonnelCount = 1
                    calculationViewModel.expectedPersonnelCount = 1
                }
                hasPersonnel = true
                performCalculation()
            }
            Button("Calculate Personnel") {
                quantityCalculationMode = .calculatePersonnel
                calculationViewModel.calculationMode = .calculatePersonnel
                // Ensure estimate is set for personnel calculation
                hasEstimate = true
                performCalculation()
            }
            Button("Calculate Productivity (Manual)") {
                quantityCalculationMode = .manualEntry
                calculationViewModel.calculationMode = .manualEntry
                onCalculationUpdate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what to calculate from quantity and other inputs")
        }
    }

    // MARK: - Quantifiable Content

    private var quantifiableContent: some View {
        Group {
            Divider()
                .padding(.vertical, DesignSystem.Spacing.xs)

            // Info about tap-to-calculate
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Tap any calculated value to change what's being calculated",
                style: .info
            )

            // Historical productivity badge
            if productivityViewModel.historicalProductivity != nil, taskType != nil {
                HistoricalProductivityBadge(
                    viewModel: productivityViewModel,
                    unit: unit
                )
            }

            Divider()
                .padding(.vertical, DesignSystem.Spacing.sm)

            // All inputs visible - one is calculated
            quantityInputRow

            // Unit change warning (prompts user to re-enter quantity)
            if let warning = unitChangeWarning {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.top, 2)
            }

            productivityInputRow
            personnelInputRow
            durationInputRow

            // Calculation error message (compact, inline)
            if let error = calculationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 2)
            }

            // Show result summary
            if hasEstimate || hasPersonnel {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                calculationSummary
            }

            // Personnel recommendation
            if calculationViewModel.shouldShowPersonnelRecommendation(hasDueDate: schedule.hasDueDate) {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)

                PersonnelRecommendationView(
                    effortHours: calculationViewModel.calculatedEffort,
                    startDate: schedule.hasStartDate ? schedule.startDate : nil,
                    deadline: schedule.dueDate,
                    currentSelection: expectedPersonnelCount,
                    taskType: taskType,
                    allTasks: allTasks
                ) { selectedCount in
                    hasPersonnel = true
                    expectedPersonnelCount = selectedCount
                    calculationViewModel.expectedPersonnelCount = selectedCount
                    // Trigger recalculation when personnel is set via recommendation
                    performCalculation()
                }
                .id("\(schedule.hasStartDate ? schedule.startDate.timeIntervalSince1970 : 0)-\(schedule.dueDate.timeIntervalSince1970)")
            }
        }
    }

    // MARK: - Subviews

    private var taskTypePickerView: some View {
        Picker("Task Type", selection: $taskType) {
            Text("None").tag(nil as String?)
            ForEach(templates) { template in
                HStack {
                    Image(systemName: template.unitIcon)
                    Text("\(template.name) (\(template.unitDisplayName))")
                }
                .tag(template.name as String?)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: taskType) { _, newValue in
            calculationViewModel.taskType = newValue
            calculationViewModel.handleTaskTypeChange(newValue)

            // Set template reference
            if let selectedTaskType = newValue {
                taskTemplate = templates.first(where: { $0.name == selectedTaskType })
            } else {
                taskTemplate = nil
            }

            // Sync with bindings
            unit = calculationViewModel.unit
            productivityRate = calculationViewModel.productivityRate

            // Update productivity ViewModel
            productivityViewModel.loadProductivityRates(
                expected: calculationViewModel.expectedProductivity,
                historical: calculationViewModel.historicalProductivity,
                existingCustom: nil
            )
            productivityViewModel.currentProductivity = calculationViewModel.productivityRate
        }
    }

    // Quantity is never calculated - always an input
    private var quantityInputRow: some View {
        CalculationInputRow(
            icon: "number",
            label: "Quantity",
            value: calculationViewModel.formattedQuantity,
            isCalculated: false,
            calculatedColor: .blue
        ) {
            showQuantityPicker = true
        }
        .sheet(isPresented: $showQuantityPicker) {
            quantityPickerSheet
        }
    }

    // Productivity row - can be input or calculated (for manual mode)
    private var productivityInputRow: some View {
        let isCalculated = quantityCalculationMode == .manualEntry
        let rate = productivityRate ?? calculationViewModel.historicalProductivity ?? 0

        return CalculationInputRow(
            icon: "chart.line.uptrend.xyaxis",
            label: "Productivity",
            value: isCalculated ? "Auto-calculated" : "\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr",
            isCalculated: isCalculated,
            calculatedColor: .orange
        ) {
            if !isCalculated {
                showProductivityRateEditor = true
            } else {
                showCalculationModeMenu = true
            }
        }
        .sheet(isPresented: $showProductivityRateEditor) {
            ProductivityRateEditorView(
                isPresented: $showProductivityRateEditor,
                viewModel: productivityViewModel,
                unit: unit
            ) {
                // Update binding when productivity changes
                productivityRate = productivityViewModel.currentProductivity
                calculationViewModel.productivityRate = productivityViewModel.currentProductivity
                // Trigger recalculation with new productivity rate
                if quantityCalculationMode == .calculateDuration || quantityCalculationMode == .calculatePersonnel {
                    performCalculation()
                } else {
                    onCalculationUpdate()
                }
            }
        }
    }

    // Personnel row - can be input or calculated
    private var personnelInputRow: some View {
        let isCalculated = quantityCalculationMode == .calculatePersonnel
        let personnel = expectedPersonnelCount ?? 1

        return CalculationInputRow(
            icon: "person.2.fill",
            label: "Personnel",
            value: "\(personnel) \(personnel == 1 ? "person" : "people")",
            isCalculated: isCalculated,
            calculatedColor: .green
        ) {
            if !isCalculated {
                showPersonnelPicker = true
            } else {
                showCalculationModeMenu = true
            }
        }
        .scaleEffect(shouldAnimatePersonnel ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: shouldAnimatePersonnel)
        .sheet(isPresented: $showPersonnelPicker) {
            personnelPickerSheet
        }
    }

    // Duration row - can be input or calculated
    private var durationInputRow: some View {
        let isCalculated = quantityCalculationMode == .calculateDuration

        return CalculationInputRow(
            icon: "clock.fill",
            label: "Duration",
            value: calculationViewModel.formattedDuration,
            isCalculated: isCalculated,
            calculatedColor: .green
        ) {
            if !isCalculated {
                showDurationPicker = true
            } else {
                showCalculationModeMenu = true
            }
        }
        .scaleEffect(shouldAnimateDuration ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: shouldAnimateDuration)
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
        }
    }

    private var quantityPickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(taskType != nil ? "Set Quantity for \(taskType!)" : "Set Quantity")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Unit type: \(unit.displayName)")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("0", text: $quantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .focused($isQuantityFieldFocused)
                        .frame(maxWidth: 200)
                        .onChange(of: quantity) { _, newValue in
                            // Real-time validation as user types
                            validateQuantityInput(newValue)

                            // Clear unit change warnings when user starts typing
                            if !newValue.isEmpty {
                                unitChangeWarning = nil
                                // Only clear calculationError if it was from unit change
                                if calculationError?.contains("re-enter quantity") == true {
                                    calculationError = nil
                                }
                            }
                        }

                    // Inline validation error
                    if let error = quantityValidationError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    }
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showQuantityPicker = false
                        isQuantityFieldFocused = false
                        // Clear validation error when closing
                        quantityValidationError = nil
                    }
                }
            }
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
            .onAppear {
                isQuantityFieldFocused = true
                // Validate current value when sheet appears
                validateQuantityInput(quantity)
            }
        }
    }

    // MARK: - Calculation Summary

    private var calculationSummary: some View {
        let personnel = expectedPersonnelCount ?? 1

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Formula")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(calculationViewModel.calculationSummary(personnelCount: personnel))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(quantityCalculationMode == .manualEntry ? .secondary : .primary)
        }
    }

    // MARK: - Sheet Views

    private var personnelPickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Select Personnel Count")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                Picker("Personnel", selection: Binding(
                    get: { expectedPersonnelCount ?? 1 },
                    set: {
                        expectedPersonnelCount = $0
                        calculationViewModel.expectedPersonnelCount = $0
                        hasPersonnel = true
                        // Trigger recalculation when personnel is manually set
                        if quantityCalculationMode == .calculateDuration {
                            performCalculation()
                        } else {
                            onCalculationUpdate()
                        }
                    }
                )) {
                    ForEach(1...20, id: \.self) { count in
                        Text("\(count) \(count == 1 ? "person" : "people")")
                            .tag(count)
                    }
                }
                .pickerStyle(.wheel)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showPersonnelPicker = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var durationPickerSheet: some View {
        DurationPickerSheet(
            hours: $estimateHours,
            minutes: $estimateMinutes,
            isPresented: $showDurationPicker,
            title: "Set Duration",
            maxHours: EstimationLimits.maxDurationHours
        ) {
            hasEstimate = true
            // Trigger recalculation when duration is manually set
            if quantityCalculationMode == .calculatePersonnel {
                performCalculation()
            } else {
                onCalculationUpdate()
            }
        }
    }

    // MARK: - Helper Methods

    /// Validate quantity input in real-time with task-type-specific limits
    private func validateQuantityInput(_ input: String) {
        // Empty input is valid (allows user to clear and retype)
        guard !input.isEmpty else {
            quantityValidationError = nil
            return
        }

        // Find current template to get task-type-specific limits
        let currentTemplate = templates.first { $0.name == taskType }
        let minQuantity = currentTemplate?.minQuantity
        let maxQuantity = currentTemplate?.maxQuantity

        // Validate using task-type-specific limits
        let validation = InputValidator.validateQuantity(
            input,
            unit: unit.displayName,
            minQuantity: minQuantity,
            maxQuantity: maxQuantity
        )

        // Update error message
        if let error = validation.error {
            quantityValidationError = error.message
        } else {
            quantityValidationError = nil
        }
    }

    /// Sync ViewModel state with bindings
    private func syncViewModelState() {
        calculationViewModel.taskType = taskType
        calculationViewModel.unit = unit
        calculationViewModel.quantity = quantity
        calculationViewModel.calculationMode = quantityCalculationMode
        calculationViewModel.productivityRate = productivityRate
        calculationViewModel.estimateHours = estimateHours
        calculationViewModel.estimateMinutes = estimateMinutes
        calculationViewModel.expectedPersonnelCount = expectedPersonnelCount

        productivityViewModel.currentProductivity = productivityRate
    }

    /// Perform calculation based on current mode and sync results back to bindings
    private func performCalculation() {
        // Clear any previous error
        calculationError = nil

        switch quantityCalculationMode {
        case .calculateDuration:
            // Validate inputs before calculation
            guard let qty = Double(quantity), qty > 0 else {
                calculationError = "Quantity cannot be 0 for calculation to work"
                return
            }

            guard let rate = productivityRate ?? calculationViewModel.historicalProductivity, rate > 0 else {
                calculationError = "Productivity rate not set"
                return
            }

            guard let personnel = expectedPersonnelCount, personnel > 0 else {
                calculationError = "Personnel count required"
                return
            }

            // Store previous values to detect changes
            let previousHours = estimateHours
            let previousMinutes = estimateMinutes

            // Perform calculation
            calculationViewModel.calculateDuration(personnelCount: personnel)

            // Sync ViewModel results back to bindings
            estimateHours = calculationViewModel.estimateHours
            estimateMinutes = calculationViewModel.estimateMinutes
            hasEstimate = true

            // Trigger pulse animation if value actually changed
            if previousHours != estimateHours || previousMinutes != estimateMinutes {
                triggerDurationAnimation()
            }

        case .calculatePersonnel:
            // Validate inputs before calculation
            guard let qty = Double(quantity), qty > 0 else {
                calculationError = "Quantity cannot be 0 for calculation to work"
                return
            }

            guard let rate = productivityRate ?? calculationViewModel.historicalProductivity, rate > 0 else {
                calculationError = "Productivity rate not set"
                return
            }

            let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
            guard totalSeconds > 0 else {
                calculationError = "Duration must be greater than 0"
                return
            }

            // Store previous value to detect changes
            let previousPersonnel = expectedPersonnelCount

            // Calculate personnel from quantity, productivity, and duration
            if let calculated = calculationViewModel.calculatePersonnel() {
                expectedPersonnelCount = calculated
                calculationViewModel.expectedPersonnelCount = calculated
                hasPersonnel = true

                // Trigger pulse animation if value actually changed
                if previousPersonnel != calculated {
                    triggerPersonnelAnimation()
                }
            } else {
                calculationError = "Unable to calculate personnel"
                return
            }

        case .manualEntry:
            // No automatic calculation - productivity will be calculated on completion
            break
        }

        // Notify parent to update its state
        onCalculationUpdate()
    }

    /// Trigger brief pulse animation for duration value
    private func triggerDurationAnimation() {
        shouldAnimateDuration = true
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shouldAnimateDuration = false
        }
    }

    /// Trigger brief pulse animation for personnel value
    private func triggerPersonnelAnimation() {
        shouldAnimatePersonnel = true
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shouldAnimatePersonnel = false
        }
    }
}
