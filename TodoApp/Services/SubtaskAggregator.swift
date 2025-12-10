import SwiftUI
import SwiftData

/// Aggregator service that caches recursive subtask calculations to improve performance
/// Solves O(n²) complexity issues when computing total time, personnel counts, etc. across deep subtask hierarchies
@MainActor
class SubtaskAggregator: ObservableObject {

    // MARK: - Cache Structures

    struct AggregatedStats {
        let totalTimeSeconds: Int
        let directTimeSeconds: Int
        let personnelCounts: [Int]
        let hasPersonnelTracking: Bool
        let totalPersonHours: Double
        let directPersonHours: Double
        let cachedAt: Date
    }

    // MARK: - Cache Storage

    private var cache: [UUID: AggregatedStats] = [:]
    private let cacheLifetime: TimeInterval = 1.0 // 1 second cache

    // MARK: - Public API

    /// Get aggregated stats for a task, using cache when available
    func getStats(
        for task: Task,
        allTasks: [Task],
        currentTime: Date
    ) -> AggregatedStats {
        let taskId = task.id

        // Check cache validity
        if let cached = cache[taskId],
           Date().timeIntervalSince(cached.cachedAt) < cacheLifetime {
            return cached
        }

        // Compute fresh stats
        let stats = computeStats(for: task, allTasks: allTasks, currentTime: currentTime)
        cache[taskId] = stats
        return stats
    }

    /// Invalidate cache for a specific task (call when task data changes)
    func invalidate(taskId: UUID) {
        cache.removeValue(forKey: taskId)
    }

    /// Invalidate entire cache (call on major data changes)
    func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Computation Logic

    private func computeStats(
        for task: Task,
        allTasks: [Task],
        currentTime: Date
    ) -> AggregatedStats {
        // Compute direct time (task itself)
        let directTime = computeDirectTime(for: task, currentTime: currentTime)

        // Compute total time (task + all subtasks recursively)
        let totalTime = computeTotalTimeRecursive(for: task, allTasks: allTasks, currentTime: currentTime)

        // Compute personnel counts
        let personnelCounts = collectPersonnelCounts(for: task, allTasks: allTasks)

        // Check if any entries have personnel > 1
        let hasPersonnelTracking = checkPersonnelTracking(for: task, allTasks: allTasks)

        // Compute person-hours
        let directPersonHours = computeDirectPersonHours(for: task, currentTime: currentTime)
        let totalPersonHours = computeTotalPersonHoursRecursive(for: task, allTasks: allTasks, currentTime: currentTime)

        return AggregatedStats(
            totalTimeSeconds: totalTime,
            directTimeSeconds: directTime,
            personnelCounts: personnelCounts,
            hasPersonnelTracking: hasPersonnelTracking,
            totalPersonHours: totalPersonHours,
            directPersonHours: directPersonHours,
            cachedAt: Date()
        )
    }

    // MARK: - Time Calculations

    private func computeDirectTime(for task: Task, currentTime: Date) -> Int {
        var totalSeconds = task.directTimeSpent

        // Add active timer time if running
        if task.hasActiveTimer,
           let activeEntry = task.timeEntries?.first(where: { $0.endTime == nil }) {
            let elapsed = currentTime.timeIntervalSince(activeEntry.startTime)
            totalSeconds += max(0, Int(elapsed))
        }

        return max(0, totalSeconds)
    }

    private func computeTotalTimeRecursive(
        for task: Task,
        allTasks: [Task],
        currentTime: Date
    ) -> Int {
        var total = computeDirectTime(for: task, currentTime: currentTime)

        // Add time from all subtasks recursively
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalTimeRecursive(for: subtask, allTasks: allTasks, currentTime: currentTime)
        }

        return max(0, total)
    }

    // MARK: - Personnel Calculations

    private func collectPersonnelCounts(for task: Task, allTasks: [Task]) -> [Int] {
        var counts: [Int] = []

        // Direct entries
        if let entries = task.timeEntries {
            counts.append(contentsOf: entries.map { $0.personnelCount })
        }

        // Subtask entries recursively
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            counts.append(contentsOf: collectPersonnelCounts(for: subtask, allTasks: allTasks))
        }

        return counts
    }

    private func checkPersonnelTracking(for task: Task, allTasks: [Task]) -> Bool {
        // Check direct entries
        if let entries = task.timeEntries, entries.contains(where: { $0.personnelCount > 1 }) {
            return true
        }

        // Check subtask entries recursively
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            if checkPersonnelTracking(for: subtask, allTasks: allTasks) {
                return true
            }
        }

        return false
    }

    // MARK: - Person-Hours Calculations

    private func computeDirectPersonHours(for task: Task, currentTime: Date) -> Double {
        guard let entries = task.timeEntries else { return 0.0 }

        return entries.reduce(0.0) { total, entry in
            let endTime = entry.endTime ?? (task.hasActiveTimer ? currentTime : nil)
            guard let end = endTime else { return total }

            // Use TimeEntryManager to calculate work hours only
            let durationSeconds = TimeEntryManager.calculateDuration(start: entry.startTime, end: end)
            let personHours = (durationSeconds / 3600.0) * Double(entry.personnelCount)

            return total + personHours
        }
    }

    private func computeTotalPersonHoursRecursive(
        for task: Task,
        allTasks: [Task],
        currentTime: Date
    ) -> Double {
        var total = computeDirectPersonHours(for: task, currentTime: currentTime)

        // Add person-hours from all subtasks recursively
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        for subtask in subtasks {
            total += computeTotalPersonHoursRecursive(for: subtask, allTasks: allTasks, currentTime: currentTime)
        }

        return total
    }
}
