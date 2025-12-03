import Foundation
import SwiftData

/// Handles database initialization and seeding
struct DataSeeder {

    /// Seeds system units if they don't exist
    /// Should be called once on app launch
    static func seedSystemUnitsIfNeeded(context: ModelContext) {
        // Check if system units already exist
        let descriptor = FetchDescriptor<CustomUnit>(
            predicate: #Predicate { $0.isSystem == true }
        )

        do {
            let existingUnits = try context.fetch(descriptor)

            // If system units already exist, skip seeding
            guard existingUnits.isEmpty else {
                print("✅ System units already seeded (\(existingUnits.count) units)")
                return
            }

            // Seed system units
            print("🌱 Seeding system units...")
            for systemUnit in CustomUnit.systemUnits {
                context.insert(systemUnit)
            }

            try context.save()
            print("✅ Successfully seeded \(CustomUnit.systemUnits.count) system units")

        } catch {
            print("❌ Error seeding system units: \(error)")
        }
    }

    /// Migrates existing templates from UnitType enum to CustomUnit
    /// Optional: Can be run manually or automatically
    static func migrateTemplatesToCustomUnits(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskTemplate>()

        do {
            let templates = try context.fetch(descriptor)

            // Get all system units for lookup
            let unitDescriptor = FetchDescriptor<CustomUnit>(
                predicate: #Predicate { $0.isSystem == true }
            )
            let systemUnits = try context.fetch(unitDescriptor)

            var migratedCount = 0

            for template in templates {
                // Skip if already has customUnit
                guard template.customUnit == nil else { continue }

                // Find matching system unit by name
                let unitName = template.defaultUnit.displayName
                if let matchingUnit = systemUnits.first(where: { $0.name == unitName }) {
                    template.customUnit = matchingUnit
                    migratedCount += 1
                }
            }

            if migratedCount > 0 {
                try context.save()
                print("✅ Migrated \(migratedCount) templates to CustomUnit")
            }

        } catch {
            print("❌ Error migrating templates: \(error)")
        }
    }
}
