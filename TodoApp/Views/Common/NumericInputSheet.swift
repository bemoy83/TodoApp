import SwiftUI

/// Reusable sheet for numeric input with validation
/// Supports quantity, productivity rate, personnel, and duration inputs
struct NumericInputSheet: View {
    let title: String
    let unit: String?
    let inputType: NumericInputType
    @Binding var value: String
    @Binding var isPresented: Bool

    @FocusState private var isFocused: Bool
    @State private var validationError: ValidationError?

    let onDone: () -> Void

    enum NumericInputType {
        case quantity
        case productivity
        case personnel
        case durationHours

        var placeholder: String {
            switch self {
            case .quantity: return "Enter quantity"
            case .productivity: return "Enter rate"
            case .personnel: return "Enter count"
            case .durationHours: return "Enter hours"
            }
        }

        var keyboardType: UIKeyboardType {
            switch self {
            case .quantity, .productivity: return .decimalPad
            case .personnel, .durationHours: return .numberPad
            }
        }

        var isDecimal: Bool {
            switch self {
            case .quantity, .productivity: return true
            case .personnel, .durationHours: return false
            }
        }
    }

    init(
        title: String,
        unit: String? = nil,
        inputType: NumericInputType,
        value: Binding<String>,
        isPresented: Binding<Bool>,
        onDone: @escaping () -> Void = {}
    ) {
        self.title = title
        self.unit = unit
        self.inputType = inputType
        self._value = value
        self._isPresented = isPresented
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(title)
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                if let unit = unit {
                    Text("Unit: \(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Input field
                inputField

                // Validation error
                if let error = validationError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Text(error.message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .transition(.opacity)
                }

                // Quick presets (if applicable)
                if inputType == .personnel {
                    personnelPresetsView
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if isInputValid {
                            onDone()
                            isPresented = false
                        }
                    }
                    .disabled(!isInputValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
            .onAppear {
                isFocused = true
                validateInput(value)
            }
        }
    }

    // MARK: - Subviews

    private var inputField: some View {
        HStack {
            TextField(inputType.placeholder, text: $value)
                .keyboardType(inputType.keyboardType)
                .multilineTextAlignment(.center)
                .font(.title)
                .focused($isFocused)
                .frame(maxWidth: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(validationError != nil ? Color.red : Color.clear, lineWidth: 2)
                )
                .onChange(of: value) { _, newValue in
                    // Sanitize input
                    let sanitized = inputType.isDecimal
                        ? InputValidator.sanitizeDecimalInput(newValue)
                        : InputValidator.sanitizeIntegerInput(newValue)

                    if sanitized != newValue {
                        value = sanitized
                    }
                    validateInput(sanitized)
                }

            if let unit = unit {
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var personnelPresetsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Quick Select")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach([1, 2, 3, 5, 10, 15, 20, 25, 30], id: \.self) { count in
                        Button {
                            value = String(count)
                            validateInput(value)
                        } label: {
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    value == String(count)
                                        ? Color.blue
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(
                                    value == String(count)
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Validation

    private func validateInput(_ input: String) {
        guard !input.isEmpty else {
            validationError = nil
            return
        }

        let result: ValidationResult<Any>
        switch inputType {
        case .quantity:
            let quantityResult: ValidationResult<Double>
            if let unit = unit {
                quantityResult = InputValidator.validateQuantity(input, unit: unit)
            } else {
                quantityResult = InputValidator.validateQuantity(input)
            }
            result = quantityResult.error != nil
                ? .failure(quantityResult.error!)
                : .success(quantityResult.value!)

        case .productivity:
            let productivityResult: ValidationResult<Double>
            if let unit = unit {
                productivityResult = InputValidator.validateProductivityRate(input, unit: unit)
            } else {
                productivityResult = InputValidator.validateProductivityRate(input)
            }
            result = productivityResult.error != nil
                ? .failure(productivityResult.error!)
                : .success(productivityResult.value!)

        case .personnel:
            let personnelResult = InputValidator.validatePersonnel(input)
            result = personnelResult.error != nil
                ? .failure(personnelResult.error!)
                : .success(personnelResult.value!)

        case .durationHours:
            let durationResult = InputValidator.validateDurationHours(input)
            result = durationResult.error != nil
                ? .failure(durationResult.error!)
                : .success(durationResult.value!)
        }

        withAnimation {
            validationError = result.error
        }
    }

    private var isInputValid: Bool {
        !value.isEmpty && validationError == nil
    }
}

// MARK: - Decimal Input Sheet (Specific)

/// Decimal input sheet for quantity or productivity
struct DecimalInputSheet: View {
    let title: String
    let unit: String
    @Binding var value: Double?
    @Binding var isPresented: Bool

    @State private var inputText: String = ""
    let inputType: NumericInputSheet.NumericInputType

    let onDone: () -> Void

    init(
        title: String,
        unit: String,
        value: Binding<Double?>,
        isPresented: Binding<Bool>,
        inputType: NumericInputSheet.NumericInputType = .quantity,
        onDone: @escaping () -> Void = {}
    ) {
        self.title = title
        self.unit = unit
        self._value = value
        self._isPresented = isPresented
        self.inputType = inputType
        self.onDone = onDone
    }

    var body: some View {
        NumericInputSheet(
            title: title,
            unit: unit,
            inputType: inputType,
            value: $inputText,
            isPresented: $isPresented
        ) {
            if let parsedValue = Double(inputText) {
                value = parsedValue
            }
            onDone()
        }
        .onAppear {
            if let currentValue = value {
                inputText = inputType == .quantity
                    ? InputValidator.formatQuantity(currentValue)
                    : InputValidator.formatProductivityRate(currentValue)
            }
        }
    }
}

// MARK: - Integer Input Sheet (Specific)

/// Integer input sheet for personnel or duration
struct IntegerInputSheet: View {
    let title: String
    @Binding var value: Int?
    @Binding var isPresented: Bool

    @State private var inputText: String = ""
    let inputType: NumericInputSheet.NumericInputType

    let onDone: () -> Void

    init(
        title: String,
        value: Binding<Int?>,
        isPresented: Binding<Bool>,
        inputType: NumericInputSheet.NumericInputType = .personnel,
        onDone: @escaping () -> Void = {}
    ) {
        self.title = title
        self._value = value
        self._isPresented = isPresented
        self.inputType = inputType
        self.onDone = onDone
    }

    var body: some View {
        NumericInputSheet(
            title: title,
            unit: nil,
            inputType: inputType,
            value: $inputText,
            isPresented: $isPresented
        ) {
            if let parsedValue = Int(inputText) {
                value = parsedValue
            }
            onDone()
        }
        .onAppear {
            if let currentValue = value {
                inputText = String(currentValue)
            }
        }
    }
}

// MARK: - Preview

#Preview("Quantity Input") {
    @Previewable @State var quantity = "150"
    @Previewable @State var showSheet = true

    Button("Show Quantity Input") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        NumericInputSheet(
            title: "Enter Carpet Quantity",
            unit: "m²",
            inputType: .quantity,
            value: $quantity,
            isPresented: $showSheet
        )
    }
}

#Preview("Personnel Input") {
    @Previewable @State var personnel = "5"
    @Previewable @State var showSheet = true

    Button("Show Personnel Input") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        NumericInputSheet(
            title: "Select Personnel Count",
            unit: nil,
            inputType: .personnel,
            value: $personnel,
            isPresented: $showSheet
        )
    }
}

#Preview("Productivity Input") {
    @Previewable @State var rate = "12.5"
    @Previewable @State var showSheet = true

    Button("Show Productivity Input") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        NumericInputSheet(
            title: "Enter Productivity Rate",
            unit: "m²/person-hr",
            inputType: .productivity,
            value: $rate,
            isPresented: $showSheet
        )
    }
}
