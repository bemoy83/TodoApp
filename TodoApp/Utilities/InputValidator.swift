import Foundation

/// Validation errors with user-friendly messages
enum ValidationError: Error, Equatable {
    case invalidQuantity(String)
    case invalidProductivity(String)
    case invalidPersonnel(String)
    case invalidDuration(String)
    case emptyValue(String)
    case outOfRange(String)

    var message: String {
        switch self {
        case .invalidQuantity(let msg): return msg
        case .invalidProductivity(let msg): return msg
        case .invalidPersonnel(let msg): return msg
        case .invalidDuration(let msg): return msg
        case .emptyValue(let msg): return msg
        case .outOfRange(let msg): return msg
        }
    }
}

/// Validation result with either success or error
enum ValidationResult<T> {
    case success(T)
    case failure(ValidationError)

    var value: T? {
        if case .success(let val) = self {
            return val
        }
        return nil
    }

    var error: ValidationError? {
        if case .failure(let err) = self {
            return err
        }
        return nil
    }

    var isValid: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

/// Input validation utilities for estimation fields
/// Provides consistent validation across the app with user-friendly error messages
struct InputValidator {

    // MARK: - Quantity Validation

    /// Validate quantity input string
    /// - Parameter input: Raw string input from user
    /// - Returns: ValidationResult with Double value or error
    static func validateQuantity(_ input: String) -> ValidationResult<Double> {
        // Check for empty input
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .failure(.emptyValue("Quantity cannot be empty"))
        }

        // Parse as double
        guard let value = Double(trimmed) else {
            return .failure(.invalidQuantity("Please enter a valid number"))
        }

        // Check range
        guard EstimationLimits.isValidQuantity(value) else {
            return .failure(.outOfRange(EstimationLimits.quantityErrorMessage(for: value)))
        }

        return .success(value)
    }

    /// Validate quantity with optional unit name for better error messages
    static func validateQuantity(_ input: String, unit: String) -> ValidationResult<Double> {
        let result = validateQuantity(input)

        // Enhance error messages with unit name
        if case .failure(let error) = result {
            switch error {
            case .emptyValue:
                return .failure(.emptyValue("Please enter the quantity of \(unit)"))
            case .invalidQuantity:
                return .failure(.invalidQuantity("Please enter a valid number for \(unit)"))
            case .outOfRange(let msg):
                return .failure(.outOfRange(msg))
            default:
                return result
            }
        }

        return result
    }

    /// Validate quantity with task-type-specific limits
    /// - Parameters:
    ///   - input: Raw string input from user
    ///   - unit: Unit name for error messages
    ///   - minQuantity: Optional minimum from TaskTemplate (falls back to EstimationLimits)
    ///   - maxQuantity: Optional maximum from TaskTemplate (falls back to EstimationLimits)
    /// - Returns: ValidationResult with Double value or contextual error
    static func validateQuantity(
        _ input: String,
        unit: String,
        minQuantity: Double?,
        maxQuantity: Double?
    ) -> ValidationResult<Double> {
        // Check for empty input
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .failure(.emptyValue("Please enter the quantity of \(unit)"))
        }

        // Parse as double
        guard let value = Double(trimmed) else {
            return .failure(.invalidQuantity("Please enter a valid number for \(unit)"))
        }

        // Use task-type-specific limits if available, otherwise use EstimationLimits
        let min = minQuantity ?? EstimationLimits.minQuantity
        let max = maxQuantity ?? EstimationLimits.maxQuantity

        // Check range with contextual error message
        if value < min {
            if value == 0 {
                return .failure(.outOfRange("Quantity cannot be 0 for calculation to work"))
            }
            return .failure(.outOfRange("\(unit.capitalized) quantity must be at least \(formatQuantity(min))"))
        } else if value > max {
            return .failure(.outOfRange("\(unit.capitalized) quantity cannot exceed \(formatQuantity(max))"))
        }

