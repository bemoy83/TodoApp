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
    @State private var useCustomRate = false
    @FocusState private var isQuantityFieldFocused: Bool

    let onCalculationUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            taskTypePickerView

            if unit.isQuantifiable {
                quantityInputRow

                Divider()
                    .padding(.vertical, DesignSystem.Spacing.md)

                // Shared productivity rate view
                if let productivity = historicalProductivity {
                    productivityRateView(productivity)
                    Divider()
                }

                calculationStrategyView
                calculationModeView
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

    private var quantityInputRow: some View {
        HStack {
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

    private var calculationStrategyView: some View {
        Picker("Calculator Mode", selection: $quantityCalculationMode) {
            Text("Duration").tag(TaskEstimator.QuantityCalculationMode.calculateDuration)
            Text("Personnel").tag(TaskEstimator.QuantityCalculationMode.calculatePersonnel)
            Text("Manual").tag(TaskEstimator.QuantityCalculationMode.manualEntry)
        }
        .pickerStyle(.segmented)
        .onChange(of: quantityCalculationMode) { _, _ in
            isQuantityFieldFocused = false // Dismiss keyboard when switching modes
        }
    }

    @ViewBuilder
    private var calculationModeView: some View {
        switch quantityCalculationMode {
        case .calculateDuration:
            durationModeView
        case .calculatePersonnel:
            personnelModeView
        case .manualEntry:
            manualModeView
        }
    }

    // MARK: - Duration Mode

    private var durationModeView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            personnelInputRow

            if hasEstimate {
                let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
                if totalSeconds > 0 {
                    calculationBreakdownDuration
                }
            }
        }
    }

    private var calculationBreakdownDuration: some View {
        let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
        let personnel = expectedPersonnelCount ?? 1
        let rate = productivityRate ?? historicalProductivity ?? 1.0
        let quantityValue = Double(quantity) ?? 0

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()

            // Input: Quantity
            HStack {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Quantity:")
                    .font(.subheadline)
                Spacer()
                Text("\(quantity) \(unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Operator: Division by rate
            HStack {
                Image(systemName: "divide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Productivity:")
                    .font(.subheadline)
                Spacer()
                Text("\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Operator: Division by personnel
            HStack {
                Image(systemName: "divide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Personnel:")
                    .font(.subheadline)
                Spacer()
                Text("\(personnel) \(personnel == 1 ? "person" : "people")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Result: Duration
            TaskRowIconValueLabel(
                icon: "clock.fill",
                label: "Duration per person",
                value: totalSeconds.formattedTime(),
                tint: .green
            )
        }
    }

    // MARK: - Personnel Mode

    private var personnelModeView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            durationInputRow

            if hasPersonnel, let personnel = expectedPersonnelCount {
                calculationBreakdownPersonnel
            }
        }
    }

    private var calculationBreakdownPersonnel: some View {
        let personnel = expectedPersonnelCount ?? 1
        let rate = productivityRate ?? historicalProductivity ?? 1.0
        let quantityValue = Double(quantity) ?? 0

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()

            // Input: Quantity
            HStack {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Quantity:")
                    .font(.subheadline)
                Spacer()
                Text("\(quantity) \(unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Operator: Division by rate
            HStack {
                Image(systemName: "divide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Productivity:")
                    .font(.subheadline)
                Spacer()
                Text("\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Operator: Division by duration
            HStack {
                Image(systemName: "divide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Duration:")
                    .font(.subheadline)
                Spacer()
                Text(formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Result: Personnel
            TaskRowIconValueLabel(
                icon: "person.2.fill",
                label: "Required Personnel",
                value: "\(personnel) \(personnel == 1 ? "person" : "people")",
                tint: .green
            )
        }
    }

    // MARK: - Manual Mode

    private var manualModeView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Track quantity and set time/personnel manually. Productivity rate will be calculated when the task is completed.",
                style: .info
            )

            if let rate = productivityRate {
                Divider()

                TaskRowIconValueLabel(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Reference Rate",
                    value: "\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr",
                    tint: .secondary
                )
            }
        }
    }

    // MARK: - Shared Productivity Rate View

    private func productivityRateView(_ productivity: Double) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Historical Average Badge
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text("Historical Average:")
                    .font(.caption)
                Text("\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)

            // Toggle for custom rate
            Toggle("Use Custom Rate", isOn: $useCustomRate)
                .onChange(of: useCustomRate) { _, newValue in
                    if !newValue {
                        // Reset to historical when disabled
                        productivityRate = productivity
                        onCalculationUpdate()
                    }
                }

            // Expanded custom rate input
            if useCustomRate {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Custom Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Rate", value: Binding(
                            get: { productivityRate ?? productivity },
                            set: {
                                productivityRate = $0
                                onCalculationUpdate()
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)

                        Text("\(unit.displayName)/person-hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        productivityRate = productivity
                        onCalculationUpdate()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption)
                            Text("Use Historical Average (\(String(format: "%.1f", productivity)))")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Input Rows

    private var personnelInputRow: some View {
        HStack {
            Text("Personnel")
            Spacer()
            Text("\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showPersonnelPicker = true
        }
        .sheet(isPresented: $showPersonnelPicker) {
            personnelPickerSheet
        }
    }

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

    private var durationInputRow: some View {
        HStack {
            Text("Duration")
            Spacer()
            Text(formattedDuration)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showDurationPicker = true
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
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

        historicalProductivity = TemplateManager.getHistoricalProductivity(
            for: selectedTaskType,
            unit: template.defaultUnit,
            from: allTasks
        ) ?? template.defaultUnit.defaultProductivityRate

        productivityRate = historicalProductivity
    }
}
