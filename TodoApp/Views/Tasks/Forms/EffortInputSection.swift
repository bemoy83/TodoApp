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
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    Text("Set a deadline to see personnel recommendations")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Subviews

    private var calculatedDurationDisplay: some View {
        let personnel = expectedPersonnelCount ?? 1
        let durationHours = effortHours / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        return HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(totalSeconds.formattedTime())
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Text("(with \(personnel) \(personnel == 1 ? "person" : "people"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
        .padding(.top, 8)
    }
}
