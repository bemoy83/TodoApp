import SwiftUI

/// Handles effort-based estimation input with real-time duration calculation
struct EffortInputSection: View {
    @Binding var effortHours: Double
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int

    // Deadline (for personnel recommendations)
    let hasDueDate: Bool
    let dueDate: Date
    let hasStartDate: Bool
    let startDate: Date

    @State private var showEffortPicker = false
    @State private var effortInput: String = ""
    @State private var manuallySetEffort: Double? = nil
    @FocusState private var isEffortFieldFocused: Bool

    // MARK: - Computed Properties

    /// Total duration in hours (from estimate)
    private var durationInHours: Double {
        Double(estimateHours) + (Double(estimateMinutes) / 60.0)
    }

    /// Check if effort should be calculated from duration × personnel
    private var shouldCalculateEffort: Bool {
        // Calculate if:
        // 1. No manual effort is set
        // 2. Personnel is set
        // 3. Duration is set
        return manuallySetEffort == nil &&
               hasPersonnel &&
               (estimateHours > 0 || estimateMinutes > 0)
    }

    /// Calculated effort from duration × personnel
    private var calculatedEffort: Double {
        guard shouldCalculateEffort else { return 0 }
        let personnel = Double(expectedPersonnelCount ?? 1)
        return durationInHours * personnel
    }

    /// The effective effort (manual takes precedence over calculated)
    private var effectiveEffort: Double {
        if let manual = manuallySetEffort {
            return manual
        } else if shouldCalculateEffort {
            return calculatedEffort
        }
        return effortHours
    }

    /// Whether the current effort is calculated (not manual)
    private var isEffortCalculated: Bool {
        manuallySetEffort == nil && shouldCalculateEffort && calculatedEffort > 0
    }

    private var formattedEffort: String {
        let effort = effectiveEffort
        if effort == 0 {
            return "Not set"
        }
        // Show decimal if not a whole number
        if effort.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(effort)) person-hours"
        } else {
            return String(format: "%.1f person-hours", effort)
        }
    }

    /// Whether to show personnel recommendations
    private var shouldShowPersonnelRecommendation: Bool {
        hasDueDate && effectiveEffort > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Explanation of person-hours
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Person-hours = total work by all people",
                style: .info
            )

            Divider()

            // Effort input row
            effortPickerRow

            // Show calculated effort badge
            if isEffortCalculated {
                calculatedEffortBadge
            }

            // Show calculation breakdown or prompt
            if effectiveEffort > 0 {
                if hasPersonnel {
                    calculationBreakdown
                } else {
                    personnelPrompt
                }
            }

            // Personnel recommendation
            if shouldShowPersonnelRecommendation {
                Divider()
                    .padding(.top, DesignSystem.Spacing.sm)

                PersonnelRecommendationView(
                    effortHours: effectiveEffort,
                    startDate: hasStartDate ? startDate : nil,
                    deadline: dueDate,
                    currentSelection: expectedPersonnelCount,
                    taskType: nil,
                    allTasks: nil
                ) { selectedCount in
                    hasPersonnel = true
                    expectedPersonnelCount = selectedCount
                }
                .id("\(hasStartDate ? startDate.timeIntervalSince1970 : 0)-\(dueDate.timeIntervalSince1970)")
            }
        }
        .onChange(of: effectiveEffort) { _, newValue in
            // Sync the binding
            effortHours = newValue
        }
        .onAppear {
            // Initialize manuallySetEffort if effortHours was already set
            if effortHours > 0 {
                manuallySetEffort = effortHours
            }
        }
    }

    // MARK: - Subviews

    private var effortPickerRow: some View {
        HStack {
            Text("Total Work Effort")
            Spacer()
            Text(formattedEffort)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showEffortPicker = true
        }
        .sheet(isPresented: $showEffortPicker) {
            effortPickerSheet
        }
    }

    private var effortPickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Total Work Effort")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("0", text: $effortInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .focused($isEffortFieldFocused)
                        .frame(maxWidth: 200)
                        .onChange(of: effortInput) { _, newValue in
                            if let value = Double(newValue), value >= 0 {
                                effortHours = value
                                manuallySetEffort = value
                            } else if newValue.isEmpty {
                                effortHours = 0
                                manuallySetEffort = nil
                            }
                        }

                    Text("person-hours")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showEffortPicker = false
                        isEffortFieldFocused = false
                    }
                }
            }
            .onAppear {
                let effort = effectiveEffort
                if effort > 0 {
                    // Show clean decimal format
                    if effort.truncatingRemainder(dividingBy: 1) == 0 {
                        effortInput = "\(Int(effort))"
                    } else {
                        effortInput = String(format: "%.1f", effort)
                    }
                } else {
                    effortInput = ""
                }
                isEffortFieldFocused = true
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var calculatedEffortBadge: some View {
        let personnel = expectedPersonnelCount ?? 1
        let durationFormatted = (estimateHours * 3600 + estimateMinutes * 60).formattedTime()

        return TaskInlineInfoRow(
            icon: "function",
            message: "Calculated from \(durationFormatted) × \(personnel) \(personnel == 1 ? "person" : "people")",
            style: .info
        )
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private var personnelPrompt: some View {
        TaskInlineInfoRow(
            icon: "arrow.up.circle",
            message: "Set Personnel above to calculate duration from effort",
            style: .info
        )
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private var calculationBreakdown: some View {
        let personnel = expectedPersonnelCount ?? 1
        let durationHours = effectiveEffort / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()

            // Input: Effort
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Total Effort:")
                    .font(.subheadline)
                Spacer()
                Text(formattedEffort)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Operator: Division
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
}
