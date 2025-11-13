import SwiftUI
import SwiftData

/// Project selection section for TaskComposerForm
/// Handles both subtask (inherited) and regular task (selectable) project assignment
struct TaskComposerProjectSection: View {
    @Binding var selectedProject: Project?
    let isSubtask: Bool
    let inheritedProject: Project?

    @Query(sort: \Project.title) private var projects: [Project]

    var body: some View {
        Section("Project") {
            if isSubtask {
                subtaskProjectView
            } else {
                projectPickerView
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var subtaskProjectView: some View {
        if let project = inheritedProject {
            TaskRowIconValueLabel(
                icon: "folder.fill",
                label: "Inherited from Parent",
                value: project.title,
                tint: Color(hex: project.color)
            )
        } else {
            TaskInlineInfoRow(
                icon: "folder.badge.questionmark",
                message: "No project (inherited from parent)",
                style: .info
            )
        }
    }

    private var projectPickerView: some View {
        Picker("Assign to Project", selection: $selectedProject) {
            // No Project
            HStack {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                Text("No Project")
            }
            .tag(nil as Project?)

            // Projects
            ForEach(projects) { project in
                HStack {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 12, height: 12)
                    Text(project.title)
                }
                .tag(project as Project?)
            }
        }
        .pickerStyle(.navigationLink)
    }
}
