import SwiftUI

/// Editor for selecting and customizing productivity rates
/// Supports expected (template), historical (actual data), and custom modes
/// Used for event task estimation (carpet, walls, furniture, etc.)
struct ProductivityRateEditorView: View {
    @Binding var isPresented: Bool
    let viewModel: ProductivityRateViewModel
    let unitDisplayName: String
    let onUpdate: () -> Void

    @State private var productivityValidationError: String?
    @FocusState private var isCustomProductivityFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Set Productivity Rate")
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                // Variance warning (if significant)
                if let variance = viewModel.calculateVariance(), variance.percentage > 30 {
                    varianceWarning(variance: variance)
                }

                // Segmented control for mode selection
                Picker("Mode", selection: Binding(
                    get: { viewModel.productivityMode },
                    set: { newMode in
                        viewModel.selectMode(newMode)
                        onUpdate()
                    }
                )) {
                    ForEach(ProductivityMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Show available productivity values
                availableRatesView

                // Custom input field (only shown when Custom mode is selected)
                if viewModel.productivityMode == .custom {
                    customRateInputView
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                        isCustomProductivityFocused = false
                    }
                }
            }
            .presentationDetents([.height(450)])
            .presentationDragIndicator(.visible)
            .onAppear {
                initializeModeFromCurrentRate()
            }
        }
    }

    // MARK: - Subviews

    private func varianceWarning(variance: (percentage: Double, isPositive: Bool)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Historical is \(String(format: "%.0f", variance.percentage))% \(variance.isPositive ? "faster" : "slower") than expected.")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Consider updating your template's expected rate.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var availableRatesView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if let expected = viewModel.expectedProductivity {
                HStack {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.info)
                        .frame(width: 20)
                    Text("Expected:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", expected)) \(unitDisplayName)/person-hr")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            if let historical = viewModel.historicalProductivity {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.success)
                        .frame(width: 20)
                    Text("Historical:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", historical)) \(unitDisplayName)/person-hr")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var customRateInputView: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Custom Rate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                TextField("Enter rate", text: Binding(
                    get: { viewModel.customProductivityInput },
                    set: { newValue in
                        viewModel.setCustomRate(newValue)
                        validateProductivityInput(newValue)
                        onUpdate()
                    }
                ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .focused($isCustomProductivityFocused)
                    .frame(maxWidth: 200)

                Text("\(unitDisplayName)/person-hr")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Inline validation error (below input)
            if let error = productivityValidationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .onAppear {
            isCustomProductivityFocused = true
            // Validate current value when sheet appears
            if !viewModel.customProductivityInput.isEmpty {
                validateProductivityInput(viewModel.customProductivityInput)
            }
        }
    }

    // MARK: - Helper Methods

    /// Validate productivity rate input in real-time
    private func validateProductivityInput(_ input: String) {
        // Empty input is valid (allows user to clear and retype)
        guard !input.isEmpty else {
            productivityValidationError = nil
            return
        }

        // Validate using InputValidator
        let validation = InputValidator.validateProductivityRate(input, unit: unitDisplayName)

        // Update error message
        if let error = validation.error {
            productivityValidationError = error.message
        } else {
            productivityValidationError = nil
        }
    }

    /// Initialize mode based on current productivity rate
    private func initializeModeFromCurrentRate() {
        guard let current = viewModel.currentProductivity else { return }

        if current == viewModel.expectedProductivity {
            viewModel.productivityMode = .expected
        } else if current == viewModel.historicalProductivity {
            viewModel.productivityMode = .historical
        } else {
            viewModel.productivityMode = .custom
            viewModel.customProductivityInput = String(format: "%.1f", current)
        }
    }
}
