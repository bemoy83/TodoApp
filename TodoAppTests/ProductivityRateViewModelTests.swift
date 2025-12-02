import XCTest
@testable import TodoApp

/// Example unit tests demonstrating ViewModel testability
/// These tests run WITHOUT UI and can verify business logic independently
final class ProductivityRateViewModelTests: XCTestCase {

    // MARK: - Variance Calculation Tests

    func testVarianceCalculation_whenHistoricalFaster() {
        // Given: Expected 10, Historical 13 (30% faster)
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 13.0)

        // When: Calculate variance
        let variance = vm.calculateVariance()

        // Then: Should show 30% positive variance
        XCTAssertNotNil(variance)
        XCTAssertEqual(variance?.percentage, 30.0, accuracy: 0.1)
        XCTAssertTrue(variance?.isPositive ?? false)
    }

    func testVarianceCalculation_whenHistoricalSlower() {
        // Given: Expected 10, Historical 7 (30% slower)
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 7.0)

        // When: Calculate variance
        let variance = vm.calculateVariance()

        // Then: Should show 30% negative variance
        XCTAssertNotNil(variance)
        XCTAssertEqual(variance?.percentage, 30.0, accuracy: 0.1)
        XCTAssertFalse(variance?.isPositive ?? true)
    }

    func testVarianceCalculation_whenNoHistorical() {
        // Given: Only expected rate
        let vm = ProductivityRateViewModel()
        vm.expectedProductivity = 10.0
        vm.historicalProductivity = nil

        // When: Calculate variance
        let variance = vm.calculateVariance()

        // Then: Should return nil (no comparison possible)
        XCTAssertNil(variance)
    }

    // MARK: - Mode Selection Tests

    func testModeSelection_expected() {
        // Given: ViewModel with both rates
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 13.0)

        // When: Select expected mode
        vm.selectMode(.expected)

        // Then: Should use expected rate
        XCTAssertEqual(vm.productivityMode, .expected)
        XCTAssertEqual(vm.activeRate, 10.0)
    }

    func testModeSelection_historical() {
        // Given: ViewModel with both rates
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 13.0)

        // When: Select historical mode
        vm.selectMode(.historical)

        // Then: Should use historical rate
        XCTAssertEqual(vm.productivityMode, .historical)
        XCTAssertEqual(vm.activeRate, 13.0)
    }

    func testModeSelection_custom() {
        // Given: ViewModel with rates
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 13.0)

        // When: Set custom rate
        vm.setCustomRate("15.5")

        // Then: Should use custom rate and switch mode
        XCTAssertEqual(vm.productivityMode, .custom)
        XCTAssertEqual(vm.activeRate, 15.5, accuracy: 0.1)
        XCTAssertEqual(vm.customProductivityInput, "15.5")
    }

    // MARK: - Significant Variance Tests

    func testHasSignificantVariance_whenOver30Percent() {
        // Given: 40% variance
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 14.0)

        // When: Check for significant variance
        let hasSignificant = vm.hasSignificantVariance

        // Then: Should be true
        XCTAssertTrue(hasSignificant)
    }

    func testHasSignificantVariance_whenUnder30Percent() {
        // Given: 20% variance
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 12.0)

        // When: Check for significant variance
        let hasSignificant = vm.hasSignificantVariance

        // Then: Should be false
        XCTAssertFalse(hasSignificant)
    }

    // MARK: - Loading Productivity Rates Tests

    func testLoadProductivityRates_withCustomRateDifferent() {
        // Given: ViewModel
        let vm = ProductivityRateViewModel()

        // When: Load with custom rate different from default
        vm.loadProductivityRates(expected: 10.0, historical: 13.0, existingCustom: 15.0)

        // Then: Should restore custom rate
        XCTAssertEqual(vm.productivityMode, .custom)
        XCTAssertEqual(vm.currentProductivity, 15.0)
        XCTAssertEqual(vm.customProductivityInput, "15.0")
    }

    func testLoadProductivityRates_withCustomRateSameAsDefault() {
        // Given: ViewModel
        let vm = ProductivityRateViewModel()

        // When: Load with custom rate same as expected
        vm.loadProductivityRates(expected: 10.0, historical: 13.0, existingCustom: 10.0)

        // Then: Should use expected mode (not custom)
        XCTAssertEqual(vm.productivityMode, .expected)
        XCTAssertEqual(vm.currentProductivity, 10.0)
    }

    // MARK: - Validation Tests

    func testValidation_validRate() {
        // Given: ViewModel with valid rate
        let vm = ProductivityRateViewModel.test(expected: 12.5, historical: 13.0)

        // When: Validate
        let result = vm.validate(unit: "m²")

        // Then: Should succeed
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.value, 12.5)
    }

    func testValidation_zeroRate() {
        // Given: ViewModel with no rate set
        let vm = ProductivityRateViewModel()

        // When: Validate
        let result = vm.validate(unit: "m²")

        // Then: Should fail
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Variance Message Tests

    func testVarianceMessage_whenFaster() {
        // Given: 35% faster performance
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 13.5)

        // When: Get message
        let message = vm.varianceMessage()

        // Then: Should describe faster performance
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("35%") ?? false)
        XCTAssertTrue(message?.contains("faster") ?? false)
    }

    func testVarianceMessage_whenSlower() {
        // Given: 30% slower performance
        let vm = ProductivityRateViewModel.test(expected: 10.0, historical: 7.0)

        // When: Get message
        let message = vm.varianceMessage()

        // Then: Should describe slower performance
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("30%") ?? false)
        XCTAssertTrue(message?.contains("slower") ?? false)
    }

    // MARK: - Formatted Rate Tests

    func testFormattedRate() {
        // Given: ViewModel with rate
        let vm = ProductivityRateViewModel.test(expected: 12.5, historical: 13.0)

        // When: Format for display
        let formatted = vm.formattedRate(unit: "m²")

        // Then: Should format correctly
        XCTAssertEqual(formatted, "12.5 m²/person-hr")
    }
}
