# TodoApp Project Context

## Overview
TodoApp is a SwiftUI-based task management application with hierarchical task organization, time tracking, and project management capabilities.

## Core Architecture

### Data Models (SwiftData)
- **Task**: Primary model with subtasks, dependencies, time tracking, and project association
- **Project**: Container for tasks with color coding and progress tracking
- **TimeEntry**: Time tracking entries linked to tasks
- **Priority**: Enum for task prioritization (0=urgent, 1=high, 2=medium, 3=low)
- **TaskStatus**: Computed from completion state and dependencies (ready, inProgress, blocked, completed)

### Task Hierarchy
- Tasks can have subtasks (one level deep only)
- Subtasks inherit project from parent
- Time tracking aggregates up through hierarchy (directTimeSpent + subtask totals)
- Dependencies can exist at both parent and subtask levels
- Moving subtasks between parents updates project inheritance and recalculates order

### Key Features
1. **Task Management**
   - Create, edit, delete, complete/uncomplete tasks
   - Reorder tasks within lists
   - Move subtasks between parent tasks with validation
   - Filter by status (all, active, completed, blocked)
   - Search functionality

2. **Time Tracking**
   - Start/stop timers on tasks
   - Automatic status changes (ready → inProgress when timer starts)
   - Time aggregation through subtask hierarchy
   - Prevents timer operations on blocked tasks
   - Validates timer state before moving tasks

3. **Dependencies**
   - Tasks can depend on other tasks
   - Automatic status calculation (blocked if dependencies incomplete)
   - Prevents circular dependencies
   - Per-subtask toggle for advanced users

4. **Projects**
   - Color-coded project organization
   - Project-level time tracking and progress
   - Tasks inherit project from parent task

5. **Time Estimation & Progress Tracking**
   - **Storage**: Minutes (efficient database storage)
   - **Calculation**: Seconds (accurate live updates)

6. **Modern UI Design (Oct 2025)**
   - Consistent spacing using DesignSystem values (xxs→xxxl)
   - Section-based detail views with 44pt+ touch targets
   - Inline editing for common actions (title, priority, status)
   - Conditional rendering (only show sections with data)
   - Reusable badge components (Status, Priority, Project, DueDate, Subtasks)
   - Native search with toolbar activation
   - Card-style sections replacing heavy GroupBox styling
   - **Display**: Minutes/hours (user-friendly)
   
   **Estimate Types**:
   - Manual estimates: User sets expected duration
   - Calculated estimates: Auto-sum from subtask estimates
   - Custom overrides: Parent can override calculated total (must be ≥ subtask sum)
   
   **Progress Tracking**:
   - Live updates every 30 seconds when timers running
   - Progress bars show time vs estimate (0-100%+)
   - Status badges: On Track (<75%), Warning (75-100%), Over (>100%)
   - Remaining time display when timer active
   
   **Progress Visualization**:
   - Time progress: Shows when timer running OR >75% time used
   - Subtask progress: Shows when no time estimate but has subtasks
   - Color-coded: Green (on track), Orange (warning), Red (over)
   - Percentage display with animated transitions
   
   **Badge System**:
   - TimeEstimateBadge: Shows actual/estimated time with status color
   - RemainingTimeBadge: Compact display when timer running (e.g., "15m left")
   - FlowLayout: Badges wrap to multiple rows on narrow screens
   
   **Time Rounding**:
   - Stored as minutes for efficiency
   - Calculated with second-precision for accuracy
   - Rounds to nearest minute on timer stop (prevents display inconsistencies)
   - Example: 2m 15s rounds to 2m, 2m 45s rounds to 3m

6. **UI Features**
   - Expandable subtask views inline in lists
   - Progress bars showing subtask completion
   - Due date badges (overdue/today/tomorrow)
   - Priority indicators (urgent/high only)
   - Swipe actions and context menus
   - Haptic feedback throughout

## Recent Updates (Session: UI Refinement & Design Consistency)

