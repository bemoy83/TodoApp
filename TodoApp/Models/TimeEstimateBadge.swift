//
//  TimeEstimateBadge.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 26/10/2025.
//


//
//  TimeEstimateBadge.swift
//  TodoApp
//
//  Time estimate badge for displaying progress toward time goals
//

import SwiftUI

struct TimeEstimateBadge: View {
    let actual: Int
    let estimated: Int
    let isCalculated: Bool
    let hasActiveTimer: Bool

    init(actual: Int, estimated: Int, isCalculated: Bool = false, hasActiveTimer: Bool = false) {
        self.actual = actual
        self.estimated = estimated
        self.isCalculated = isCalculated
        self.hasActiveTimer = hasActiveTimer
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: hasActiveTimer)

            Text(displayText)
                .font(.caption)
                .monospacedDigit()

            if shouldShowStatusIcon {
                Image(systemName: estimateStatus.icon)
                    .font(.caption2)
            }

            if isCalculated {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .help("Auto-calculated from subtasks")
            }
        }
        .foregroundStyle(badgeColor)
    }

    // MARK: - Display Mode Logic

    /// Show countdown/over format only when timer is active and approaching estimate
    /// After stopping timer or completing task, always show actual/estimated format
    private var shouldShowCountdownMode: Bool {
        progress >= 0.90 && hasActiveTimer
    }

    /// Show status icon only in normal mode (countdown mode uses different icon)
    private var shouldShowStatusIcon: Bool {
        !shouldShowCountdownMode
    }

    private var iconName: String {
        if shouldShowCountdownMode {
            return remaining >= 0 ? "clock" : "exclamationmark.triangle.fill"
        } else {
            return hasActiveTimer ? "timer" : "target"
        }
    }

    private var displayText: String {
        if shouldShowCountdownMode {
            return formatCountdown()
        } else {
            return "\(actual.formattedTime()) / \(estimated.formattedTime())"
        }
    }

    private var remaining: Int {
        let actualMinutes = actual / 60
        let estimatedMinutes = estimated / 60
        return estimatedMinutes - actualMinutes
    }

    private func formatCountdown() -> String {
        let absRemaining = abs(remaining)
        let hours = absRemaining / 60
        let mins = absRemaining % 60

        var timeStr: String
        if hours > 0 {
            timeStr = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            timeStr = "\(mins)m"
        }

        return remaining >= 0 ? "\(timeStr) left" : "\(timeStr) over"
    }
    
    private var progress: Double {
        guard estimated > 0 else { return 0 }
        return Double(actual) / Double(estimated)
    }
    
    private var estimateStatus: TimeEstimateStatus {
        TimeEstimateStatus.from(progress: progress)
    }
    
    private var badgeColor: Color {
        if shouldShowCountdownMode {
            return remaining >= 0 ? estimateStatus.color : .red
        }

        if hasActiveTimer {
            return DesignSystem.Colors.timerActive
        }

        return estimateStatus.color
    }
}

#Preview("On Track") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 30 * 60, estimated: 120 * 60)
        TimeEstimateBadge(actual: 60 * 60, estimated: 120 * 60)
    }
    .padding()
}

#Preview("Warning") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 90 * 60, estimated: 120 * 60)
        TimeEstimateBadge(actual: 110 * 60, estimated: 120 * 60)
    }
    .padding()
}

#Preview("Over") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 120 * 60, estimated: 120 * 60)
        TimeEstimateBadge(actual: 150 * 60, estimated: 120 * 60)
    }
    .padding()
}

#Preview("With Active Timer") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 45 * 60, estimated: 120 * 60, hasActiveTimer: true)
        TimeEstimateBadge(actual: 100 * 60, estimated: 120 * 60, hasActiveTimer: true)
        TimeEstimateBadge(actual: 130 * 60, estimated: 120 * 60, hasActiveTimer: true)
    }
    .padding()
}

#Preview("Calculated") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 45 * 60, estimated: 180 * 60, isCalculated: true)
        TimeEstimateBadge(actual: 150 * 60, estimated: 180 * 60, isCalculated: true)
    }
    .padding()
}
