import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            // Create model container
            modelContainer = try ModelContainer(
                for: Task.self, Project.self, TimeEntry.self, TaskTemplate.self, CustomUnit.self, Tag.self
            )

            // Seed system units on first launch
            DataSeeder.seedSystemUnitsIfNeeded(context: modelContainer.mainContext)

            // Seed system tags on first launch
            DataSeeder.seedSystemTagsIfNeeded(context: modelContainer.mainContext)

            // Optionally migrate existing templates (safe to run multiple times)
            DataSeeder.migrateTemplatesToCustomUnits(context: modelContainer.mainContext)

            // Link existing tasks to templates (safe to run multiple times)
            DataSeeder.linkTasksToTemplates(context: modelContainer.mainContext)

        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
