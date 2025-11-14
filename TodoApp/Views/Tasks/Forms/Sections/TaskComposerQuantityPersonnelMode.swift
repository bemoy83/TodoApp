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

    @State private var showDurationPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                historicalProductivityView(productivity)
                Divider()
            }

            durationPickerView
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

    private var durationPickerView: some View {
        HStack {
            Text("Duration")
            Spacer()
            Text(formattedDuration)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showDurationPicker = true
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
        }
    }

    private var durationPickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Duration")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                DatePicker(
                    "Duration",
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
                            hasEstimate = true
                            onUpdate()
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
                        showDurationPicker = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var formattedDuration: String {
        let totalMinutes = (estimateHours * 60) + estimateMinutes
        if totalMinutes == 0 {
            return "Not set"
        }

        if estimateHours > 0 && estimateMinutes > 0 {
            return "\(estimateHours)h \(estimateMinutes)m"
        } else if estimateHours > 0 {
            return "\(estimateHours)h"
        } else {
            return "\(estimateMinutes)m"
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
