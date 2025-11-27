import SwiftUI
import SwiftData

/// Productivity mode selection for task estimation
enum ProductivityMode: String, CaseIterable {
    case expected = "Expected"
    case historical = "Historical"
    case custom = "Custom"
}

/// Quantity-based estimation calculator section
/// Handles task type selection, unit tracking, and calculation modes
/// Consolidated implementation with shared productivity view and calculation transparency
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

    // Deadline (for personnel recommendations)
    let hasDueDate: Bool
    let dueDate: Date
    let hasStartDate: Bool
    let startDate: Date

    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query(filter: #Predicate<Task> { task in !task.isArchived }, sort: \Task.order) private var allTasks: [Task]

    @State private var historicalProductivity: Double?
    @State private var expectedProductivity: Double?
    @State private var productivityMode: ProductivityMode = .expected
    @State private var customProductivityInput: String = ""
    @State private var showQuantityPicker = false
    @State private var showPersonnelPicker = false
    @State private var showDurationPicker = false
    @State private var showProductivityRateEditor = false
    @State private var showCalculationModeMenu = false
    @FocusState private var isQuantityFieldFocused: Bool
    @FocusState private var isCustomProductivityFocused: Bool

    let onCalculationUpdate: () -> Void

    // MARK: - Computed Properties

    /// Calculate effort hours from quantity and productivity (only when in Calculate Duration or Personnel mode)
    private var calculatedEffort: Double {
        let quantityValue = Double(quantity) ?? 0
        let rate = productivityRate ?? historicalProductivity ?? 0
        guard quantityValue > 0, rate > 0 else { return 0 }

        // Effort = Quantity ÷ Productivity Rate (gives us person-hours)
        return quantityValue / rate
    }

    /// Whether to show personnel recommendations
    private var shouldShowPersonnelRecommendation: Bool {
        guard hasDueDate, calculatedEffort > 0 else { return false }

        // Only show when we're calculating duration (user needs personnel recommendation)
        return quantityCalculationMode == .calculateDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            taskTypePickerView

            if unit.isQuantifiable {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)

                // Info about tap-to-calculate
                TaskInlineInfoRow(
                    icon: "info.circle",
                    message: "Tap any calculated value to change what's being calculated",
                    style: .info
                )

                // Historical productivity badge
                if let historical = historicalProductivity, taskType != nil {
                    historicalProductivityBadge(historical: historical)
                }

                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)

                // All inputs visible - one is calculated
                quantityInputRow
                productivityInputRow
                personnelInputRow
                durationInputRow

                // Shared calculation mode menu
                    .confirmationDialog("Switch Calculation", isPresented: $showCalculationModeMenu) {
                        Button("Calculate Duration") {
                            quantityCalculationMode = .calculateDuration
                            // Ensure personnel is set for duration calculation
                            if expectedPersonnelCount == nil {
                                expectedPersonnelCount = 1
                            }
                            hasPersonnel = true
                            onCalculationUpdate()
                        }
                        Button("Calculate Personnel") {
                            quantityCalculationMode = .calculatePersonnel
                            // Ensure estimate is set for personnel calculation
                            hasEstimate = true
                            onCalculationUpdate()
                        }
                        Button("Calculate Productivity (Manual)") {
                            quantityCalculationMode = .manualEntry
                            onCalculationUpdate()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Choose what to calculate from quantity and other inputs")
                    }

                // Show result summary
                if hasEstimate || hasPersonnel {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    calculationSummary
                }

                // Personnel recommendation
                if shouldShowPersonnelRecommendation {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.sm)

                    PersonnelRecommendationView(
                        effortHours: calculatedEffort,
                        startDate: hasStartDate ? startDate : nil,
                        deadline: dueDate,
                        currentSelection: expectedPersonnelCount,
                        taskType: taskType,
                        allTasks: allTasks
                    ) { selectedCount in
                        hasPersonnel = true
                        expectedPersonnelCount = selectedCount
                        // Trigger recalculation when personnel is set via recommendation
                        onCalculationUpdate()
                    }
                    .id("\(hasStartDate ? startDate.timeIntervalSince1970 : 0)-\(dueDate.timeIntervalSince1970)")
                }
            } else if taskType != nil {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle.fill",
                    message: "Select a task type with a quantifiable unit to enable quantity tracking",
                    style: .warning
                )
            }
        }
        .onAppear {
            // Initialize productivity rates if task type is already set
            if let currentTaskType = taskType {
                // Store the existing custom productivity rate (if any) before initialization
                let existingCustomRate = productivityRate

                // Initialize template and historical rates
                handleTaskTypeChange(currentTaskType)

                // Restore custom productivity rate if it was already set
                // (This preserves user's manual customization when reopening tasks)
                if let customRate = existingCustomRate, customRate > 0 {
                    // Check if the existing rate differs from template/historical defaults
                    // If so, it's a custom value that should be preserved
                    let defaultRate = expectedProductivity ?? historicalProductivity ?? unit.defaultProductivityRate

                    if abs(customRate - defaultRate) > 0.01 {
                        // User had set a custom rate - restore it
                        productivityRate = customRate
                        productivityMode = .custom
                        customProductivityInput = String(format: "%.1f", customRate)
                    }
                }
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
        .onChange(of: expectedPersonnelCount) { _, _ in
            // Trigger recalculation when personnel count changes
            // (relevant when in Calculate Duration mode)
            if quantityCalculationMode == .calculateDuration {
                onCalculationUpdate()
            }
        }
    }

    // MARK: - Subviews

    private var taskTypePickerView: some View {
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
            handleTaskTypeChange(newValue)
        }
    }

    private var formattedQuantity: String {
        if quantity.isEmpty || quantity == "0" {
            return "Not set"
        }
        return "\(quantity) \(unit.displayName)"
    }

    // Quantity is never calculated - always an input
    private var quantityInputRow: some View {
        HStack {
            Image(systemName: "number")
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text("Quantity")

            Spacer()

            Text(formattedQuantity)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showQuantityPicker = true
        }
        .sheet(isPresented: $showQuantityPicker) {
            quantityPickerSheet
        }
        .onChange(of: quantity) { _, _ in
            onCalculationUpdate()
        }
    }

    // Productivity row - can be input or calculated (for manual mode)
    private var productivityInputRow: some View {
        let isCalculated = quantityCalculationMode == .manualEntry
        let rate = productivityRate ?? historicalProductivity ?? 0

        return HStack {
            Image(systemName: isCalculated ? "lock.fill" : "chart.line.uptrend.xyaxis")
                .font(.subheadline)
                .foregroundStyle(isCalculated ? .orange : .blue)
                .frame(width: 24)

            Text("Productivity")

            Spacer()

            if isCalculated {
                Text("Auto-calculated")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else {
                Text("\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr")
                    .foregroundStyle(.secondary)
            }

            if !isCalculated {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCalculated {
                showProductivityRateEditor = true
            } else {
                showCalculationModeMenu = true
            }
        }
        .sheet(isPresented: $showProductivityRateEditor) {
            productivityRateEditorSheet
        }
    }

    // Personnel row - can be input or calculated
    private var personnelInputRow: some View {
        let isCalculated = quantityCalculationMode == .calculatePersonnel
        let personnel = expectedPersonnelCount ?? 1

        return HStack {
            Image(systemName: isCalculated ? "lock.fill" : "person.2.fill")
                .font(.subheadline)
                .foregroundStyle(isCalculated ? .green : .blue)
                .frame(width: 24)

            Text("Personnel")

            Spacer()

            Text("\(personnel) \(personnel == 1 ? "person" : "people")")
                .foregroundStyle(isCalculated ? .green : .secondary)

            if !isCalculated {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "function")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCalculated {
                showPersonnelPicker = true
            } else {
                showCalculationModeMenu = true
            }
        }
        .sheet(isPresented: $showPersonnelPicker) {
            personnelPickerSheet
        }
    }

    // Duration row - can be input or calculated
    private var durationInputRow: some View {
        let isCalculated = quantityCalculationMode == .calculateDuration

        return HStack {
            Image(systemName: isCalculated ? "lock.fill" : "clock.fill")
                .font(.subheadline)
                .foregroundStyle(isCalculated ? .green : .blue)
                .frame(width: 24)

            Text("Duration")

            Spacer()

            Text(formattedDuration)
                .foregroundStyle(isCalculated ? .green : .secondary)

            if !isCalculated {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "function")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCalculated {
                showDurationPicker = true
            } else {
                showCalculationModeMenu = true
            }
        }
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
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showQuantityPicker = false
                        isQuantityFieldFocused = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .onAppear {
                isQuantityFieldFocused = true
            }
        }
    }

    // MARK: - Calculation Summary

    private var calculationSummary: some View {
        let quantityValue = Double(quantity) ?? 0
        let rate = productivityRate ?? historicalProductivity ?? 1.0
        let personnel = expectedPersonnelCount ?? 1
        let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Formula")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            switch quantityCalculationMode {
            case .calculateDuration:
                Text("\(String(format: "%.0f", quantityValue)) ÷ \(String(format: "%.1f", rate)) ÷ \(personnel) = \(totalSeconds.formattedTime())")
                    .font(.subheadline)
                    .fontWeight(.medium)

            case .calculatePersonnel:
                Text("\(String(format: "%.0f", quantityValue)) ÷ \(String(format: "%.1f", rate)) ÷ \(totalSeconds.formattedTime()) = \(personnel) \(personnel == 1 ? "person" : "people")")
                    .font(.subheadline)
                    .fontWeight(.medium)

            case .manualEntry:
                Text("Productivity will be calculated on task completion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Productivity Rate Editor Sheet

    private var productivityRateEditorSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Productivity Rate")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                // Variance warning (if significant)
                if let variance = calculateVariance(), variance.percentage > 30 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Historical is \(String(format: "%.0f", variance.percentage))% \(variance.isPositive ? "faster" : "slower") than expected.")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Consider updating your template's expected rate.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                // Segmented control for mode selection
                Picker("Mode", selection: $productivityMode) {
                    ForEach(ProductivityMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: productivityMode) { _, newMode in
                    updateProductivityRate(for: newMode)
                }

                // Show available productivity values
                VStack(spacing: DesignSystem.Spacing.sm) {
                    if let expected = expectedProductivity {
                        HStack {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.info)
                                .frame(width: 20)
                            Text("Expected:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", expected)) \(unit.displayName)/person-hr")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    if let historical = historicalProductivity {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.success)
                                .frame(width: 20)
                            Text("Historical:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", historical)) \(unit.displayName)/person-hr")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)

                // Custom input field (only shown when Custom mode is selected)
                if productivityMode == .custom {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Custom Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack {
                            TextField("Enter rate", text: $customProductivityInput)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.title2)
                                .focused($isCustomProductivityFocused)
                                .frame(maxWidth: 200)
                                .onChange(of: customProductivityInput) { _, newValue in
                                    // Update productivity rate as user types
                                    if let customRate = Double(newValue), customRate > 0 {
                                        productivityRate = customRate
                                        onCalculationUpdate()
                                    }
                                }

                            Text("\(unit.displayName)/person-hr")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showProductivityRateEditor = false
                        isCustomProductivityFocused = false
                    }
                }
            }
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.visible)
            .onAppear {
                // Initialize mode based on current productivity rate
                if let current = productivityRate {
                    if current == expectedProductivity {
                        productivityMode = .expected
                    } else if current == historicalProductivity {
                        productivityMode = .historical
                    } else {
                        productivityMode = .custom
                        customProductivityInput = String(format: "%.1f", current)
                    }
                }
            }
        }
    }

    /// Update productivity rate based on selected mode
    private func updateProductivityRate(for mode: ProductivityMode) {
        switch mode {
        case .expected:
            if let expected = expectedProductivity {
                productivityRate = expected
                onCalculationUpdate()
            }
        case .historical:
            if let historical = historicalProductivity {
                productivityRate = historical
                onCalculationUpdate()
            }
        case .custom:
            // Focus custom input field
            isCustomProductivityFocused = true

            // Parse and apply custom rate
            if let customRate = Double(customProductivityInput), customRate > 0 {
                productivityRate = customRate
                onCalculationUpdate()
            }
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
                        hasPersonnel = true
                        onCalculationUpdate()
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
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Duration")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                DatePicker(
                    "Duration",
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
                            hasEstimate = true
                            onCalculationUpdate()
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.wheel)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDurationPicker = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var formattedDuration: String {
        let totalMinutes = (estimateHours * 60) + estimateMinutes
        if totalMinutes == 0 {
            return "Not set"
        }

        if estimateHours > 0 && estimateMinutes > 0 {
            return "\(estimateHours)h \(estimateMinutes)m"
        } else if estimateHours > 0 {
            return "\(estimateHours)h"
        } else {
            return "\(estimateMinutes)m"
        }
    }

    // MARK: - Helper Methods

    /// Calculate variance percentage between historical and expected
    private func calculateVariance() -> (percentage: Double, isPositive: Bool)? {
        guard let historical = historicalProductivity,
              let expected = expectedProductivity,
              expected > 0 else {
            return nil
        }

        let variance = ((historical - expected) / expected) * 100
        return (abs(variance), variance > 0)
    }

    /// Historical productivity info badge with variance indicator
    @ViewBuilder
    private func historicalProductivityBadge(historical: Double) -> some View {
        let variance = calculateVariance()
        let hasSignificantVariance = if let variance = variance {
            variance.percentage > 30
        } else {
            false
        }

        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.success)

            Text("Historical:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(String(format: "%.1f", historical)) \(unit.displayName)/person-hr")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Variance indicator
            if let variance = variance {
                HStack(spacing: 2) {
                    Image(systemName: variance.isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text("\(String(format: "%.0f", variance.percentage))%")
                        .font(.caption2)
                }
                .foregroundStyle(variance.isPositive ? DesignSystem.Colors.success : .orange)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hasSignificantVariance ? Color.orange.opacity(0.1) : DesignSystem.Colors.success.opacity(0.1))
        )
    }

    private func handleTaskTypeChange(_ newValue: String?) {
        guard let selectedTaskType = newValue,
              let template = templates.first(where: { $0.name == selectedTaskType }) else {
            return
        }

        unit = template.defaultUnit

        // Store historical and expected productivity separately
        historicalProductivity = TemplateManager.getHistoricalProductivity(
            for: selectedTaskType,
            unit: template.defaultUnit,
            from: allTasks
        )
        expectedProductivity = template.defaultProductivityRate

        // Reset to expected mode for each new task (goal-oriented)
        productivityMode = .expected
        customProductivityInput = ""

        // Priority order (goal-oriented approach):
        // 1. Template's expected productivity rate (if set) - the goal
        // 2. Historical data (if available) - fallback
        // 3. Unit's default productivity rate (fallback)
        productivityRate = template.defaultProductivityRate
            ?? historicalProductivity
            ?? template.defaultUnit.defaultProductivityRate
    }
}
