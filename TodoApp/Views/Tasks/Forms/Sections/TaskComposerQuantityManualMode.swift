import SwiftUI

/// Manual entry mode for quantity-based estimation
/// Tracks quantity without automatic calculations
struct TaskComposerQuantityManualMode: View {
    let productivityRate: Double?
    let unit: UnitType

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            TaskInlineInfoRow(
                icon: "info.circle",
                message: "Track quantity and set time/personnel manually. Productivity rate will be calculated when the task is completed.",
                style: .info
            )

            if let rate = productivityRate {
                Divider()

                TaskRowIconValueLabel(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Reference Rate",
                    value: "\(String(format: "%.1f", rate)) \(unit.displayName)/person-hr",
                    tint: .secondary
                )
            }
        }
    }
}
