import SwiftUI
import SwiftData

/// Sheet for editing an existing time entry
struct EditTimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var entry: TimeEntry

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    init(entry: TimeEntry) {
        self.entry = entry
        _startDate = State(initialValue: entry.startTime)
        _endDate = State(initialValue: entry.endTime ?? Date())
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
                }

                Section {
                    HStack {
                        Text("Duration")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedDuration)
                            .fontWeight(.medium)
                            .foregroundStyle(isValid ? .primary : .red)
                    }
                } header: {
                    Text("Calculated Duration")
                }

                if !isValid {
                    Section {
                        Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveChanges() {
        guard isValid else {
            validationMessage = "End time must be after start time"
            showingValidationError = true
            return
        }

        withAnimation {
            entry.startTime = startDate
            entry.endTime = endDate
            try? modelContext.save()
        }

        HapticManager.success()
        dismiss()
    }
}
