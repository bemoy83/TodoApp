import SwiftUI

/// Displays resource planning recommendations based on effort and deadline.
/// Shows available work hours, minimum crew size, and scenario options (Tight/Safe/Buffer).
struct PersonnelRecommendationView: View {
    let effortHours: Double
    let deadline: Date
    let currentSelection: Int?
    let onSelect: (Int) -> Void

    // MARK: - Computed Properties

    private var availableHours: Double {
        WorkHoursCalculator.calculateAvailableHours(from: Date(), to: deadline)
    }

    private var minimumPersonnel: Int {
        WorkHoursCalculator.calculateMinimumPersonnel(
            effortHours: effortHours,
            availableHours: availableHours
        )
    }

    private var scenarios: [(people: Int, hoursPerPerson: Double, status: String, icon: String)] {
        WorkHoursCalculator.generateScenarios(
            effortHours: effortHours,
            minimumPersonnel: minimumPersonnel
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                Text("Resource Planning")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 4)

            // Available time
            HStack {
                Text("Available time:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f hours", availableHours))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Minimum crew
            HStack {
                Text("Minimum crew:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(minimumPersonnel) \(minimumPersonnel == 1 ? "person" : "people")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            Divider()
                .padding(.vertical, 4)

            // Scenarios label
            Text("Scenarios:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Scenario buttons
            ForEach(scenarios, id: \.people) { scenario in
                scenarioButton(for: scenario)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - View Builders

    @ViewBuilder
    private func scenarioButton(for scenario: (people: Int, hoursPerPerson: Double, status: String, icon: String)) -> some View {
        Button {
            onSelect(scenario.people)
            HapticManager.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: scenario.icon)
                    .font(.body)
                    .foregroundStyle(scenario.people == minimumPersonnel ? .orange : .green)
                    .frame(width: 18)

                Text("\(scenario.people) \(scenario.people == 1 ? "person" : "people")")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f hrs/person", scenario.hoursPerPerson))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(scenario.status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(scenario.people == minimumPersonnel ? .orange : .green)
                }

                if currentSelection == scenario.people {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentSelection == scenario.people ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}
