import Foundation
import SwiftData

/// Handles importing task templates from JSON files with conflict detection and resolution
struct TemplateImporter {

    // MARK: - Import Result Types

    enum ImportError: LocalizedError {
        case invalidFileFormat
        case unsupportedVersion(Int)
        case decodingFailed(String)
        case invalidUnitType(String)
        case noTemplatesFound

        var errorDescription: String? {
            switch self {
            case .invalidFileFormat:
                return "Invalid file format. Expected a .todotemplate file."
            case .unsupportedVersion(let version):
                return "Unsupported file version \(version). Please update the app."
            case .decodingFailed(let message):
                return "Failed to read file: \(message)"
            case .invalidUnitType(let unit):
                return "Unknown unit type: \(unit)"
            case .noTemplatesFound:
                return "No templates found in file."
            }
        }
    }

    /// Conflict resolution strategy for duplicate templates
    enum ConflictStrategy {
        case skip           // Skip importing this template
        case replace        // Replace existing template
        case keepBoth       // Import with renamed name (add number suffix)
    }

    /// Represents a conflict between imported and existing templates
    struct TemplateConflict: Identifiable {
        let id = UUID()
        let importedTemplate: TemplateExporter.ExportableTemplate
        let existingTemplate: TaskTemplate
        var strategy: ConflictStrategy = .skip

        var conflictDescription: String {
            "Template '\(importedTemplate.name)' with unit '\(importedTemplate.customUnit?.name ?? importedTemplate.defaultUnit)' already exists"
        }
    }

    /// Result of conflict detection before import
    struct ImportPreview {
        let templates: [TemplateExporter.ExportableTemplate]
        let conflicts: [TemplateConflict]
        let newTemplates: [TemplateExporter.ExportableTemplate]

        var hasConflicts: Bool {
            !conflicts.isEmpty
        }

        var totalCount: Int {
            templates.count
        }
    }

    /// Result of the import operation
    struct ImportResult {
        let imported: Int
        let skipped: Int
        let replaced: Int
        let errors: [String]

        var success: Bool {
            errors.isEmpty && imported > 0
        }

        var message: String {
            if errors.isEmpty {
                var parts: [String] = []
                if imported > 0 {
                    parts.append("\(imported) imported")
                }
                if replaced > 0 {
                    parts.append("\(replaced) replaced")
                }
                if skipped > 0 {
                    parts.append("\(skipped) skipped")
                }
                return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
            } else {
                return "Import failed: \(errors.first ?? "Unknown error")"
            }
        }
    }

    // MARK: - Import Methods

    /// Read and validate import file, returning a preview for conflict resolution
    static func previewImport(from url: URL, context: ModelContext) throws -> ImportPreview {
        // Read and decode file
        let data = try Data(contentsOf: url)
        let container = try decodeContainer(from: data)

        // Validate version
        guard container.version == 1 else {
            throw ImportError.unsupportedVersion(container.version)
        }

        guard !container.templates.isEmpty else {
            throw ImportError.noTemplatesFound
        }

        // Fetch existing templates
        let existingTemplates = try context.fetch(FetchDescriptor<TaskTemplate>())

        // Detect conflicts
        var conflicts: [TemplateConflict] = []
        var newTemplates: [TemplateExporter.ExportableTemplate] = []

        for importedTemplate in container.templates {
            if let existing = findConflictingTemplate(
                importedTemplate,
                in: existingTemplates
            ) {
                conflicts.append(TemplateConflict(
                    importedTemplate: importedTemplate,
                    existingTemplate: existing
                ))
            } else {
                newTemplates.append(importedTemplate)
            }
        }

        return ImportPreview(
            templates: container.templates,
            conflicts: conflicts,
            newTemplates: newTemplates
        )
    }

    /// Execute import with conflict resolution strategies
    static func executeImport(
        preview: ImportPreview,
        conflicts: [TemplateConflict],
        context: ModelContext
    ) -> ImportResult {
        var imported = 0
        var skipped = 0
        var replaced = 0
        var errors: [String] = []

        // Import new templates (no conflicts)
        for template in preview.newTemplates {
            do {
                try importTemplate(template, context: context)
                imported += 1
            } catch {
                errors.append("Failed to import '\(template.name)': \(error.localizedDescription)")
            }
        }

        // Handle conflicts based on strategies
        for conflict in conflicts {
            switch conflict.strategy {
            case .skip:
                skipped += 1

            case .replace:
                do {
                    // Delete existing
                    context.delete(conflict.existingTemplate)

                    // Import new
                    try importTemplate(conflict.importedTemplate, context: context)
                    replaced += 1
                } catch {
                    errors.append("Failed to replace '\(conflict.importedTemplate.name)': \(error.localizedDescription)")
                }

            case .keepBoth:
                do {
                    // Find unique name
                    let uniqueName = generateUniqueName(
                        base: conflict.importedTemplate.name,
                        context: context
                    )

                    // Import with new name
                    var modifiedTemplate = conflict.importedTemplate
                    modifiedTemplate = TemplateExporter.ExportableTemplate(
                        name: uniqueName,
                        defaultUnit: modifiedTemplate.defaultUnit,
                        defaultProductivityRate: modifiedTemplate.defaultProductivityRate,
                        minQuantity: modifiedTemplate.minQuantity,
                        maxQuantity: modifiedTemplate.maxQuantity,
                        customUnit: modifiedTemplate.customUnit
                    )
                    try importTemplate(modifiedTemplate, context: context)
                    imported += 1
                } catch {
                    errors.append("Failed to import '\(conflict.importedTemplate.name)': \(error.localizedDescription)")
                }
            }
        }

        // Save context
        if errors.isEmpty {
            do {
                try context.save()
            } catch {
                errors.append("Failed to save: \(error.localizedDescription)")
            }
        }

        return ImportResult(
            imported: imported,
            skipped: skipped,
            replaced: replaced,
            errors: errors
        )
    }

