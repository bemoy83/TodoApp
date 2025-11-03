//
//  TaskRowCalculations.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 28/10/2025.
//


import SwiftUI
import SwiftData

/// Helper for calculating time tracking and progress metrics for TaskRowView
/// Separates computation logic from UI rendering
struct TaskRowCalculations {
    let task: Task
    let allTasks: [Task]
    let currentTime: Date
    
    // MARK: - Subtask Counts
    
    var subtaskCount: Int {
        allTasks.filter { $0.parentTask?.id == task.id }.count
    }
    
    var completedDirectSubtaskCount: Int {
        allTasks.filter { $0.parentTask?.id == task.id && $0.isCompleted }.count
    }
    
    var hasSubtasks: Bool {
        subtaskCount > 0
    }
    
    // MARK: - Time Calculations

    /// Total time spent in SECONDS (accurate for progress calculations)
    var totalTimeSpentSeconds: Int {
        var total = task.directTimeSpent  // Already in seconds

        // Add live session if main task timer is running
        if task.hasActiveTimer {
            total += currentSessionSeconds
        }

        // Add time from subtasks (recursive, includes their live sessions)
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }

        return max(0, total)
    }

    /// Total time spent in MINUTES for display (backward compatibility)
    var totalTimeSpent: Int {
        totalTimeSpentSeconds / 60
    }

    /// Current session seconds for main task
    private var currentSessionSeconds: Int {
        guard task.hasActiveTimer,
              let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) else {
            return 0
        }
        let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
        return max(0, Int(elapsed))
    }

    /// Recursive helper to compute total time including live sessions in SECONDS
    private func computeTotalTimeSeconds(for task: Task) -> Int {
        var total = task.directTimeSpent  // Already in seconds

        // Add live session for this specific task
        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                total += max(0, Int(elapsed))
            }
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeSeconds(for: subtask)
        }
        return max(0, total)
    }
    
    // MARK: - Time Estimate Progress

    /// Live time progress calculation (includes running timers)
    /// Now uses seconds for precision (matches TaskTimeTrackingView)
    var liveTimeProgress: Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        return Double(totalTimeSpentSeconds) / Double(estimate)  // seconds / seconds
    }
    
    /// Live estimate status (includes running timers)
    var liveEstimateStatus: TimeEstimateStatus? {
        guard let progress = liveTimeProgress else { return nil }
        
        if progress >= 1.0 {
            return .over
        } else if progress >= 0.75 {
            return .warning
        } else {
            return .onTrack
        }
    }
    
    /// Live remaining time (includes running timers) - in minutes
    var liveTimeRemaining: Int? {
        guard let estimate = task.effectiveEstimate else { return nil }
        let remainingSeconds = estimate - totalTimeSpentSeconds  // seconds - seconds
        return remainingSeconds / 60  // Convert to minutes for display
    }
    
    // MARK: - Timer Status
    
    /// Check if task or any subtask has active timer
    var hasAnyTimerRunning: Bool {
        if task.hasActiveTimer {
            return true
        }
        return checkSubtasksForTimer(in: allTasks.filter { $0.parentTask?.id == task.id })
    }
    
    private func checkSubtasksForTimer(in subtasks: [Task]) -> Bool {
        for subtask in subtasks {
            if subtask.hasActiveTimer {
                return true
            }
            let nestedSubtasks = allTasks.filter { $0.parentTask?.id == subtask.id }
            if checkSubtasksForTimer(in: nestedSubtasks) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Progress Bar Logic
    
    /// Determine which progress bar to show (contextual)
    var shouldShowTimeProgress: Bool {
        guard task.effectiveEstimate != nil else { return false }

        // Show progress bar when timer is running
        if hasAnyTimerRunning {
            return true
        }

        // Show progress bar when approaching estimate (75%+)
        if let progress = task.timeProgress, progress >= 0.75 {
            return true
        }

        return false
    }
    
    var shouldShowSubtaskProgress: Bool {
        !shouldShowTimeProgress && subtaskCount > 0
    }
    
    // MARK: - Subtask Progress
    
    var subtaskProgressPercentage: Double {
        guard subtaskCount > 0 else { return 0 }
        return Double(completedDirectSubtaskCount) / Double(subtaskCount)
    }
    
    func subtaskProgressColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return DesignSystem.Colors.taskCompleted
        } else if subtaskProgressPercentage == 0 {
            return DesignSystem.Colors.taskReady
        } else if subtaskProgressPercentage < 1.0 {
            return DesignSystem.Colors.taskInProgress
        } else {
            return DesignSystem.Colors.taskCompleted
        }
    }
}