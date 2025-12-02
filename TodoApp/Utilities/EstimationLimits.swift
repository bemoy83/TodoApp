import Foundation

/// Configurable limits for estimation inputs
/// Designed for large-scale event management with high personnel counts and long durations
struct EstimationLimits {
    // MARK: - Personnel Limits

    /// Minimum personnel count
    static let minPersonnel = 1

    /// Maximum personnel count (configurable for large venue events)
    /// Default: 100 people (sufficient for major exhibition builds)
    static let maxPersonnel = 100

    /// Default personnel count when first enabled
    static let defaultPersonnel = 1

    // MARK: - Duration Limits

    /// Minimum duration in hours
    static let minDurationHours = 0

    /// Maximum duration in hours (configurable for multi-day projects)
    /// Default: 500 hours (~20 days of 24/7 work or ~60 days of 8hr shifts)
    static let maxDurationHours = 500

    /// Maximum duration in minutes (within an hour)
    static let maxDurationMinutes = 59

    // MARK: - Quantity Limits

    /// Minimum quantity value
    static let minQuantity: Double = 0.0

    /// Maximum quantity value (e.g., for carpet tiles in m²)
    /// Default: 1,000,000 (sufficient for very large venues)
    static let maxQuantity: Double = 1_000_000.0

    /// Decimal places for quantity input
    static let quantityDecimalPlaces = 2

    // MARK: - Productivity Limits

    /// Minimum productivity rate (units per person-hour)
    static let minProductivityRate: Double = 0.01

    /// Maximum productivity rate (units per person-hour)
    /// Default: 10,000 (e.g., for small lightweight items)
    static let maxProductivityRate: Double = 10_000.0

    /// Decimal places for productivity rate
    static let productivityDecimalPlaces = 2

    // MARK: - Variance Thresholds

    /// Percentage threshold for "significant" variance between historical and expected
    /// Default: 30% difference triggers warnings
    static let significantVarianceThreshold: Double = 0.30

    /// Percentage threshold for "critical" variance requiring attention
    /// Default: 50% difference triggers strong warnings
    static let criticalVarianceThreshold: Double = 0.50

    // MARK: - Validation

    /// Validate personnel count is within limits
    static func isValidPersonnel(_ count: Int) -> Bool {
        count >= minPersonnel && count <= maxPersonnel
    }

    /// Validate duration hours is within limits
    static func isValidDurationHours(_ hours: Int) -> Bool {
        hours >= minDurationHours && hours <= maxDurationHours
    }

    /// Validate quantity is within limits
    static func isValidQuantity(_ quantity: Double) -> Bool {
        quantity >= minQuantity && quantity <= maxQuantity
    }

    /// Validate productivity rate is within limits
    static func isValidProductivityRate(_ rate: Double) -> Bool {
        rate >= minProductivityRate && rate <= maxProductivityRate
    }

    /// Clamp personnel count to valid range
    static func clampPersonnel(_ count: Int) -> Int {
        max(minPersonnel, min(count, maxPersonnel))
    }

    /// Clamp duration hours to valid range
    static func clampDurationHours(_ hours: Int) -> Int {
        max(minDurationHours, min(hours, maxDurationHours))
    }

    /// Clamp quantity to valid range
    static func clampQuantity(_ quantity: Double) -> Double {
        max(minQuantity, min(quantity, maxQuantity))
    }

    /// Clamp productivity rate to valid range
    static func clampProductivityRate(_ rate: Double) -> Double {
        max(minProductivityRate, min(rate, maxProductivityRate))
    }

    // MARK: - User-Facing Messages

    /// Error message for invalid personnel
    static func personnelErrorMessage(for count: Int) -> String {
        if count < minPersonnel {
            return "Personnel must be at least \(minPersonnel)"
        } else if count > maxPersonnel {
            return "Personnel cannot exceed \(maxPersonnel). Contact support for higher limits."
        }
        return ""
    }

    /// Error message for invalid duration
    static func durationErrorMessage(for hours: Int) -> String {
        if hours < minDurationHours {
            return "Duration must be at least 0 hours"
        } else if hours > maxDurationHours {
            return "Duration cannot exceed \(maxDurationHours) hours (\(maxDurationHours / 24) days)"
        }
        return ""
    }

    /// Error message for invalid quantity
    static func quantityErrorMessage(for quantity: Double) -> String {
        if quantity < minQuantity {
            return "Quantity must be greater than 0"
        } else if quantity > maxQuantity {
            return "Quantity cannot exceed \(String(format: "%.0f", maxQuantity))"
        }
        return ""
    }

    /// Error message for invalid productivity rate
    static func productivityErrorMessage(for rate: Double) -> String {
        if rate < minProductivityRate {
            return "Productivity rate must be at least \(String(format: "%.2f", minProductivityRate))"
        } else if rate > maxProductivityRate {
            return "Productivity rate cannot exceed \(String(format: "%.0f", maxProductivityRate))"
        }
        return ""
    }
}

// MARK: - Customizable Limits (for future settings UI)

extension EstimationLimits {
    /// Custom limits that can be configured per-user or per-organization
    struct CustomLimits {
        var maxPersonnel: Int
        var maxDurationHours: Int
        var maxQuantity: Double
        var maxProductivityRate: Double

        /// Default custom limits (uses static defaults)
        static var `default`: CustomLimits {
            CustomLimits(
                maxPersonnel: EstimationLimits.maxPersonnel,
                maxDurationHours: EstimationLimits.maxDurationHours,
                maxQuantity: EstimationLimits.maxQuantity,
                maxProductivityRate: EstimationLimits.maxProductivityRate
            )
        }

        /// Enterprise-scale limits for very large venues
        static var enterprise: CustomLimits {
            CustomLimits(
                maxPersonnel: 500,
                maxDurationHours: 2000,
                maxQuantity: 10_000_000,
                maxProductivityRate: 50_000
            )
        }
    }
}
