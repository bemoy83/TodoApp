import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Sheet for generating formatted reports from templates
struct ReportTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allTasks: [Task]
    @Query private var allProjects: [Project]
    @Query private var allTimeEntries: [TimeEntry]

    @State private var selectedTemplate: ReportTemplate = .weeklySummary
    @State private var selectedFormat: ReportFormat = .markdown
    @State private var selectedRange: ReportData.DateRange = .lastWeek
    @State private var selectedProject: Project?
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()

    @State private var showingShareSheet = false
    @State private var reportFileURL: URL?
    @State private var isGenerating = false

    private var sortedProjects: [Project] {
        allProjects.sorted { $0.title < $1.title }
    }

    private var availableFormats: [ReportFormat] {
        selectedTemplate.supportedFormats
    }

    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        switch selectedRange {
        case .lastWeek:
            return "Last 7 days"
        case .lastMonth:
            return "Last 30 days"
        case .lastThreeMonths:
            return "Last 3 months"
        case .allTime:
            return "All data"
        case .custom:
            return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }

    private var canGenerate: Bool {
        // Project performance requires a project selection
        if selectedTemplate.requiresProjectSelection && selectedProject == nil {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Template Selection
                Section {
                    Picker("Report Type", selection: $selectedTemplate) {
                        ForEach(ReportTemplate.allCases) { template in
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.rawValue)
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: template.icon)
                            }
                            .tag(template)
                        }
                    }
                    .onChange(of: selectedTemplate) { _, newValue in
                        // Reset project selection when template changes
                        if !newValue.requiresProjectSelection {
                            selectedProject = nil
                        }
                        // Ensure selected format is supported
                        if !newValue.supportedFormats.contains(selectedFormat) {
                            selectedFormat = newValue.supportedFormats.first ?? .markdown
                        }
                    }
                } header: {
                    Text("Report Template")
                }

                // Format Selection
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(availableFormats) { format in
                            Label(format.rawValue, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Output Format")
                } footer: {
                    Text(formatDescription)
                }

                // Date Range
                Section {
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(ReportData.DateRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }

                    if selectedRange == .custom {
                        DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Date Range")
                } footer: {
                    Text(dateRangeDescription)
                }

                // Project Selection (conditional)
                if selectedTemplate.requiresProjectSelection || selectedTemplate == .weeklySummary || selectedTemplate == .monthlySummary {
                    Section {
                        Picker("Project", selection: $selectedProject) {
                            if !selectedTemplate.requiresProjectSelection {
                                Text("All Projects").tag(nil as Project?)
                            }
                            ForEach(sortedProjects) { project in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: project.color))
                                        .frame(width: 12, height: 12)
                                    Text(project.title)
                                }
                                .tag(project as Project?)
                            }
                        }
                    } header: {
                        Text(selectedTemplate.requiresProjectSelection ? "Select Project" : "Filter by Project")
                    } footer: {
                        if selectedTemplate.requiresProjectSelection {
                            Text("This report type requires a project selection")
                                .foregroundStyle(DesignSystem.Colors.error)
                        }
                    }
                }

                // Preview
                Section {
                    HStack {
                        Image(systemName: selectedTemplate.icon)
                            .foregroundStyle(.secondary)
                        Text("Report Type")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedTemplate.rawValue)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: selectedFormat.icon)
                            .foregroundStyle(.secondary)
                        Text("Format")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedFormat.rawValue)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Period")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dateRangeDescription)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                } header: {
                    Text("Report Preview")
                }
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generateAndShareReport()
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Label("Generate", systemImage: "doc.badge.plus")
                        }
                    }
                    .disabled(!canGenerate || isGenerating)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = reportFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var formatDescription: String {
        switch selectedFormat {
        case .markdown:
            return "Formatted text with headings, tables, and bullet points (.md)"
        case .plainText:
            return "Simple text format, easy to read (.txt)"
        case .csv:
            return "Spreadsheet-compatible data format (.csv)"
        }
    }

    // MARK: - Report Generation

    private func generateAndShareReport() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let reportData = ReportData(
                template: selectedTemplate,
                format: selectedFormat,
                dateRange: selectedRange,
                customStartDate: customStartDate,
                customEndDate: customEndDate,
                selectedProject: selectedProject,
                tasks: allTasks,
                projects: allProjects,
                timeEntries: allTimeEntries
            )

            let reportContent = ReportGenerator.generate(from: reportData)

            // Create file name
            let templateName = selectedTemplate.rawValue.replacingOccurrences(of: " ", with: "_")
            let timestamp = Date().ISO8601Format()
            let fileName = "TodoApp_\(templateName)_\(timestamp).\(selectedFormat.fileExtension)"

            // Write to temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try reportContent.write(to: fileURL, atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    self.reportFileURL = fileURL
                    self.isGenerating = false
                    self.showingShareSheet = true
                    HapticManager.success()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    print("Failed to write report: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReportTemplatesSheet()
        .modelContainer(for: [Task.self, Project.self, TimeEntry.self], inMemory: true)
}
