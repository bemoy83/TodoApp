import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for exporting templates
struct TemplateExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let templates: [TaskTemplate]

    init(templates: [TaskTemplate]) {
        self.templates = templates
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export-only document
        self.templates = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try TemplateExporter.exportTemplates(templates)
        return FileWrapper(regularFileWithContents: data)
    }
}
