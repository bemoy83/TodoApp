import SwiftUI
import SwiftData

/// Main estimation section with three modes: Duration, Effort, and Quantity
/// Orchestrates the different estimation methods and calculator
struct TaskComposerEstimateSection: View {
    // Estimation mode
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode

    // Duration mode bindings
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasCustomEstimate: Bool

    // Effort mode bindings
    @Binding var effortHours: Double
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var hasDueDate: Bool
    let dueDate: Date

    // Quantity mode bindings
    @Binding var taskType: String?
    @Binding var unit: UnitType
    @Binding var quantity: String
    @Binding var quantityCalculationMode: TaskEstimator.QuantityCalculationMode
    @Binding var productivityRate: Double?

    // Context
    let isSubtask: Bool
    let parentSubtaskEstimateTotal: Int?
    let taskSubtaskEstimateTotal: Int?

    // Callbacks
    let onEstimateValidation: () -> Void
    let onEffortUpdate: () -> Void
    let onQuantityUpdate: () -> Void

    @Query(filter: #Predicate<Task> { task in !task.isArchived }, sort: \Task.order) private var allTasks: [Task]

    var body: some View {
        Section("Estimate") {
            Toggle("Set Estimate", isOn: $hasEstimate)

            if hasEstimate {
                estimationModePickerView
                parentEstimateView
                estimationContentView
            } else {
                TaskInlineInfoRow(
                    icon: "info.circle",
                    message: "No estimate set for this task",
                    style: .info
                )
            }
        }
    }

    // MARK: - Subviews

    private var estimationModePickerView: some View {
        Picker("Estimation Method", selection: $unifiedEstimationMode) {
            ForEach(TaskEstimator.UnifiedEstimationMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var parentEstimateView: some View {
        if unifiedEstimationMode == .duration,
           isSubtask,
           let parentTotal = parentSubtaskEstimateTotal,
           parentTotal > 0 {
            TaskRowIconValueLabel(
                icon: "clock.badge.checkmark",
                label: "Parent's Estimate",
                value: (parentTotal * 60).formattedTime(),
                tint: .blue
            )
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var estimationContentView: some View {
        switch unifiedEstimationMode {
        case .duration:
            TaskComposerDurationMode(
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasCustomEstimate: $hasCustomEstimate,
                isSubtask: isSubtask,
                taskSubtaskEstimateTotal: taskSubtaskEstimateTotal,
                onValidation: onEstimateValidation
            )

        case .effort:
            EffortInputSection(
                effortHours: $effortHours,
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                hasDueDate: $hasDueDate,
                dueDate: dueDate
            )
            .onChange(of: effortHours) { _, _ in
                onEffortUpdate()
            }
            .onChange(of: expectedPersonnelCount) { _, _ in
                onEffortUpdate()
            }

        case .quantity:
            TaskComposerQuantitySection(
                taskType: $taskType,
                unit: $unit,
                quantity: $quantity,
                quantityCalculationMode: $quantityCalculationMode,
                productivityRate: $productivityRate,
                hasEstimate: $hasEstimate,
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasPersonnel: $hasPersonnel,
                expectedPersonnelCount: $expectedPersonnelCount,
                onCalculationUpdate: onQuantityUpdate
            )
        }
    }
}
