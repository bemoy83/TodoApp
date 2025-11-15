import SwiftUI

/// Handles effort-based estimation input with real-time duration calculation
struct EffortInputSection: View {
    @Binding var effortHours: Double
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    @State private var showEffortPicker = false
    @State private var effortInput: String = ""
    @FocusState private var isEffortFieldFocused: Bool

    private var formattedEffort: String {
        if effortHours == 0 {
            return "Not set"
        }
        // Show decimal if not a whole number
        if effortHours.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(effortHours)) person-hours"
        } else {
            return String(format: "%.1f person-hours", effortHours)
        }
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

            // Show calculation breakdown or prompt
            if effortHours > 0 {
                if hasPersonnel {
                    calculationBreakdown
                } else {
                    personnelPrompt
                }
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
                            } else if newValue.isEmpty {
                                effortHours = 0
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
                if effortHours > 0 {
                    // Show clean decimal format
                    if effortHours.truncatingRemainder(dividingBy: 1) == 0 {
                        effortInput = "\(Int(effortHours))"
                    } else {
                        effortInput = String(format: "%.1f", effortHours)
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
        let durationHours = effortHours / Double(personnel)
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
