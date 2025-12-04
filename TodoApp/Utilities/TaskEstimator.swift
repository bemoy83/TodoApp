import Foundation

/// Pure utility for processing task input data into task properties.
/// Handles notes trimming, time estimate calculations, and effort/personnel logic.
/// Separated from views for consistency, testability, and maintainability.
struct TaskEstimator {

    // MARK: - State Container

    /// Groups all estimation-related state for cleaner binding management
    /// Used by TaskComposerForm and TaskComposerEstimateSection
    struct EstimationState {
        // Mode selection
        var mode: UnifiedEstimationMode = .duration

        // Duration mode
        var hasEstimate: Bool = false
        var estimateHours: Int = 0
        var estimateMinutes: Int = 0
        var hasCustomEstimate: Bool = false

        // Effort mode
        var effortHours: Double = 0.0
        var hasPersonnel: Bool = false
        var expectedPersonnelCount: Int? = nil

        // Quantity mode
        var taskType: String? = nil
        var unit: UnitType = .none
        var quantity: String = ""
        var quantityCalculationMode: QuantityCalculationMode = .calculateDuration
        var productivityRate: Double? = nil
        var taskTemplate: TaskTemplate? = nil

        // MARK: - Computed Properties

        /// Total estimate in seconds
        var totalEstimateSeconds: Int {
            (estimateHours * 3600) + (estimateMinutes * 60)
        }

        /// Total estimate in minutes
        var totalEstimateMinutes: Int {
            (estimateHours * 60) + estimateMinutes
        }

        /// Formatted estimate string (e.g., "2h 30m")
        var formattedEstimate: String {
            totalEstimateSeconds.formattedTime()
        }

        /// Whether a valid estimate exists
        var hasValidEstimate: Bool {
            hasEstimate && totalEstimateMinutes > 0
        }

        // MARK: - Initialization

        /// Create default state
        init() {}

        /// Create state from existing task
        init(from task: Task) {
            self.hasEstimate = task.estimatedSeconds != nil
            if let seconds = task.estimatedSeconds {
                self.estimateHours = seconds / 3600
                self.estimateMinutes = (seconds % 3600) / 60
            }
            self.hasCustomEstimate = task.hasCustomEstimate
            self.effortHours = task.effortHours ?? 0.0
            self.hasPersonnel = task.expectedPersonnelCount != nil
            self.expectedPersonnelCount = task.expectedPersonnelCount
            self.taskType = task.taskType
            self.unit = task.unit
            self.quantity = task.quantity.map { String($0) } ?? ""
            // Prioritize custom productivity rate over calculated historical rate
            self.productivityRate = task.customProductivityRate ?? task.unitsPerHour
            self.taskTemplate = task.taskTemplate
        }
    }

    // MARK: - Result Types

    /// Result of estimate calculation containing all computed values
    struct EstimateResult {
        let estimatedSeconds: Int?
        let hasCustomEstimate: Bool
        let effortHours: Double?
        let expectedPersonnelCount: Int?

        /// Empty result (no estimate set)
        static var none: EstimateResult {
            EstimateResult(
                estimatedSeconds: nil,
                hasCustomEstimate: false,
                effortHours: nil,
                expectedPersonnelCount: nil
            )
        }
    }

    // MARK: - Unified Calculator Types

    /// Main estimation mode - determines which calculator the user is using
    enum UnifiedEstimationMode: String, CaseIterable, Identifiable {
        case duration = "Duration"
        case effort = "Effort"
        case quantity = "Quantity"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .duration: return "clock"
            case .effort: return "person.2"
            case .quantity: return "chart.bar"
            }
        }
    }

    /// Quantity calculator sub-modes (only used when UnifiedEstimationMode == .quantity)
    enum QuantityCalculationMode: String, CaseIterable, Identifiable {
        case calculateDuration = "Calculate Duration"
        case calculatePersonnel = "Calculate Personnel"
        case manualEntry = "Manual Entry"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .calculateDuration:
                return "Input personnel → calculate duration"
            case .calculatePersonnel:
                return "Input duration → calculate personnel"
            case .manualEntry:
                return "Track quantity, calculate productivity on completion"
            }
        }
    }

    // MARK: - Public Methods

    /// Trim whitespace from notes and convert empty strings to nil
    /// - Parameter notes: Raw notes text from input
    /// - Returns: Trimmed notes or nil if empty
    static func processNotes(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Calculate time estimate data from input parameters
    /// - Parameters:
    ///   - estimateByEffort: Whether using effort-based mode
    ///   - effortHours: Total work effort in person-hours
    ///   - hasEstimate: Whether duration estimate is set
    ///   - estimateHours: Duration hours input
    ///   - estimateMinutes: Duration minutes input
    ///   - hasCustomEstimate: Whether estimate overrides subtask calculations
    ///   - hasPersonnel: Whether personnel count is set
    ///   - expectedPersonnelCount: Number of people assigned
    /// - Returns: EstimateResult with calculated values
    static func calculateEstimate(
        estimateByEffort: Bool,
        effortHours: Double,
        hasEstimate: Bool,
        estimateHours: Int,
        estimateMinutes: Int,
        hasCustomEstimate: Bool,
        hasPersonnel: Bool,
        expectedPersonnelCount: Int?
    ) -> EstimateResult {

        // EFFORT-BASED MODE
        if estimateByEffort && effortHours > 0 {
            let personnel = expectedPersonnelCount ?? 1
            let durationHours = effortHours / Double(personnel)
            let estimatedSeconds = Int(durationHours * 3600) // Convert to seconds

            return EstimateResult(
                estimatedSeconds: estimatedSeconds,
                hasCustomEstimate: true,
                effortHours: effortHours,
                expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
            )
        }

        // DURATION-BASED MODE
        if hasEstimate {
            let totalMinutes = (estimateHours * 60) + estimateMinutes
            let totalSeconds = totalMinutes * 60
            let finalSeconds = totalSeconds > 0 ? totalSeconds : nil

            return EstimateResult(
                estimatedSeconds: finalSeconds,
                hasCustomEstimate: hasCustomEstimate && finalSeconds != nil,
                effortHours: nil,
                expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
            )
        }

        // NO ESTIMATE
        return EstimateResult(
            estimatedSeconds: nil,
            hasCustomEstimate: false,
            effortHours: nil,
            expectedPersonnelCount: hasPersonnel ? expectedPersonnelCount : nil
        )
    }

    /// Apply estimate result to an existing task (for editing)
    /// - Parameters:
    ///   - task: Task to update
    ///   - result: EstimateResult to apply
    static func applyEstimate(to task: Task, result: EstimateResult) {
        task.estimatedSeconds = result.estimatedSeconds
        task.hasCustomEstimate = result.hasCustomEstimate
        task.effortHours = result.effortHours
        task.expectedPersonnelCount = result.expectedPersonnelCount
    }
}

