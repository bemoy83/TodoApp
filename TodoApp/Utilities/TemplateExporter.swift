import Foundation
import SwiftData

/// Handles exporting task templates (with custom units) to JSON format
struct TemplateExporter {

    // MARK: - Export Data Structures

    /// Exportable format for CustomUnit
    struct ExportableCustomUnit: Codable {
        let name: String
        let icon: String
        let isQuantifiable: Bool
        let isSystem: Bool

        init(from customUnit: CustomUnit) {
            self.name = customUnit.name
            self.icon = customUnit.icon
            self.isQuantifiable = customUnit.isQuantifiable
            self.isSystem = customUnit.isSystem
        }
    }

    /// Exportable format for TaskTemplate
    struct ExportableTemplate: Codable {
        let name: String
        let defaultUnit: String // UnitType raw value
        let defaultProductivityRate: Double?
        let minQuantity: Double?
        let maxQuantity: Double?
        let customUnit: ExportableCustomUnit? // Related custom unit

        init(from template: TaskTemplate) {
            self.name = template.name
            self.defaultUnit = template.defaultUnit.rawValue
            self.defaultProductivityRate = template.defaultProductivityRate
            self.minQuantity = template.minQuantity
            self.maxQuantity = template.maxQuantity
            self.customUnit = template.customUnit.map { ExportableCustomUnit(from: $0) }
        }
    }

    /// Container format with version info
    struct ExportContainer: Codable {
        let version: Int = 1 // Format version for future compatibility
        let exportDate: Date
        let templates: [ExportableTemplate]

        static let fileExtension = "todotemplate"
        static let mimeType = "application/json"
    }

    // MARK: - Export Methods

    /// Export all templates to JSON data
    static func exportTemplates(_ templates: [TaskTemplate]) throws -> Data {
        let exportableTemplates = templates.map { ExportableTemplate(from: $0) }
        let container = ExportContainer(
            exportDate: Date(),
            templates: exportableTemplates
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(container)
    }

    /// Export templates to a file URL
    static func exportTemplates(_ templates: [TaskTemplate], to url: URL) throws {
        let data = try exportTemplates(templates)
        try data.write(to: url, options: .atomic)
    }

    /// Generate suggested filename for export
    static func suggestedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "templates-\(dateString).\(ExportContainer.fileExtension)"
    }
}
