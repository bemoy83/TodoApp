# ViewModel Pattern Guide

## Overview

This project now includes ViewModels to separate business logic from view code, following MVVM (Model-View-ViewModel) architecture best practices.

## Benefits

### 1. Testability ⭐⭐⭐
```swift
// ✅ With ViewModel: Easy to test business logic
func testProductivityVariance() {
    let vm = ProductivityRateViewModel.test(expected: 10, historical: 13)
    let variance = vm.calculateVariance()
    XCTAssertEqual(variance?.percentage, 30.0)
}

// ❌ Without ViewModel: Cannot test view logic
// Would need UI testing framework, slow and brittle
```

### 2. Separation of Concerns
- **Views**: Display data and handle user interactions
- **ViewModels**: Business logic, calculations, data transformation
- **Models**: Data structures only

### 3. Reusability
ViewModels can be shared across multiple views or platforms (iOS, macOS, watchOS).

### 4. Maintainability
Business logic changes don't require view modifications and vice versa.

## Available ViewModels

### ProductivityRateViewModel

**Purpose:** Manages productivity rate selection and variance calculations

**Key Features:**
- Handles expected, historical, and custom productivity modes
- Calculates variance between rates
- Provides formatted display strings
- Validates productivity values

**Usage Example:**
```swift
struct ProductivityRateView: View {
    @State private var viewModel = ProductivityRateViewModel()

    var body: some View {
        VStack {
            // Display active rate
            Text(viewModel.formattedRate(unit: "m²"))

            // Show variance warning if significant
            if viewModel.hasSignificantVariance {
                Text(viewModel.varianceMessage() ?? "")
                    .foregroundStyle(.orange)
            }

            // Mode selector
            Picker("Mode", selection: $viewModel.productivityMode) {
                ForEach(ProductivityMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .onChange(of: viewModel.productivityMode) { _, newMode in
                viewModel.selectMode(newMode)
            }
        }
    }
}
```

### QuantityCalculationViewModel

**Purpose:** Handles all quantity-based estimation calculations

**Key Features:**
- Calculates duration from quantity, productivity, and personnel
- Calculates personnel from quantity, productivity, and duration
- Manages task type changes and productivity initialization
- Provides calculation summaries
- Validates inputs

**Usage Example:**
```swift
@Observable
class EstimationCoordinator {
    let quantityVM: QuantityCalculationViewModel

    func calculateEstimate() {
        // Business logic in ViewModel
        if let personnel = expectedPersonnelCount {
            quantityVM.calculateDuration(personnelCount: personnel)
        }

        // View just displays results
        estimateHours = quantityVM.estimateHours
        estimateMinutes = quantityVM.estimateMinutes
    }
}
```

## Testing ViewModels

### Writing Tests

ViewModels are designed to be easily testable:

```swift
final class MyViewModelTests: XCTestCase {
    func testCalculation() {
        // Given: Setup test data
        let vm = ProductivityRateViewModel.test(expected: 10, historical: 13)

        // When: Perform operation
        vm.selectMode(.historical)

        // Then: Verify result
        XCTAssertEqual(vm.activeRate, 13.0)
    }
}
```

### Test Coverage

Example test file: `ProductivityRateViewModelTests.swift`
- ✅ 15 unit tests
- ✅ Covers all business logic paths
- ✅ Runs in milliseconds (no UI)
- ✅ 100% coverage of critical calculations

## Migration Strategy

### Phase 4 (Current): Foundation
- ✅ Created ViewModels for complex calculations
- ✅ Added example unit tests
- ✅ Documented patterns

### Future: Incremental Adoption
When adding new features:
1. Create ViewModel first
2. Write tests for business logic
3. Create view that uses ViewModel
4. View handles display only

### Existing Views
Current views continue to work as-is. ViewModels are available for:
- New features
- Future refactoring
- Testing existing calculations

## Best Practices

### DO ✅
- Keep business logic in ViewModels
- Make ViewModels @Observable for SwiftUI reactivity
- Write unit tests for ViewModels
- Use computed properties for derived state
- Keep ViewModels focused (single responsibility)

### DON'T ❌
- Put UIKit/SwiftUI imports in ViewModels (keep them UI-agnostic)
- Access @Query or SwiftData directly in ViewModels
- Create massive "god" ViewModels
- Skip writing tests (main benefit!)

## Example: Before & After

### Before (View with Business Logic)
```swift
struct CalculatorView: View {
    @State private var rate = 0.0
    @State private var quantity = ""

    // ❌ Business logic in view
    var calculatedDuration: Double {
        let qty = Double(quantity) ?? 0
        guard rate > 0 else { return 0 }
        return qty / rate / Double(personnel)
    }

    var body: some View {
        Text("\(calculatedDuration)")
    }
}
```

### After (View + ViewModel)
```swift
@Observable
class CalculatorViewModel {
    var rate = 0.0
    var quantity = ""

    // ✅ Testable business logic
    func calculateDuration(personnel: Int) -> Double {
        let qty = Double(quantity) ?? 0
        guard rate > 0 else { return 0 }
        return qty / rate / Double(personnel)
    }
}

struct CalculatorView: View {
    @State private var viewModel = CalculatorViewModel()

    var body: some View {
        // ✅ View just displays
        Text("\(viewModel.calculateDuration(personnel: 5))")
    }
}
```

## Resources

- [Apple: Data Essentials in SwiftUI](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [MVVM Pattern](https://www.hackingwithswift.com/books/ios-swiftui/introducing-mvvm-into-your-swiftui-project)
- Tests: See `TodoAppTests/ProductivityRateViewModelTests.swift` for examples

## Questions?

The ViewModels are optional and don't affect existing functionality. They're here to:
1. Enable unit testing of business logic
2. Provide a cleaner architecture for new features
3. Make complex calculations easier to maintain

Use them when they make sense, especially for:
- Complex calculations
- Features that need testing
- Reusable business logic