### TaskRowView Modernization
**Problem**: Rows felt "chubby" with excessive padding and wasted space
**Solution**: Systematic spacing reduction
- VStack spacing: `.sm` (12-16pt) → `.xs` (4pt)
- Content padding: Removed vertical padding entirely
- List row insets: Variable `.xs` → Fixed 4pt top/bottom
- Gutter width: ~80pt → 56pt (button 48pt → 40pt)
- **Result**: ~12-16pt saved per row, cleaner modern look

**Subtask Badge Repositioning**:
- Moved from metadata row to title row (right-aligned)
- Eliminates empty metadata rows when only subtask badge present
- Visual continuity - badge always in same spot
- Metadata row now only shows when it has actual content

### TaskListView Search Enhancement
**Implementation**: Native `.searchable()` with programmatic trigger
- Toolbar magnifying glass button activates search
- Uses `isPresented: $isSearching` binding
- `placement: .toolbar` - hidden until activated
- iOS Reminders-style: clean, minimal, integrated

### TaskDetailHeaderView Complete Redesign
**Philosophy Shift**: From badge-based (optimized for scanning) to section-based (optimized for interaction)

**Problem with Badges**:
- Tiny tap targets (~24pt)
- Chaotic when clustered
- Poor for inline editing
- Felt inconsistent with list view pattern

**New Sectioned Approach**:
1. **Title Section** (always shown)
   - Tap to edit inline
   - Large pencil icon on right
   - `.title3` font, semibold

2. **Status Section** (always shown)
   - Full-width button with 44pt+ tap target
   - Icon + status name + hint text
   - Colored background (status-specific)
   - Expandable blocking dependencies (if blocked)

3. **Dates Section** (conditional - only if has dates)
   - Created date (always)
   - Due date (if set, actionable)
   - Completed date (if completed)
   - Icon + label + value layout

4. **Organization Section** (conditional - only if has project)
   - Project badge (actionable for changing)
   - Priority menu (tap to change)
   - Consistent row layout

5. **Notes Section** (conditional - only if has notes)
   - Expandable/collapsible
   - Light gray background when expanded

**Section Header Pattern**:
- Uppercase `.caption` font
- Gray color (`.secondary`)
- Consistent spacing

**Benefits**:
- Proper touch targets (44pt minimum)
- Clear information hierarchy
- Better inline editing affordances
- Dynamic - sections only appear when relevant
- More space-efficient than old GroupBox approach

### Design System Enhancements

**New View Modifier**:
```swift
.detailCardStyle() // Replaces manual card styling
```
- Consistent padding, background, corner radius, shadow
- Used across TaskDetailHeaderView and future detail cards

**Badge Components** (Badges.swift):
- `StatusBadge`: Tappable status indicator
- `PriorityBadge`: Menu-based priority picker
- `ProjectBadge`: Project color dot + name
- All use design system colors/spacing

**Typography Rationalization**:
Reduced from 5 sizes to 3 core sizes:
- Section headers: `.caption` (11pt) - uppercase, gray
- Primary content: `.body` (17pt) - semibold for emphasis
- Secondary text: `.subheadline` (15pt) - values, hints
- Icons: `.body` consistently

**Spacing Values** (from DesignSystem.swift):
- `xxs`: 2pt (tight lists)
- `xs`: 4pt (compact spacing)
- `sm`: 8pt (comfortable spacing)
- `md`: 12pt (section gaps)
- `lg`: 16pt (major sections)
- `xl`: 20pt
- `xxl`: 24pt
- `xxxl`: 32pt

### Key Design Insights

**List View vs Detail View**:
- **List rows**: Optimize for scanning, compact, badge-based
- **Detail views**: Optimize for interaction, generous touch targets, section-based
- Different contexts need different patterns

**Conditional Rendering**:
- Only show sections when they have content
- Prevents UI bloat with empty states
- Computed properties control visibility

**Touch Target Discipline**:
- Minimum 44pt for primary actions
- Full-width buttons for common actions
- Clear visual affordance (chevrons, backgrounds)

