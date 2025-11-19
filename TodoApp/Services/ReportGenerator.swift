import Foundation

// MARK: - Report Generator

struct ReportGenerator {

    // MARK: - Main Generation Method

    static func generate(from data: ReportData) -> String {
        switch data.template {
        case .weeklySummary:
            return generateWeeklySummary(data: data)
        case .monthlySummary:
            return generateMonthlySummary(data: data)
        case .projectPerformance:
            return generateProjectPerformance(data: data)
        case .personnelUtilization:
            return generatePersonnelUtilization(data: data)
        case .taskEfficiency:
            return generateTaskEfficiency(data: data)
        case .budgetAnalysis:
            return generateBudgetAnalysis(data: data)
        case .taskTypeEfficiency:
            return generateTaskTypeEfficiency(data: data)
        }
    }

    // MARK: - Weekly Summary Report

    private static func generateWeeklySummary(data: ReportData) -> String {
        let entries = data.filteredTimeEntries
        let tasks = data.filteredTasks

        let completedTasks = tasks.filter { $0.isCompleted }
        let totalHours = entries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            return total + end.timeIntervalSince(entry.startTime) / 3600
        }
        let totalPersonHours = entries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let hours = end.timeIntervalSince(entry.startTime) / 3600
            return total + (hours * Double(entry.personnelCount))
        }

        switch data.format {
        case .markdown:
            return generateWeeklySummaryMarkdown(
                entries: entries,
                tasks: tasks,
                completedTasks: completedTasks,
                totalHours: totalHours,
                totalPersonHours: totalPersonHours,
                data: data
            )
        case .plainText:
            return generateWeeklySummaryPlainText(
                entries: entries,
                tasks: tasks,
                completedTasks: completedTasks,
                totalHours: totalHours,
                totalPersonHours: totalPersonHours,
                data: data
            )
        case .csv:
            return generateWeeklySummaryCSV(
                entries: entries,
                tasks: tasks,
                data: data
            )
        }
    }

    private static func generateWeeklySummaryMarkdown(
        entries: [TimeEntry],
        tasks: [Task],
        completedTasks: [Task],
        totalHours: Double,
        totalPersonHours: Double,
        data: ReportData
    ) -> String {
        var md = "# Weekly Summary Report\n\n"
        md += "*Generated: \(formatDate(Date()))*\n\n"
        md += "## Overview\n\n"
        md += "- **Period**: \(formatDateRange(data.effectiveDateRange))\n"
        md += "- **Tasks Completed**: \(completedTasks.count) of \(tasks.count)\n"
        md += "- **Total Hours**: \(String(format: "%.1f", totalHours)) hrs\n"
        md += "- **Person-Hours**: \(String(format: "%.1f", totalPersonHours)) hrs\n\n"

        // Completed Tasks
        if !completedTasks.isEmpty {
            md += "## Completed Tasks\n\n"
            for task in completedTasks.sorted(by: { $0.completedDate! > $1.completedDate! }) {
                let projectName = task.project?.title ?? "No Project"
                let hours = Double(task.totalTimeSpent) / 3600
                md += "- **\(task.title)** (\(projectName)) - \(String(format: "%.1f", hours)) hrs\n"
            }
            md += "\n"
        }

        // Project Breakdown
        let projectGroups = Dictionary(grouping: entries, by: { $0.task?.project?.title ?? "No Project" })
        if !projectGroups.isEmpty {
            md += "## Time by Project\n\n"
            md += "| Project | Hours | Person-Hours |\n"
            md += "|---------|-------|-------------|\n"

            for (project, projectEntries) in projectGroups.sorted(by: { $0.key < $1.key }) {
                let hours = projectEntries.reduce(0.0) { total, entry in
                    guard let end = entry.endTime else { return total }
                    return total + end.timeIntervalSince(entry.startTime) / 3600
                }
                let personHours = projectEntries.reduce(0.0) { total, entry in
                    guard let end = entry.endTime else { return total }
                    let h = end.timeIntervalSince(entry.startTime) / 3600
                    return total + (h * Double(entry.personnelCount))
                }
                md += "| \(project) | \(String(format: "%.1f", hours)) | \(String(format: "%.1f", personHours)) |\n"
            }
        }

        return md
    }

    private static func generateWeeklySummaryPlainText(
        entries: [TimeEntry],
        tasks: [Task],
        completedTasks: [Task],
        totalHours: Double,
        totalPersonHours: Double,
        data: ReportData
    ) -> String {
        var text = "WEEKLY SUMMARY REPORT\n"
        text += "Generated: \(formatDate(Date()))\n\n"
        text += "OVERVIEW\n"
        text += "========\n"
        text += "Period: \(formatDateRange(data.effectiveDateRange))\n"
        text += "Tasks Completed: \(completedTasks.count) of \(tasks.count)\n"
        text += "Total Hours: \(String(format: "%.1f", totalHours)) hrs\n"
        text += "Person-Hours: \(String(format: "%.1f", totalPersonHours)) hrs\n\n"

        if !completedTasks.isEmpty {
            text += "COMPLETED TASKS\n"
            text += "===============\n"
            for task in completedTasks.sorted(by: { $0.completedDate! > $1.completedDate! }) {
                let projectName = task.project?.title ?? "No Project"
                let hours = Double(task.totalTimeSpent) / 3600
                text += "- \(task.title) (\(projectName)) - \(String(format: "%.1f", hours)) hrs\n"
            }
            text += "\n"
        }

        return text
    }

    private static func generateWeeklySummaryCSV(
        entries: [TimeEntry],
        tasks: [Task],
        data: ReportData
    ) -> String {
        var csv = "Report Type,Weekly Summary\n"
        csv += "Generated,\(formatDate(Date()))\n"
        csv += "Period,\(formatDateRange(data.effectiveDateRange))\n\n"
        csv += "Task,Project,Status,Completed Date,Hours,Person-Hours\n"

        for task in tasks.sorted(by: { $0.createdDate > $1.createdDate }) {
            let projectName = task.project?.title ?? "No Project"
            let status = task.isCompleted ? "Completed" : "Active"
            let completedDate = task.completedDate != nil ? formatDate(task.completedDate!) : ""
            let hours = String(format: "%.2f", Double(task.totalTimeSpent) / 3600)

            // Calculate person-hours for this task
            let personHours = task.timeEntries?.reduce(0.0) { total, entry in
                guard let end = entry.endTime else { return total }
                let h = end.timeIntervalSince(entry.startTime) / 3600
                return total + (h * Double(entry.personnelCount))
            } ?? 0.0

            csv += "\"\(task.title)\",\"\(projectName)\",\(status),\(completedDate),\(hours),\(String(format: "%.2f", personHours))\n"
        }

        return csv
    }

    // MARK: - Monthly Summary Report

    private static func generateMonthlySummary(data: ReportData) -> String {
        // Similar to weekly but with more detailed breakdowns
        let entries = data.filteredTimeEntries
        let tasks = data.filteredTasks
        let completedTasks = tasks.filter { $0.isCompleted }

        let totalHours = entries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            return total + end.timeIntervalSince(entry.startTime) / 3600
        }

        let totalPersonHours = entries.reduce(0.0) { total, entry in
            guard let end = entry.endTime else { return total }
            let hours = end.timeIntervalSince(entry.startTime) / 3600
            return total + (hours * Double(entry.personnelCount))
        }

        switch data.format {
        case .markdown:
            var md = "# Monthly Summary Report\n\n"
            md += "*Generated: \(formatDate(Date()))*\n\n"
            md += "## Overview\n\n"
            md += "- **Period**: \(formatDateRange(data.effectiveDateRange))\n"
            md += "- **Total Tasks**: \(tasks.count)\n"
            md += "- **Completed**: \(completedTasks.count) (\(Int(Double(completedTasks.count) / Double(max(tasks.count, 1)) * 100))%)\n"
            md += "- **Total Hours**: \(String(format: "%.1f", totalHours)) hrs\n"
            md += "- **Person-Hours**: \(String(format: "%.1f", totalPersonHours)) hrs\n\n"

            // Project breakdown - using effective project to handle subtask inheritance
            let projectGroups = Dictionary(grouping: tasks, by: { getEffectiveProject(for: $0)?.title ?? "No Project" })
            md += "## Project Performance\n\n"
            md += "| Project | Tasks | Completed | Hours | Person-Hours |\n"
            md += "|---------|-------|-----------|-------|-------------|\n"

            for (project, projectTasks) in projectGroups.sorted(by: { $0.key < $1.key }) {
                let completed = projectTasks.filter { $0.isCompleted }.count
                let hours = projectTasks.reduce(0.0) { total, task in
                    total + Double(task.totalTimeSpent) / 3600
                }
                // Use recursive person-hours calculation including subtasks
                let personHours = projectTasks.reduce(0.0) { total, task in
                    total + computePersonHours(for: task, allTasks: data.tasks)
                }
                md += "| \(project) | \(projectTasks.count) | \(completed) | \(String(format: "%.1f", hours)) | \(String(format: "%.1f", personHours)) |\n"
            }

            return md

        case .plainText:
            var text = "MONTHLY SUMMARY REPORT\n"
            text += "Generated: \(formatDate(Date()))\n\n"
            text += "OVERVIEW\n"
            text += "========\n"
            text += "Period: \(formatDateRange(data.effectiveDateRange))\n"
            text += "Total Tasks: \(tasks.count)\n"
            text += "Completed: \(completedTasks.count)\n"
            text += "Total Hours: \(String(format: "%.1f", totalHours)) hrs\n"
            text += "Person-Hours: \(String(format: "%.1f", totalPersonHours)) hrs\n"
            return text

        case .csv:
            return generateMonthlySummaryCSV(tasks: tasks, data: data)
        }
    }

    private static func generateMonthlySummaryCSV(tasks: [Task], data: ReportData) -> String {
        var csv = "Report Type,Monthly Summary\n"
        csv += "Generated,\(formatDate(Date()))\n"
        csv += "Period,\(formatDateRange(data.effectiveDateRange))\n\n"
        csv += "Project,Total Tasks,Completed Tasks,Completion %,Total Hours,Person-Hours\n"

        // Use effective project to handle subtask inheritance
        let projectGroups = Dictionary(grouping: tasks, by: { getEffectiveProject(for: $0)?.title ?? "No Project" })

        for (project, projectTasks) in projectGroups.sorted(by: { $0.key < $1.key }) {
            let completed = projectTasks.filter { $0.isCompleted }.count
            let completionPct = Int(Double(completed) / Double(max(projectTasks.count, 1)) * 100)
            let hours = projectTasks.reduce(0.0) { total, task in
                total + Double(task.totalTimeSpent) / 3600
            }
            // Use recursive person-hours calculation
            let personHours = projectTasks.reduce(0.0) { total, task in
                total + computePersonHours(for: task, allTasks: data.tasks)
            }
            csv += "\"\(project)\",\(projectTasks.count),\(completed),\(completionPct)%,\(String(format: "%.2f", hours)),\(String(format: "%.2f", personHours))\n"
        }

        return csv
    }

    // MARK: - Project Performance Report

    private static func generateProjectPerformance(data: ReportData) -> String {
        guard let project = data.selectedProject else {
            return "Error: No project selected"
        }

        // Include both direct tasks and subtasks (which inherit project from parent)
        let projectTasks = data.tasks.filter { getEffectiveProject(for: $0)?.id == project.id }
        let completedTasks = projectTasks.filter { $0.isCompleted }
        let totalHours = projectTasks.reduce(0.0) { total, task in
            total + Double(task.totalTimeSpent) / 3600
        }
        // Use recursive person-hours calculation including all subtasks
        let totalPersonHours = projectTasks.reduce(0.0) { total, task in
            total + computePersonHours(for: task, allTasks: data.tasks)
        }

        switch data.format {
        case .markdown:
            var md = "# Project Performance Report\n\n"
            md += "## \(project.title)\n\n"
            md += "*Generated: \(formatDate(Date()))*\n\n"
            md += "### Overview\n\n"
            md += "- **Total Tasks**: \(projectTasks.count)\n"
            md += "- **Completed**: \(completedTasks.count) (\(Int(Double(completedTasks.count) / Double(max(projectTasks.count, 1)) * 100))%)\n"
            md += "- **In Progress**: \(projectTasks.count - completedTasks.count)\n"
            md += "- **Total Hours**: \(String(format: "%.1f", totalHours)) hrs\n"
            md += "- **Person-Hours**: \(String(format: "%.1f", totalPersonHours)) hrs\n\n"

            // Task list
            if !projectTasks.isEmpty {
                md += "### Tasks\n\n"
                md += "| Task | Status | Hours | Person-Hours |\n"
                md += "|------|--------|-------|-------------|\n"

                for task in projectTasks.sorted(by: { $0.createdDate > $1.createdDate }) {
                    let status = task.isCompleted ? "✓ Done" : "○ Active"
                    let hours = Double(task.totalTimeSpent) / 3600
                    // Use recursive person-hours calculation to include subtasks
                    let personHours = computePersonHours(for: task, allTasks: data.tasks)
                    md += "| \(task.title) | \(status) | \(String(format: "%.1f", hours)) | \(String(format: "%.1f", personHours)) |\n"
                }
            }

            return md

        case .plainText:
            var text = "PROJECT PERFORMANCE REPORT\n"
            text += "==========================\n"
            text += "Project: \(project.title)\n"
            text += "Generated: \(formatDate(Date()))\n\n"
            text += "OVERVIEW\n"
            text += "--------\n"
            text += "Total Tasks: \(projectTasks.count)\n"
            text += "Completed: \(completedTasks.count)\n"
            text += "Total Hours: \(String(format: "%.1f", totalHours)) hrs\n"
            text += "Person-Hours: \(String(format: "%.1f", totalPersonHours)) hrs\n"
            return text

        case .csv:
            var csv = "Report Type,Project Performance\n"
            csv += "Project,\(project.title)\n"
            csv += "Generated,\(formatDate(Date()))\n\n"
            csv += "Task,Status,Created,Completed,Hours,Person-Hours\n"

            for task in projectTasks.sorted(by: { $0.createdDate > $1.createdDate }) {
                let status = task.isCompleted ? "Completed" : "Active"
                let created = formatDate(task.createdDate)
                let completed = task.completedDate != nil ? formatDate(task.completedDate!) : ""
                let hours = String(format: "%.2f", Double(task.totalTimeSpent) / 3600)
                // Use recursive person-hours calculation to include subtasks
                let personHours = computePersonHours(for: task, allTasks: data.tasks)
                csv += "\"\(task.title)\",\(status),\(created),\(completed),\(hours),\(String(format: "%.2f", personHours))\n"
            }

            return csv
        }
    }

    // MARK: - Personnel Utilization Report

    private static func generatePersonnelUtilization(data: ReportData) -> String {
        let entries = data.filteredTimeEntries

        // Group by personnel count
        let personnelGroups = Dictionary(grouping: entries, by: { $0.personnelCount })

        switch data.format {
        case .markdown:
            var md = "# Personnel Utilization Report\n\n"
            md += "*Generated: \(formatDate(Date()))*\n"
            md += "*Period: \(formatDateRange(data.effectiveDateRange))*\n\n"

            md += "## Summary\n\n"
            let totalPersonHours = entries.reduce(0.0) { total, entry in
                guard let end = entry.endTime else { return total }
                let hours = end.timeIntervalSince(entry.startTime) / 3600
                return total + (hours * Double(entry.personnelCount))
            }
            md += "- **Total Person-Hours**: \(String(format: "%.1f", totalPersonHours)) hrs\n"
            md += "- **Time Entries**: \(entries.count)\n\n"

            // Breakdown by crew size
            md += "## Crew Size Breakdown\n\n"
            md += "| Crew Size | Entries | Total Hours | Person-Hours |\n"
            md += "|-----------|---------|-------------|-------------|\n"

            for (count, groupEntries) in personnelGroups.sorted(by: { $0.key < $1.key }) {
                let hours = groupEntries.reduce(0.0) { total, entry in
                    guard let end = entry.endTime else { return total }
                    return total + end.timeIntervalSince(entry.startTime) / 3600
                }
                let personHours = hours * Double(count)
                md += "| \(count) \(count == 1 ? "person" : "people") | \(groupEntries.count) | \(String(format: "%.1f", hours)) | \(String(format: "%.1f", personHours)) |\n"
            }

            return md

        case .plainText:
            var text = "PERSONNEL UTILIZATION REPORT\n"
            text += "Generated: \(formatDate(Date()))\n"
            text += "Period: \(formatDateRange(data.effectiveDateRange))\n\n"

            let totalPersonHours = entries.reduce(0.0) { total, entry in
                guard let end = entry.endTime else { return total }
                let hours = end.timeIntervalSince(entry.startTime) / 3600
                return total + (hours * Double(entry.personnelCount))
            }
            text += "Total Person-Hours: \(String(format: "%.1f", totalPersonHours)) hrs\n"
            text += "Time Entries: \(entries.count)\n"
            return text

        case .csv:
            var csv = "Report Type,Personnel Utilization\n"
            csv += "Generated,\(formatDate(Date()))\n"
            csv += "Period,\(formatDateRange(data.effectiveDateRange))\n\n"
            csv += "Task,Project,Date,Crew Size,Hours,Person-Hours\n"

            for entry in entries.sorted(by: { $0.startTime > $1.startTime }) {
                guard let end = entry.endTime else { continue }
                let taskName = entry.task?.title ?? "Unknown"
                let projectName = entry.task?.project?.title ?? "No Project"
                let date = formatDate(entry.startTime)
                let hours = end.timeIntervalSince(entry.startTime) / 3600
                let personHours = hours * Double(entry.personnelCount)

                csv += "\"\(taskName)\",\"\(projectName)\",\(date),\(entry.personnelCount),\(String(format: "%.2f", hours)),\(String(format: "%.2f", personHours))\n"
            }

            return csv
        }
    }

    // MARK: - Task Efficiency Report

    private static func generateTaskEfficiency(data: ReportData) -> String {
        let tasks = data.filteredTasks.filter { $0.effectiveEstimate != nil }

        switch data.format {
        case .markdown:
            var md = "# Task Efficiency Report\n\n"
            md += "*Generated: \(formatDate(Date()))*\n"
            md += "*Period: \(formatDateRange(data.effectiveDateRange))*\n\n"

            if tasks.isEmpty {
                md += "*No tasks with estimates found in this period.*\n"
                return md
            }

            // Summary
            let onTrack = tasks.filter { $0.estimateStatus == .onTrack }.count
            let warning = tasks.filter { $0.estimateStatus == .warning }.count
            let over = tasks.filter { $0.estimateStatus == .over }.count

            md += "## Summary\n\n"
            md += "- **On Track**: \(onTrack) tasks\n"
            md += "- **Warning**: \(warning) tasks (75-100% time used)\n"
            md += "- **Over Estimate**: \(over) tasks\n\n"

            // Task details
            md += "## Task Details\n\n"
            md += "| Task | Project | Estimated | Actual | Status |\n"
            md += "|------|---------|-----------|--------|--------|\n"

            for task in tasks.sorted(by: { ($0.timeProgress ?? 0) > ($1.timeProgress ?? 0) }) {
                let projectName = task.project?.title ?? "No Project"
                let estimated = String(format: "%.1f", Double(task.effectiveEstimate ?? 0) / 3600)
                let actual = String(format: "%.1f", Double(task.totalTimeSpent) / 3600)
                let progress = Int((task.timeProgress ?? 0) * 100)
                let status = progress > 100 ? "🔴 Over" : progress > 75 ? "⚠️ Warning" : "✅ On Track"

                md += "| \(task.title) | \(projectName) | \(estimated)h | \(actual)h | \(status) (\(progress)%) |\n"
            }

            return md

        case .plainText:
            var text = "TASK EFFICIENCY REPORT\n"
            text += "Generated: \(formatDate(Date()))\n"
            text += "Period: \(formatDateRange(data.effectiveDateRange))\n\n"

            if tasks.isEmpty {
                text += "No tasks with estimates found in this period.\n"
                return text
            }

            for task in tasks {
                let estimated = String(format: "%.1f", Double(task.effectiveEstimate ?? 0) / 3600)
                let actual = String(format: "%.1f", Double(task.totalTimeSpent) / 3600)
                let progress = Int((task.timeProgress ?? 0) * 100)
                text += "- \(task.title): \(actual)h / \(estimated)h (\(progress)%)\n"
            }

            return text

        case .csv:
            var csv = "Report Type,Task Efficiency\n"
            csv += "Generated,\(formatDate(Date()))\n"
            csv += "Period,\(formatDateRange(data.effectiveDateRange))\n\n"
            csv += "Task,Project,Estimated Hours,Actual Hours,Progress %,Status\n"

            for task in tasks.sorted(by: { $0.createdDate > $1.createdDate }) {
                let projectName = task.project?.title ?? "No Project"
                let estimated = String(format: "%.2f", Double(task.effectiveEstimate ?? 0) / 3600)
                let actual = String(format: "%.2f", Double(task.totalTimeSpent) / 3600)
                let progress = Int((task.timeProgress ?? 0) * 100)
                let status = progress > 100 ? "Over" : progress > 75 ? "Warning" : "On Track"

                csv += "\"\(task.title)\",\"\(projectName)\",\(estimated),\(actual),\(progress),\(status)\n"
            }

            return csv
        }
    }

    // MARK: - Helper Functions

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if range.start == Date.distantPast && range.end == Date.distantFuture {
            return "All Time"
        }

        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }

    /// Get the effective project for a task (handles subtask inheritance from parent)
    private static func getEffectiveProject(for task: Task) -> Project? {
        // If task has direct project, return it
        if let project = task.project {
            return project
        }

        // Otherwise, check parent task's project (subtasks inherit from parent)
        if let parent = task.parentTask {
            return getEffectiveProject(for: parent)
        }

        return nil
    }

    /// Recursively calculate person-hours for a task and all its subtasks
    /// This matches the logic from TaskTimeTrackingView
    private static func computePersonHours(for task: Task, allTasks: [Task]) -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        var totalPersonSeconds = 0.0

        // Calculate direct person-hours from time entries
        for entry in entries {
            guard let end = entry.endTime else { continue }
            let duration = end.timeIntervalSince(entry.startTime)
            totalPersonSeconds += duration * Double(entry.personnelCount)
        }

        // Recursively add person-hours from subtasks
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            totalPersonSeconds += computePersonHours(for: subtask, allTasks: allTasks) * 3600  // Convert hours back to seconds
        }

        return totalPersonSeconds / 3600  // Convert to hours
    }

    // MARK: - Budget Analysis Report

    private static func generateBudgetAnalysis(data: ReportData) -> String {
        // Filter projects with budgets
        let projectsWithBudgets = data.projects.filter { $0.estimatedHours != nil && $0.estimatedHours! > 0 }

        switch data.format {
        case .markdown:
            var md = "# Budget Analysis Report\n\n"
            md += "*Generated: \(formatDate(Date()))*\n\n"

            if projectsWithBudgets.isEmpty {
                md += "*No projects with budgets found.*\n"
                return md
            }

            md += "## Overview\n\n"
            let totalBudget = projectsWithBudgets.reduce(0.0) { $0 + ($1.estimatedHours ?? 0) }
            let totalPlanned = projectsWithBudgets.reduce(0.0) { $0 + ($1.taskPlannedHours ?? 0) }
            let totalActual = projectsWithBudgets.reduce(0.0) { $0 + $1.totalTimeSpentHours }
            let overPlannedCount = projectsWithBudgets.filter { $0.isOverPlanned }.count

            md += "- **Total Projects**: \(projectsWithBudgets.count)\n"
            md += "- **Over-Planned Projects**: \(overPlannedCount)\n"
            md += "- **Total Budget**: \(String(format: "%.1f", totalBudget))h\n"
            md += "- **Total Planned**: \(String(format: "%.1f", totalPlanned))h\n"
            md += "- **Total Actual**: \(String(format: "%.1f", totalActual))h\n"
            md += "- **Budget Utilization**: \(Int((totalActual / totalBudget) * 100))%\n\n"

            md += "## Project Budget Breakdown\n\n"
            md += "| Project | Budget | Planned | Actual | Plan Var | Budget Used | Status |\n"
            md += "|---------|--------|---------|--------|----------|-------------|--------|\n"

            for project in projectsWithBudgets.sorted(by: { $0.title < $1.title }) {
                let budget = project.estimatedHours ?? 0
                let planned = project.taskPlannedHours ?? 0
                let actual = project.totalTimeSpentHours
                let planVar = project.planningVariance ?? 0
                let budgetUsed = budget > 0 ? Int((actual / budget) * 100) : 0

                let status: String
                if project.isOverPlanned {
                    status = "⚠️ Over-Planned"
                } else if budgetUsed > 100 {
                    status = "🔴 Over Budget"
                } else if budgetUsed > 85 {
                    status = "⚠️ Nearing"
                } else {
                    status = "✅ On Track"
                }

                md += "| \(project.title) | \(String(format: "%.1f", budget))h | \(String(format: "%.1f", planned))h | \(String(format: "%.1f", actual))h | "
                md += planVar > 0 ? "+\(String(format: "%.1f", planVar))h" : "\(String(format: "%.1f", planVar))h"
                md += " | \(budgetUsed)% | \(status) |\n"
            }

            // Add section for projects needing attention
            let needsAttention = projectsWithBudgets.filter { $0.isOverPlanned || ($0.timeProgress ?? 0) > 0.85 }
            if !needsAttention.isEmpty {
                md += "\n## Projects Needing Attention\n\n"
                for project in needsAttention {
                    md += "### \(project.title)\n\n"
                    if project.isOverPlanned, let variance = project.planningVariance {
                        md += "- **Over-Planned**: Task estimates exceed budget by \(String(format: "%.1f", variance))h\n"
                        md += "- **Suggestion**: Reduce scope, add resources, or negotiate budget increase\n"
                    }
                    if let progress = project.timeProgress, progress > 0.85 {
                        let budget = project.estimatedHours ?? 0
                        let actual = project.totalTimeSpentHours
                        md += "- **Budget Alert**: \(String(format: "%.1f", actual))h of \(String(format: "%.1f", budget))h used (\(Int(progress * 100))%)\n"
                        md += "- **Suggestion**: Monitor remaining tasks and adjust timeline\n"
                    }
                    md += "\n"
                }
            }

            return md

        case .plainText:
            var text = "BUDGET ANALYSIS REPORT\n"
            text += "=====================\n"
            text += "Generated: \(formatDate(Date()))\n\n"

            if projectsWithBudgets.isEmpty {
                text += "No projects with budgets found.\n"
                return text
            }

            let totalBudget = projectsWithBudgets.reduce(0.0) { $0 + ($1.estimatedHours ?? 0) }
            let totalPlanned = projectsWithBudgets.reduce(0.0) { $0 + ($1.taskPlannedHours ?? 0) }
            let totalActual = projectsWithBudgets.reduce(0.0) { $0 + $1.totalTimeSpentHours }

            text += "OVERVIEW\n"
            text += "--------\n"
            text += "Total Projects: \(projectsWithBudgets.count)\n"
            text += "Total Budget: \(String(format: "%.1f", totalBudget))h\n"
            text += "Total Planned: \(String(format: "%.1f", totalPlanned))h\n"
            text += "Total Actual: \(String(format: "%.1f", totalActual))h\n\n"

            text += "PROJECTS\n"
            text += "--------\n"
            for project in projectsWithBudgets.sorted(by: { $0.title < $1.title }) {
                let budget = project.estimatedHours ?? 0
                let planned = project.taskPlannedHours ?? 0
                let actual = project.totalTimeSpentHours
                text += "\(project.title):\n"
                text += "  Budget: \(String(format: "%.1f", budget))h | Planned: \(String(format: "%.1f", planned))h | Actual: \(String(format: "%.1f", actual))h\n"
            }

            return text

        case .csv:
            var csv = "Report Type,Budget Analysis\n"
            csv += "Generated,\(formatDate(Date()))\n\n"
            csv += "Project,Budget Hours,Planned Hours,Actual Hours,Planning Variance,Budget Used %,Status\n"

            for project in projectsWithBudgets.sorted(by: { $0.title < $1.title }) {
                let budget = project.estimatedHours ?? 0
                let planned = project.taskPlannedHours ?? 0
                let actual = project.totalTimeSpentHours
                let planVar = project.planningVariance ?? 0
                let budgetUsed = budget > 0 ? Int((actual / budget) * 100) : 0

                let status: String
                if project.isOverPlanned {
                    status = "Over-Planned"
                } else if budgetUsed > 100 {
                    status = "Over Budget"
                } else if budgetUsed > 85 {
                    status = "Nearing"
                } else {
                    status = "On Track"
                }

                csv += "\"\(project.title)\",\(String(format: "%.2f", budget)),\(String(format: "%.2f", planned)),\(String(format: "%.2f", actual)),\(String(format: "%.2f", planVar)),\(budgetUsed),\(status)\n"
            }

            return csv
        }
    }

    // MARK: - Task Type Efficiency Report

    private static func generateTaskTypeEfficiency(data: ReportData) -> String {
        let tasks = data.filteredTasks

        // Group by task type
        let tasksByType = Dictionary(grouping: tasks, by: { $0.taskType })

        switch data.format {
        case .markdown:
            var md = "# Task Type Efficiency Report\n\n"
            md += "*Generated: \(formatDate(Date()))*\n"
            md += "*Period: \(formatDateRange(data.effectiveDateRange))*\n\n"

            if tasks.isEmpty {
                md += "*No tasks found in this period.*\n"
                return md
            }

            md += "## Overview\n\n"
            let totalHours = tasks.reduce(0.0) { $0 + (Double($1.totalTimeSpent) / 3600.0) }
            md += "- **Total Tasks**: \(tasks.count)\n"
            md += "- **Total Hours**: \(String(format: "%.1f", totalHours))h\n"
            md += "- **Task Types**: \(tasksByType.count)\n\n"

            md += "## Efficiency by Task Type\n\n"
            md += "| Task Type | Count | Avg Hours | Total Hours | Avg Person-Hours |\n"
            md += "|-----------|-------|-----------|-------------|------------------|\n"

            for (taskType, typeTasks) in tasksByType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let count = typeTasks.count
                let totalHours = typeTasks.reduce(0.0) { $0 + (Double($1.totalTimeSpent) / 3600.0) }
                let avgHours = totalHours / Double(count)
                let totalPersonHours = typeTasks.reduce(0.0) { total, task in
                    total + computePersonHours(for: task, allTasks: data.tasks)
                }
                let avgPersonHours = totalPersonHours / Double(count)

                md += "| \(taskType.rawValue) | \(count) | \(String(format: "%.1f", avgHours))h | \(String(format: "%.1f", totalHours))h | \(String(format: "%.1f", avgPersonHours))h |\n"
            }

            md += "\n## Task Type Distribution\n\n"
            for (taskType, typeTasks) in tasksByType.sorted(by: { $1.count < $0.count }) {
                let percentage = Int(Double(typeTasks.count) / Double(tasks.count) * 100)
                md += "- **\(taskType.rawValue)**: \(typeTasks.count) tasks (\(percentage)%)\n"
            }

            return md

        case .plainText:
            var text = "TASK TYPE EFFICIENCY REPORT\n"
            text += "===========================\n"
            text += "Generated: \(formatDate(Date()))\n"
            text += "Period: \(formatDateRange(data.effectiveDateRange))\n\n"

            if tasks.isEmpty {
                text += "No tasks found in this period.\n"
                return text
            }

            for (taskType, typeTasks) in tasksByType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let totalHours = typeTasks.reduce(0.0) { $0 + (Double($1.totalTimeSpent) / 3600.0) }
                let avgHours = totalHours / Double(typeTasks.count)
                text += "\(taskType.rawValue): \(typeTasks.count) tasks, avg \(String(format: "%.1f", avgHours))h per task\n"
            }

            return text

        case .csv:
            var csv = "Report Type,Task Type Efficiency\n"
            csv += "Generated,\(formatDate(Date()))\n"
            csv += "Period,\(formatDateRange(data.effectiveDateRange))\n\n"
            csv += "Task Type,Count,Average Hours,Total Hours,Average Person-Hours\n"

            for (taskType, typeTasks) in tasksByType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let count = typeTasks.count
                let totalHours = typeTasks.reduce(0.0) { $0 + (Double($1.totalTimeSpent) / 3600.0) }
                let avgHours = totalHours / Double(count)
                let totalPersonHours = typeTasks.reduce(0.0) { total, task in
                    total + computePersonHours(for: task, allTasks: data.tasks)
                }
                let avgPersonHours = totalPersonHours / Double(count)

                csv += "\(taskType.rawValue),\(count),\(String(format: "%.2f", avgHours)),\(String(format: "%.2f", totalHours)),\(String(format: "%.2f", avgPersonHours))\n"
            }

            return csv
        }
    }
}
