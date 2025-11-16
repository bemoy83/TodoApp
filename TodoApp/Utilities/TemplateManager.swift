import Foundation
import SwiftData

/// Utility for managing task templates and calculating historical productivity metrics
struct TemplateManager {

    /// Calculate historical average productivity for a given unit type
    /// Returns nil if no historical data available
    static func calculateHistoricalProductivity(
        for unit: UnitType,
        from tasks: [Task]
    ) -> Double? {
        guard unit.isQuantifiable else { return nil }

        // Filter to completed tasks with productivity data for this unit
        let relevantTasks = tasks.filter { task in
            task.unit == unit &&
            task.hasProductivityData &&
            task.isCompleted
        }

        guard !relevantTasks.isEmpty else { return nil }

        // Calculate average
        let productivityValues = relevantTasks.compactMap { $0.unitsPerHour }
        guard !productivityValues.isEmpty else { return nil }

        let sum = productivityValues.reduce(0.0, +)
        return sum / Double(productivityValues.count)
    }

    /// Calculate historical average productivity for a specific task type and unit
    /// More accurate than unit-only lookup as it matches the exact work category
    /// Returns nil if no historical data available
    static func getHistoricalProductivity(
        for taskType: String,
        unit: UnitType,
        from tasks: [Task]
    ) -> Double? {
        guard unit.isQuantifiable else { return nil }

        // Filter to completed tasks with productivity data for this task type + unit
        let relevantTasks = tasks.filter { task in
            task.taskType == taskType &&
            task.unit == unit &&
            task.hasProductivityData &&
            task.isCompleted
        }

        guard !relevantTasks.isEmpty else { return nil }

        // Calculate average
        let productivityValues = relevantTasks.compactMap { $0.unitsPerHour }
        guard !productivityValues.isEmpty else { return nil }

        let sum = productivityValues.reduce(0.0, +)
        return sum / Double(productivityValues.count)
    }

    /// Get count of historical tasks for a given unit type
    static func getHistoricalTaskCount(
        for unit: UnitType,
        from tasks: [Task]
    ) -> Int {
        guard unit.isQuantifiable else { return 0 }

        return tasks.filter { task in
            task.unit == unit &&
            task.hasProductivityData &&
            task.isCompleted
        }.count
    }

    /// Get count of historical tasks for a specific task type and unit
    /// More accurate than unit-only lookup as it matches the exact work category
    static func getHistoricalTaskCount(
        for taskType: String,
        unit: UnitType,
        from tasks: [Task]
    ) -> Int {
        guard unit.isQuantifiable else { return 0 }

        return tasks.filter { task in
            task.taskType == taskType &&
            task.unit == unit &&
            task.hasProductivityData &&
            task.isCompleted
        }.count
    }

    /// Create a task from a template with pre-filled defaults
    static func createTask(from template: TaskTemplate) -> Task {
        Task(
            title: "",  // User will fill this in
            unit: template.defaultUnit,
            taskType: template.name
        )
    }

    /// Apply template defaults to an existing task
    static func applyTemplate(_ template: TaskTemplate, to task: Task) {
        task.unit = template.defaultUnit
        task.taskType = template.name
    }

    /// Check if default templates have been created
    static func needsDefaultTemplates(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<TaskTemplate>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count == 0
    }

    /// Insert default templates into the model context
    static func insertDefaultTemplates(into context: ModelContext) {
        for template in TaskTemplate.defaultTemplates {
            context.insert(template)
        }

        try? context.save()
    }
}

// MARK: - Template Analytics

extension TemplateManager {
    /// Comprehensive analytics for a template
    struct TemplateAnalytics {
        let template: TaskTemplate
        let historicalTaskCount: Int
        let averageProductivity: Double?
        let unit: UnitType

        var hasHistoricalData: Bool {
            historicalTaskCount > 0
        }

        var formattedProductivity: String? {
            guard let avg = averageProductivity else { return nil }
            return String(format: "%.1f %@/person-hr", avg, unit.displayName)
        }
    }

    /// Calculate analytics for a template based on historical task data
    /// Uses taskType + unit combination for accurate productivity tracking
    static func calculateAnalytics(
        for template: TaskTemplate,
        from tasks: [Task]
    ) -> TemplateAnalytics {
        let taskType = template.name
        let unit = template.defaultUnit

        // Use taskType-specific methods to get accurate data
        let count = getHistoricalTaskCount(for: taskType, unit: unit, from: tasks)
        let avgProductivity = getHistoricalProductivity(for: taskType, unit: unit, from: tasks)

        return TemplateAnalytics(
            template: template,
            historicalTaskCount: count,
            averageProductivity: avgProductivity,
            unit: unit
        )
    }
}
