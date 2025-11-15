import SwiftUI

/// Handles effort-based estimation input with real-time duration calculation
struct EffortInputSection: View {
    @Binding var effortHours: Double
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    @State private var showEffortPicker = false

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
                message: "Person-hours = total work required by all people combined",
                style: .info
            )

            Divider()

            // Effort input row
            effortPickerRow

            // Show calculation breakdown or prompt
            if effortHours > 0 {
                if hasPersonnel, let personnel = expectedPersonnelCount, personnel > 0 {
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

                // Use DatePicker to select hours only
                DatePicker(
                    "Effort Hours",
                    selection: Binding(
                        get: {
                            // Convert hours to a date
                            let hours = Int(effortHours)
                            let minutes = Int((effortHours - Double(hours)) * 60)
                            return Calendar.current.date(
                                from: DateComponents(hour: hours, minute: minutes)
                            ) ?? Date()
                        },
                        set: { newValue in
                            // Extract hours and minutes from date
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            let hours = Double(components.hour ?? 0)
                            let minutes = Double(components.minute ?? 0)
                            effortHours = hours + (minutes / 60.0)
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.wheel)

                Text("Total person-hours of work required")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showEffortPicker = false
                    }
                }
            }
            .presentationDetents([.height(350)])
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

            // Calculation steps
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
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
                    .padding(.vertical, 2)

                // Result: Duration
                TaskRowIconValueLabel(
                    icon: "clock.fill",
                    label: "= Duration per person",
                    value: totalSeconds.formattedTime(),
                    tint: .green
                )
            }
            .padding(12)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
}
