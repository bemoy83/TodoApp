import Foundation
import Observation

/// ViewModel for quantity-based estimation calculations
/// Handles all business logic for quantity mode, separating it from view code
@Observable
final class QuantityCalculationViewModel {
    // MARK: - Input State

    var taskType: String?
    var unit: UnitType = .none
    var quantity: String = ""
    var calculationMode: TaskEstimator.QuantityCalculationMode = .calculateDuration
    var productivityRate: Double?
    var estimateHours: Int = 0
    var estimateMinutes: Int = 0
    var expectedPersonnelCount: Int?

    // MARK: - Internal State

    var historicalProductivity: Double?
    var expectedProductivity: Double?
    var productivityMode: ProductivityMode = .expected
    var customProductivityInput: String = ""

    // MARK: - Dependencies

    private let templates: [TaskTemplate]
    private let allTasks: [Task]

    // MARK: - Initialization

    init(templates: [TaskTemplate], allTasks: [Task]) {
        self.templates = templates
        self.allTasks = allTasks
    }

    // MARK: - Computed Properties

    /// Calculate effort hours from quantity and productivity
    var calculatedEffort: Double {
        let quantityValue = Double(quantity) ?? 0
        let rate = productivityRate ?? historicalProductivity ?? 0
        guard quantityValue > 0, rate > 0 else { return 0 }

        // Effort = Quantity ÷ Productivity Rate (gives us person-hours)
        return quantityValue / rate
    }

    /// Whether to show personnel recommendations
    func shouldShowPersonnelRecommendation(hasDueDate: Bool) -> Bool {
        guard hasDueDate, calculatedEffort > 0 else { return false }
        return calculationMode == .calculateDuration
    }

    /// Total duration in seconds
    var totalDurationSeconds: Int {
        (estimateHours * 3600) + (estimateMinutes * 60)
    }

    /// Formatted duration string
    var formattedDuration: String {
        let totalMinutes = (estimateHours * 60) + estimateMinutes
        if totalMinutes == 0 {
            return "Not set"
        }

        if estimateHours > 0 && estimateMinutes > 0 {
            return "\(estimateHours)h \(estimateMinutes)m"
        } else if estimateHours > 0 {
            return "\(estimateHours)h"
        } else {
            return "\(estimateMinutes)m"
        }
    }

    /// Formatted quantity string
    var formattedQuantity: String {
        if quantity.isEmpty || quantity == "0" {
            return "Not set"
        }
        return "\(quantity) \(unit.displayName)"
    }

    // MARK: - Business Logic

    /// Calculate duration from quantity, productivity, and personnel
    func calculateDuration(personnelCount: Int) {
        guard calculationMode == .calculateDuration,
              let qty = Double(quantity), qty > 0,
              let rate = productivityRate, rate > 0,
              personnelCount > 0 else {
            return
        }

        let durationHours = (qty / rate) / Double(personnelCount)
        let totalSeconds = Int(durationHours * 3600)

        estimateHours = totalSeconds / 3600
        estimateMinutes = (totalSeconds % 3600) / 60
    }

    /// Calculate personnel from quantity, productivity, and duration
    func calculatePersonnel() -> Int? {
        guard calculationMode == .calculatePersonnel,
              let qty = Double(quantity), qty > 0,
              let rate = productivityRate, rate > 0,
              totalDurationSeconds > 0 else {
            return nil
        }

        let durationHours = Double(totalDurationSeconds) / 3600.0
        let personnel = Int(ceil((qty / rate) / durationHours))
        return max(1, personnel)
    }

    /// Handle task type change - load productivity rates
    func handleTaskTypeChange(_ newTaskType: String?) {
        guard let selectedTaskType = newTaskType,
              let template = templates.first(where: { $0.name == selectedTaskType }) else {
            return
        }

        unit = template.defaultUnit

        // Store historical and expected productivity separately
        historicalProductivity = TemplateManager.getHistoricalProductivity(
            for: selectedTaskType,
            unit: template.defaultUnit,
            from: allTasks
        )
        expectedProductivity = template.defaultProductivityRate

        // Reset to expected mode for each new task (goal-oriented)
        productivityMode = .expected
        customProductivityInput = ""

        // Priority order (goal-oriented approach):
        // 1. Template's expected productivity rate (if set) - the goal
        // 2. Historical data (if available) - fallback
        // 3. CustomUnit's default productivity rate (fallback)
        productivityRate = template.defaultProductivityRate
            ?? historicalProductivity
            ?? template.customUnit?.defaultProductivityRate
            ?? template.defaultUnit.defaultProductivityRate
    }

    /// Initialize from existing task data
    func initialize(
        existingTaskType: String?,
        existingQuantity: String,
        existingProductivityRate: Double?,
        existingUnit: UnitType
    ) {
        self.taskType = existingTaskType
        self.quantity = existingQuantity
        self.unit = existingUnit

        if let currentTaskType = existingTaskType {
            let existingCustomRate = existingProductivityRate

            // Initialize template and historical rates
            handleTaskTypeChange(currentTaskType)

            // Restore custom productivity rate if it differs from defaults
            if let customRate = existingCustomRate, customRate > 0 {
                let defaultRate = expectedProductivity ?? historicalProductivity ?? unit.defaultProductivityRate ?? 0.0

                if abs(customRate - defaultRate) > 0.01 {
                    // This is a saved custom rate - restore it and set mode to custom
                    productivityRate = customRate
                    productivityMode = .custom
                    customProductivityInput = String(format: "%.1f", customRate)
                }
            }
        }
    }

    /// Update productivity rate based on selected mode
    func updateProductivityRate(for mode: ProductivityMode) {
        switch mode {
        case .expected:
            if let expected = expectedProductivity {
                productivityRate = expected
            }
        case .historical:
            if let historical = historicalProductivity {
                productivityRate = historical
            }
        case .custom:
            // Parse custom rate
            if let customRate = Double(customProductivityInput), customRate > 0 {
                productivityRate = customRate
            }
        }
    }

    /// Calculate variance percentage between historical and expected
    func calculateVariance() -> (percentage: Double, isPositive: Bool)? {
        guard let historical = historicalProductivity,
              let expected = expectedProductivity,
              expected > 0 else {
            return nil
        }

        let variance = ((historical - expected) / expected) * 100
        return (abs(variance), variance > 0)
    }

    /// Validate quantity input
    func validateQuantity() -> ValidationResult<Double> {
        InputValidator.validateQuantity(quantity, unit: unit.displayName)
    }

    /// Validate productivity rate input
    func validateProductivityRate() -> ValidationResult<Double> {
        guard let rate = productivityRate else {
            return .failure(.emptyValue("Productivity rate not set"))
        }
        return InputValidator.validateProductivityRate(String(rate), unit: unit.displayName)
    }
}

// MARK: - Calculation Summary

extension QuantityCalculationViewModel {
    /// Get calculation summary text
    func calculationSummary(personnelCount: Int) -> String {
        let quantityValue = Double(quantity) ?? 0
        let rate = productivityRate ?? 1.0

        switch calculationMode {
        case .calculateDuration:
            return "\(String(format: "%.0f", quantityValue)) ÷ \(String(format: "%.1f", rate)) ÷ \(personnelCount) = \(totalDurationSeconds.formattedTime())"

        case .calculatePersonnel:
            return "\(String(format: "%.0f", quantityValue)) ÷ \(String(format: "%.1f", rate)) ÷ \(totalDurationSeconds.formattedTime()) = \(personnelCount) \(personnelCount == 1 ? "person" : "people")"

        case .manualEntry:
            return "Productivity will be calculated on task completion"
        }
    }
}
