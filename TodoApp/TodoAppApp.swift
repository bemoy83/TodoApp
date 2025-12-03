import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Task.self, Project.self, TimeEntry.self, TaskTemplate.self, CustomUnit.self])
        }
    }
}
