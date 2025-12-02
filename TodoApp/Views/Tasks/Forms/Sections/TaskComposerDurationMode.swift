import SwiftUI

/// Duration mode for manual time estimate entry
/// Handles subtask estimate aggregation, schedule-based duration, and custom overrides
struct TaskComposerDurationMode: View {
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasCustomEstimate: Bool

    let isSubtask: Bool
    let taskSubtaskEstimateTotal: Int?

    // Schedule context for auto-calculating duration from working window
    let schedule: ScheduleContext

    let onValidation: () -> Void

    @State private var showTimePicker = false
    @State private var manualOverride = false
    @State private var hasInitialized = false

    private var hasSubtasksWithEstimates: Bool {
        !isSubtask && (taskSubtaskEstimateTotal ?? 0) > 0
    }

    /// Whether we have a working window (schedule) set
    private var hasSchedule: Bool {
        schedule.hasWorkingWindow
    }

    /// Calculate duration from schedule (available work hours)
    private var scheduleDurationSeconds: Int? {
        schedule.availableWorkSeconds
    }

    /// Determine the source of duration (priority order: manual > schedule > subtasks)
    private var durationSource: DurationSource {
        if manualOverride {
            return .manual
        } else if hasSchedule && scheduleDurationSeconds != nil {
            return .schedule
        } else if hasSubtasksWithEstimates {
            return .subtasks
        } else {
            return .manual
        }
    }

    enum DurationSource {
        case manual
        case schedule
        case subtasks
    }

    private var formattedDuration: String {
        let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
        return totalSeconds.formattedTime()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Show source info based on what's providing the duration
            switch durationSource {
            case .schedule:
                scheduleInfoView
                Divider()
            case .subtasks:
                if hasSubtasksWithEstimates {
                    overrideInfoView
                    Divider()
                }
            case .manual:
                EmptyView()
            }

            timePickerRow
        }
        .onAppear {
            // Guard: Only initialize once to prevent side effects on re-appear
            guard !hasInitialized else { return }
            hasInitialized = true

            // Initialize from schedule if available
            if hasSchedule, let scheduleDuration = scheduleDurationSeconds, !manualOverride {
                estimateHours = scheduleDuration / 3600
                estimateMinutes = (scheduleDuration % 3600) / 60
                hasEstimate = true
                hasCustomEstimate = hasSubtasksWithEstimates
            } else if hasSubtasksWithEstimates {
                hasCustomEstimate = true
            }
        }
        .onChange(of: schedule) { _, _ in
            updateFromSchedule()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var scheduleInfoView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TaskRowIconValueLabel(
                icon: "calendar.badge.clock",
                label: "Calculated from Working Window",
                value: formattedDuration,
                tint: .blue
            )

            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Duration matches your scheduled work hours. Tap to override manually.",
                style: .info
            )
        }
    }

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
        DurationPickerSheet(
            hours: $estimateHours,
            minutes: $estimateMinutes,
            isPresented: $showTimePicker,
            title: "Set Time Estimate",
            maxHours: EstimationLimits.maxDurationHours
        ) {
            // Mark as manual override if user changes it
            if hasSchedule {
                manualOverride = true
            }
            hasEstimate = true
            onValidation()
        }
    }

    // MARK: - Helper Methods

    private func updateFromSchedule() {
        // Only update if not manually overridden and we have a schedule
        guard !manualOverride, hasSchedule, let scheduleDuration = scheduleDurationSeconds else {
            return
        }

        estimateHours = scheduleDuration / 3600
        estimateMinutes = (scheduleDuration % 3600) / 60
        hasEstimate = true
    }
}
