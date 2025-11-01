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

    /// Total time spent including live sessions (parent + all subtasks recursively)
    /// Returns time in MINUTES for display
    var totalTimeSpent: Int {
        var total = task.directTimeSpent / 60  // Convert seconds to minutes for display

        // Add live session if main task timer is running
        if task.hasActiveTimer {
            total += currentSessionMinutes
        }

        // Add time from subtasks (recursive, includes their live sessions)
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }

        return max(0, total) // Ensure non-negative
    }
    
    /// Current session minutes for main task
    private var currentSessionMinutes: Int {
        guard task.hasActiveTimer,
              let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) else {
            return 0
        }
        let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
        return max(0, Int(elapsed / 60))
    }
    
    /// Recursive helper to compute total time including live sessions
    /// Returns time in MINUTES
    private func computeTotalTime(for task: Task) -> Int {
        var total = task.directTimeSpent / 60  // Convert seconds to minutes

        // Add live session for this specific task
        if task.hasActiveTimer {
            if let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
                let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
                let minutes = Int(elapsed / 60)
                total += max(0, minutes)
            }
        }

        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTime(for: subtask)
        }
        return max(0, total)
    }
    
    // MARK: - Time Estimate Progress
    
    /// Live time progress calculation (includes running timers)
    var liveTimeProgress: Double? {
        guard let estimate = task.effectiveEstimate, estimate > 0 else { return nil }
        let estimateMinutes = estimate / 60  // Convert seconds to minutes
        return Double(totalTimeSpent) / Double(estimateMinutes)
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
        let estimateMinutes = estimate / 60  // Convert seconds to minutes
        let spentMinutes = totalTimeSpent
        let remainingMinutes = estimateMinutes - spentMinutes
        return remainingMinutes
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
        
        if hasAnyTimerRunning {
            return true
        }
        
        if let progress = task.timeProgress {
            return progress >= 0.75
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