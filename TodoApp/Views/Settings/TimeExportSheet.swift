import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Sheet for exporting time tracking data to CSV
struct TimeExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allTasks: [Task]
    @Query private var allProjects: [Project]
    @Query private var allTimeEntries: [TimeEntry]

    @State private var selectedRange: DateRange = .allTime
    @State private var selectedProject: Project?
    @State private var includeSubtasks: Bool = true
    @State private var showingShareSheet = false
    @State private var csvFileURL: URL?
    @State private var isGenerating = false

    enum DateRange: String, CaseIterable, Identifiable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        case allTime = "All Time"
        case custom = "Custom Range"

        var id: String { rawValue }
    }

    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()

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
            return "All time entries"
        case .custom:
            return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }

    private var entriesCount: Int {
        filteredTimeEntries.count
    }

    private var filteredTimeEntries: [TimeEntry] {
        var entries = allTimeEntries.filter { $0.endTime != nil } // Only completed entries

        // Filter by date range
        let (startDate, endDate) = getDateRange()
        entries = entries.filter { entry in
            guard let end = entry.endTime else { return false }
            return end >= startDate && end <= endDate
        }

        // Filter by project if selected
        if let project = selectedProject {
            entries = entries.filter { $0.task?.project?.id == project.id }
        }

        return entries.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(DateRange.allCases) { range in
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

                Section {
                    Picker("Project", selection: $selectedProject) {
                        Text("All Projects").tag(nil as Project?)
                        ForEach(allProjects.sorted { $0.name < $1.name }) { project in
                            Text(project.name).tag(project as Project?)
                        }
                    }
                } header: {
                    Text("Filter by Project")
                }

                Section {
                    Toggle("Include Subtask Time", isOn: $includeSubtasks)
                } footer: {
                    Text("When enabled, time tracked on subtasks will be included in the export")
                }

                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        Text("Time Entries")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(entriesCount)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Format")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("CSV")
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("Export Preview")
                }
            }
            .navigationTitle("Export Time Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generateAndShareCSV()
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(entriesCount == 0 || isGenerating)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = csvFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func getDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedRange {
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .lastThreeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        case .custom:
            return (customStartDate, customEndDate)
        }
    }

    private func generateAndShareCSV() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let csvContent = generateCSV()

            // Create temporary file
            let fileName = "TodoApp_TimeExport_\(Date().ISO8601Format()).csv"
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)

            do {
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    self.csvFileURL = fileURL
                    self.isGenerating = false
                    self.showingShareSheet = true
                    HapticManager.success()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    print("Failed to write CSV: \(error)")
                }
            }
        }
    }

    private func generateCSV() -> String {
        var csv = "Task,Project,Start Time,End Time,Duration (minutes),Duration (hours),Date,Notes\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateStyle = .medium
        dateOnlyFormatter.timeStyle = .none

        for entry in filteredTimeEntries {
            guard let endTime = entry.endTime,
                  let task = entry.task else { continue }

            let taskName = task.title.replacingOccurrences(of: "\"", with: "\"\"") // Escape quotes
            let projectName = task.project?.name.replacingOccurrences(of: "\"", with: "\"\"") ?? "No Project"
            let startTimeStr = dateFormatter.string(from: entry.startTime)
            let endTimeStr = dateFormatter.string(from: endTime)
            let dateStr = dateOnlyFormatter.string(from: entry.startTime)

            let duration = endTime.timeIntervalSince(entry.startTime)
            let minutes = Int(duration / 60)
            let hours = String(format: "%.2f", duration / 3600)

            let notes = task.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            csv += "\"\(taskName)\",\"\(projectName)\",\"\(startTimeStr)\",\"\(endTimeStr)\",\(minutes),\(hours),\"\(dateStr)\",\"\(notes)\"\n"
        }

        return csv
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
