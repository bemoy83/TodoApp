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
            Image(systemName: hasActiveTimer ? "timer" : "target")
                .font(.caption2)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: hasActiveTimer)
            
            Text("\(formatMinutes(actual)) / \(formatMinutes(estimated))")
                .font(.caption)
                .monospacedDigit()
            
            if let status = estimateStatus {
                Image(systemName: status.icon)
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
    
    private var progress: Double {
        guard estimated > 0 else { return 0 }
        return Double(actual) / Double(estimated)
    }
    
    private var estimateStatus: TimeEstimateStatus? {
        if progress >= 1.0 {
            return .over
        } else if progress >= 0.75 {
            return .warning
        } else {
            return .onTrack
        }
    }
    
    private var badgeColor: Color {
        if hasActiveTimer {
            return DesignSystem.Colors.timerActive
        }
        return estimateStatus?.color ?? .secondary
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

#Preview("On Track") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 30, estimated: 120)
        TimeEstimateBadge(actual: 60, estimated: 120)
    }
    .padding()
}

#Preview("Warning") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 90, estimated: 120)
        TimeEstimateBadge(actual: 110, estimated: 120)
    }
    .padding()
}

#Preview("Over") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 120, estimated: 120)
        TimeEstimateBadge(actual: 150, estimated: 120)
    }
    .padding()
}

#Preview("With Active Timer") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 45, estimated: 120, hasActiveTimer: true)
        TimeEstimateBadge(actual: 100, estimated: 120, hasActiveTimer: true)
        TimeEstimateBadge(actual: 130, estimated: 120, hasActiveTimer: true)
    }
    .padding()
}

#Preview("Calculated") {
    VStack(spacing: 16) {
        TimeEstimateBadge(actual: 45, estimated: 180, isCalculated: true)
        TimeEstimateBadge(actual: 150, estimated: 180, isCalculated: true)
    }
    .padding()
}