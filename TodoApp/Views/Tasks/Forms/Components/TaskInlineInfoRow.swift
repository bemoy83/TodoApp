import SwiftUI

/// Inline info/warning/error message row with icon
/// No background - flat design consistent with recent UI changes
struct TaskInlineInfoRow: View {
    let icon: String
    let message: String
    var style: InfoStyle = .info
    var iconSize: Font = .caption2

    enum InfoStyle {
        case info
        case warning
        case success
        case error

        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .success: return .green
            case .error: return .red
            }
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(iconSize)
                .foregroundStyle(style.color)
                .frame(width: 28)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
