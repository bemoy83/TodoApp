import SwiftUI

/// Duration calculation mode for quantity-based estimation
/// Calculates duration from quantity, productivity rate, and personnel count
struct TaskComposerQuantityDurationMode: View {
    @Binding var historicalProductivity: Double?
    @Binding var productivityRate: Double?
    @Binding var expectedPersonnelCount: Int?
    @Binding var hasPersonnel: Bool
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int

    let unit: UnitType
    let onUpdate: () -> Void

    @State private var showPersonnelPicker = false
    @State private var useCustomRate = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                productivityRateView(productivity)
                Divider()
            }

            personnelStepperView
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

    private var personnelStepperView: some View {
        HStack {
            Text("Personnel")
            Spacer()
            Text("\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showPersonnelPicker = true
        }
        .sheet(isPresented: $showPersonnelPicker) {
            personnelPickerSheet
        }
    }

    private var personnelPickerSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Select Personnel Count")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                Picker("Personnel", selection: Binding(
                    get: { expectedPersonnelCount ?? 1 },
                    set: {
                        expectedPersonnelCount = $0
                        hasPersonnel = true
                        onUpdate()
                    }
                )) {
                    ForEach(1...20, id: \.self) { count in
                        Text("\(count) \(count == 1 ? "person" : "people")")
                            .tag(count)
                    }
                }
                .pickerStyle(.wheel)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showPersonnelPicker = false
                    }
                }
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
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
