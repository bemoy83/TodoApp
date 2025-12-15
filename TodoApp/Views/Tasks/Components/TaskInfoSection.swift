import SwiftUI
import SwiftData

/// Info section content for TaskDetailView
/// Shows task metadata like created and completed dates
struct TaskInfoSection: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Created date (always shown)
            SharedDateRow(
                icon: "clock",
                label: "Created",
                date: task.createdDate,
                color: .secondary
            )

            // Completed date (conditional)
            if let completedDate = task.completedDate {
                SharedDateRow(
                    icon: "checkmark.circle.fill",
                    label: "Completed",
                    date: completedDate,
                    color: .green
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Summary Badge Helper

extension TaskInfoSection {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        // If completed, show completion info
        if let completedDate = task.completedDate {
            return "Completed \(relativeDate(completedDate))"
        }

        // Otherwise show creation info
        return "Created \(relativeDate(task.createdDate))"
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        if task.completedDate != nil {
            return .green
        }
        return .secondary
    }

    /// Formats date as relative string (e.g., "2d ago", "today", "Dec 14")
    private static func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        // Check if same day
        if calendar.isDateInToday(date) {
            return "today"
        }

        if calendar.isDateInYesterday(date) {
            return "yesterday"
        }

        // Calculate days difference
        let components = calendar.dateComponents([.day], from: date, to: now)
        if let days = components.day {
            if days > 0 && days < 7 {
                return "\(days)d ago"
            } else if days < 0 && days > -7 {
                return "in \(abs(days))d"
            }
        }

        // Fallback to formatted date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Active Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install Carpet")
    container.mainContext.insert(task)

    TaskInfoSection(task: task)
        .padding()
}

#Preview("Completed Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install Carpet")
    task.isCompleted = true
    task.completedDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date())

    container.mainContext.insert(task)

    TaskInfoSection(task: task)
        .padding()
}
