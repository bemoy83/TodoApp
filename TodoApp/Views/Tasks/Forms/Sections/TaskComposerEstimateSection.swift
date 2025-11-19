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

    // Deadline (for personnel recommendations)
    let hasDueDate: Bool
    let dueDate: Date
    let hasStartDate: Bool
    let startDate: Date
    let hasEndDate: Bool
    let endDate: Date

    // Callbacks
    let onEstimateValidation: () -> Void
    let onEffortUpdate: () -> Void
    let onQuantityUpdate: () -> Void

    @Query(filter: #Predicate<Task> { task in !task.isArchived }, sort: \Task.order) private var allTasks: [Task]

    var body: some View {
        Section("Estimate") {
            Toggle("Set Estimate", isOn: $hasEstimate)

            if hasEstimate {
                persistentEstimateSummary
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

    private var estimateSourceLabel: String {
        switch unifiedEstimationMode {
        case .duration:
            if hasCustomEstimate {
                return "Custom Duration (overriding subtasks)"
            } else if (taskSubtaskEstimateTotal ?? 0) > 0 {
                return "Auto-calculated from Subtasks"
            }
            return "Estimated Duration"
        case .effort:
            if hasPersonnel {
                let personnel = expectedPersonnelCount ?? 1
                return "Duration from Effort (\(personnel) \(personnel == 1 ? "person" : "people"))"
            }
            return "Duration from Effort"
        case .quantity:
            return "Duration from Quantity"
        }
    }

    private var formattedEstimate: String {
        let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
        return totalSeconds.formattedTime()
    }

    @ViewBuilder
    private var persistentEstimateSummary: some View {
        let totalMinutes = (estimateHours * 60) + estimateMinutes

        if totalMinutes > 0 {
            TaskRowIconValueLabel(
                icon: "clock.badge.checkmark",
                label: estimateSourceLabel,
                value: formattedEstimate,
                tint: .green
            )
        } else {
            TaskInlineInfoRow(
                icon: "exclamationmark.triangle",
                message: "No estimate set yet - enter values below",
                style: .warning
            )
        }
    }

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
                estimateHours: $estimateHours,
                estimateMinutes: $estimateMinutes,
                hasDueDate: hasDueDate,
                dueDate: dueDate,
                hasStartDate: hasStartDate,
                startDate: startDate
            )
            .onChange(of: effortHours) { _, _ in
                onEffortUpdate()
            }
            .onChange(of: hasPersonnel) { _, _ in
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
                hasDueDate: hasDueDate,
                dueDate: dueDate,
                hasStartDate: hasStartDate,
                startDate: startDate,
                onCalculationUpdate: onQuantityUpdate
            )
        }
    }
}
