import Foundation
import SwiftData

// MARK: - Tag Category Enum

enum TagCategory: String, Codable, CaseIterable, Sendable {
    case resource = "Resource"
    case phase = "Phase"
    case location = "Location"
    case team = "Team"
    case vendor = "Vendor"
    case custom = "Custom"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .resource: return "cube.box"
        case .phase: return "clock"
        case .location: return "map.fill"
        case .team: return "person.2.fill"
        case .vendor: return "building.2.fill"
        case .custom: return "tag.fill"
        }
    }
}

// MARK: - Tag Model

/// Tag for organizing and filtering tasks
/// Global tags shared across all projects
@Model
final class Tag: Hashable {
    var id: UUID
    var name: String            // Display name (e.g., "carpet", "setup", "hall-a")
    var icon: String            // SF Symbol name
    var color: String           // Color name for badge (e.g., "blue", "purple", "orange")
    var category: TagCategory   // Category for organization
    var isSystem: Bool          // System-provided tags (pre-seeded)
    var createdDate: Date
    var order: Int?             // Display order within category

    // Many-to-many relationship with tasks
    @Relationship(deleteRule: .nullify, inverse: \Task.tags)
    var tasks: [Task]?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        category: TagCategory,
        isSystem: Bool = false,
        createdDate: Date = Date(),
        order: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.category = category
        self.isSystem = isSystem
        self.createdDate = createdDate
        self.order = order
    }

    // MARK: - Hashable Conformance

    static func == (lhs: Tag, rhs: Tag) -> Bool {
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

    /// Number of tasks using this tag
    @Transient
    var taskCount: Int {
        tasks?.count ?? 0
    }
}

// MARK: - System Tags

extension Tag {
    /// System-provided tags for event management
    static let systemTags: [Tag] = [
        // Resource tags
        Tag(
            name: "Carpet",
            icon: "square.grid.2x2",
            color: "blue",
            category: .resource,
            isSystem: true,
            order: 0
        ),
        Tag(
            name: "Walls",
            icon: "square.split.2x2",
            color: "purple",
            category: .resource,
            isSystem: true,
            order: 1
        ),
        Tag(
            name: "Furniture",
            icon: "chair.lounge",
            color: "orange",
            category: .resource,
            isSystem: true,
            order: 2
        ),
        Tag(
            name: "Electrical",
            icon: "bolt.fill",
            color: "yellow",
            category: .resource,
            isSystem: true,
            order: 3
        ),

        // Phase tags
        Tag(
            name: "Setup",
            icon: "wrench.and.screwdriver",
            color: "green",
            category: .phase,
            isSystem: true,
            order: 0
        ),
        Tag(
            name: "Teardown",
            icon: "arrow.down.circle",
            color: "red",
            category: .phase,
            isSystem: true,
            order: 1
        ),

        // Location tags
        Tag(
            name: "Hall A",
            icon: "building.fill",
            color: "cyan",
            category: .location,
            isSystem: true,
            order: 0
        ),
        Tag(
            name: "Hall B",
            icon: "building.2.fill",
            color: "teal",
            category: .location,
            isSystem: true,
            order: 1
        ),

        // Team tags
        Tag(
            name: "Carpentry",
            icon: "hammer.fill",
            color: "brown",
            category: .team,
            isSystem: true,
            order: 0
        ),
        Tag(
            name: "Logistics",
            icon: "shippingbox.fill",
            color: "indigo",
            category: .team,
            isSystem: true,
            order: 1
        ),

        // Priority signals
        Tag(
            name: "Rush",
            icon: "flame.fill",
            color: "red",
            category: .custom,
            isSystem: true,
            order: 0
        ),
        Tag(
            name: "VIP",
            icon: "star.fill",
            color: "yellow",
            category: .custom,
            isSystem: true,
            order: 1
        )
    ]

    /// Find system tag by name
    static func systemTag(named: String) -> Tag? {
        systemTags.first { $0.name == named }
    }
}

// MARK: - Color Utilities

extension Tag {
    /// Converts tag color string to SwiftUI Color
    /// Centralized color mapping to avoid duplication across views
    var colorValue: Color {
        Tag.color(from: color)
    }

    /// Static helper to convert color string to Color
    /// Useful when working with color strings directly (e.g., in forms)
    static func color(from colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "teal": return .teal
        case "brown": return .brown
        case "indigo": return .indigo
        case "pink": return .pink
        case "mint": return .mint
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }
}
