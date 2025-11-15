import SwiftUI
import SwiftData

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

    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query(filter: #Predicate<Task> { task in !task.isArchived }, sort: \Task.order) private var allTasks: [Task]

    @State private var historicalProductivity: Double?
    @State private var showQuantityPicker = false
    @State private var showPersonnelPicker = false
    @State private var showDurationPicker = false
    @State private var showProductivityRateEditor = false
    @State private var showCalculationModeMenu = false
    @State private var useCustomRate = false
    @FocusState private var isQuantityFieldFocused: Bool

    let onCalculationUpdate: () -> Void

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
            } else if taskType != nil {
                TaskInlineInfoRow(
                    icon: "exclamationmark.triangle.fill",
                    message: "Select a task type with a quantifiable unit to enable quantity tracking",
                    style: .warning
                )
            }
        }
        .onAppear {
            // Set initial toggle state based on whether custom rate exists
            useCustomRate = productivityRate != nil && productivityRate != historicalProductivity

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
        let productivity = historicalProductivity ?? 1.0

        return NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Productivity Rate")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    if let historical = historicalProductivity {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text("Historical Average:")
                                .font(.caption)
                            Text("\(String(format: "%.1f", historical)) \(unit.displayName)/person-hr")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.bottom, DesignSystem.Spacing.sm)
                    }

                    HStack {
                        TextField("Rate", value: Binding(
                            get: { productivityRate ?? productivity },
                            set: {
                                productivityRate = $0
                                onCalculationUpdate()
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(maxWidth: 200)

                        Text("\(unit.displayName)/person-hr")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let historical = historicalProductivity {
                        Button {
                            productivityRate = historical
                            onCalculationUpdate()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption)
                                Text("Use Historical Average")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showProductivityRateEditor = false
                    }
                }
            }
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
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

    private func handleTaskTypeChange(_ newValue: String?) {
        guard let selectedTaskType = newValue,
              let template = templates.first(where: { $0.name == selectedTaskType }) else {
            return
        }

        unit = template.defaultUnit

        // Priority order:
        // 1. Historical data (if available)
        // 2. Template's expected productivity rate (if set)
        // 3. Unit's default productivity rate (fallback)
        historicalProductivity = TemplateManager.getHistoricalProductivity(
            for: selectedTaskType,
            unit: template.defaultUnit,
            from: allTasks
        )

        productivityRate = historicalProductivity
            ?? template.defaultProductivityRate
            ?? template.defaultUnit.defaultProductivityRate
    }
}
