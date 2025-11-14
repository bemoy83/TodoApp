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

    @State private var showTimePicker = false

    private var hasSubtasksWithEstimates: Bool {
        !isSubtask && (taskSubtaskEstimateTotal ?? 0) > 0
    }

    private var formattedDuration: String {
        let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
        return totalSeconds.formattedTime()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if hasSubtasksWithEstimates {
                overrideInfoView
                Divider()
            }

            timePickerRow
            estimateSummaryView
        }
        .onAppear {
            hasCustomEstimate = hasSubtasksWithEstimates
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var overrideInfoView: some View {
        if let total = taskSubtaskEstimateTotal {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                TaskRowIconValueLabel(
                    icon: "sum",
                    label: "Auto-Calculated from Subtasks",
                    value: (total * 60).formattedTime(),
                    tint: .green
                )

                TaskInlineInfoRow(
                    icon: "info.circle",
                    message: "Setting a custom estimate will override the auto-calculated total",
                    style: .warning
                )
            }
        }
    }

    private var timePickerRow: some View {
        HStack {
            Text("Time Estimate")
            Spacer()
            Text(formattedDuration)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showTimePicker = true
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
    }

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Time Estimate")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                DatePicker(
                    "Time Estimate",
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
                            estimateHours = min(max(components.hour ?? 0, 0), 99)
                            estimateMinutes = min(max(components.minute ?? 0, 0), 59)
                            onValidation()
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
                        showTimePicker = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var estimateSummaryView: some View {
        let totalMinutes = (estimateHours * 60) + estimateMinutes
        if totalMinutes == 0 {
            TaskInlineInfoRow(
                icon: "exclamationmark.triangle",
                message: "Setting 0 time will remove the estimate",
                style: .warning
            )
            .padding(.top, DesignSystem.Spacing.xs)
        }
    }
}