### Files Modified This Session
- `TaskRowView.swift` - Spacing reduction, gutter optimization
- `TaskRowContent.swift` - Badge repositioning
- `TaskListView.swift` - Search implementation
- `TaskDetailHeaderView.swift` - Complete sectioned redesign
- `ViewModifiers.swift` - Added `.detailCardStyle()`
- `Badges.swift` - Added `StatusBadge`, `PriorityBadge`, `ProjectBadge`

## Recent Updates (Session: Task Moving & UI Refinements)

### Task Moving Between Parents
- **MoveToTaskPicker**: Full implementation for moving subtasks between parent tasks
  - Prevents circular dependencies (can't move parent into its own subtask tree)
  - Validates timer state (can't move tasks with active timers)
  - Updates project inheritance automatically
  - Recalculates order values for new parent
  - Includes 0.5s delay on dismiss to allow SwiftData propagation

### Query-Based Data Architecture
**Problem Solved**: `@Bindable` relationships don't update when changes happen in other contexts (like sheet dismissals)

**Solution**: Migrated all views to use `@Query` instead of relationship properties

**Updated Views**:
- `TaskRowView`: Query-based subtask counts and completion tracking
- `TaskExpandedSubtasksView`: Query-based subtask filtering by parent ID
- `TaskSubtasksView`: Query-based subtask lists
- `TaskDetailHeaderView`: Query-based parent task lookup
- `TaskTimeTrackingView`: Query-based recursive time calculation
- `ProjectRowView`: Query-based task counts and time totals
- `ProjectDetailView`: Query-based project task filtering

**Key Pattern**:
```swift
// Old (broken when changes happen elsewhere)
private var subtasks: [Task] {
    task.subtasks ?? []
}

// New (always fresh)
@Query(sort: \Task.order) private var allTasks: [Task]
private var subtasks: [Task] {
    allTasks.filter { $0.parentTask?.id == task.id }
}
```

### TaskRowView Enhancements

**Progress Visualization**:
- Progress bar showing subtask completion percentage
- Color-coded: gray (0%) → blue (1-99%) → green (100%)
- Animated transitions on completion state changes
- Percentage display aligned right

**Layout Refinements**:
- Subtask badge moved to top-right for consistency
- Expansion chevron fixed to bottom-center (always in same spot)
- Count + percentage display for better information density
- Tighter spacing for more compact rows
- Vertical padding reduced for slimmer appearance

**Current Layout**:
```
┌─────────────────────────────────┐
│ [○] Task Title            [2/5] │ ← Badge right-aligned
│     📅 Due Date                 │
│     ████████░░░░░░         40%  │ ← Progress + percentage
│              ▼                  │ ← Chevron centered
└─────────────────────────────────┘
```

### Subtask View Refinements

**TaskExpandedSubtasksView**:
- Removed redundant status text ("In Progress", "Blocked")
- Rely on icon color for status indication
- Cleaner, more scannable inline view

**TaskSubtasksView** (Detail View):
- Added priority badges (urgent/high only)
- Added due date indicators (overdue/today/tomorrow)
- Added time spent display
- More informative for task planning

### TaskExpansionState Improvements
- Centralized expansion state management
- Shared singleton for consistent state across views
- Works in both TaskListView and ProjectDetailView
- Smooth spring animations on expand/collapse

### Architecture Patterns Established

**Query-Based Views**: All relationship-dependent views now use `@Query` for reactive updates
**Recursive Calculations**: Time tracking properly aggregates through subtask hierarchies
**Context Propagation**: SwiftData changes properly sync across view hierarchies
**Defensive Coding**: Nil-coalescing for optional orders, safe parent lookups

### Known Limitations
- Card-style list rows attempted but reverted due to List spacing issues
- Custom card modifiers created (CardStyleModifiers.swift) but not currently in use
- May revisit card styling with different approach in future

### Testing Improvements
All task movement scenarios validated:
- ✅ Move subtask between parents updates time correctly
- ✅ Parent task counts update immediately
- ✅ Project time totals recalculate properly
- ✅ Expansion state persists during moves
- ✅ No phantom tasks or disappearing subtasks
- ✅ Timer state properly validated before moves

## Data Flow Architecture

### Query-Based Reactivity
All views that display relationships use `@Query` to ensure updates propagate correctly:

1. **User makes change** (e.g., moves subtask in MoveToTaskPicker)
2. **modelContext.save()** persists to SwiftData
3. **@Query observers** automatically detect change
4. **Views recompute** filtered/sorted data
5. **UI updates** with animations

### Why Not @Bindable Relationships?
- `@Bindable` caches relationship data
- Changes in other contexts (sheets, background) don't trigger updates
- `@Query` always fetches fresh data from SwiftData store
- Small performance cost, but ensures correctness

### Time Calculation Pattern
```swift
// Recursive aggregation through query
private func computeTotalTime(for task: Task) -> Int {
    var total = task.directTimeSpent
    let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
    for subtask in subtasks {
        total += computeTotalTime(for: subtask)
    }
    return total
}
```

## Key Files

### Models
- **Task.swift**: Core task model with computed properties (status, totalTimeSpent, hasActiveTimer, etc.)
- **Project.swift**: Project model with task aggregations
- **TimeEntry.swift**: Time tracking entry model
- **Enums.swift**: Priority, TaskStatus, TaskFilter enums

### Views - Task Management
- **TaskListView.swift**: Main task list with sections, filtering, reordering, and expansion support
- **TaskRowView.swift**: Parent task display with progress bar, query-based subtask tracking, compact layout
- **TaskExpandedSubtasksView.swift**: Inline subtask display with query-based filtering and reordering
- **TaskDetailView.swift**: Detailed task view with all components
- **TaskDetailHeaderView.swift**: Task header with status, metadata, and query-based parent lookup
- **TaskSubtasksView.swift**: Detail view subtasks with priority, due dates, time spent (query-based)
- **TaskTimeTrackingView.swift**: Timer controls with recursive time calculation via query
- **TaskDependenciesView.swift**: Dependency management with blocking indicators
- **TaskEditView.swift**: Task editing form
- **AddTaskView.swift**: New task creation sheet
- **MoveToTaskPicker.swift**: Sheet for moving subtasks between parents with circular dependency prevention

### Views - Projects
- **ProjectListView.swift**: Project overview with reordering
- **ProjectDetailView.swift**: Project tasks with query-based filtering and expansion support
- **ProjectRowView.swift**: Project list row with query-based time and task count calculations
- **ProjectHeaderView.swift**: Project detail header with statistics
- **AddProjectSheet.swift**: New project creation
- **EditProjectSheet.swift**: Project editing

### Views - Components
- **TaskMoreActionsSheet.swift**: Quick actions menu (delete, duplicate, move, change priority, set due date)
- **DependencyPickerView.swift**: Dependency selection interface
- **TaskEmptyStateView.swift**: Empty state for task lists
- **SubtasksBadge.swift**: Subtask count indicator
- **DueDateBadge.swift**: Due date display with color coding
- **TaskRowCalculations.swift**: Time/progress computation logic separated from UI
- **TaskRowContent.swift**: Badge and progress bar UI components (TimeEstimateBadge, RemainingTimeBadge, TaskRowProgressBar)
- **FlowLayout.swift**: Responsive badge wrapping layout for narrow screens

### Utilities
- **TaskExpansionState.swift**: Centralized expansion state management (singleton)
- **TaskActionRouter.swift**: Centralized task action coordination with executor pattern
- **TaskActionExecutor.swift**: Executes task actions with validation and alerts
- **TaskActionAlert.swift**: Alert model for user confirmations/errors
- **Reorderer.swift**: Generic reordering utility used across all list views
- **HapticManager.swift**: Haptic feedback coordinator
- **DesignSystem.swift**: Centralized design tokens (colors, spacing, typography)

### View Modifiers
- **TaskActionAlertModifier.swift**: Presents task action alerts
- **RowSwipeActions.swift**: Swipe action configuration
- **RowContextMenu.swift**: Context menu configuration

### Services
- **TaskService.swift**: Business logic for dependencies and status calculation

## Design System

### Colors
- Task status colors (blocked: orange, ready: blue, inProgress: blue, completed: green)
- Timer active: red with pulsing animation
- Priority colors (urgent: red, high: orange, medium: blue, low: gray)
- Semantic colors (primary, secondary, tertiary, background variations)

### Spacing Scale
- xxs: 2pt
- xs: 4pt
- sm: 8pt
- md: 12-16pt
- lg: 20-24pt
- xl: 32pt
- xxl: 48pt
- xxxl: 64pt

### Typography
- Title, headline, body, subheadline, caption scales
- Monospaced digits for counts and percentages
- Dynamic type support

### Animations
- Spring animations for expansion/collapse (response: 0.3, dampingFraction: 0.7)
- Standard easeInOut for progress bars (duration: 0.3)
- Symbol effects for icon transitions (.replace)
- Reduce motion support for accessibility

## Common Patterns

### Task Actions
All task actions (complete, delete, duplicate, etc.) go through:
1. **TaskActionRouter**: Routes action to appropriate executor
2. **TaskActionExecutor**: Validates and executes with error handling
3. **TaskActionAlert**: Presents confirmation/error to user
4. **HapticManager**: Provides tactile feedback

### Swipe Actions
Consistent across all task rows:
- Leading: Complete/Uncomplete
- Trailing: More actions menu

### Context Menus
Long-press on any task reveals:
- Complete/Uncomplete
- Edit
- Delete
- Duplicate
- Move to parent
- Change priority
- Set due date

### List Reordering
All lists support drag-to-reorder in edit mode:
1. Tap "Reorder" button
2. Enter edit mode
3. Drag tasks to new positions
4. Order property updates automatically
5. Changes persist via Reorderer utility

## Development Notes

### SwiftData Relationships
- Use `@Query` for all views that depend on relationships
- Never trust `@Bindable` for relationship data across contexts
- Always filter by ID: `allTasks.filter { $0.parentTask?.id == taskId }`
- Use nil-coalescing for optional order values: `$0.order ?? Int.max`

### Time Tracking
- `directTimeSpent`: Only time on this specific task
- `totalTimeSpent`: Recursive sum of direct time + all subtask times
- Computed properties use query-based recursive calculation
- Always validate timer state before operations

### Status Calculation
- Auto-computed from completion and dependencies
- `blocked`: Has incomplete dependencies (own or subtask dependencies)
- `inProgress`: Has active timer
- `completed`: isCompleted flag set
- `ready`: Default state

### Subtask Rules
- Only one level deep (subtasks can't have subtasks)
- Inherit project from parent
- Can have own dependencies (opt-in for subtasks)
- Can be moved between parents with validation
- Contribute time upward to parent

### Error Handling
- TaskActionExecutor validates all operations
- Presents user-friendly alerts via TaskActionAlert
- Haptic feedback for success/failure
- Graceful degradation on edge cases

## Future Considerations
- Card-style list rows (needs custom List replacement)
- Tags/labels system
- Recurring tasks
- Calendar integration
- Notifications for due dates
- Data export/import
- Collaboration features

## Testing Checklist
- [ ] Create/edit/delete tasks
- [ ] Complete/uncomplete with dependencies
- [ ] Start/stop timers
- [ ] Move subtasks between parents
- [ ] Reorder tasks in lists
- [ ] Filter and search
- [ ] Add/remove dependencies
- [ ] Time aggregation accuracy
- [ ] Project time calculations
- [ ] Expansion state persistence
- [ ] Swipe actions functionality
- [ ] Context menu actions
- [ ] Haptic feedback
- [ ] Accessibility (VoiceOver, Dynamic Type, Reduce Motion)
