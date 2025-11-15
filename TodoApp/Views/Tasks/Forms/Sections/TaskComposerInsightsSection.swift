import SwiftUI

/// Insights & Recommendations section for TaskComposerForm
/// Provides cross-section intelligence by analyzing multiple inputs together
/// Shows personnel recommendations, deadline warnings, and productivity insights
struct TaskComposerInsightsSection: View {
    // Estimate data
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var effortHours: Double

    // Personnel data
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    // Due date data
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date

    // Quantity data (for productivity insights)
    @Binding var taskType: String?
    @Binding var productivityRate: Double?
    let historicalProductivity: Double? // Optional - may not always be available

    @State private var showInsights = false

    var body: some View {
        Section {
            Toggle("Insights & Recommendations", isOn: $showInsights)

            if showInsights {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Debug info
                    debugInfoView

                    if let recommendation = personnelRecommendation {
                        personnelRecommendationView(recommendation)
                    }

                    if let warning = deadlineWarning {
                        deadlineWarningView(warning)
                    }

                    if let insight = productivityInsight {
                        productivityInsightView(insight)
                    }

                    if personnelRecommendation == nil && deadlineWarning == nil && productivityInsight == nil {
                        noInsightsView
                    }
                }
            }
        }
    }

    // MARK: - Debug View

    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG INFO")
                .font(.caption2)
                .foregroundStyle(.red)
            Text("Mode: \(unifiedEstimationMode.rawValue)")
                .font(.caption2)
            Text("Estimate: \(estimateHours)h \(estimateMinutes)m")
                .font(.caption2)
            Text("Effort: \(effortHours) person-hours")
                .font(.caption2)
            Text("Has Due Date: \(hasDueDate ? "Yes" : "No")")
                .font(.caption2)
            if hasDueDate {
                let calendar = Calendar.current
                let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                Text("Days until deadline: \(days)")
                    .font(.caption2)
                    .foregroundStyle(days > 0 ? .green : .red)
            }
            Text("Due Date: \(dueDate.formatted())")
                .font(.caption2)
            Text("Has Personnel: \(hasPersonnel ? "Yes" : "No")")
                .font(.caption2)
            Text("Personnel Count: \(expectedPersonnelCount?.description ?? "nil")")
                .font(.caption2)

            Divider()

            // Show why insights aren't appearing
            Text("INSIGHT CHECKS:")
                .font(.caption2)
                .foregroundStyle(.orange)

            if unifiedEstimationMode == .effort && effortHours > 0 && hasDueDate {
                let calendar = Calendar.current
                let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                let recommended = Int(ceil(effortHours / (Double(days) * 8.0)))
                let current = expectedPersonnelCount ?? 1
                Text("Personnel: Recommended=\(recommended), Current=\(current), Match=\(recommended == current)")
                    .font(.caption2)
                    .foregroundStyle(recommended == current ? .orange : .green)
            }

            let totalMinutes = (estimateHours * 60) + estimateMinutes
            if hasDueDate && totalMinutes > 0 {
                let calendar = Calendar.current
                let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                if days > 0 {
                    let personnel = expectedPersonnelCount ?? 1
                    let availableHours = Double(days) * 8.0 * Double(personnel)
                    let estimateHrs = Double(totalMinutes) / 60.0
                    let util = (estimateHrs / availableHours) * 100
                    Text("Deadline: Util=\(Int(util))%, Threshold=80%")
                        .font(.caption2)
                        .foregroundStyle(util > 80 ? .green : .orange)
                }
            }

            Divider()
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Insight Calculations

    /// Personnel recommendation based on effort and deadline
    private var personnelRecommendation: PersonnelRecommendation? {
        // Only recommend if in effort mode with effort set and deadline exists
        guard unifiedEstimationMode == .effort,
              effortHours > 0,
              hasDueDate,
              dueDate > Date() else {
            return nil
        }

        let now = Date()
        let calendar = Calendar.current
        let daysUntilDeadline = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0

        guard daysUntilDeadline > 0 else { return nil }

        // Assume 8 working hours per day
        let hoursPerDay = 8.0
        let totalAvailableHours = Double(daysUntilDeadline) * hoursPerDay

        // Calculate recommended personnel
        let recommendedPersonnel = Int(ceil(effortHours / totalAvailableHours))
        let currentPersonnel = expectedPersonnelCount ?? 1

        // Only show if recommendation differs from current
        guard recommendedPersonnel != currentPersonnel else { return nil }

        return PersonnelRecommendation(
            recommended: recommendedPersonnel,
            current: currentPersonnel,
            effortHours: effortHours,
            daysAvailable: daysUntilDeadline,
            hoursPerDay: hoursPerDay
        )
    }

    /// Deadline feasibility warning
    private var deadlineWarning: DeadlineWarning? {
        guard hasDueDate,
              dueDate > Date() else {
            return nil
        }

        let totalEstimateMinutes = (estimateHours * 60) + estimateMinutes
        guard totalEstimateMinutes > 0 else { return nil }

        let calendar = Calendar.current
        let daysUntilDeadline = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0

        guard daysUntilDeadline > 0 else { return nil }

        let hoursPerDay = 8.0
        let personnel = expectedPersonnelCount ?? 1
        let totalAvailableHours = Double(daysUntilDeadline) * hoursPerDay * Double(personnel)
        let estimateHours = Double(totalEstimateMinutes) / 60.0

        // Warn if estimate exceeds 80% of available time
        let utilizationPercent = (estimateHours / totalAvailableHours) * 100

        if utilizationPercent > 100 {
            return DeadlineWarning(
                type: .impossible,
                estimateHours: estimateHours,
                availableHours: totalAvailableHours,
                utilizationPercent: utilizationPercent,
                daysAvailable: daysUntilDeadline,
                personnel: personnel
            )
        } else if utilizationPercent > 80 {
            return DeadlineWarning(
                type: .tight,
                estimateHours: estimateHours,
                availableHours: totalAvailableHours,
                utilizationPercent: utilizationPercent,
                daysAvailable: daysUntilDeadline,
                personnel: personnel
            )
        }

        return nil
    }

    /// Productivity insight for quantity mode
    private var productivityInsight: ProductivityInsight? {
        guard let historical = historicalProductivity,
              let current = productivityRate,
              taskType != nil,
              current != historical else {
            return nil
        }

        let percentDifference = ((current - historical) / historical) * 100

        // Only show if difference is significant (>10%)
        guard abs(percentDifference) > 10 else { return nil }

        return ProductivityInsight(
            historical: historical,
            current: current,
            percentDifference: percentDifference
        )
    }

    // MARK: - Insight Views

    private func personnelRecommendationView(_ recommendation: PersonnelRecommendation) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                Text("Personnel Recommendation")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.orange)

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Based on:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "briefcase.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Effort: \(String(format: "%.1f", recommendation.effortHours)) person-hours")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Deadline: \(recommendation.daysAvailable) \(recommendation.daysAvailable == 1 ? "day" : "days") (\(Int(recommendation.hoursPerDay))h/day)")
                        .font(.caption)
                }
            }
            .padding(.leading, DesignSystem.Spacing.xs)

            Divider()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.orange)

                Text("Recommend **\(recommendation.recommended) \(recommendation.recommended == 1 ? "person" : "people")** to complete on time")
                    .font(.subheadline)
            }

            Button {
                expectedPersonnelCount = recommendation.recommended
                hasPersonnel = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Use \(recommendation.recommended) \(recommendation.recommended == 1 ? "Person" : "People")")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }

    private func deadlineWarningView(_ warning: DeadlineWarning) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: warning.type == .impossible ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .font(.subheadline)
                Text(warning.type == .impossible ? "Deadline Not Feasible" : "Tight Deadline")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(warning.type == .impossible ? .red : .orange)

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Estimate: \(String(format: "%.1f", warning.estimateHours))h")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Available: \(String(format: "%.1f", warning.availableHours))h (\(warning.daysAvailable) days × \(warning.personnel) \(warning.personnel == 1 ? "person" : "people"))")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "gauge.high")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Utilization: \(Int(warning.utilizationPercent))%")
                        .font(.caption)
                }
            }
            .padding(.leading, DesignSystem.Spacing.xs)

            Divider()

            if warning.type == .impossible {
                Text("⚠️ Estimate exceeds available time. Consider adding more personnel or extending the deadline.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("⚠️ Very tight timeline with little buffer for unexpected issues.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background((warning.type == .impossible ? Color.red : Color.orange).opacity(0.05))
        .cornerRadius(8)
    }

    private func productivityInsightView(_ insight: ProductivityInsight) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: insight.percentDifference > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                    .font(.subheadline)
                Text("Productivity Insight")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.blue)

            Divider()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: insight.percentDifference > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(insight.percentDifference > 0 ? .green : .orange)

                if insight.percentDifference > 0 {
                    Text("Expected productivity is **\(Int(abs(insight.percentDifference)))% higher** than your historical average.")
                        .font(.subheadline)
                } else {
                    Text("Expected productivity is **\(Int(abs(insight.percentDifference)))% lower** than your historical average.")
                        .font(.subheadline)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Historical")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", insight.historical))
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", insight.current))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.leading, DesignSystem.Spacing.md)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private var noInsightsView: some View {
        TaskInlineInfoRow(
            icon: "info.circle",
            message: "Insights will appear here based on your task configuration",
            style: .info
        )
    }
}

// MARK: - Data Models

private struct PersonnelRecommendation {
    let recommended: Int
    let current: Int
    let effortHours: Double
    let daysAvailable: Int
    let hoursPerDay: Double
}

private struct DeadlineWarning {
    enum WarningType {
        case tight      // 80-100% utilization
        case impossible // >100% utilization
    }

    let type: WarningType
    let estimateHours: Double
    let availableHours: Double
    let utilizationPercent: Double
    let daysAvailable: Int
    let personnel: Int
}

private struct ProductivityInsight {
    let historical: Double
    let current: Double
    let percentDifference: Double
}
