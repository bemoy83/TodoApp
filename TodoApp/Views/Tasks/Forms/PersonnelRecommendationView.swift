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
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(.blue)
                Text("Resource Planning")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.blue)

            // Available time
            HStack {
                Text("Available time:")
                    .font(.caption2)
                Spacer()
                Text(String(format: "%.1f hours", availableHours))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)

            // Minimum crew
            HStack {
                Text("Minimum crew:")
                    .font(.caption2)
                Spacer()
                Text("\(minimumPersonnel) \(minimumPersonnel == 1 ? "person" : "people")")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Scenarios label
            Text("Scenarios:")
                .font(.caption)
                .fontWeight(.medium)
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
            HStack(spacing: 8) {
                Image(systemName: scenario.icon)
                    .font(.caption2)
                    .foregroundStyle(scenario.people == minimumPersonnel ? .orange : .green)
                    .frame(width: 16)

                Text("\(scenario.people) \(scenario.people == 1 ? "person" : "people")")
                    .font(.caption)

                Spacer()

                Text(String(format: "%.1f hrs/person", scenario.hoursPerPerson))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(scenario.status)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(scenario.people == minimumPersonnel ? .orange : .green)

                if currentSelection == scenario.people {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentSelection == scenario.people ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}
