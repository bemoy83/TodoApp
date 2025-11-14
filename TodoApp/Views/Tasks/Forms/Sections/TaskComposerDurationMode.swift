import SwiftUI

/// Duration mode for manual time estimate entry
/// Handles subtask estimate aggregation and custom overrides
struct TaskComposerDurationMode: View {
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasCustomEstimate: Bool

    let isSubtask: Bool
    let taskSubtaskEstimateTotal: Int?
    let onValidation: () -> Void

    private var hasSubtasksWithEstimates: Bool {
        !isSubtask && (taskSubtaskEstimateTotal ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            estimateToggleView

            if hasEstimate {
                timePickerView
                estimateSummaryView
                overrideWarningView
            } else if hasSubtasksWithEstimates {
                autoCalculatedEstimateView
            }
        }
    }

    // MARK: - Subviews

    private var estimateToggleView: some View {
        Toggle(
            hasSubtasksWithEstimates ? "Override Subtask Estimates" : "Set Time Estimate",
            isOn: $hasEstimate
        )
        .onChange(of: hasEstimate) { _, newValue in
            hasCustomEstimate = hasSubtasksWithEstimates ? newValue : false
            if newValue {
                onValidation()
            }
        }
    }

    @ViewBuilder
    private var autoCalculatedEstimateView: some View {
        if let total = taskSubtaskEstimateTotal {
            TaskRowIconValueLabel(
                icon: "sum",
                label: "Auto-Calculated from Subtasks",
                value: (total * 60).formattedTime(),
                tint: .green
            )
        }
    }

    private var timePickerView: some View {
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
                    onValidation()
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
    }

    @ViewBuilder
    private var estimateSummaryView: some View {
        let totalMinutes = (estimateHours * 60) + estimateMinutes
        if totalMinutes > 0 {
            TaskRowIconValueLabel(
                icon: "clock.fill",
                label: "Estimated Duration",
                value: (totalMinutes * 60).formattedTime(),
                tint: .blue
            )
            .padding(.top, 4)
        } else {
            TaskInlineInfoRow(
                icon: "exclamationmark.triangle",
                message: "Setting 0 time will remove the estimate",
                style: .warning
            )
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var overrideWarningView: some View {
        if hasSubtasksWithEstimates, let total = taskSubtaskEstimateTotal {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Custom estimate will be used instead of auto-calculated \((total * 60).formattedTime()) from subtasks",
                style: .warning
            )
            .padding(.top, 4)
        }
    }
}
