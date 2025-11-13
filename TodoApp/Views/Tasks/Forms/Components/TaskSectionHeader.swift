import SwiftUI

/// Consistent uppercase caption-style section header
/// Matches styling across TaskQuantityView and TaskDetailView
struct TaskSectionHeader: View {
    let title: String
    var topPadding: CGFloat = DesignSystem.Spacing.md

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, topPadding)
    }
}
