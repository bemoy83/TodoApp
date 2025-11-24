import SwiftUI

struct ProjectStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Button {
                        project.status = status
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: getIcon(for: status))
                                .font(.title3)
                                .foregroundStyle(getColor(for: status))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.rawValue)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.primary)

                                Text(getDescription(for: status))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                            }

                            Spacer()

                            if project.status == status {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(getColor(for: status))
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Project Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }

    private func getIcon(for status: ProjectStatus) -> String {
        switch status {
        case .planning: return "lightbulb.fill"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }

    private func getColor(for status: ProjectStatus) -> Color {
        switch status {
        case .planning: return DesignSystem.Colors.info
        case .inProgress: return DesignSystem.Colors.success
        case .completed: return DesignSystem.Colors.taskCompleted
        case .onHold: return DesignSystem.Colors.warning
        }
    }

    private func getDescription(for status: ProjectStatus) -> String {
        switch status {
        case .planning: return "Event is being planned"
        case .inProgress: return "Setup or teardown in progress"
        case .completed: return "Event finished"
        case .onHold: return "Temporarily paused"
        }
    }
}
