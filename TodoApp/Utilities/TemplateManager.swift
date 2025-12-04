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

    // MARK: - Template-Based Productivity (New)

    /// Calculate historical average productivity for a specific template
    /// Uses template reference for accurate matching (supports multiple templates with same name)
    /// Falls back to name+unit matching for tasks created before template relationship was added
    /// Returns nil if no historical data available
    static func getHistoricalProductivity(
        for template: TaskTemplate,
        from tasks: [Task]
    ) -> Double? {
        guard template.isQuantifiable else { return nil }

        // Filter to completed tasks with productivity data for this template
        let relevantTasks = tasks.filter { task in
            // Prefer template reference matching (new way)
            if task.taskTemplate?.id == template.id {
                return task.hasProductivityData && task.isCompleted
            }
            // Fallback to name+unit matching (legacy tasks)
            return task.taskType == template.name &&
                   task.unit == template.defaultUnit &&
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

    /// Get count of historical tasks for a specific template
    /// Uses template reference for accurate matching (supports multiple templates with same name)
    /// Falls back to name+unit matching for tasks created before template relationship was added
    static func getHistoricalTaskCount(
        for template: TaskTemplate,
        from tasks: [Task]
    ) -> Int {
        guard template.isQuantifiable else { return 0 }

        return tasks.filter { task in
            // Prefer template reference matching (new way)
            if task.taskTemplate?.id == template.id {
                return task.hasProductivityData && task.isCompleted
            }
            // Fallback to name+unit matching (legacy tasks)
            return task.taskType == template.name &&
                   task.unit == template.defaultUnit &&
                   task.hasProductivityData &&
                   task.isCompleted
        }.count
    }

    /// Create a task from a template with pre-filled defaults
    static func createTask(from template: TaskTemplate) -> Task {
        Task(
            title: "",  // User will fill this in
            unit: template.defaultUnit,
            taskType: template.name,
            taskTemplate: template
        )
    }

    /// Apply template defaults to an existing task
    static func applyTemplate(_ template: TaskTemplate, to task: Task) {
        task.unit = template.defaultUnit
        task.taskType = template.name
        task.taskTemplate = template
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
        let unitDisplayName: String

        var hasHistoricalData: Bool {
            historicalTaskCount > 0
        }

        var formattedProductivity: String? {
            guard let avg = averageProductivity else { return nil }
            return String(format: "%.1f %@/person-hr", avg, unitDisplayName)
        }
    }

    /// Calculate analytics for a template based on historical task data
    /// Uses template reference for accurate productivity tracking (supports multiple templates with same name)
    static func calculateAnalytics(
        for template: TaskTemplate,
        from tasks: [Task]
    ) -> TemplateAnalytics {
        // Use new template-based methods for accurate matching
        let count = getHistoricalTaskCount(for: template, from: tasks)
        let avgProductivity = getHistoricalProductivity(for: template, from: tasks)

        return TemplateAnalytics(
            template: template,
            historicalTaskCount: count,
            averageProductivity: avgProductivity,
            unitDisplayName: template.unitDisplayName
        )
    }
}
