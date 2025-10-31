import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            ProjectListView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Task.self, TimeEntry.self])
}