        return .success(value)
    }

    // MARK: - Productivity Rate Validation

    /// Validate productivity rate input string
    /// - Parameter input: Raw string input from user
    /// - Returns: ValidationResult with Double value or error
    static func validateProductivityRate(_ input: String) -> ValidationResult<Double> {
        // Check for empty input
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .failure(.emptyValue("Productivity rate cannot be empty"))
        }

        // Parse as double
        guard let value = Double(trimmed) else {
            return .failure(.invalidProductivity("Please enter a valid productivity rate"))
        }

        // Check range
        guard EstimationLimits.isValidProductivityRate(value) else {
            return .failure(.outOfRange(EstimationLimits.productivityErrorMessage(for: value)))
        }

        return .success(value)
    }

    /// Validate productivity rate with unit name
    static func validateProductivityRate(_ input: String, unit: String) -> ValidationResult<Double> {
        let result = validateProductivityRate(input)

        // Enhance error messages with unit name
        if case .failure(let error) = result {
            switch error {
            case .emptyValue:
                return .failure(.emptyValue("Please enter productivity rate (\(unit)/person-hr)"))
            case .invalidProductivity:
                return .failure(.invalidProductivity("Please enter a valid rate for \(unit)/person-hr"))
            case .outOfRange(let msg):
                return .failure(.outOfRange(msg))
            default:
                return result
            }
        }

        return result
    }

    // MARK: - Personnel Validation

    /// Validate personnel count
    /// - Parameter count: Personnel count to validate
    /// - Returns: ValidationResult with Int value or error
    static func validatePersonnel(_ count: Int) -> ValidationResult<Int> {
        guard EstimationLimits.isValidPersonnel(count) else {
            return .failure(.outOfRange(EstimationLimits.personnelErrorMessage(for: count)))
        }
        return .success(count)
    }

    /// Validate personnel string input
    static func validatePersonnel(_ input: String) -> ValidationResult<Int> {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .failure(.emptyValue("Personnel count cannot be empty"))
        }

        guard let value = Int(trimmed) else {
            return .failure(.invalidPersonnel("Please enter a valid whole number for personnel"))
        }

        return validatePersonnel(value)
    }

    // MARK: - Duration Validation

    /// Validate duration hours
    /// - Parameter hours: Duration in hours
    /// - Returns: ValidationResult with Int value or error
    static func validateDurationHours(_ hours: Int) -> ValidationResult<Int> {
        guard EstimationLimits.isValidDurationHours(hours) else {
            return .failure(.outOfRange(EstimationLimits.durationErrorMessage(for: hours)))
        }
        return .success(hours)
    }

    /// Validate duration string input
    static func validateDurationHours(_ input: String) -> ValidationResult<Int> {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .failure(.emptyValue("Duration cannot be empty"))
        }

        guard let value = Int(trimmed) else {
            return .failure(.invalidDuration("Please enter a valid whole number for hours"))
        }

        return validateDurationHours(value)
    }

    /// Validate complete duration (hours and minutes)
    static func validateDuration(hours: Int, minutes: Int) -> ValidationResult<(hours: Int, minutes: Int)> {
        // Validate hours
        guard EstimationLimits.isValidDurationHours(hours) else {
            return .failure(.outOfRange(EstimationLimits.durationErrorMessage(for: hours)))
        }

        // Validate minutes
        guard minutes >= 0 && minutes <= 59 else {
            return .failure(.invalidDuration("Minutes must be between 0 and 59"))
        }

        // Check if total duration is zero
        if hours == 0 && minutes == 0 {
            return .failure(.invalidDuration("Duration must be greater than 0"))
        }

        return .success((hours: hours, minutes: minutes))
    }

    // MARK: - Batch Validation

    /// Validate all quantity-related inputs at once
    static func validateQuantityInputs(
        quantity: String,
        productivityRate: String,
        unit: String
    ) -> [ValidationError] {
        var errors: [ValidationError] = []

        if let error = validateQuantity(quantity, unit: unit).error {
            errors.append(error)
        }

        if let error = validateProductivityRate(productivityRate, unit: unit).error {
            errors.append(error)
        }

        return errors
    }

    /// Validate all duration-related inputs at once
    static func validateDurationInputs(
        hours: Int,
        minutes: Int,
        personnel: Int?
    ) -> [ValidationError] {
        var errors: [ValidationError] = []

        if let error = validateDuration(hours: hours, minutes: minutes).error {
            errors.append(error)
        }

        if let personnelCount = personnel,
           let error = validatePersonnel(personnelCount).error {
            errors.append(error)
        }

        return errors
    }

    // MARK: - Format Helpers

    /// Format quantity with proper decimal places
    static func formatQuantity(_ value: Double) -> String {
        String(format: "%.\(EstimationLimits.quantityDecimalPlaces)f", value)
    }

    /// Format productivity rate with proper decimal places
    static func formatProductivityRate(_ value: Double) -> String {
        String(format: "%.\(EstimationLimits.productivityDecimalPlaces)f", value)
    }

    /// Parse and format decimal input (removes invalid characters)
    static func sanitizeDecimalInput(_ input: String) -> String {
        // Allow digits, decimal point, and negative sign
        let allowed = CharacterSet(charactersIn: "0123456789.-")
        let filtered = input.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    /// Parse and format integer input (removes invalid characters)
    static func sanitizeIntegerInput(_ input: String) -> String {
        // Allow only digits
        let allowed = CharacterSet.decimalDigits
        let filtered = input.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }
}
