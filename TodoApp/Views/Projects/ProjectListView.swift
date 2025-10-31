import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    
    @State private var showingAddProject = false
    @State private var editMode: EditMode = .inactive
    
    // Tier 2: staged empty-state entrance
    @State private var appeared = false
    
    // Sort projects by order
    private var sortedProjects: [Project] {
        projects.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(sortedProjects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectRowView(project: project)
                        }
                        .allowsHitTesting(editMode == .inactive)
                    }
                    .onMove { source, destination in
                        reorderProjects(from: source, to: destination)
                    }
                }
                if projects.isEmpty {
                    emptyState
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            withAnimation(DesignSystem.Animation.standard) {
                                editMode = (editMode == .active) ? .inactive : .active
                                HapticManager.selection()
                            }
                        } label: {
                            Label(
                                editMode == .active ? "Done" : "Reorder",
                                systemImage: editMode == .active ? "checkmark" : "line.3.horizontal"
                            )
                        }
                        Button { showingAddProject = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectSheet()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Image(systemName: "folder")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(.systemBlue))
            }
            Text("No Projects Yet")
                .font(DesignSystem.Typography.title3)
            Text("Add projects to organize your tasks")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddProject = true
            } label: {
                Label("Add Project", systemImage: "plus").fontWeight(.semibold)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .emptyStateStyle()
    }
    
    // MARK: - Reorder Function
    private func reorderProjects(from source: IndexSet, to destination: Int) {
        Reorderer.reorder(
            items: sortedProjects,
            currentOrder: { $0.order ?? Int.max },          // <- coalesce optional order
            setOrder: { project, index in project.order = index },
            from: source,
            to: destination,
            save: { try modelContext.save() }
        )
    }
}

#Preview("Empty Project List") {
    ProjectListView()
        .modelContainer(for: [Project.self, Task.self, TimeEntry.self])
}
