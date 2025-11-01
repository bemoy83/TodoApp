import SwiftUI
import SwiftData

struct ProjectRowView: View {
    let project: Project
    
    // ✅ Add query to watch for task changes
    @Query(sort: \Task.order) private var allTasks: [Task]
    
    // ✅ Compute task counts from query
    private var topLevelTaskCount: Int {
        allTasks.filter { $0.project?.id == project.id && $0.parentTask == nil }.count
    }
    
    private var completedTopLevelTaskCount: Int {
        allTasks.filter { $0.project?.id == project.id && $0.parentTask == nil && $0.isCompleted }.count
    }
    
    // ✅ Compute total time from query
    private var totalTimeSpent: Int {
        let projectTasks = allTasks.filter { $0.project?.id == project.id && $0.parentTask == nil }
        return projectTasks.reduce(0) { total, task in
            total + computeTotalTime(for: task)
        }
    }
    
    // Recursive helper to include subtask time
    private func computeTotalTime(for task: Task) -> Int {
        var total = task.directTimeSpent
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return total
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Project color indicator
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(project.title)
                    .font(DesignSystem.Typography.headline)
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    MetaLabel("\(completedTopLevelTaskCount) / \(topLevelTaskCount)", systemImage: "checklist")
                    
                    if totalTimeSpent > 0 {
                        MetaLabel(totalTimeSpent.formattedTime(), systemImage: "clock")
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
