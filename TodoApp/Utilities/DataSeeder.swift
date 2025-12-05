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

    /// Links existing tasks to templates based on taskType and unit matching
    /// Should be called after template migration to CustomUnits
    static func linkTasksToTemplates(context: ModelContext) {
        let taskDescriptor = FetchDescriptor<Task>()

        do {
            let tasks = try context.fetch(taskDescriptor)

            // Get all templates for lookup
            let templateDescriptor = FetchDescriptor<TaskTemplate>()
            let templates = try context.fetch(templateDescriptor)

            var linkedCount = 0

            for task in tasks {
                // Skip if already linked
                guard task.taskTemplate == nil else { continue }

                // Skip if no taskType set
                guard let taskTypeName = task.taskType else { continue }

                // Try to find matching template by name and unit
                // This handles the case where multiple templates have the same name
                let matchingTemplate = templates.first { template in
                    template.name == taskTypeName &&
                    template.defaultUnit == task.unit
                }

                if let template = matchingTemplate {
                    task.taskTemplate = template
                    linkedCount += 1
                }
            }

            if linkedCount > 0 {
                try context.save()
                print("✅ Linked \(linkedCount) tasks to templates")
            } else {
                print("✅ No tasks need template linking")
            }

        } catch {
            print("❌ Error linking tasks to templates: \(error)")
        }
    }
}
