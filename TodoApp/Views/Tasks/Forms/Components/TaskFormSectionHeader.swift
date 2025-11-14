import SwiftUI

/// Consistent uppercase caption-style section header for forms
/// Matches styling across TaskQuantityView and TaskDetailView
struct TaskFormSectionHeader: View {
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
