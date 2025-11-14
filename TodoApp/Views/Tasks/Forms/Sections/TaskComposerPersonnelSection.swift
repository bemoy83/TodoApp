import SwiftUI

/// Personnel assignment section for TaskComposerForm
/// Handles both auto-calculated (read-only) and manual personnel entry
struct TaskComposerPersonnelSection: View {
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode

    let personnelIsAutoCalculated: Bool
    let quantityCalculationMode: TaskEstimator.QuantityCalculationMode

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
            TaskInlineInfoRow(
                icon: "lock.fill",
                message: "Personnel count is auto-calculated from the estimation calculator above",
                style: .info
            )

            TaskRowIconValueLabel(
                icon: "person.2.fill",
                label: "Expected Personnel",
                value: "\(expectedPersonnelCount ?? 1) \(expectedPersonnelCount == 1 ? "person" : "people")",
                tint: .blue
            )
            .padding(.top, DesignSystem.Spacing.xs)

            Button {
                unifiedEstimationMode = .duration
            } label: {
                Label("Switch to Manual Mode", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            .padding(.top, 4)
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
        Picker("Expected crew size", selection: Binding(
            get: { expectedPersonnelCount ?? 1 },
            set: { expectedPersonnelCount = $0 }
        )) {
            ForEach(1...20, id: \.self) { count in
                Text("\(count) \(count == 1 ? "person" : "people")")
                    .tag(count)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
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
