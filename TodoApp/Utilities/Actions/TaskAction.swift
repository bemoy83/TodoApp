//
//  TaskAction.swift
//  Utilities/Actions
//

import SwiftUI

enum TaskAction: Equatable {
    case complete
    case uncomplete
    case startTimer
    case stopTimer
    case duplicate
    case setPriority(Int)          // use existing priority scale (rawValue on Task.priority)
    case moveToProject(Project)    // existing Project type
    case addSubtask                // intent only; UI handled elsewhere
    case delete
    case edit   // navigation intent; router just signals it

    // MARK: - Metadata

    struct Metadata: Equatable {
        let label: String
        let systemImage: String
        let isDestructive: Bool
        let preferredTint: Color?
        init(label: String, systemImage: String, isDestructive: Bool = false, preferredTint: Color? = nil) {
            self.label = label
            self.systemImage = systemImage
            self.isDestructive = isDestructive
            self.preferredTint = preferredTint
        }
    }

    /// Canonical label/icon/tint for consistent UI across surfaces.
    var metadata: Metadata {
        switch self {
        case .complete:
            return .init(label: "Complete", systemImage: "checkmark.circle.fill", preferredTint: DesignSystem.Colors.success)
        case .uncomplete:
            return .init(label: "Uncomplete", systemImage: "arrow.uturn.backward.circle", preferredTint: DesignSystem.Colors.warning)
        case .startTimer:
            return .init(label: "Start Timer", systemImage: "timer", preferredTint: DesignSystem.Colors.info)
        case .stopTimer:
            return .init(label: "Stop Timer", systemImage: "stop.circle.fill", preferredTint: DesignSystem.Colors.error)
        case .duplicate:
            return .init(label: "Duplicate", systemImage: "doc.on.doc", preferredTint: nil)
        case .setPriority:
            // Specific color handled by caller based on selected Priority level.
            return .init(label: "Set Priority", systemImage: "flag.fill", preferredTint: nil)
        case .moveToProject:
            return .init(label: "Move to Project", systemImage: "folder", preferredTint: nil)
        case .addSubtask:
            return .init(label: "Add Subtask", systemImage: "plus.square.on.square", preferredTint: nil)
        case .delete:
            return .init(label: "Delete", systemImage: "trash.fill", isDestructive: true, preferredTint: DesignSystem.Colors.error)
        case .edit:
            return .init(label: "Edit", systemImage: "pencil", preferredTint: nil)
        }
    }
}
