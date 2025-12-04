import Foundation
import SwiftData

/// Reusable task template for common work types (e.g., "Carpet Installation", "Booth Wall Setup")
/// Pre-configures default unit and expected productivity for faster task creation
@Model
final class TaskTemplate {
    var id: UUID
    var name: String
    var defaultUnit: UnitType // Legacy: kept for migration compatibility
    var defaultProductivityRate: Double? // Expected/target productivity rate (units/person-hr)
    var minQuantity: Double? // Minimum realistic quantity for this task type
    var maxQuantity: Double? // Maximum realistic quantity for this task type
    var createdDate: Date
    var order: Int?

    // New: Custom unit relationship
    var customUnit: CustomUnit?

    // Inverse relationship to tasks using this template
    @Relationship(deleteRule: .nullify, inverse: \Task.taskTemplate)
    var tasks: [Task]?

    init(
        id: UUID = UUID(),
        name: String,
        defaultUnit: UnitType = UnitType.none,
        defaultProductivityRate: Double? = nil,
        minQuantity: Double? = nil,
        maxQuantity: Double? = nil,
        createdDate: Date = Date(),
        order: Int? = nil,
        customUnit: CustomUnit? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultUnit = defaultUnit
        self.defaultProductivityRate = defaultProductivityRate
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.createdDate = createdDate
        self.order = order
        self.customUnit = customUnit
    }

    // MARK: - Computed Properties

    @Transient
    var orderValue: Int {
        order ?? 0
    }

    /// Active unit: CustomUnit if set, otherwise legacy UnitType
    @Transient
    var unit: CustomUnit? {
        customUnit
    }

    /// Unit display name (for UI)
    @Transient
    var unitDisplayName: String {
        customUnit?.displayName ?? defaultUnit.displayName
    }

    /// Whether the unit is quantifiable
    @Transient
    var isQuantifiable: Bool {
        customUnit?.isQuantifiable ?? defaultUnit.isQuantifiable
    }

    /// Unit icon
    @Transient
    var unitIcon: String {
        customUnit?.icon ?? defaultUnit.icon
    }
}

// MARK: - Default Templates

extension TaskTemplate {
    /// Common exhibition/event build templates with realistic quantity bounds
    static let defaultTemplates: [TaskTemplate] = [
        TaskTemplate(
            name: "Carpet Installation",
            defaultUnit: .squareMeters,
            minQuantity: 5,
            maxQuantity: 5000,
            order: 0
        ),
        TaskTemplate(
            name: "Booth Wall Setup",
            defaultUnit: .meters,
            minQuantity: 2,
            maxQuantity: 1000,
            order: 1
        ),
        TaskTemplate(
            name: "Furniture Assembly",
            defaultUnit: .pieces,
            minQuantity: 1,
            maxQuantity: 500,
            order: 2
        ),
        TaskTemplate(
            name: "Material Delivery",
            defaultUnit: .pieces,
            minQuantity: 1,
            maxQuantity: 1000,
            order: 3
        ),
        TaskTemplate(
            name: "Paint/Finish Work",
            defaultUnit: .squareMeters,
            minQuantity: 10,
            maxQuantity: 10000,
            order: 4
        )
    ]
}
