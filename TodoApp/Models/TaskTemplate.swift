import Foundation
import SwiftData

/// Reusable task template for common work types (e.g., "Carpet Installation", "Booth Wall Setup")
/// Pre-configures default unit and expected productivity for faster task creation
@Model
final class TaskTemplate {
    var id: UUID
    var name: String
    var defaultUnit: UnitType
    var defaultProductivityRate: Double? // Expected/target productivity rate (units/person-hr)
    var createdDate: Date
    var order: Int?

    init(
        id: UUID = UUID(),
        name: String,
        defaultUnit: UnitType = UnitType.none,
        defaultProductivityRate: Double? = nil,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultUnit = defaultUnit
        self.defaultProductivityRate = defaultProductivityRate
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
        TaskTemplate(name: "Carpet Installation", defaultUnit: .squareMeters, order: 0),
        TaskTemplate(name: "Booth Wall Setup", defaultUnit: .meters, order: 1),
        TaskTemplate(name: "Furniture Assembly", defaultUnit: .pieces, order: 2),
        TaskTemplate(name: "Material Delivery", defaultUnit: .pieces, order: 3),
        TaskTemplate(name: "Paint/Finish Work", defaultUnit: .squareMeters, order: 4)
    ]
}
