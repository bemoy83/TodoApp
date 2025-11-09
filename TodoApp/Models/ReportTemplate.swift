import Foundation

// MARK: - Report Template Types

enum ReportTemplate: String, CaseIterable, Identifiable {
    case weeklySummary = "Weekly Summary"
    case monthlySummary = "Monthly Summary"
    case projectPerformance = "Project Performance"
    case personnelUtilization = "Personnel Utilization"
    case taskEfficiency = "Task Efficiency"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weeklySummary: return "calendar.badge.clock"
        case .monthlySummary: return "calendar"
        case .projectPerformance: return "chart.bar.fill"
        case .personnelUtilization: return "person.2.fill"
        case .taskEfficiency: return "gauge.with.dots.needle.bottom.50percent"
        }
    }

    var description: String {
        switch self {
        case .weeklySummary:
            return "Summary of tasks, hours, and person-hours for the last 7 days"
        case .monthlySummary:
            return "Comprehensive monthly report with project breakdowns"
        case .projectPerformance:
            return "Detailed analysis of a specific project's progress and efficiency"
        case .personnelUtilization:
            return "Person-hours breakdown across projects and tasks"
        case .taskEfficiency:
            return "Tasks completed vs estimated time, highlighting overruns"
        }
    }

    var requiresProjectSelection: Bool {
        switch self {
        case .projectPerformance:
            return true
        default:
            return false
        }
    }

    var supportedFormats: [ReportFormat] {
        [.markdown, .plainText, .csv]
    }
}

// MARK: - Report Format Types

enum ReportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown"
    case plainText = "Plain Text"
    case csv = "CSV"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .csv: return "csv"
        }
    }

    var icon: String {
        switch self {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .csv: return "tablecells"
        }
    }
}

// MARK: - Report Data Container

struct ReportData {
    let template: ReportTemplate
    let format: ReportFormat
    let dateRange: DateRange
    let customStartDate: Date?
    let customEndDate: Date?
    let selectedProject: Project?
    let tasks: [Task]
    let projects: [Project]
    let timeEntries: [TimeEntry]

    enum DateRange: String, CaseIterable, Identifiable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        case allTime = "All Time"
        case custom = "Custom Range"

        var id: String { rawValue }
    }

    var effectiveDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .lastThreeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        case .custom:
            return (customStartDate ?? Date.distantPast, customEndDate ?? Date())
        }
    }

    var filteredTimeEntries: [TimeEntry] {
        let (start, end) = effectiveDateRange

        return timeEntries.filter { entry in
            guard let endTime = entry.endTime else { return false }

            // Date range filter
            guard endTime >= start && endTime <= end else { return false }

            // Project filter (if applicable)
            if let project = selectedProject {
                return entry.task?.project?.id == project.id
            }

            return true
        }
    }

    var filteredTasks: [Task] {
        let (start, end) = effectiveDateRange

        return tasks.filter { task in
            // Include if created or completed in range
            let inRange = (task.createdDate >= start && task.createdDate <= end) ||
                         (task.completedDate != nil && task.completedDate! >= start && task.completedDate! <= end)

            guard inRange else { return false }

            // Project filter (if applicable)
            if let project = selectedProject {
                return task.project?.id == project.id
            }

            return true
        }
    }
}
