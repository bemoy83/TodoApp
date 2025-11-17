import Foundation
import SwiftData

// MARK: - Active Events Data

struct ActiveEventsData {
    let activeProjects: [Project]
    let totalActivePersonnel: Int
    let totalHoursThisWeek: Double

    static func calculate(from projects: [Project], timeEntries: [TimeEntry]) -> ActiveEventsData {
        // Filter active projects (in progress with incomplete tasks)
        let activeProjects = projects
            .filter { $0.isActive }
            .sorted { p1, p2 in
                // Sort by health (critical first), then by due date
                if p1.healthStatus != p2.healthStatus {
                    return p1.healthStatus.sortOrder < p2.healthStatus.sortOrder
                }
                if let d1 = p1.dueDate, let d2 = p2.dueDate {
                    return d1 < d2
                }
                return p1.title < p2.title
            }

        // Count active personnel (unique people working on active timers)
        let activeTasksWithTimers = projects
            .flatMap { $0.tasks ?? [] }
            .filter { $0.hasActiveTimer }

        let totalActivePersonnel = activeTasksWithTimers.reduce(0) { total, task in
            guard let entries = task.timeEntries else { return total }
            let activeEntry = entries.first { $0.endTime == nil }
            return total + (activeEntry?.personnelCount ?? 0)
        }

        // Calculate hours logged this week
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return ActiveEventsData(
                activeProjects: activeProjects,
                totalActivePersonnel: totalActivePersonnel,
                totalHoursThisWeek: 0
            )
        }

        let thisWeekEntries = timeEntries.filter { entry in
            guard let endTime = entry.endTime else { return false }
            return endTime >= weekStart
        }

        let totalHoursThisWeek = thisWeekEntries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let duration = end.timeIntervalSince(entry.startTime)
            return total + (duration / 3600)
        }

        return ActiveEventsData(
            activeProjects: activeProjects,
            totalActivePersonnel: totalActivePersonnel,
            totalHoursThisWeek: totalHoursThisWeek
        )
    }
}

// MARK: - Project Attention Data

struct ProjectAttentionNeeded {
    let projectsNeedingAttention: [ProjectIssue]

    var hasIssues: Bool {
        !projectsNeedingAttention.isEmpty
    }

    var totalIssueCount: Int {
        projectsNeedingAttention.reduce(0) { $0 + $1.totalIssues }
    }

    static func calculate(from projects: [Project]) -> ProjectAttentionNeeded {
        var issues: [ProjectIssue] = []

        for project in projects {
            guard project.status != .completed else { continue }

            let tasks = project.tasks ?? []
            let incompleteTasks = tasks.filter { !$0.isCompleted && !$0.isArchived }

            var projectIssues: [String] = []
            var overdueCount = 0
            var blockedCount = 0
            var missingEstimates = 0
            var nearingBudget = 0
            var overPlanned = false

            // Check for overdue tasks
            let now = Date()
            overdueCount = incompleteTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < now
            }.count

            // Check for blocked tasks
            blockedCount = incompleteTasks.filter { $0.status == .blocked }.count

            // Check for missing estimates (only for non-planning projects and medium/high priority tasks)
            if project.status != .planning {
                missingEstimates = incompleteTasks.filter { task in
                    task.effectiveEstimate == nil && task.priority < 3 // Exclude low priority tasks
                }.count
            }

            // Check if actual time is nearing budget
            if let progress = project.timeProgress, progress >= 0.85 {
                nearingBudget = 1
            }

            // Check if task planning exceeds budget
            if project.isOverPlanned {
                overPlanned = true
            }

            // Build issue descriptions
            if overdueCount > 0 {
                projectIssues.append("\(overdueCount) overdue")
            }
            if blockedCount > 0 {
                projectIssues.append("\(blockedCount) blocked")
            }
            if missingEstimates > 0 {
                projectIssues.append("\(missingEstimates) missing estimates")
            }
            if overPlanned {
                if let variance = project.planningVariance {
                    projectIssues.append("over-planned by \(String(format: "%.0f", variance))h")
                } else {
                    projectIssues.append("over-planned")
                }
            }
            if nearingBudget > 0 {
                projectIssues.append("nearing budget")
            }

            // Only add if there are issues
            if !projectIssues.isEmpty {
                issues.append(ProjectIssue(
                    project: project,
                    issueDescriptions: projectIssues,
                    overdueCount: overdueCount,
                    blockedCount: blockedCount,
                    missingEstimatesCount: missingEstimates,
                    nearingBudget: nearingBudget > 0,
                    overPlanned: overPlanned
                ))
            }
        }

        // Sort by severity (critical health first, then by issue count)
        issues.sort { i1, i2 in
            if i1.project.healthStatus != i2.project.healthStatus {
                return i1.project.healthStatus.sortOrder < i2.project.healthStatus.sortOrder
            }
            return i1.totalIssues > i2.totalIssues
        }

        return ProjectAttentionNeeded(projectsNeedingAttention: issues)
    }
}

// MARK: - Project Issue

struct ProjectIssue: Identifiable {
    let project: Project
    let issueDescriptions: [String]
    let overdueCount: Int
    let blockedCount: Int
    let missingEstimatesCount: Int
    let nearingBudget: Bool
    let overPlanned: Bool

    var id: UUID { project.id }

    var totalIssues: Int {
        overdueCount + blockedCount + missingEstimatesCount + (nearingBudget ? 1 : 0) + (overPlanned ? 1 : 0)
    }

    var summaryText: String {
        issueDescriptions.joined(separator: ", ")
    }
}

// MARK: - Upcoming Events Data

struct UpcomingEventsData {
    let upcomingProjects: [Project]

    static func calculate(from projects: [Project]) -> UpcomingEventsData {
        let now = Date()

        // Projects that are planned or have future due dates
        let upcomingProjects = projects
            .filter { project in
                // Either in planning status or has a future due date
                if project.status == .planning {
                    return true
                }
                if let dueDate = project.dueDate, dueDate > now {
                    return true
                }
                return false
            }
            .sorted { p1, p2 in
                // Sort by due date (nearest first)
                if let d1 = p1.dueDate, let d2 = p2.dueDate {
                    return d1 < d2
                }
                if p1.dueDate != nil {
                    return true
                }
                if p2.dueDate != nil {
                    return false
                }
                return p1.title < p2.title
            }
            .prefix(5) // Limit to next 5 upcoming events
            .map { $0 }

        return UpcomingEventsData(upcomingProjects: upcomingProjects)
    }
}

// MARK: - Project Health Status Sort Order

extension ProjectHealthStatus {
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .onTrack: return 2
        }
    }
}
