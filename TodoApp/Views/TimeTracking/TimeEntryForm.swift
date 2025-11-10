import SwiftUI

/// Shared form component for creating/editing time entries.
/// Used by both ManualTimeEntrySheet and EditTimeEntrySheet to eliminate duplication.
struct TimeEntryForm: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var personnelCount: Int

    let showFooter: Bool

    init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        personnelCount: Binding<Int>,
        showFooter: Bool = true
    ) {
        self._startDate = startDate
        self._endDate = endDate
        self._personnelCount = personnelCount
        self.showFooter = showFooter
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        TimeEntryManager.isValid(start: startDate, end: endDate)
    }

    private var duration: TimeInterval {
        TimeEntryManager.calculateDuration(start: startDate, end: endDate)
    }

    private var formattedDuration: String {
        TimeEntryManager.formatDuration(duration, showSeconds: true)
    }

    private var personHours: Double {
        TimeEntryManager.calculatePersonHours(durationSeconds: duration, personnelCount: personnelCount)
    }

    private var formattedPersonHours: String {
        String(format: "%.1f", personHours)
    }

    // MARK: - Body

    var body: some View {
        Form {
            // Time Range Section
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
                if showFooter {
                    Text("Add time that wasn't tracked automatically")
                }
            }

            // Personnel Section
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

            // Calculated Time Section
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

            // Validation Error Section
            if !isValid {
                Section {
                    Label(
                        TimeEntryManager.validationErrorMessage,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(Color.red)
                }
            }
        }
    }
}
