import Foundation
import SwiftData

/// Custom unit type for quantity tracking
/// Allows users to define their own units beyond predefined options
@Model
final class CustomUnit: Hashable {
    var id: UUID
    var name: String // Display name (e.g., "orders", "m²", "pieces")
    var icon: String // SF Symbol name
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
        isQuantifiable: Bool = true,
        isSystem: Bool = false,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isQuantifiable = isQuantifiable
        self.isSystem = isSystem
        self.createdDate = createdDate
        self.order = order
    }

    // MARK: - Hashable Conformance

    static func == (lhs: CustomUnit, rhs: CustomUnit) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
            isQuantifiable: false,
            isSystem: true,
            order: 0
        ),
        CustomUnit(
            name: "m²",
            icon: "square.grid.2x2",
            isQuantifiable: true,
            isSystem: true,
            order: 1
        ),
        CustomUnit(
            name: "m",
            icon: "ruler",
            isQuantifiable: true,
            isSystem: true,
            order: 2
        ),
        CustomUnit(
            name: "pcs",
            icon: "cube.box",
            isQuantifiable: true,
            isSystem: true,
            order: 3
        ),
        CustomUnit(
            name: "kg",
            icon: "scalemass",
            isQuantifiable: true,
            isSystem: true,
            order: 4
        ),
        CustomUnit(
            name: "L",
            icon: "drop",
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
