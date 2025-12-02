import SwiftUI

/// Main estimation section with three modes: Duration, Effort, and Quantity
/// Orchestrates the different estimation methods and calculator
struct TaskComposerEstimateSection: View {
    // Grouped estimation state (replaces 13 individual bindings)
    @Binding var estimation: TaskEstimator.EstimationState

    // Context
    let isSubtask: Bool
    let parentSubtaskEstimateTotal: Int?
    let taskSubtaskEstimateTotal: Int?

    // Schedule context (consolidates 6 date parameters)
    let schedule: ScheduleContext

    // Data passed from parent (no @Query)
    let templates: [TaskTemplate]
    let allTasks: [Task]

    // Callbacks (consolidated)
    let callbacks: DetailedEstimationCallbacks

    var body: some View {
        Section("Estimate") {
            Toggle("Set Estimate", isOn: $estimation.hasEstimate)

            if estimation.hasEstimate {
                VStack(spacing: 16) {
                    // Summary at top for immediate visibility (green background provides separation)
                    persistentEstimateSummary

                    // Configuration below (child views have their own internal dividers)
                    VStack(spacing: 12) {
                        estimationModePickerView
                        parentEstimateView
                        estimationContentView
                    }
                }
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
        switch estimation.mode {
        case .duration:
            if estimation.hasCustomEstimate {
                return "Custom Duration (overriding subtasks)"
            } else if (taskSubtaskEstimateTotal ?? 0) > 0 {
                return "Auto-calculated from Subtasks"
            }
            return "Estimated Duration"
        case .effort:
            if estimation.hasPersonnel {
                let personnel = estimation.expectedPersonnelCount ?? 1
                return "Duration from Effort (\(personnel) \(personnel == 1 ? "person" : "people"))"
            }
            return "Duration from Effort"
        case .quantity:
            return "Duration from Quantity"
        }
    }

    @ViewBuilder
    private var persistentEstimateSummary: some View {
        if estimation.totalEstimateMinutes > 0 {
            TaskRowIconValueLabel(
                icon: "clock.badge.checkmark",
                label: estimateSourceLabel,
                value: estimation.formattedEstimate,
                tint: .green
            )
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.08))
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
        Picker("Estimation Method", selection: $estimation.mode) {
            ForEach(TaskEstimator.UnifiedEstimationMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var parentEstimateView: some View {
        if estimation.mode == .duration,
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
        switch estimation.mode {
        case .duration:
            TaskComposerDurationMode(
                hasEstimate: $estimation.hasEstimate,
                estimateHours: $estimation.estimateHours,
                estimateMinutes: $estimation.estimateMinutes,
                hasCustomEstimate: $estimation.hasCustomEstimate,
                isSubtask: isSubtask,
                taskSubtaskEstimateTotal: taskSubtaskEstimateTotal,
                schedule: schedule,
                onValidation: callbacks.onEstimateChange
            )

        case .effort:
            EffortInputSection(
                effortHours: $estimation.effortHours,
                hasPersonnel: $estimation.hasPersonnel,
                expectedPersonnelCount: $estimation.expectedPersonnelCount,
                estimateHours: $estimation.estimateHours,
                estimateMinutes: $estimation.estimateMinutes,
                schedule: schedule
            )
            .onChange(of: estimation.effortHours) { _, _ in
                callbacks.onEffortChange()
            }
            .onChange(of: estimation.hasPersonnel) { _, _ in
                callbacks.onEffortChange()
            }
            .onChange(of: estimation.expectedPersonnelCount) { _, _ in
                callbacks.onEffortChange()
            }

        case .quantity:
            TaskComposerQuantitySection(
                taskType: $estimation.taskType,
                unit: $estimation.unit,
                quantity: $estimation.quantity,
                quantityCalculationMode: $estimation.quantityCalculationMode,
                productivityRate: $estimation.productivityRate,
                hasEstimate: $estimation.hasEstimate,
                estimateHours: $estimation.estimateHours,
                estimateMinutes: $estimation.estimateMinutes,
                hasPersonnel: $estimation.hasPersonnel,
                expectedPersonnelCount: $estimation.expectedPersonnelCount,
                schedule: schedule,
                templates: templates,
                allTasks: allTasks,
                onCalculationUpdate: callbacks.onQuantityChange
            )
        }
    }
}
