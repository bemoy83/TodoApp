import SwiftUI

/// Reusable selector for quantity calculation modes
/// Allows users to choose what to calculate: duration, personnel, or productivity
struct CalculationModeSelector: View {
    @Binding var mode: TaskEstimator.QuantityCalculationMode
    @Binding var showMenu: Bool

    let onModeChange: (TaskEstimator.QuantityCalculationMode) -> Void

    var body: some View {
        EmptyView()
            .confirmationDialog(
                "Switch Calculation Mode",
                isPresented: $showMenu,
                titleVisibility: .visible
            ) {
                Button("Calculate Duration") {
                    changeMode(to: .calculateDuration)
                }

                Button("Calculate Personnel") {
                    changeMode(to: .calculatePersonnel)
                }

                Button("Calculate Productivity (Manual)") {
                    changeMode(to: .manualEntry)
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose what to calculate from quantity and other inputs.\n\nNote: Switching modes may reset some values.")
            }
    }

    private func changeMode(to newMode: TaskEstimator.QuantityCalculationMode) {
        mode = newMode
        onModeChange(newMode)
    }
}

/// Visual indicator showing current calculation mode
struct CalculationModeIndicator: View {
    let mode: TaskEstimator.QuantityCalculationMode
    let icon: String
    let label: String
    let color: Color

    init(
        mode: TaskEstimator.QuantityCalculationMode,
        icon: String = "function",
        label: String? = nil,
        color: Color = .blue
    ) {
        self.mode = mode
        self.icon = icon
        self.label = label ?? mode.rawValue
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

/// Badge showing which field is being calculated
struct CalculatedFieldBadge: View {
    let fieldName: String
    let isCalculated: Bool

    var body: some View {
        if isCalculated {
            HStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("Auto")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
        }
    }
}

/// Row for input/calculated fields in quantity mode
struct EstimationInputRow: View {
    let icon: String
    let label: String
    let value: String
    let isCalculated: Bool
    let action: () -> Void

    init(
        icon: String,
        label: String,
        value: String,
        isCalculated: Bool,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.value = value
        self.isCalculated = isCalculated
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isCalculated ? "lock.fill" : icon)
                    .font(.subheadline)
                    .foregroundStyle(isCalculated ? .green : .blue)
                    .frame(width: 24)

                Text(label)
                    .foregroundStyle(.primary)

                Spacer()

                Text(value)
                    .foregroundStyle(isCalculated ? .green : .secondary)

                if !isCalculated {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "function")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Calculation summary view showing the formula
struct CalculationSummaryView: View {
    let mode: TaskEstimator.QuantityCalculationMode
    let quantity: Double
    let productivityRate: Double
    let personnelCount: Int
    let durationHours: Int
    let durationMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: "function")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Formula")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            formulaText
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.leading, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private var formulaText: some View {
        let totalSeconds = (durationHours * 3600) + (durationMinutes * 60)

        switch mode {
        case .calculateDuration:
            Text("\(String(format: "%.0f", quantity)) ÷ \(String(format: "%.1f", productivityRate)) ÷ \(personnelCount) = \(totalSeconds.formattedTime())")

        case .calculatePersonnel:
            Text("\(String(format: "%.0f", quantity)) ÷ \(String(format: "%.1f", productivityRate)) ÷ \(totalSeconds.formattedTime()) = \(personnelCount) \(personnelCount == 1 ? "person" : "people")")

        case .manualEntry:
            Text("Productivity will be calculated on task completion")
                .foregroundStyle(.secondary)
        }
    }
}

/// Explanation card for calculation modes
struct CalculationModeExplanation: View {
    let mode: TaskEstimator.QuantityCalculationMode

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: iconForMode)
                    .font(.caption)
                    .foregroundStyle(colorForMode)

                Text(titleForMode)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorForMode)
            }

            Text(descriptionForMode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForMode.opacity(0.1))
        )
    }

    private var iconForMode: String {
        switch mode {
        case .calculateDuration: return "clock.fill"
        case .calculatePersonnel: return "person.2.fill"
        case .manualEntry: return "chart.line.uptrend.xyaxis"
        }
    }

    private var colorForMode: Color {
        switch mode {
        case .calculateDuration: return .blue
        case .calculatePersonnel: return .green
        case .manualEntry: return .orange
        }
    }

    private var titleForMode: String {
        switch mode {
        case .calculateDuration: return "Calculating Duration"
        case .calculatePersonnel: return "Calculating Personnel"
        case .manualEntry: return "Manual Entry Mode"
        }
    }

    private var descriptionForMode: String {
        switch mode {
        case .calculateDuration:
            return "Enter quantity, productivity rate, and personnel count to calculate how long the task will take"
        case .calculatePersonnel:
            return "Enter quantity, productivity rate, and duration to calculate how many people are needed"
        case .manualEntry:
            return "Track quantity manually. Productivity rate will be calculated automatically when the task is completed"
        }
    }
}

// MARK: - Preview

#Preview("Calculation Mode Selector") {
    @Previewable @State var mode: TaskEstimator.QuantityCalculationMode = .calculateDuration
    @Previewable @State var showMenu = false

    VStack(spacing: 20) {
        Button("Switch Calculation Mode") {
            showMenu = true
        }

        CalculationModeIndicator(mode: mode)

        CalculationModeExplanation(mode: mode)
    }
    .padding()
    .background(CalculationModeSelector(mode: $mode, showMenu: $showMenu) { newMode in
        print("Mode changed to: \(newMode)")
    })
}

#Preview("Estimation Input Rows") {
    VStack(spacing: 12) {
        EstimationInputRow(
            icon: "number",
            label: "Quantity",
            value: "250 m²",
            isCalculated: false
        ) {
            print("Edit quantity")
        }

        EstimationInputRow(
            icon: "chart.line.uptrend.xyaxis",
            label: "Productivity",
            value: "12.5 m²/hr",
            isCalculated: false
        ) {
            print("Edit productivity")
        }

        EstimationInputRow(
            icon: "person.2.fill",
            label: "Personnel",
            value: "5 people",
            isCalculated: true
        ) {
            print("Cannot edit - calculated")
        }

        EstimationInputRow(
            icon: "clock.fill",
            label: "Duration",
            value: "4h 0m",
            isCalculated: false
        ) {
            print("Edit duration")
        }
    }
    .padding()
}

#Preview("Calculation Summary") {
    CalculationSummaryView(
        mode: .calculateDuration,
        quantity: 250,
        productivityRate: 12.5,
        personnelCount: 5,
        durationHours: 4,
        durationMinutes: 0
    )
    .padding()
}