// MARK: - Intelligent Calculator

extension TaskEstimator {

    /// Calculation mode for intelligent time/effort estimation
    enum CalculationMode: String, CaseIterable, Identifiable {
        case calculateDuration = "Calculate Duration"
        case calculatePersonnel = "Calculate Personnel"
        case manual = "Manual Entry"

        var id: String { rawValue }
    }

    /// Result of productivity-based calculation
    struct ProductivityCalculation {
        let mode: CalculationMode
        let quantity: Double?
        let productivityRate: Double?  // units per person-hour
        let personnelCount: Int?
        let durationSeconds: Int?

        /// Calculated duration based on quantity, productivity, and personnel
        /// Formula: duration = (quantity / rate) / personnel
        var calculatedDurationSeconds: Int? {
            guard mode == .calculateDuration,
                  let qty = quantity, qty > 0,
                  let rate = productivityRate, rate > 0,
                  let personnel = personnelCount, personnel > 0 else { return nil }

            let hours = (qty / rate) / Double(personnel)
            return Int(hours * 3600)
        }

        /// Calculated personnel count based on quantity, productivity, and duration
        /// Formula: personnel = (quantity / rate) / (duration in hours)
        var calculatedPersonnelCount: Int? {
            guard mode == .calculatePersonnel,
                  let qty = quantity, qty > 0,
                  let rate = productivityRate, rate > 0,
                  let duration = durationSeconds, duration > 0 else { return nil }

            let durationHours = Double(duration) / 3600.0
            let personnel = (qty / rate) / durationHours
            return max(1, Int(ceil(personnel)))
        }

        /// Human-readable duration string (e.g., "3h 15m")
        var formattedDuration: String? {
            guard let seconds = calculatedDurationSeconds else { return nil }
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }

        /// Human-readable personnel count (e.g., "3 people")
        var formattedPersonnel: String? {
            guard let count = calculatedPersonnelCount else { return nil }
            return "\(count) \(count == 1 ? "person" : "people")"
        }
    }

    /// Calculate estimates using productivity-based intelligence
    /// - Parameters:
    ///   - mode: Calculation mode (duration, personnel, or manual)
    ///   - quantity: Amount of work to complete
    ///   - productivityRate: Historical or default productivity rate (units/person-hr)
    ///   - personnelCount: Number of people working
    ///   - durationHours: Duration in hours
    ///   - durationMinutes: Duration in minutes
    /// - Returns: ProductivityCalculation with results
    static func calculateWithProductivity(
        mode: CalculationMode,
        quantity: Double?,
        productivityRate: Double?,
        personnelCount: Int?,
        durationHours: Int?,
        durationMinutes: Int?
    ) -> ProductivityCalculation {

        let durationSeconds = (durationHours.map { $0 * 3600 } ?? 0) +
                             (durationMinutes.map { $0 * 60 } ?? 0)

        return ProductivityCalculation(
            mode: mode,
            quantity: quantity,
            productivityRate: productivityRate,
            personnelCount: personnelCount,
            durationSeconds: durationSeconds > 0 ? durationSeconds : nil
        )
    }

    // MARK: - Cross-Validation

    /// Convert quantity-based calculation to equivalent effort hours
    /// Formula: effortHours = quantity / productivityRate
    static func quantityToEffortHours(
        quantity: Double,
        productivityRate: Double
    ) -> Double? {
        guard quantity > 0, productivityRate > 0 else { return nil }
        return quantity / productivityRate
    }

    /// Convert effort hours to equivalent quantity
    /// Formula: quantity = effortHours × productivityRate
    static func effortHoursToQuantity(
        effortHours: Double,
        productivityRate: Double
    ) -> Double? {
        guard effortHours > 0, productivityRate > 0 else { return nil }
        return effortHours * productivityRate
    }

    /// Compare two calculation methods and detect significant differences
    struct CalculationComparison {
        let primaryValue: Double
        let alternativeValue: Double
        let differencePercent: Double
        let isSignificant: Bool  // > 15% difference

        var formattedDifference: String {
            let sign = differencePercent > 0 ? "+" : ""
            return "\(sign)\(String(format: "%.0f", differencePercent))%"
        }

        init(primary: Double, alternative: Double, threshold: Double = 0.15) {
            self.primaryValue = primary
            self.alternativeValue = alternative
            self.differencePercent = ((alternative - primary) / primary) * 100
            self.isSignificant = abs(differencePercent / 100) > threshold
        }
    }
}

