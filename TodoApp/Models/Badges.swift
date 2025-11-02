//
//  TaskBadges.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 10/10/2025.
//

import SwiftUI

// MARK: - Date Formatting Helper

extension Date {
    /// Smart date formatting: "Today", "Tomorrow", or abbreviated date
    var smartFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        } else {
            return self.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Due Date Badge

struct DueDateBadge: View {
    let date: Date
    let isCompleted: Bool
    let isInherited: Bool
    let estimatedSeconds: Int?
    let hasActiveTimer: Bool

    init(
        date: Date,
        isCompleted: Bool,
        isInherited: Bool = false,
        estimatedSeconds: Int? = nil,
        hasActiveTimer: Bool = false
    ) {
        self.date = date
        self.isCompleted = isCompleted
        self.isInherited = isInherited
        self.estimatedSeconds = estimatedSeconds
        self.hasActiveTimer = hasActiveTimer
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)

            Text(displayText)
                .font(.caption)

            if isInherited && !shouldShowCountdown {
                Text("(inherited)")
                    .font(.caption2)
                    .italic()
            }
        }
        .foregroundStyle(badgeColor)
    }

    // MARK: - Smart Threshold Logic

    /// Calculate smart threshold based on task estimate
    /// - With estimate: 1.5x estimated time, minimum 2 hours
    /// - Without estimate: 6 hours default
    private var countdownThresholdSeconds: TimeInterval {
        if let estimate = estimatedSeconds {
            let estimateHours = Double(estimate) / 3600.0
            let thresholdHours = max(estimateHours * 1.5, 2.0)
            return thresholdHours * 3600.0
        } else {
            return 6.0 * 3600.0  // 6 hours default
        }
    }

    /// Seconds remaining until due date
    private var secondsRemaining: TimeInterval {
        date.timeIntervalSince(Date())
    }

    /// Show countdown when: (1) within threshold OR (2) timer is active
    private var shouldShowCountdown: Bool {
        if isCompleted { return false }
        if hasActiveTimer { return true }  // Always show when timer active
        return secondsRemaining <= countdownThresholdSeconds && secondsRemaining > -Double.infinity
    }

    private var isOverdue: Bool {
        secondsRemaining < 0
    }

    // MARK: - Display Logic

    private var iconName: String {
        if isCompleted {
            return "checkmark.circle.fill"
        } else if shouldShowCountdown {
            return isOverdue ? "exclamationmark.triangle.fill" : "clock"
        } else {
            return isInherited ? "calendar.badge.clock" : "calendar"
        }
    }

    private var displayText: String {
        if shouldShowCountdown {
            return formatCountdown()
        } else {
            return date.smartFormatted
        }
    }

    private func formatCountdown() -> String {
        let absSeconds = abs(Int(secondsRemaining))
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60

        var timeStr: String
        if hours > 0 {
            timeStr = minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            timeStr = "\(minutes)m"
        }

        return isOverdue ? "\(timeStr) overdue" : "\(timeStr) left"
    }

    private var badgeColor: Color {
        if isCompleted {
            return .secondary
        }

        if isOverdue {
            return .red  // Overdue - urgent
        } else if shouldShowCountdown {
            return .orange  // Countdown mode - approaching deadline
        } else if Calendar.current.isDateInToday(date) {
            return .orange  // Due today (but not in countdown threshold yet)
        } else {
            return .secondary
        }
    }
}

// MARK: - Subtasks Badge

// TaskBadges.swift — minimal secondary style
struct SubtasksBadge: View {
    private enum Mode { case totalOnly(Int), progress(Int, Int) }
    private let mode: Mode

    init(count: Int) { self.mode = .totalOnly(count) }
    init(completed: Int, total: Int) { self.mode = .progress(completed, total) }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "list.bullet.indent").font(.caption2)
            Text(label).font(.caption).monospacedDigit()
        }
        .foregroundStyle(.secondary)            // subtle, secondary
        .accessibilityLabel(accessibility)
    }

    private var label: String {
        switch mode { case .totalOnly(let n): "\(n)"; case .progress(let c, let t): "\(c)/\(t)" }
    }
    private var accessibility: String {
        switch mode { case .totalOnly(let n): "\(n) subtasks"
        case .progress(let c, let t): "\(c) of \(t) subtasks completed" }
    }
}


// MARK: - Dependency Indicator

struct DependencyIndicator: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("\(count)")
                .font(.caption)
        }
        .foregroundStyle(.orange)
    }
}

// MARK: - Priority Indicator

struct PriorityIndicator: View {
    let priority: Priority
    
    var body: some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            .alignmentGuide(.lastTextBaseline) { d in d[VerticalAlignment.center] }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TaskStatus
    let action: () -> Void
    
    private var statusColor: Color {
        switch status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.caption2)
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(statusColor)
        }
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    @Binding var priority: Int
    
    private var taskPriority: Priority {
        Priority(rawValue: priority) ?? .medium
    }
    
    var body: some View {
        Menu {
            ForEach([Priority.urgent, .high, .medium, .low], id: \.self) { priorityOption in
                Button {
                    priority = priorityOption.rawValue
                    HapticManager.selection()
                } label: {
                    Label(priorityOption.label, systemImage: priorityOption.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: taskPriority.icon)
                    .font(.caption2)
                Text(taskPriority.label)
                    .font(.caption)
            }
            .foregroundStyle(taskPriority.color)
        }
    }
}

// MARK: - Project Badge

struct ProjectBadge: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 8, height: 8)
            Text(project.title)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
