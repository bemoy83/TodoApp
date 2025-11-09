//
//  SettingsView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetch data for statistics
    @Query private var projects: [Project]
    @Query private var tasks: [Task]
    @Query private var timeEntries: [TimeEntry]
    
    // App Settings
    @AppStorage("defaultPriority") private var defaultPriority: Int = 2
    @AppStorage("showCompletedByDefault") private var showCompletedByDefault: Bool = true
    @AppStorage("compactViewMode") private var compactViewMode: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    
    // State for alerts and toasts
    @State private var showingClearDataAlert = false
    @State private var showingExportSheet = false
    @State private var showingReportSheet = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var isClearing = false
    @State private var isFixingOrder = false
    
    // Computed statistics
    private var totalProjects: Int {
        projects.count
    }
    
    private var totalTasks: Int {
        tasks.count
    }
    
    private var totalTimeTracked: Int {
        tasks.reduce(0) { $0 + $1.directTimeSpent }
    }
    
    // Check if any tasks or projects need order fixing
    private var needsOrderFix: Bool {
        tasks.contains { ($0.order ?? 0) == 0 } || projects.contains { ($0.order ?? 0) == 0 }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                AppSettingsSection(
                    appearanceMode: $appearanceMode,
                    defaultPriority: $defaultPriority,
                    showCompletedByDefault: $showCompletedByDefault,
                    compactViewMode: $compactViewMode
                )
                
                DataStatisticsSection(
                    totalProjects: totalProjects,
                    totalTasks: totalTasks,
                    totalTimeTracked: totalTimeTracked
                )
                
                DataManagementSection(
                    isClearing: isClearing,
                    isFixingOrder: isFixingOrder,
                    showFixOrderButton: needsOrderFix,
                    onExport: { showingExportSheet = true },
                    onGenerateReport: { showingReportSheet = true },
                    onClearData: { showingClearDataAlert = true },
                    onFixOrder: { assignOrderToExistingTasks() }
                )
                
                AboutSection(onShowToast: showToast)
                
                SupportSection()
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all projects, tasks, and time entries. This action cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                TimeExportSheet()
            }
            .sheet(isPresented: $showingReportSheet) {
                ReportTemplatesSheet()
            }
            .overlay(alignment: .bottom) {
                if showingToast {
                    ToastView(message: toastMessage)
                        .padding(.bottom, DesignSystem.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(DesignSystem.Animation.spring, value: showingToast)
        }
    }
    
    // MARK: - Helper Functions
    
    private func clearAllData() {
        isClearing = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        // Delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                // Fetch all objects
                let projectsFetch = FetchDescriptor<Project>()
                let tasksFetch = FetchDescriptor<Task>()
                let timeEntriesFetch = FetchDescriptor<TimeEntry>()
                
                let allProjects = try? modelContext.fetch(projectsFetch)
                let allTasks = try? modelContext.fetch(tasksFetch)
                let allTimeEntries = try? modelContext.fetch(timeEntriesFetch)
                
                // Clear all task relationships first to avoid "future" errors
                allTasks?.forEach { task in
                    task.dependsOn?.removeAll()
                    task.blockedBy?.removeAll()
                    task.subtasks?.removeAll()
                    task.timeEntries?.removeAll()
                    task.parentTask = nil
                    task.project = nil
                }
                
                // Now safe to delete all
                allProjects?.forEach { modelContext.delete($0) }
                allTasks?.forEach { modelContext.delete($0) }
                allTimeEntries?.forEach { modelContext.delete($0) }
                
                // Save changes
                try modelContext.save()
                
                isClearing = false
                
                // Success haptic
                generator.notificationOccurred(.success)
                
                // Show confirmation
                showToast("All data cleared successfully")
                
            } catch {
                isClearing = false
                
                // Error haptic
                generator.notificationOccurred(.error)
                
                showToast("Failed to clear data")
            }
        }
    }
    
    private func assignOrderToExistingTasks() {
        isFixingOrder = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                // Fix project ordering
                let sortedProjects = projects.sorted { $0.createdDate < $1.createdDate }
                for (index, project) in sortedProjects.enumerated() {
                    project.order = index
                }
                
                // Group tasks by parent
                var tasksByParent: [UUID?: [Task]] = [:]
                for task in tasks {
                    let parentId = task.parentTask?.id
                    if tasksByParent[parentId] == nil {
                        tasksByParent[parentId] = []
                    }
                    tasksByParent[parentId]?.append(task)
                }
                
                // Assign order within each group
                for (_, groupTasks) in tasksByParent {
                    let sortedTasks = groupTasks.sorted { $0.createdDate < $1.createdDate }
                    for (index, task) in sortedTasks.enumerated() {
                        task.order = index
                    }
                }
                
                // Save changes
                try modelContext.save()
                
                isFixingOrder = false
                
                // Success haptic
                generator.notificationOccurred(.success)
                
                // Show confirmation
                showToast("Task order fixed successfully!")
                
            } catch {
                isFixingOrder = false
                
                // Error haptic
                generator.notificationOccurred(.error)
                
                showToast("Failed to fix task order: \(error.localizedDescription)")
            }
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(DesignSystem.Animation.spring) {
            showingToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(DesignSystem.Animation.spring) {
                showingToast = false
            }
        }
    }
}

// MARK: - Helper Views

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(DesignSystem.Typography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .designShadow(DesignSystem.Shadow.lg)
    }
}

struct PlaceholderView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.secondary)
            
            Text(title)
                .font(DesignSystem.Typography.title2)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xxxl)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Settings View") {
    SettingsView()
        .modelContainer(for: [Project.self, Task.self, TimeEntry.self])
}
