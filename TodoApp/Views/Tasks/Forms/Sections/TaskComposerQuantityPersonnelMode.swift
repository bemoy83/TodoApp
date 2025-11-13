import SwiftUI

/// Personnel calculation mode for quantity-based estimation
/// Calculates personnel from quantity, productivity rate, and duration
struct TaskComposerQuantityPersonnelMode: View {
    @Binding var historicalProductivity: Double?
    @Binding var productivityRate: Double?
    @Binding var isProductivityOverrideExpanded: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasEstimate: Bool
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    let unit: UnitType
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                historicalProductivityView(productivity)
                Divider()
            }

            durationHoursPickerView
            durationMinutesPickerView
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

    private var durationHoursPickerView: some View {
        HStack {
            Text("Duration (hours)")
            Spacer()
            Picker("Hours", selection: Binding(
                get: { estimateHours },
                set: {
                    estimateHours = $0
                    hasEstimate = true
                    onUpdate()
                }
            )) {
                ForEach(0..<100, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
    }

    private var durationMinutesPickerView: some View {
        HStack {
            Text("Minutes")
            Spacer()
            Picker("Minutes", selection: Binding(
                get: { estimateMinutes },
                set: {
                    estimateMinutes = $0
                    hasEstimate = true
                    onUpdate()
                }
            )) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text("\(minute)").tag(minute)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
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
        if hasPersonnel, let personnel = expectedPersonnelCount {
            Divider()

            TaskRowIconValueLabel(
                icon: "person.2.fill",
                label: "Required Personnel",
                value: "\(personnel) \(personnel == 1 ? "person" : "people")",
                tint: .green
            )
        }
    }
}
