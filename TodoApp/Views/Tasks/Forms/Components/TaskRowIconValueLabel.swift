import SwiftUI

/// Reusable row component with icon, label, and value
/// Consistent with TaskQuantityView and TaskDetailView styling
struct TaskRowIconValueLabel: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = .blue
    var iconSize: Font = .body

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(iconSize)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