    // MARK: - Private Helper Methods

    private static func decodeContainer(from data: Data) throws -> TemplateExporter.ExportContainer {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(TemplateExporter.ExportContainer.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }
    }

    /// Find existing template that conflicts with imported one
    /// Conflict = same name AND same unit (either both use same custom unit name OR same default unit)
    private static func findConflictingTemplate(
        _ imported: TemplateExporter.ExportableTemplate,
        in existing: [TaskTemplate]
    ) -> TaskTemplate? {
        return existing.first { template in
            // Must have same name
            guard template.name == imported.name else { return false }

            // Check unit match
            if let importedCustomUnit = imported.customUnit {
                // Imported has custom unit - check if existing has same custom unit name
                return template.customUnit?.name == importedCustomUnit.name
            } else {
                // Imported uses legacy unit - check if existing uses same legacy unit
                return template.customUnit == nil &&
                       template.defaultUnit.rawValue == imported.defaultUnit
            }
        }
    }

    /// Import a single template into the context
    private static func importTemplate(
        _ exportable: TemplateExporter.ExportableTemplate,
        context: ModelContext
    ) throws {
        // Validate and convert unit type
        guard let unitType = UnitType(rawValue: exportable.defaultUnit) else {
            throw ImportError.invalidUnitType(exportable.defaultUnit)
        }

        // Handle custom unit (if present)
        var customUnit: CustomUnit? = nil
        if let exportedUnit = exportable.customUnit {
            customUnit = try importCustomUnit(exportedUnit, context: context)
        }

        // Get next order value
        let nextOrder = getNextTemplateOrder(context: context)

        // Create template
        let template = TaskTemplate(
            name: exportable.name,
            defaultUnit: unitType,
            defaultProductivityRate: exportable.defaultProductivityRate,
            minQuantity: exportable.minQuantity,
            maxQuantity: exportable.maxQuantity,
            order: nextOrder,
            customUnit: customUnit
        )

        context.insert(template)
    }

    /// Import or reuse existing custom unit
    private static func importCustomUnit(
        _ exportable: TemplateExporter.ExportableCustomUnit,
        context: ModelContext
    ) throws -> CustomUnit {
        // Check if unit with same name already exists
        let descriptor = FetchDescriptor<CustomUnit>(
            predicate: #Predicate { $0.name == exportable.name }
        )

        if let existing = try context.fetch(descriptor).first {
            // Reuse existing unit (don't create duplicate)
            // Note: System units can't be overwritten
            return existing
        }

        // Create new custom unit (never mark as system on import)
        let nextOrder = getNextCustomUnitOrder(context: context)
        let unit = CustomUnit(
            name: exportable.name,
            icon: exportable.icon,
            isQuantifiable: exportable.isQuantifiable,
            isSystem: false, // Never import as system unit
            order: nextOrder
        )

        context.insert(unit)
        return unit
    }

    /// Generate unique name for template (adds number suffix)
    private static func generateUniqueName(base: String, context: ModelContext) -> String {
        var counter = 1
        var name = "\(base) \(counter)"

        let allTemplates = (try? context.fetch(FetchDescriptor<TaskTemplate>())) ?? []

        while allTemplates.contains(where: { $0.name == name }) {
            counter += 1
            name = "\(base) \(counter)"
        }

        return name
    }

    /// Get next order value for templates
    private static func getNextTemplateOrder(context: ModelContext) -> Int {
        let templates = (try? context.fetch(FetchDescriptor<TaskTemplate>())) ?? []
        let maxOrder = templates.compactMap { $0.order }.max() ?? -1
        return maxOrder + 1
    }

    /// Get next order value for custom units
    private static func getNextCustomUnitOrder(context: ModelContext) -> Int {
        let units = (try? context.fetch(FetchDescriptor<CustomUnit>())) ?? []
        let maxOrder = units.compactMap { $0.order }.max() ?? -1
        return maxOrder + 1
    }
}

// MARK: - ExportableTemplate Extension

extension TemplateExporter.ExportableTemplate {
    /// Custom init for keep-both strategy with renamed name
    init(
        name: String,
        defaultUnit: String,
        defaultProductivityRate: Double?,
        minQuantity: Double?,
        maxQuantity: Double?,
        customUnit: TemplateExporter.ExportableCustomUnit?
    ) {
        self.name = name
        self.defaultUnit = defaultUnit
        self.defaultProductivityRate = defaultProductivityRate
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.customUnit = customUnit
    }
}
