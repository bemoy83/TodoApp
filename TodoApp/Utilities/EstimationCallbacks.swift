import Foundation

/// Unified callbacks for estimation changes
/// Consolidates multiple onChange handlers into a single, cohesive structure
struct EstimationCallbacks {
    /// Called when any estimation value changes
    let onEstimationChange: () -> Void

    // MARK: - Convenience Methods

    /// Trigger estimation change callback
    func notifyChange() {
        onEstimationChange()
    }

    // MARK: - Factory Methods

    /// Create callbacks with a single unified handler
    static func unified(_ handler: @escaping () -> Void) -> EstimationCallbacks {
        EstimationCallbacks(onEstimationChange: handler)
    }

    /// Create empty callbacks (no-op)
    static var empty: EstimationCallbacks {
        EstimationCallbacks(onEstimationChange: {})
    }
}

/// Extended callbacks for more granular control (optional)
/// Use this when you need to distinguish between different types of changes
struct DetailedEstimationCallbacks {
    let onEstimateChange: () -> Void
    let onEffortChange: () -> Void
    let onQuantityChange: () -> Void
    let onPersonnelChange: () -> Void

    // MARK: - Conversion

    /// Convert to unified callbacks (all changes trigger same handler)
    func toUnified() -> EstimationCallbacks {
        EstimationCallbacks {
            self.onEstimateChange()
            self.onEffortChange()
            self.onQuantityChange()
            self.onPersonnelChange()
        }
    }

    /// Create from a single unified handler
    static func from(unified: @escaping () -> Void) -> DetailedEstimationCallbacks {
        DetailedEstimationCallbacks(
            onEstimateChange: unified,
            onEffortChange: unified,
            onQuantityChange: unified,
            onPersonnelChange: unified
        )
    }

    /// Create empty callbacks (no-op)
    static var empty: DetailedEstimationCallbacks {
        let noop = {}
        return DetailedEstimationCallbacks(
            onEstimateChange: noop,
            onEffortChange: noop,
            onQuantityChange: noop,
            onPersonnelChange: noop
        )
    }
}
