import Foundation
import Observation

/// ViewModel for productivity rate management
/// Demonstrates testable business logic separation from view code
@Observable
final class ProductivityRateViewModel {
    // MARK: - State

    var historicalProductivity: Double?
    var expectedProductivity: Double?
    var currentProductivity: Double?
    var productivityMode: ProductivityMode = .expected
    var customProductivityInput: String = ""

    // MARK: - Computed Properties

    /// Active productivity rate based on mode
    var activeRate: Double {
        switch productivityMode {
        case .expected:
            return expectedProductivity ?? 0
        case .historical:
            return historicalProductivity ?? 0
        case .custom:
            return Double(customProductivityInput) ?? currentProductivity ?? 0
        }
    }

    /// Whether there's a significant variance between historical and expected
    var hasSignificantVariance: Bool {
        guard let variance = calculateVariance() else { return false }
        return variance.percentage > 30
    }

    // MARK: - Business Logic

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

    /// Get variance message for UI display
    func varianceMessage() -> String? {
        guard let variance = calculateVariance() else { return nil }

        let direction = variance.isPositive ? "faster" : "slower"
        return "Historical is \(String(format: "%.0f", variance.percentage))% \(direction) than expected."
    }

    /// Update productivity rate for selected mode
    func selectMode(_ mode: ProductivityMode) {
        productivityMode = mode

        switch mode {
        case .expected:
            if let expected = expectedProductivity {
                currentProductivity = expected
            }
        case .historical:
            if let historical = historicalProductivity {
                currentProductivity = historical
            }
        case .custom:
            // Keep current or use custom input
            if let customRate = Double(customProductivityInput), customRate > 0 {
                currentProductivity = customRate
            }
        }
    }

    /// Set custom productivity rate
    func setCustomRate(_ input: String) {
        customProductivityInput = input
        if let rate = Double(input), rate > 0 {
            currentProductivity = rate
            productivityMode = .custom
        }
    }

    /// Initialize productivity rates for a task type
    func loadProductivityRates(
        expected: Double?,
        historical: Double?,
        existingCustom: Double?
    ) {
        self.expectedProductivity = expected
        self.historicalProductivity = historical

        // If there's a custom rate that differs from defaults, restore it
        if let customRate = existingCustom, customRate > 0 {
            let defaultRate = expected ?? historical ?? 0.0

            if abs(customRate - defaultRate) > 0.01 {
                currentProductivity = customRate
                productivityMode = .custom
                customProductivityInput = String(format: "%.1f", customRate)
                return
            }
        }

        // Otherwise, use expected (goal-oriented) or fallback to historical
        productivityMode = .expected
        currentProductivity = expected ?? historical
    }

    /// Format rate for display
    func formattedRate(unit: String) -> String {
        String(format: "%.1f %@/person-hr", activeRate, unit)
    }

    /// Validate current productivity rate
    func validate(unit: String) -> ValidationResult<Double> {
        guard activeRate > 0 else {
            return .failure(.emptyValue("Productivity rate not set"))
        }

        guard EstimationLimits.isValidProductivityRate(activeRate) else {
            return .failure(.outOfRange(EstimationLimits.productivityErrorMessage(for: activeRate)))
        }

        return .success(activeRate)
    }
}

// MARK: - Testable Examples

extension ProductivityRateViewModel {
    /// Create a test instance with specific rates
    static func test(expected: Double, historical: Double) -> ProductivityRateViewModel {
        let vm = ProductivityRateViewModel()
        vm.loadProductivityRates(expected: expected, historical: historical, existingCustom: nil)
        return vm
    }

    /// Example: User performing better than expected
    static var exampleFaster: ProductivityRateViewModel {
        test(expected: 10.0, historical: 13.5)  // 35% faster
    }

    /// Example: User performing slower than expected
    static var exampleSlower: ProductivityRateViewModel {
        test(expected: 10.0, historical: 7.0)  // 30% slower
    }
}
