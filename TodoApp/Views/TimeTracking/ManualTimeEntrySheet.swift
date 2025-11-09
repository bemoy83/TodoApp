import SwiftUI
import SwiftData

/// Sheet for manually creating a new time entry
struct ManualTimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: Task

    @State private var startDate = Date().addingTimeInterval(-3600) // Default: 1 hour ago
    @State private var endDate = Date()
    @State private var personnelCount: Int
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    init(task: Task) {
        self.task = task
        // Pre-fill with task's expected personnel count
        _personnelCount = State(initialValue: task.expectedPersonnelCount)
    }

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

    private var personHours: Double {
        (duration / 3600) * Double(personnelCount)
    }

    private var formattedPersonHours: String {
        String(format: "%.1f", personHours)
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
                    Stepper(value: $personnelCount, in: 1...20) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.secondary)
                            Text("Personnel")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(personnelCount)")
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Crew Size")
                } footer: {
                    Text("Number of people working during this time")
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

                    if personnelCount > 1 {
                        HStack {
                            Text("Person-Hours")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedPersonHours + " hrs")
                                .fontWeight(.semibold)
                                .foregroundStyle(DesignSystem.Colors.info)
                        }
                    }
                } header: {
                    Text("Calculated Time")
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
            personnelCount: personnelCount,
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
