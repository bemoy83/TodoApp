import SwiftUI
import SwiftData

struct AddProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var projects: [Project]
    
    @State private var title = ""
    @State private var selectedColor = "#007AFF"
    
    private let predefinedColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00",
        "#8E8E93", "#00C7BE"
    ]
    
    // Next order value for new project
    private var nextOrder: Int {
        let maxOrder = projects.map { $0.order ?? 0 }.max() ?? -1
        return maxOrder + 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $title)
                }
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DesignSystem.Spacing.lg) {
                        ForEach(predefinedColors, id: \.self) { color in
                            ColorButton(
                                color: color,
                                isSelected: selectedColor == color
                            ) {
                                selectedColor = color
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addProject() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addProject() {
        let newProject = Project(
            title: title,
            color: selectedColor,
            order: nextOrder
        )
        modelContext.insert(newProject)
        HapticManager.success()
        dismiss()
    }
}

#Preview("Project List with Projects") {
    // Show the sheet form in a preview-friendly wrapper
    struct Host: View {
        @State private var show = true
        var body: some View {
            NavigationStack {
                List { Text("Projects") }
                    .navigationTitle("Projects")
            }
            .sheet(isPresented: $show) { AddProjectSheet() }
            .onAppear { show = true }
        }
    }
    return Host()
        .modelContainer(for: [Project.self, Task.self, TimeEntry.self])
}
