//
//  TaskActionAvailability.swift
//  Utilities/Actions
//

import Foundation

struct TaskActionAvailabilityContext: Equatable {
    let isCompleted: Bool
    let isSubtask: Bool
    let hasActiveTimer: Bool
    let inProjectDetail: Bool
    init(isCompleted: Bool, isSubtask: Bool, hasActiveTimer: Bool, inProjectDetail: Bool) {
        self.isCompleted = isCompleted
        self.isSubtask = isSubtask
        self.hasActiveTimer = hasActiveTimer
        self.inProjectDetail = inProjectDetail
    }
}

struct TaskActionAvailabilityProfile: Equatable {
    /// Order matters; first action in `swipeLeading` / `swipeTrailing` is the full-swipe primary.
    let swipeLeading: [TaskAction]
    let swipeTrailing: [TaskAction]
    let quickActions: [TaskAction]
    let editShortcuts: [TaskAction]
}

enum TaskActionAvailability {

    /// Produces a per-surface action set from the given context.
    /// Parameterized actions like `setPriority(_:)` / `moveToProject(_:)` are intentionally omitted here.
    static func profile(for ctx: TaskActionAvailabilityContext) -> TaskActionAvailabilityProfile {

        // Leading swipe: complete/uncomplete primary; timer secondary when relevant.
        let leading: [TaskAction] = {
            var items: [TaskAction] = []
            items.append(ctx.isCompleted ? .uncomplete : .complete)
            if !ctx.isCompleted {
                items.append(ctx.hasActiveTimer ? .stopTimer : .startTimer)
            }
            return items
        }()

        // Trailing swipe: edit only (More button). Delete moved to context menu for reliability.
        let trailing: [TaskAction] = [
            .edit
        ]

        // Quick Actions (sheet): Do + edit-lite + delete. No multi-field forms here.
        var quick: [TaskAction] = [
            ctx.isCompleted ? .uncomplete : .complete,
            ctx.hasActiveTimer ? .stopTimer : .startTimer,
            .duplicate,
            .edit,
            .delete
        ]
        if !ctx.isSubtask {
            quick.insert(.addSubtask, at: 2)
        }

        // Edit shortcuts: placeholders for Session 2.
        let editShortcuts: [TaskAction] = [
            .edit
        ]

        return TaskActionAvailabilityProfile(
            swipeLeading: leading,
            swipeTrailing: trailing,
            quickActions: quick,
            editShortcuts: editShortcuts
        )
    }
}
