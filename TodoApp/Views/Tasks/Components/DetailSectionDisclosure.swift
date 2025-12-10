import SwiftUI

/// Reusable collapsible disclosure group for TaskDetailView sections
/// Provides consistent expand/collapse behavior with optional summary badges
struct DetailSectionDisclosure<Content: View, Summary: View>: View {
    let title: String
    let icon: String?
    @Binding var isExpanded: Bool
    let summary: () -> Summary
    let content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder summary: @escaping () -> Summary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.summary = summary
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header button (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    HapticManager.light()
                }
            } label: {
                HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                    // Optional icon
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                    }

                    // Section title
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    // Summary badge (when collapsed)
                    if !isExpanded {
                        summary()
                    }

                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Content (when expanded)
            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .detailCardStyle()
    }
}

// MARK: - Convenience initializer for sections without summary badges

extension DetailSectionDisclosure where Summary == EmptyView {
    init(
        title: String,
        icon: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.summary = { EmptyView() }
        self.content = content
    }
}

// MARK: - Preview

#Preview("Collapsed") {
    DetailSectionDisclosure(
        title: "Time Tracking",
        icon: "clock",
        isExpanded: .constant(false)
    ) {
        HStack(spacing: 4) {
            Text("4h 30m")
            Text("•")
            Text("62% of estimate")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    } content: {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full time tracking content would go here")
                .padding()
            Text("Timer controls, progress bars, etc.")
                .padding()
        }
    }
    .padding()
}

#Preview("Expanded") {
    DetailSectionDisclosure(
        title: "Time Tracking",
        icon: "clock",
        isExpanded: .constant(true)
    ) {
        HStack(spacing: 4) {
            Text("4h 30m")
            Text("•")
            Text("62% of estimate")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    } content: {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full time tracking content would go here")
                .padding()
            Text("Timer controls, progress bars, etc.")
                .padding()
        }
    }
    .padding()
}

#Preview("No Summary Badge") {
    DetailSectionDisclosure(
        title: "Dependencies",
        icon: "link",
        isExpanded: .constant(false)
    ) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dependencies content")
                .padding()
        }
    }
    .padding()
}
