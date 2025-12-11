import SwiftUI
import SwiftData

/// Plan tab view - comprehensive workspace for task planning and structure
struct TaskDetailPlanView: View {
    @Bindable var task: Task
    @Binding var currentAlert: TaskActionAlert?

    // Collapsible section states
    @Binding var isTimeTrackingExpanded: Bool
    @Binding var isPersonnelExpanded: Bool
    @Binding var isQuantityExpanded: Bool
    @Binding var isTagsExpanded: Bool
    @Binding var isSubtasksExpanded: Bool
    @Binding var isDependenciesExpanded: Bool
    @Binding var isNotesExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Task header details (moved from top-level header)
            TaskDetailHeaderView(task: task, alert: $currentAlert)

            // Group 1: Estimates & Resources
            DetailSectionDisclosure(
                title: "Estimates & Resources",
                icon: "chart.bar.fill",
                isExpanded: $isTimeTrackingExpanded,
                summary: { estimatesResourcesSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Time estimation
                        TaskTimeTrackingView(task: task)

                        Divider()

                        // Personnel planning
                        TaskPersonnelView(task: task)

                        Divider()

                        // Quantity target
                        TaskQuantityView(task: task)
                    }
                }
            )

            // Group 2: Structure & Dependencies
            DetailSectionDisclosure(
                title: "Structure & Dependencies",
                icon: "diagram.split.2x2",
                isExpanded: $isSubtasksExpanded,
                summary: { structureSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Subtasks
                        TaskSubtasksView(task: task)

                        Divider()

                        // Dependencies
                        TaskDependenciesView(task: task)
                    }
                }
            )

            // Group 3: Metadata (Tags + Notes)
            DetailSectionDisclosure(
                title: "Metadata",
                icon: "tag.fill",
                isExpanded: $isTagsExpanded,
                summary: { metadataSummary },
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Tags
                        TaskTagsView(task: task)

                        // Notes (Phase 3: Now editable in Plan tab only)
                        if let notes = task.notes, !notes.isEmpty {
                            Divider()

                            SharedNotesSection(notes: notes, isExpanded: $isNotesExpanded)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                    }
                }
            )
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - Summary Views

    // Summary for Estimates & Resources group
    @ViewBuilder
    private var estimatesResourcesSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let estimate = task.effectiveEstimate {
                Text(estimate.formattedTime())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let personnel = task.expectedPersonnelCount {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(personnel)p")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if task.hasQuantityProgress {
                Text("•")
                    .foregroundStyle(.tertiary)
                let progress = Int((task.quantityProgress ?? 0) * 100)
                Text("\(progress)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Summary for Structure group
    @ViewBuilder
    private var structureSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if task.subtaskCount > 0 {
                Text("\(task.completedDirectSubtaskCount)/\(task.subtaskCount) subtasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if (task.dependsOn?.count ?? 0) > 0 {
                if task.subtaskCount > 0 {
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                let depCount = task.dependsOn?.count ?? 0
                Text("\(depCount) \(depCount == 1 ? "dependency" : "dependencies")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Summary for Metadata group
    @ViewBuilder
    private var metadataSummary: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let tags = task.tags, !tags.isEmpty {
                Text("\(tags.count) \(tags.count == 1 ? "tag" : "tags")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = task.notes, !notes.isEmpty {
                if let tags = task.tags, !tags.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                Text("Has notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
