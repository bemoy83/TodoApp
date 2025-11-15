import SwiftUI

/// Personnel assignment section for TaskComposerForm
/// Handles both auto-calculated (read-only) and manual personnel entry
struct TaskComposerPersonnelSection: View {
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode

    let personnelIsAutoCalculated: Bool
    let quantityCalculationMode: TaskEstimator.QuantityCalculationMode

    @State private var showPersonnelPicker = false

    var body: some View {
        Section("Personnel") {
            if personnelIsAutoCalculated {
                autoCalculatedPersonnelView
            } else {
                manualPersonnelView
            }
        }
    }

    // MARK: - Subviews

    private var autoCalculatedPersonnelView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Linked badge indicator
            HStack(spacing: 6) {
                Image(systemName: "link.circle.fill")
                    .font(.subheadline)
                Text("Linked to Estimate (below)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            Divider()

            // Personnel count display
            TaskRowIconValueLabel(
                icon: "person.2.fill",
                label: "Required Personnel",
                value: "\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")",
                tint: .green
            )

            // Calculation mode context
            TaskInlineInfoRow(
                icon: "info.circle",
                message: quantityCalculationMode == .calculatePersonnel
                    ? "Auto-calculated from quantity, productivity rate, and duration in Estimate section"
                    : "Personnel is being calculated by the Estimate section",
                style: .info
            )
            .padding(.top, DesignSystem.Spacing.xs)

            Divider()

            // How to unlink context
            TaskInlineInfoRow(
                icon: "lightbulb",
                message: "To set personnel manually, change Estimate mode to Duration or Effort",
                style: .info
            )
            .padding(.top, DesignSystem.Spacing.xs)
        }
    }

    private var manualPersonnelView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle("Set Expected Personnel", isOn: $hasPersonnel)

            if hasPersonnel {
                personnelPickerView
                personnelInfoView
            } else {
                TaskInlineInfoRow(
                    icon: "info.circle.fill",
                    message: "Defaults to 1 person if not set",
                    style: .info
                )
            }
        }
    }

    private var personnelPickerView: some View {
        HStack {
            Text("Expected Personnel")
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
                    set: { expectedPersonnelCount = $0 }
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

    private var personnelInfoView: some View {
        TaskInlineInfoRow(
            icon: "info.circle.fill",
            message: "Pre-fills time entry forms with this count",
            style: .info
        )
        .padding(.top, DesignSystem.Spacing.xs)
    }
}
