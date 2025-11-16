import SwiftUI

/// View model for quantity-based estimation calculator
/// Extracts calculation logic from the view layer
@Observable
class TaskComposerCalculatorViewModel {
    // Inputs
    var quantity: String = ""
    var unit: UnitType = .none
    var taskType: String?
    var calculationMode: TaskEstimator.QuantityCalculationMode = .calculateDuration
    var productivityRate: Double?
    var historicalProductivity: Double?

    // State
    var isProductivityOverrideExpanded = false

    // MARK: - Computed Properties

    /// Parsed quantity value
    var quantityValue: Double? {
        Double(quantity)
    }

    /// Whether the calculator has valid inputs
    var hasValidInputs: Bool {
        guard let qty = quantityValue, qty > 0,
              let rate = productivityRate, rate > 0 else {
            return false
        }
        return true
    }

    // MARK: - Calculation Methods

    /// Calculate duration from quantity and personnel
    func calculateDuration(personnel: Int) -> (hours: Int, minutes: Int)? {
        guard hasValidInputs,
              let qty = quantityValue,
              let rate = productivityRate,
              personnel > 0 else {
            return nil
        }

        let durationHours = (qty / rate) / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        return (hours, minutes)
    }

    /// Calculate personnel from quantity and duration
    func calculatePersonnel(durationHours: Int, durationMinutes: Int) -> Int? {
        guard hasValidInputs,
              let qty = quantityValue,
              let rate = productivityRate else {
            return nil
        }

        let totalDurationHours = Double(durationHours) + (Double(durationMinutes) / 60.0)
        guard totalDurationHours > 0 else { return nil }

        let personnel = Int(ceil((qty / rate) / totalDurationHours))
        return max(1, personnel)
    }

    /// Get formatted productivity rate string
    func formattedProductivityRate() -> String {
        guard let rate = productivityRate else { return "" }
        return String(format: "%.1f", rate)
    }

    /// Get formatted historical productivity string
    func formattedHistoricalProductivity() -> String {
        guard let rate = historicalProductivity else { return "" }
        return String(format: "%.1f", rate)
    }

    // MARK: - Update Methods

    /// Update productivity rate from template selection
    func updateFromTemplate(_ template: TaskTemplate, tasks: [Task]) {
        unit = template.defaultUnit

        // Store historical productivity separately for comparison
        historicalProductivity = TemplateManager.getHistoricalProductivity(
            for: template.name,
            unit: template.defaultUnit,
            from: tasks
        )

        // Priority order (goal-oriented approach):
        // 1. Template's expected productivity rate (if set) - the goal
        // 2. Historical data (if available) - fallback
        // 3. Unit's default productivity rate (fallback)
        productivityRate = template.defaultProductivityRate
            ?? historicalProductivity
            ?? template.defaultUnit.defaultProductivityRate
    }

    /// Reset override expansion state when mode changes
    func resetOverrideState() {
        isProductivityOverrideExpanded = false
    }
}
