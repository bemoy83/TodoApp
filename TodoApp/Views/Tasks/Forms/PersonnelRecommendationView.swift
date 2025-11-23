import SwiftUI

/// Displays resource planning recommendations based on effort and deadline.
/// Shows available work hours, minimum crew size, and scenario options (Recommended/Safe/Buffer).
/// Optionally uses historical analytics to adjust recommendations.
/// Supports working windows (start date to end date) for scheduled work.
struct PersonnelRecommendationView: View {
    let effortHours: Double
    let startDate: Date?  // Optional: when work is scheduled to start (defaults to NOW)
    let deadline: Date
    let currentSelection: Int?
    let onSelect: (Int) -> Void

    // Optional: Historical learning parameters
    let taskType: String?
    let allTasks: [Task]?

    // Initialize without historical learning or start date (backward compatible)
    init(effortHours: Double, deadline: Date, currentSelection: Int?, onSelect: @escaping (Int) -> Void) {
        self.effortHours = effortHours
        self.startDate = nil
        self.deadline = deadline
        self.currentSelection = currentSelection
        self.onSelect = onSelect
        self.taskType = nil
        self.allTasks = nil
    }

    // Initialize with historical learning (backward compatible - no start date)
    init(effortHours: Double, deadline: Date, currentSelection: Int?, taskType: String?, allTasks: [Task]?, onSelect: @escaping (Int) -> Void) {
        self.effortHours = effortHours
        self.startDate = nil
        self.deadline = deadline
        self.currentSelection = currentSelection
        self.onSelect = onSelect
        self.taskType = taskType
        self.allTasks = allTasks
    }

    // Initialize with full support (working window + historical learning)
    init(effortHours: Double, startDate: Date?, deadline: Date, currentSelection: Int?, taskType: String?, allTasks: [Task]?, onSelect: @escaping (Int) -> Void) {
        self.effortHours = effortHours
        self.startDate = startDate
        self.deadline = deadline
        self.currentSelection = currentSelection
        self.onSelect = onSelect
        self.taskType = taskType
        self.allTasks = allTasks
    }

    // MARK: - Computed Properties

    private var availableHours: Double {
        // Use start date if provided, otherwise default to NOW (backward compatible)
        WorkHoursCalculator.calculateAvailableHours(from: startDate ?? Date(), to: deadline)
    }

    private var analytics: TaskTypeAnalytics? {
        guard let taskType = taskType, let allTasks = allTasks else { return nil }
        return TaskTypeAnalytics.calculate(for: taskType, from: allTasks)
    }

    private var usesAnalytics: Bool {
        analytics?.isSignificant ?? false
    }

    private var scenarios: [(people: Int, hoursPerPerson: Double, status: String, icon: String, contextMessage: String?)] {
        if usesAnalytics {
            return WorkHoursCalculator.generateScenariosWithAnalytics(
                effortHours: effortHours,
                availableHours: availableHours,
                analytics: analytics
            )
        } else {
            // Convert old format to new format
            let oldScenarios = WorkHoursCalculator.generateScenarios(
                effortHours: effortHours,
                minimumPersonnel: WorkHoursCalculator.calculateMinimumPersonnel(
                    effortHours: effortHours,
                    availableHours: availableHours
                )
            )
            return oldScenarios.map { (people: $0.people, hoursPerPerson: $0.hoursPerPerson, status: $0.status, icon: $0.icon, contextMessage: nil) }
        }
    }

    private var minimumPersonnel: Int {
        scenarios.first?.people ?? 1
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
                Text(usesAnalytics ? "Recommended crew:" : "Minimum crew:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(minimumPersonnel) \(minimumPersonnel == 1 ? "person" : "people")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(usesAnalytics ? .green : .orange)
            }

            // Analytics context
            if usesAnalytics, let analytics = analytics {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("Based on \(analytics.sampleSize) completed \(analytics.taskType) \(analytics.sampleSize == 1 ? "task" : "tasks")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    private func scenarioButton(for scenario: (people: Int, hoursPerPerson: Double, status: String, icon: String, contextMessage: String?)) -> some View {
        Button {
            onSelect(scenario.people)
            HapticManager.selection()
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: scenario.icon)
                        .font(.body)
                        .foregroundStyle(scenario.people == minimumPersonnel ? (usesAnalytics ? .green : .orange) : .green)
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
                            .foregroundStyle(scenario.people == minimumPersonnel ? (usesAnalytics ? .green : .orange) : .green)
                    }

                    if currentSelection == scenario.people {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }

                // Context message (e.g., "Installation tasks are typically 18% over estimate")
                if let contextMessage = scenario.contextMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text(contextMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
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
