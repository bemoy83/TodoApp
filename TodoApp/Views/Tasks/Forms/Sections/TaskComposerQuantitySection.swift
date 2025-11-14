import SwiftUI
import SwiftData

/// Quantity-based estimation calculator section
/// Handles task type selection, unit tracking, and calculation modes
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
    @FocusState private var isQuantityFieldFocused: Bool

    let onCalculationUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            taskTypePickerView

            if unit.isQuantifiable {
                quantityInputRow

                Divider()
                    .padding(.vertical, DesignSystem.Spacing.md)

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
        Group {
            switch quantityCalculationMode {
        case .calculateDuration:
            TaskComposerQuantityDurationMode(
                historicalProductivity: $historicalProductivity,
                productivityRate: $productivityRate,
                expectedPersonnelCount: $expectedPersonnelCount,
                hasPersonnel: $hasPersonnel,
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                unit: unit,
                onUpdate: onCalculationUpdate
            )
            .id("duration-mode")

        case .calculatePersonnel:
            TaskComposerQuantityPersonnelMode(
                historicalProductivity: $historicalProductivity,
                productivityRate: $productivityRate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasEstimate: $hasEstimate,
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                unit: unit,
                onUpdate: onCalculationUpdate
            )
            .id("personnel-mode")

        case .manualEntry:
            TaskComposerQuantityManualMode(
                productivityRate: productivityRate,
                unit: unit
            )
            .id("manual-mode")
            }
        }
        .animation(nil, value: quantityCalculationMode)
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
