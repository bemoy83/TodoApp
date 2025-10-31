import SwiftUI
import SwiftData

/// Backwards-compatible wrapper so existing call sites keep working.
/// Internally delegates to the unified AddTaskView(project:).
struct AddTaskToProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    
    var body: some View {
        AddTaskView(project: project) { _ in
            // no-op; caller already gets model updates via SwiftData
            dismiss()
        }
    }
}
