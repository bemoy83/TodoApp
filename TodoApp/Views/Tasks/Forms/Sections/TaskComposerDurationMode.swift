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

    // Schedule parameters for auto-calculating duration from working window
    let hasStartDate: Bool
    let startDate: Date
    let hasEndDate: Bool
    let endDate: Date

    let onValidation: () -> Void

    @State private var showTimePicker = false
    @State private var manualOverride = false

    private var hasSubtasksWithEstimates: Bool {
        !isSubtask && (taskSubtaskEstimateTotal ?? 0) > 0
    }

    /// Whether we have a working window (schedule) set
    private var hasSchedule: Bool {
        hasStartDate && hasEndDate
    }

    /// Calculate duration from schedule (available work hours)
    private var scheduleDurationSeconds: Int? {
        guard hasSchedule else { return nil }
        let hours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
        return Int(hours * 3600)
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
                break
            }

            timePickerRow
        }
        .onAppear {
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
        .onChange(of: startDate) { _, _ in
            updateFromSchedule()
        }
        .onChange(of: endDate) { _, _ in
            updateFromSchedule()
        }
        .onChange(of: hasStartDate) { _, _ in
            updateFromSchedule()
        }
        .onChange(of: hasEndDate) { _, _ in
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

                            // Mark as manual override if user changes it
                            if hasSchedule {
                                manualOverride = true
                            }

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
