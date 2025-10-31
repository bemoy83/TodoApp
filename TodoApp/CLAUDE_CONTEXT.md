# CLAUDE_CONTEXT.md

I'm working on an iOS todo app in Swift/SwiftUI and need help with implementation, architecture, and code generation.

## YOUR ROLE:
You are my development partner. Your job is to:
- Implement features and write production-ready code
- Help solve bugs and performance issues
- Propose improvements and discuss tradeoffs
- Guide architecture and design decisions
- Answer Swift/SwiftUI questions
- Provide code examples and complete implementations

## MY APP - CURRENT STATE:

### MODELS (SwiftData):
- **Project**: title, color, order, tasks relationship
- **Task**: title, priority (0-3), dueDate, completedDate, createdDate, notes, order, project, parentTask, subtasks, dependsOn (dependencies), blockedBy, timeEntries, **estimatedMinutes, hasCustomEstimate**
- **TimeEntry**: startTime, endTime (nil = running), task
- **Priority** enum: urgent(0), high(1), medium(2), low(3)
- **TaskFilter** enum: all, active, completed, blocked
- **TaskStatus** enum: ready, inProgress, blocked, completed (computed, not stored)
- **TimeEstimateStatus** enum: onTrack, warning, over (for progress visualization)

### KEY FEATURES IMPLEMENTED:
✅ Projects with color coding and time summaries
✅ Tasks with full CRUD operations
✅ One-level subtasks (no sub-subtasks) with inline expansion
✅ Task dependencies (many-to-many) with circular prevention
✅ Computed task status: ready, inProgress, blocked, completed
✅ Completion guards (can't complete blocked tasks without override)
✅ Time tracking with start/stop timer and recursive aggregation
✅ Time estimation with manual/calculated/custom estimates
✅ Progress tracking with live updates (30s refresh when timers active)
✅ Contextual progress bars (time estimate OR subtask completion)
✅ Drag-to-reorder for tasks, projects, subtasks (using order property)
✅ Search and filter (all/active/completed/blocked)
✅ Move subtasks between parents with validation
✅ Progress bars showing subtask completion or time estimate progress
✅ Expandable subtask views in both list and project detail views
✅ Swipe actions and context menus with centralized routing
✅ Haptic feedback throughout
✅ Settings page with data management

### CRITICAL ARCHITECTURE PATTERN: Query-Based Views

**🎯 ALWAYS use `@Query` for relationship-dependent data, NEVER use `@Bindable` relationships directly.**

**Why**: `@Bindable` caches relationship data and doesn't update when changes happen in other contexts (sheets, navigation, etc.). `@Query` always fetches fresh data from SwiftData.

**Pattern**:
```swift
// ❌ WRONG - will be stale after changes in other contexts
private var subtasks: [Task] {
    task.subtasks ?? []
}

// ✅ CORRECT - always fresh
@Query(sort: \Task.order) private var allTasks: [Task]
private var subtasks: [Task] {
    allTasks.filter { $0.parentTask?.id == task.id }
}
```

**Views using this pattern**:
- TaskRowView (subtask counts)
- TaskExpandedSubtasksView (subtask list)
- TaskSubtasksView (detail view subtasks)
- TaskDetailHeaderView (parent lookup)
- TaskTimeTrackingView (recursive time)
- ProjectRowView (task counts/time)
- ProjectDetailView (task filtering)

### ARCHITECTURE:
- Target: iOS 17+, Swift 5.9+, SwiftData
- Design system: DesignSystem.swift with centralized Colors, Spacing, Typography, CornerRadius, Animation
- View modifiers: Reusable styles (.cardStyle, .primaryButtonStyle, etc.)
- Centralized actions: TaskActionRouter + TaskActionExecutor pattern
- Expansion state: TaskExpansionState singleton for consistent UI
- File structure: Organized by feature (Tasks/, Projects/, Settings/)

### DESIGN DECISIONS:
- **Subtasks**: One level only, inherit project from parent, can be moved between parents
- **Status**: Fully computed (not stored), always accurate from dependencies and completion
- **Time**: Recursive aggregation via query (subtasks roll up to parent)
- **Reordering**: Edit mode with native .onMove, order property persists
- **Empty states**: Contextual messages based on filter/search
- **Expansion**: Centered chevron at bottom, progress bar above
- **Actions**: All go through TaskActionRouter → TaskActionExecutor → TaskActionAlert
- **Dark mode**: All colors use semantic system colors

### TASK ROW LAYOUT (Current):
```
┌─────────────────────────────────┐
│ [○] Task Title            [2/5] │ ← Badge right-aligned
│     📅 Due Date  ⏱️ 2h/3h       │ ← Badges wrap if needed
│     ████████░░░░░░         40%  │ ← Progress + percentage
│              ▼                  │ ← Chevron centered
└─────────────────────────────────┘
```

**Progress bar logic**:
- Shows **time progress** when: timer running OR >75% time used
- Shows **subtask progress** when: no time estimate but has subtasks
- Color: Green (on track) → Orange (warning) → Red (over)

### FILE ORGANIZATION:
```
Views/
├── Tasks/ (TaskListView, TaskRowView, TaskExpandedSubtasksView, etc.)
│   ├── TaskRowCalculations.swift (time/progress computation logic)
│   └── TaskRowContent.swift (badge/progress UI components)
├── Projects/ (ProjectListView, ProjectRowView, ProjectDetailView, etc.)
├── Components/ (DueDateBadge, SubtasksBadge, TaskMoreActionsSheet, FlowLayout, etc.)
└── Settings/ (SettingsView, various section components)

Models/ (Task, Project, TimeEntry, Enums)

Services/ (TaskService with business logic)

Utilities/
├── TaskActionRouter.swift (action coordination)
├── TaskActionExecutor.swift (action execution with validation)
├── TaskActionAlert.swift (alert model)
├── TaskExpansionState.swift (expansion singleton)
├── Reorderer.swift (generic reordering)
├── HapticManager.swift (haptic feedback)
└── DesignSystem.swift (design tokens)

ViewModifiers/
├── TaskActionAlertModifier.swift
├── RowSwipeActions.swift
├── RowContextMenu.swift
└── Various style modifiers
```

### COMMON PATTERNS:

**Task Actions Flow**:
1. User triggers action (tap, swipe, context menu)
2. TaskActionRouter receives action
3. TaskActionExecutor validates and executes
4. TaskActionAlert presents result
5. HapticManager provides feedback

**Swipe Actions** (consistent everywhere):
- Leading: Complete/Uncomplete
- Trailing: More actions menu

**Time Calculation** (recursive via query):
```swift
private func computeTotalTime(for task: Task) -> Int {
    var total = task.directTimeSpent
    let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
    for subtask in subtasks {
        total += computeTotalTime(for: subtask)
    }
    return total
}
```

**Time Estimation** (storage vs calculation):
- **Storage**: Minutes (efficient, stored in `estimatedMinutes`)
- **Calculation**: Seconds (accurate for live timers)
- **Display**: Minutes/hours (user-friendly)
- **Rounding**: `Int((seconds / 60.0).rounded())` on timer stop
- **Types**: Manual (user sets), Calculated (sum of subtasks), Custom (override with validation)

**Reordering** (all lists):
```swift
Reorderer.reorder(
    items: tasks,
    currentOrder: { $0.order ?? Int.max },
    setOrder: { task, index in task.order = index },
    from: source,
    to: destination,
    save: { try modelContext.save() }
)
```

### DEVELOPMENT RULES:

1. **Always use @Query for relationships** - Never trust @Bindable across contexts
2. **Filter by ID, not object equality** - `$0.parentTask?.id == taskId`
3. **Nil-coalesce order values** - `$0.order ?? Int.max`
4. **Route actions through TaskActionRouter** - No duplicate business logic in views
5. **Validate before moving tasks** - Check timer state, circular dependencies
6. **Use HapticManager** - Consistent tactile feedback
7. **Follow DesignSystem** - Don't hardcode colors/spacing
8. **Keep views under 200 lines** - Extract components when needed
9. **Add delays after saves in sheets** - 0.5s for SwiftData propagation
10. **Test with expansion state** - Ensure UI updates when expanded
11. **⚠️ CRITICAL: Clear relationships before delete** - Always clear `dependsOn`, `blockedBy`, `subtasks`, `timeEntries`, `parentTask`, `project` before calling `modelContext.delete()` to avoid SwiftData "future" crashes

### KNOWN ISSUES:
- Card-style rows don't work well with List (spacing issues)
- CardStyleModifiers.swift exists but not currently used

### TESTING CHECKLIST:
When implementing features, validate:
- ✅ Works when task is expanded
- ✅ Works when task is collapsed
- ✅ Updates immediate after action
- ✅ Swipe actions still work
- ✅ Context menu still works
- ✅ Haptic feedback fires
- ✅ Works in edit/reorder mode
- ✅ Time calculations update
- ✅ Project totals update
- ✅ No crashes on edge cases

### RESPONSE STYLE:
**Keep responses SHORT and FOCUSED:**
- Brief explanation (2-3 sentences max)
- Code in artifacts (for any file or >30 lines)
- Key decisions in code comments
- No extensive documentation/summaries
- No multiple markdown files unless requested

**Code delivery:**
- ✅ USE artifacts for complete files
- ✅ USE artifacts for substantial code (>30 lines)
- ✅ Brief inline snippets for small changes (<20 lines)
- ❌ NO long explanations before/after code
- ❌ NO excessive documentation files

### EXAMPLE INTERACTION:
Me: "The subtask badge isn't updating when I move a task"
You: "This is the @Bindable relationship caching issue. Here's the fix using @Query..."
[artifact with complete updated file]

Ready to build! What would you like to work on?
