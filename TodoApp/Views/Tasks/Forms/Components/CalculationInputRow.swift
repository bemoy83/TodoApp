import SwiftUI

/// Reusable input row for quantity-based calculations
/// Used for quantity, productivity, personnel, and duration inputs
/// Shows different states: editable (blue) or calculated/locked (colored)
struct CalculationInputRow: View {
    let icon: String
    let label: String
    let value: String
    let isCalculated: Bool
    let calculatedColor: Color
    let onTap: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isCalculated ? "lock.fill" : icon)
                .font(.subheadline)
                .foregroundStyle(isCalculated ? calculatedColor : .blue)
                .frame(width: 24)

            Text(label)

            Spacer()

            Text(value)
                .foregroundStyle(isCalculated ? calculatedColor : .secondary)

            if !isCalculated {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "function")
                    .font(.caption2)
                    .foregroundStyle(calculatedColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
