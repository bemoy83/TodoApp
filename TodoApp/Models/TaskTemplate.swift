import Foundation
import SwiftData

/// Reusable task template for common work types (e.g., "Carpet Installation", "Booth Wall Setup")
/// Pre-configures default unit, personnel, and estimates for faster task creation
@Model
final class TaskTemplate {
    var id: UUID
    var name: String
    var defaultUnit: UnitType
    var defaultPersonnelCount: Int?
    var defaultEstimateSeconds: Int?
    var createdDate: Date
    var order: Int?

    init(
        id: UUID = UUID(),
        name: String,
        defaultUnit: UnitType = UnitType.none,
        defaultPersonnelCount: Int? = nil,
        defaultEstimateSeconds: Int? = nil,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultUnit = defaultUnit
        self.defaultPersonnelCount = defaultPersonnelCount
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
            defaultUnit: .squareMeters,
            defaultPersonnelCount: 2,
            order: 0
        ),
        TaskTemplate(
            name: "Booth Wall Setup",
            defaultUnit: .meters,
            defaultPersonnelCount: 3,
            order: 1
        ),
        TaskTemplate(
            name: "Furniture Assembly",
            defaultUnit: .pieces,
            defaultPersonnelCount: 1,
            order: 2
        ),
        TaskTemplate(
            name: "Material Delivery",
            defaultUnit: .pieces,
            defaultPersonnelCount: 2,
            order: 3
        ),
        TaskTemplate(
            name: "Paint/Finish Work",
            defaultUnit: .squareMeters,
            defaultPersonnelCount: 1,
            order: 4
        )
    ]
}
