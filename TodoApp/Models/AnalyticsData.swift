import Foundation
import SwiftData

// MARK: - Today's Activity Data

struct TodaysActivity {
    let activeTimers: Int
    let activePersonnel: Int  // Total people working on active timers
    let hoursLoggedToday: Double
    let personHoursToday: Double
    let tasksCompletedToday: Int

    static func calculate(from tasks: [Task], timeEntries: [TimeEntry]) -> TodaysActivity {
        let today = Calendar.current.startOfDay(for: Date())
        let now = Date()

        // Active timers
        let activeTimerTasks = tasks.filter { $0.hasActiveTimer }
        let activeTimers = activeTimerTasks.count
        let activePersonnel = activeTimerTasks.reduce(0) { total, task in
            guard let entries = task.timeEntries else { return total }
            let activeEntry = entries.first { $0.endTime == nil }
            return total + (activeEntry?.personnelCount ?? 0)
        }

        // Hours logged today (completed entries that ended today)
        let todayEntries = timeEntries.filter { entry in
            guard let endTime = entry.endTime else { return false }
            return Calendar.current.isDate(endTime, inSameDayAs: now)
        }

        let hoursLoggedToday = todayEntries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let duration = end.timeIntervalSince(entry.startTime)
            return total + (duration / 3600)
        }

        let personHoursToday = todayEntries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let duration = end.timeIntervalSince(entry.startTime)
            return total + ((duration / 3600) * Double(entry.personnelCount))
        }

        // Tasks completed today
        let tasksCompletedToday = tasks.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return Calendar.current.isDate(completedDate, inSameDayAs: now)
        }.count

        return TodaysActivity(
            activeTimers: activeTimers,
            activePersonnel: activePersonnel,
            hoursLoggedToday: hoursLoggedToday,
            personHoursToday: personHoursToday,
            tasksCompletedToday: tasksCompletedToday
        )
    }
}

// MARK: - Attention Needed Data

struct AttentionNeeded {
    let overdueTasks: [Task]
    let blockedTasks: [Task]
    let tasksWithoutEstimates: [Task]
    let tasksNearingEstimate: [Task]  // 80%+ time used

    var hasIssues: Bool {
        !overdueTasks.isEmpty || !blockedTasks.isEmpty ||
        !tasksWithoutEstimates.isEmpty || !tasksNearingEstimate.isEmpty
    }

    var totalIssueCount: Int {
        overdueTasks.count + blockedTasks.count +
        tasksWithoutEstimates.count + tasksNearingEstimate.count
    }

    static func calculate(from tasks: [Task]) -> AttentionNeeded {
        let now = Date()
        let incompleteTasks = tasks.filter { !$0.isCompleted }

        // Overdue tasks (have due date and it's passed)
        let overdueTasks = incompleteTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now
        }

        // Blocked tasks (status is blocked)
        let blockedTasks = incompleteTasks.filter { $0.status == .blocked }

        // Tasks without estimates (incomplete, no estimate set)
        let tasksWithoutEstimates = incompleteTasks.filter { task in
            task.effectiveEstimate == nil
        }

        // Tasks nearing estimate (80%+ of time used)
        let tasksNearingEstimate = incompleteTasks.filter { task in
            guard let progress = task.timeProgress else { return false }
            return progress >= 0.8 && progress < 1.0
        }

        return AttentionNeeded(
            overdueTasks: overdueTasks,
            blockedTasks: blockedTasks,
            tasksWithoutEstimates: tasksWithoutEstimates,
            tasksNearingEstimate: tasksNearingEstimate
        )
    }
}

// MARK: - Analytics Card Types

enum AnalyticsCardType: String, Identifiable {
    case activeTimers = "Active Timers"
    case hoursToday = "Hours Today"
    case personHoursToday = "Person-Hours Today"
    case tasksCompleted = "Tasks Completed"
    case overdueTasks = "Overdue Tasks"
    case blockedTasks = "Blocked Tasks"
    case noEstimates = "Missing Estimates"
    case nearingEstimate = "Nearing Estimate"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .activeTimers: return "timer"
        case .hoursToday: return "clock.fill"
        case .personHoursToday: return "person.2.fill"
        case .tasksCompleted: return "checkmark.circle.fill"
        case .overdueTasks: return "exclamationmark.triangle.fill"
        case .blockedTasks: return "hand.raised.fill"
        case .noEstimates: return "questionmark.circle.fill"
        case .nearingEstimate: return "gauge.with.dots.needle.67percent"
        }
    }

    var color: String {
        switch self {
        case .activeTimers: return "blue"
        case .hoursToday: return "indigo"
        case .personHoursToday: return "purple"
        case .tasksCompleted: return "green"
        case .overdueTasks: return "red"
        case .blockedTasks: return "orange"
        case .noEstimates: return "yellow"
        case .nearingEstimate: return "orange"
        }
    }
}
