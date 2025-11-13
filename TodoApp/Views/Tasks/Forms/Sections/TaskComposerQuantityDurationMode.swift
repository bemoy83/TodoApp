import SwiftUI

/// Duration calculation mode for quantity-based estimation
/// Calculates duration from quantity, productivity rate, and personnel count
struct TaskComposerQuantityDurationMode: View {
    @Binding var historicalProductivity: Double?
    @Binding var productivityRate: Double?
    @Binding var isProductivityOverrideExpanded: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var hasPersonnel: Bool
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int

    let unit: UnitType
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                historicalProductivityView(productivity)
                Divider()
            }

            personnelStepperView
            productivityOverrideView
            calculatedResultView
        }
    }

    // MARK: - Subviews

    private func historicalProductivityView(_ productivity: Double) -> some View {
        HStack {
            TaskRowIconValueLabel(
                icon: "chart.line.uptrend.xyaxis",
                label: "Historical Average",
                value: "\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr",
                tint: DesignSystem.Colors.success
            )

            Spacer()

            Button {
                withAnimation {
                    isProductivityOverrideExpanded.toggle()
                }
            } label: {
                Image(systemName: isProductivityOverrideExpanded ? "pencil.circle.fill" : "pencil.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var personnelStepperView: some View {
        Stepper(value: Binding(
            get: { expectedPersonnelCount ?? 1 },
            set: {
                expectedPersonnelCount = $0
                hasPersonnel = true
                onUpdate()
            }
        ), in: 1...20) {
            HStack {
                Text("Personnel")
                Spacer()
                Text("\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var productivityOverrideView: some View {
        if productivityRate != nil && isProductivityOverrideExpanded {
            Divider()

            HStack {
                Text("Custom Rate")
                Spacer()
                TextField("Rate", value: Binding(
                    get: { productivityRate ?? 0 },
                    set: {
                        productivityRate = $0
                        onUpdate()
                    }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                Text("\(unit.displayName)/person-hr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var calculatedResultView: some View {
        if hasEstimate {
            let totalSeconds = (estimateHours * 3600) + (estimateMinutes * 60)
            if totalSeconds > 0 {
                Divider()

                TaskRowIconValueLabel(
                    icon: "checkmark.circle.fill",
                    label: "Estimated Duration",
                    value: totalSeconds.formattedTime(),
                    tint: .blue
                )
            }
        }
    }
}
