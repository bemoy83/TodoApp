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

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }

            KPIDashboardView()
                .tabItem {
                    Label("KPIs", systemImage: "gauge.with.dots.needle.67percent")
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
