import Foundation
import SwiftData

/// Reusable task template for common work types (e.g., "Carpet Installation", "Booth Wall Setup")
/// Pre-configures default unit, personnel, and estimates for faster task creation
@Model
final class TaskTemplate {
    var id: UUID
    var name: String
    var taskType: String
    var defaultUnit: UnitType
    var defaultEstimateSeconds: Int?
    var createdDate: Date
    var order: Int?

    init(
        id: UUID = UUID(),
        name: String,
        taskType: String,
        defaultUnit: UnitType = UnitType.none,
        defaultEstimateSeconds: Int? = nil,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.taskType = taskType
        self.defaultUnit = defaultUnit
        self.defaultEstimateSeconds = defaultEstimateSeconds
        self.createdDate = createdDate
        self.order = order
    }

    // MARK: - Computed Properties

    @Transient
    var orderValue: Int {
        order ?? 0
    }
}

// MARK: - Default Templates

extension TaskTemplate {
    /// Common exhibition/event build templates
    static let defaultTemplates: [TaskTemplate] = [
        TaskTemplate(
            name: "Carpet Installation",
            taskType: "Carpet Installation",
            defaultUnit: .squareMeters,
            order: 0
        ),
        TaskTemplate(
            name: "Booth Wall Setup",
            taskType: "Booth Wall Setup",
            defaultUnit: .meters,
            order: 1
        ),
        TaskTemplate(
            name: "Furniture Assembly",
            taskType: "Furniture Assembly",
            defaultUnit: .pieces,
            order: 2
        ),
        TaskTemplate(
            name: "Material Delivery",
            taskType: "Material Delivery",
            defaultUnit: .pieces,
            order: 3
        ),
        TaskTemplate(
            name: "Paint/Finish Work",
            taskType: "Paint/Finish Work",
            defaultUnit: .squareMeters,
            order: 4
        )
    ]
}
