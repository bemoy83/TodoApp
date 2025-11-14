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
    @State private var showProductivitySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                historicalProductivityView(productivity)
                Divider()
            }

            personnelStepperView
            calculatedResultView
        }
    }

    // MARK: - Subviews

    private func historicalProductivityView(_ productivity: Double) -> some View {
        HStack {
            Text("Productivity Rate")
            Spacer()
            Text("\(String(format: "%.1f", productivity)) \(unit.displayName)/person-hr")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showProductivitySheet = true
        }
        .sheet(isPresented: $showProductivitySheet) {
            productivityRateSheet
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

    private var productivityRateSheet: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Productivity Rate")
                        .font(.headline)

                    Text("Enter custom rate or use historical average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DesignSystem.Spacing.md)

                HStack {
                    TextField("Rate", value: Binding(
                        get: { productivityRate ?? historicalProductivity ?? 0 },
                        set: {
                            productivityRate = $0
                            onUpdate()
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title2)

                    Text("\(unit.displayName)/person-hr")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                if let historical = historicalProductivity {
                    Button {
                        productivityRate = historical
                        onUpdate()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Use Historical Average (\(String(format: "%.1f", historical)))")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showProductivitySheet = false
                    }
                }
            }
            .presentationDetents([.height(280)])
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
