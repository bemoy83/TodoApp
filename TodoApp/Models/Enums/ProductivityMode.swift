import Foundation

/// Productivity mode selection for task estimation
/// Used for choosing between expected (template), historical (actual data), or custom rates
enum ProductivityMode: String, CaseIterable {
    case expected = "Expected"
    case historical = "Historical"
    case custom = "Custom"
}
