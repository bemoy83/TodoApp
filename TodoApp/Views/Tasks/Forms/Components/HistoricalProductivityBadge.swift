import SwiftUI

/// Badge showing historical productivity rate with variance indicator
/// Used to display performance comparison for event tasks (carpet, walls, furniture, etc.)
struct HistoricalProductivityBadge: View {
    let viewModel: ProductivityRateViewModel
    let unitDisplayName: String

    var body: some View {
        let variance = viewModel.calculateVariance()
        let hasSignificantVariance = viewModel.hasSignificantVariance

        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.success)

            Text("Historical:")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let historical = viewModel.historicalProductivity {
                Text("\(String(format: "%.1f", historical)) \(unitDisplayName)/person-hr")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            // Variance indicator
            if let variance = variance {
                HStack(spacing: 2) {
                    Image(systemName: variance.isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text("\(String(format: "%.0f", variance.percentage))%")
                        .font(.caption2)
                }
                .foregroundStyle(variance.isPositive ? DesignSystem.Colors.success : .orange)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hasSignificantVariance ? Color.orange.opacity(0.1) : DesignSystem.Colors.success.opacity(0.1))
        )
    }
}
