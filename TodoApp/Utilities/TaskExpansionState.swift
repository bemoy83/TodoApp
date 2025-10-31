import SwiftUI
internal import Combine

/// Manages which parent tasks have their subtasks expanded.
/// State persists across app launches using UserDefaults.
class TaskExpansionState: ObservableObject {  // ✅ Changed from @Observable
    static let shared = TaskExpansionState()
    
    private let defaults = UserDefaults.standard
    private let key = "expandedTaskIDs"
    
    @Published private(set) var expandedIDs: Set<UUID> = []  // ✅ Now @Published
    
    private init() {
        // Load from UserDefaults on init
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            expandedIDs = decoded
        }
    }
    
    /// Save to UserDefaults
    private func save() {
        if let encoded = try? JSONEncoder().encode(expandedIDs) {
            defaults.set(encoded, forKey: key)
        }
    }
    
    /// Check if a task is expanded
    func isExpanded(_ taskID: UUID) -> Bool {
        expandedIDs.contains(taskID)
    }
    
    /// Toggle expansion state for a task
    func toggle(_ taskID: UUID) {
        if expandedIDs.contains(taskID) {
            expandedIDs.remove(taskID)
        } else {
            expandedIDs.insert(taskID)
        }
        save()
    }
    
    /// Expand a task
    func expand(_ taskID: UUID) {
        expandedIDs.insert(taskID)
        save()
    }
    
    /// Collapse a task
    func collapse(_ taskID: UUID) {
        expandedIDs.remove(taskID)
        save()
    }
    
    /// Collapse all tasks
    func collapseAll() {
        expandedIDs = []
        save()
    }
}
