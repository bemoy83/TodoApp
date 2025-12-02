import SwiftUI

/// Text field with built-in validation and error display
/// Provides consistent validation UI across the app
struct ValidatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let validator: (String) -> ValidationResult<Double>

    @State private var validationError: ValidationError?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    validateInput(newValue)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(validationError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

            if let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationError != nil)
    }

    private func validateInput(_ input: String) {
        let result = validator(input)
        withAnimation {
            validationError = result.error
        }
    }
}

/// Decimal text field with validation for quantity/productivity inputs
struct ValidatedDecimalField: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    let unit: String?
    let validationType: DecimalValidationType

    @State private var validationError: ValidationError?
    @FocusState private var isFocused: Bool

    enum DecimalValidationType {
        case quantity
        case productivity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                TextField(placeholder, text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onChange(of: value) { _, newValue in
                        // Sanitize input
                        let sanitized = InputValidator.sanitizeDecimalInput(newValue)
                        if sanitized != newValue {
                            value = sanitized
                        }
                        validateInput(sanitized)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(validationError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )

                if let unit = unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }

            if let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationError != nil)
    }

    private func validateInput(_ input: String) {
        guard !input.isEmpty else {
            validationError = nil
            return
        }

        let result: ValidationResult<Double>
        switch validationType {
        case .quantity:
            result = if let unit = unit {
                InputValidator.validateQuantity(input, unit: unit)
            } else {
                InputValidator.validateQuantity(input)
            }
        case .productivity:
            result = if let unit = unit {
                InputValidator.validateProductivityRate(input, unit: unit)
            } else {
                InputValidator.validateProductivityRate(input)
            }
        }

        withAnimation {
            validationError = result.error
        }
    }

    /// Whether the current input is valid
    var isValid: Bool {
        validationError == nil && !value.isEmpty
    }

    /// Get validated value if valid, nil otherwise
    var validatedValue: Double? {
        guard !value.isEmpty else { return nil }

        let result: ValidationResult<Double>
        switch validationType {
        case .quantity:
            result = InputValidator.validateQuantity(value)
        case .productivity:
            result = InputValidator.validateProductivityRate(value)
        }

        return result.value
    }
}

/// Integer text field with validation for personnel/duration inputs
struct ValidatedIntegerField: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    let validationType: IntegerValidationType

    @State private var validationError: ValidationError?
    @FocusState private var isFocused: Bool

    enum IntegerValidationType {
        case personnel
        case durationHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TextField(placeholder, text: $value)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: value) { _, newValue in
                    // Sanitize input
                    let sanitized = InputValidator.sanitizeIntegerInput(newValue)
                    if sanitized != newValue {
                        value = sanitized
                    }
                    validateInput(sanitized)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(validationError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

            if let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationError != nil)
    }

    private func validateInput(_ input: String) {
        guard !input.isEmpty else {
            validationError = nil
            return
        }

        let result: ValidationResult<Int>
        switch validationType {
        case .personnel:
            result = InputValidator.validatePersonnel(input)
        case .durationHours:
            result = InputValidator.validateDurationHours(input)
        }

        withAnimation {
            validationError = result.error
        }
    }

    /// Whether the current input is valid
    var isValid: Bool {
        validationError == nil && !value.isEmpty
    }

    /// Get validated value if valid, nil otherwise
    var validatedValue: Int? {
        guard !value.isEmpty else { return nil }

        let result: ValidationResult<Int>
        switch validationType {
        case .personnel:
            result = InputValidator.validatePersonnel(value)
        case .durationHours:
            result = InputValidator.validateDurationHours(value)
        }

        return result.value
    }
}

// MARK: - Preview

#Preview("Quantity Field - Valid") {
    @Previewable @State var quantity = "250"

    VStack(spacing: 20) {
        ValidatedDecimalField(
            title: "Quantity",
            placeholder: "0",
            value: $quantity,
            unit: "m²",
            validationType: .quantity
        )
        .padding()
    }
}

#Preview("Quantity Field - Invalid") {
    @Previewable @State var quantity = "-50"

    VStack(spacing: 20) {
        ValidatedDecimalField(
            title: "Quantity",
            placeholder: "0",
            value: $quantity,
            unit: "m²",
            validationType: .quantity
        )
        .padding()
    }
}

#Preview("Personnel Field - Valid") {
    @Previewable @State var personnel = "15"

    VStack(spacing: 20) {
        ValidatedIntegerField(
            title: "Personnel",
            placeholder: "0",
            value: $personnel,
            validationType: .personnel
        )
        .padding()
    }
}
