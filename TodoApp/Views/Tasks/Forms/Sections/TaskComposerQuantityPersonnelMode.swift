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
    @State private var showProductivitySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let productivity = historicalProductivity {
                historicalProductivityView(productivity)
                Divider()
            }

            durationPickerView
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
