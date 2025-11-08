import SwiftUI
import SwiftData

/// Sheet for manually creating a new time entry
struct ManualTimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: Task

    @State private var startDate = Date().addingTimeInterval(-3600) // Default: 1 hour ago
    @State private var endDate = Date()
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    private var isValid: Bool {
        endDate > startDate
    }

    private var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    private var formattedDuration: String {
        let seconds = Int(duration)
        return seconds.formattedTime(showSeconds: true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Start Time",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End Time",
                        selection: $endDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("Time Range")
                } footer: {
                    Text("Add time that wasn't tracked automatically")
                }

                Section {
                    HStack {
                        Text("Duration")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedDuration)
                            .fontWeight(.medium)
                            .foregroundStyle(isValid ? .primary : Color.red)
                    }
                } header: {
                    Text("Calculated Duration")
                }

                if !isValid {
                    Section {
                        Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .navigationTitle("Add Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createEntry()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createEntry() {
        guard isValid else {
            validationMessage = "End time must be after start time"
            showingValidationError = true
            return
        }

        let newEntry = TimeEntry(
            startTime: startDate,
            endTime: endDate,
            createdDate: Date(),
            task: task
        )

        withAnimation {
            modelContext.insert(newEntry)

            // Add to task's timeEntries array
            if task.timeEntries == nil {
                task.timeEntries = []
            }
            task.timeEntries?.append(newEntry)

            try? modelContext.save()
        }

        HapticManager.success()
        dismiss()
    }
}
