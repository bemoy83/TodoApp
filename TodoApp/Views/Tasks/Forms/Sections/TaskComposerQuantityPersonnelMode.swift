import SwiftUI

/// Personnel calculation mode for quantity-based estimation
/// Calculates personnel from quantity, productivity rate, and duration
struct TaskComposerQuantityPersonnelMode: View {
    @Binding var historicalProductivity: Double?
    @Binding var productivityRate: Double?
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasEstimate: Bool
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    let unit: UnitType
    let onUpdate: () -> Void

    @State private var showDurationPicker = false
    @State private var useCustomRate = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                productivityRateView(productivity)
                Divider()
            }

            durationPickerView
            calculatedResultView
        }
        .onAppear {
            // Set initial toggle state based on whether custom rate exists
            useCustomRate = productivityRate != nil && productivityRate != historicalProductivity
        }
    }

    // MARK: - Subviews

    private func productivityRateView(_ productivity: Double) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Historical Average (Read-Only)
            VStack(alignment: .leading, spacing: 2) {
                Text("Historical Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Toggle for custom rate
            Toggle("Use Custom Rate", isOn: $useCustomRate)
                .onChange(of: useCustomRate) { _, newValue in
                    if !newValue {
                        // Reset to historical when disabled
                        productivityRate = productivity
                        onUpdate()
                    }
                }

            // Expanded custom rate input
            if useCustomRate {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Custom Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Rate", value: Binding(
                            get: { productivityRate ?? productivity },
                            set: {
                                productivityRate = $0
                                onUpdate()
                            }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                        Text("\(unit.displayName)/person-hr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        productivityRate = productivity
                        onUpdate()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption)
                            Text("Use Historical Average (\(String(format: "%.1f", productivity)))")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
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
