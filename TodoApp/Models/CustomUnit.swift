import Foundation
import SwiftData

/// Custom unit type for quantity tracking
/// Allows users to define their own units beyond predefined options
@Model
final class CustomUnit {
    var id: UUID
    var name: String // Display name (e.g., "orders", "m²", "pieces")
    var icon: String // SF Symbol name
    var defaultProductivityRate: Double? // Optional default productivity
    var isQuantifiable: Bool // Whether this unit requires quantity input
    var isSystem: Bool // System-provided units (can't be deleted)
    var createdDate: Date
    var order: Int? // Display order in lists

    // Relationship: Templates using this unit
    @Relationship(deleteRule: .nullify, inverse: \TaskTemplate.customUnit)
    var templates: [TaskTemplate]?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        defaultProductivityRate: Double? = nil,
        isQuantifiable: Bool = true,
        isSystem: Bool = false,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.defaultProductivityRate = defaultProductivityRate
        self.isQuantifiable = isQuantifiable
        self.isSystem = isSystem
        self.createdDate = createdDate
        self.order = order
    }

    // MARK: - Computed Properties

    @Transient
    var displayName: String {
        name
    }

    @Transient
    var orderValue: Int {
        order ?? 0
    }
}

// MARK: - Default System Units

extension CustomUnit {
    /// System-provided units (migrated from UnitType enum)
    static let systemUnits: [CustomUnit] = [
        CustomUnit(
            name: "None",
            icon: "minus.circle",
            defaultProductivityRate: nil,
            isQuantifiable: false,
            isSystem: true,
            order: 0
        ),
        CustomUnit(
            name: "m²",
            icon: "square.grid.2x2",
            defaultProductivityRate: 10.0,
            isQuantifiable: true,
            isSystem: true,
            order: 1
        ),
        CustomUnit(
            name: "m",
            icon: "ruler",
            defaultProductivityRate: 5.0,
            isQuantifiable: true,
            isSystem: true,
            order: 2
        ),
        CustomUnit(
            name: "pcs",
            icon: "cube.box",
            defaultProductivityRate: 2.0,
            isQuantifiable: true,
            isSystem: true,
            order: 3
        ),
        CustomUnit(
            name: "kg",
            icon: "scalemass",
            defaultProductivityRate: 50.0,
            isQuantifiable: true,
            isSystem: true,
            order: 4
        ),
        CustomUnit(
            name: "L",
            icon: "drop",
            defaultProductivityRate: 100.0,
            isQuantifiable: true,
            isSystem: true,
            order: 5
        )
    ]

    /// Find system unit by name (for migration)
    static func systemUnit(named: String) -> CustomUnit? {
        systemUnits.first { $0.name == named }
    }
}
