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
    @FocusState private var isQuantityFieldFocused: Bool

    let onCalculationUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            taskTypePickerView

            if taskType != nil {
                unitDisplayView
            }

            if unit.isQuantifiable {
                quantityInputView
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

    @ViewBuilder
    private var unitDisplayView: some View {
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

    @ViewBuilder
    private var quantityInputView: some View {
        HStack {
            TextField("Quantity", text: $quantity)
                .keyboardType(.decimalPad)
                .focused($isQuantityFieldFocused)

            Text(unit.displayName)
                .foregroundStyle(.secondary)
        }
    }

    private var calculationStrategyView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TaskFormSectionHeader(title: "Calculation Strategy")

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
                isQuantityFieldFocused = false // Dismiss keyboard when switching modes
            }
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
