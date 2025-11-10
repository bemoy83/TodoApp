import SwiftUI
import SwiftData

/// Sheet for editing an existing time entry
struct EditTimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var entry: TimeEntry

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var personnelCount: Int

    init(entry: TimeEntry) {
        self.entry = entry
        _startDate = State(initialValue: entry.startTime)
        _endDate = State(initialValue: entry.endTime ?? Date())
        _personnelCount = State(initialValue: entry.personnelCount)
    }

    private var isValid: Bool {
        TimeEntryManager.isValid(start: startDate, end: endDate)
    }

    var body: some View {
        NavigationStack {
            TimeEntryForm(
                startDate: $startDate,
                endDate: $endDate,
                personnelCount: $personnelCount,
                showFooter: false
            )
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
        guard isValid else { return }

        withAnimation {
            entry.startTime = startDate
            entry.endTime = endDate
            entry.personnelCount = personnelCount
            try? modelContext.save()
        }

        HapticManager.success()
        dismiss()
    }
}
