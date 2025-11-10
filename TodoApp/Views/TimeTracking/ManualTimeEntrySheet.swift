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

    init(task: Task) {
        self.task = task
        // Pre-fill with task's expected personnel count (defaults to 1 if not set)
        _personnelCount = State(initialValue: task.expectedPersonnelCount ?? 1)
    }

    private var isValid: Bool {
        TimeEntryManager.isValid(start: startDate, end: endDate)
    }

    var body: some View {
        NavigationStack {
            TimeEntryForm(
                startDate: $startDate,
                endDate: $endDate,
                personnelCount: $personnelCount
            )
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
        guard isValid else { return }

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
