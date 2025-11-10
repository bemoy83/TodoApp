import SwiftUI

/// Handles effort-based estimation input with real-time duration calculation
/// and personnel recommendations.
struct EffortInputSection: View {
    @Binding var effortHours: Double
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?
    @Binding var hasDueDate: Bool
    let dueDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Effort input field
            HStack {
                Text("Total Work Effort")
                    .font(.subheadline)
                Spacer()
                TextField("0", value: $effortHours, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("person-hours")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Show calculated duration if personnel is set
            if effortHours > 0 && hasPersonnel {
                calculatedDurationDisplay
            }

            // Show personnel recommendation if deadline set
            if hasDueDate && effortHours > 0 {
                PersonnelRecommendationView(
                    effortHours: effortHours,
                    deadline: dueDate,
                    currentSelection: expectedPersonnelCount,
                    onSelect: { count in
                        hasPersonnel = true
                        expectedPersonnelCount = count
                    }
                )
            } else if effortHours > 0 {
                // Prompt to set deadline
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Set a deadline to see personnel recommendations")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Subviews

    private var calculatedDurationDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            let personnel = expectedPersonnelCount ?? 1
            let durationHours = effortHours / Double(personnel)
            Text("Duration: \(String(format: "%.1f", durationHours)) hours")
                .font(.caption)
            Text("(with \(personnel) \(personnel == 1 ? "person" : "people"))")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}
