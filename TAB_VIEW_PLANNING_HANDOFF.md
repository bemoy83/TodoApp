# Tab View Implementation - Planning Session Handoff

## Session Objective
Plan and design a **workflow-centric tab-based interface** for TaskDetailView that organizes information by the user's execution phases: **Plan → Execute → Review**.

---

## Project Context

### Application
**TodoApp** - Event management task tracking system for iOS (SwiftUI + SwiftData)

### User's Workflow
The user manages event setup tasks with a **distinct phase-based workflow**:
1. **Planning Phase:** Define scope, estimates, dependencies, crew requirements
2. **Execution Phase:** Track time, update progress, manage active work
3. **Review Phase:** Compare actual vs expected, analyze productivity

**Key User Requirement:** "Want zero distractions during time-critical moments" - execution phase must be streamlined.

### Current Implementation
- **Single scrolling detail view** with collapsible sections
- Smart context-aware defaults (execution mode, review mode, planning mode)
- Heavy scrolling required (~60% reduction goal with tabs)

---

## Current Branch State

**Branch:** `claude/collapsible-detail-sections-01MFSx9P76dB9pHNVDetGMU4`

### Recent Commits (Latest First)
1. **89bfd08** - Tab foundation improvements (time helpers, blocking analysis, quantity badge)
2. **dbd9441** - Separate expected/completed quantity tracking
3. **2a955e1** - Parent status propagation from subtasks
4. **8a6132d** - CompactTagSummary integration
5. **9b3a168** - Optional binding fixes
6. **72b7cb7** - Wrapped all sections with DetailSectionDisclosure
7. **ff33e07** - Created DetailSectionDisclosure component

### What's Complete
✅ Collapsible detail sections with smart defaults
✅ Expected vs completed quantity tracking (with progress bars)
✅ Parent task status propagates from subtask status
✅ Time entry helpers (todayEntries, todayHours, activeTimerEntry)
✅ Blocking analysis (blockingReasons, canStartWork)
✅ Progress summary badges for collapsed sections

---

## Technical Foundation (Ready for Tabs)

### Task Model Enhancements (Task.swift)

#### Quantity Tracking
```swift
var expectedQuantity: Double?       // Planning: target amount
var quantity: Double?                // Execution: actual completed
var quantityProgress: Double?        // 0.0 - 1.0+ (computed)
var quantityRemaining: Double?       // Expected - completed (computed)
var hasQuantityProgress: Bool        // Whether tracking is active (computed)
```

#### Time Entry Helpers
```swift
var activeTimerEntry: TimeEntry?     // Currently running timer
var todayEntries: [TimeEntry]        // Today's completed entries
var todayHours: Double               // Today's tracked hours
var todayPersonHours: Double         // Today's person-hours
```

#### Blocking Analysis
```swift
var blockingReasons: [String]        // ["Waiting on: Task A", "Subtask 'B' blocked by: Task C"]
var canStartWork: Bool               // Not blocked, not completed
var blockingDependencies: [Task]     // Incomplete dependencies
var blockingSubtaskDependencies: [(subtask: Task, dependency: Task)]
```

#### Status & Progress
```swift
var status: TaskStatus               // .blocked, .ready, .inProgress, .completed
var hasInProgressSubtasks: Bool      // Subtask status propagates up
var hasCompletedSubtasks: Bool       // Shows parent progress
```

#### Existing Properties (Already Available)
```swift
// Time tracking
var totalTimeSpent: Int              // Recursive sum including subtasks
var directTimeSpent: Int             // Only this task's time
var hasActiveTimer: Bool             // Timer running check
var effectiveEstimate: Int?          // Custom or calculated from subtasks

// Personnel
var expectedPersonnelCount: Int?     // Planned crew size

// Dependencies
var dependsOn: [Task]?               // Tasks this depends on
var hasIncompleteDependencies: Bool  // Blocked status check

// Subtasks
var subtasks: [Task]?                // Child tasks
var subtaskCount: Int                // Direct children count
var completedDirectSubtaskCount: Int // Completed children

// Dates
var dueDate: Date?
var startDate: Date?
var endDate: Date?
var completedDate: Date?

// Other
var tags: [Tag]?
var notes: String?
var priority: Int
```

---

## Current UI Structure

### TaskDetailView.swift (Main Detail View)
**Current Layout:**
```
ScrollView
  └─ VStack
      ├─ TaskDetailHeaderView (title, status, priority)
      ├─ DetailSectionDisclosure("Time Tracking") { TaskTimeTrackingView }
      ├─ DetailSectionDisclosure("Personnel") { TaskPersonnelView }
      ├─ DetailSectionDisclosure("Quantity") { TaskQuantityView }
      ├─ DetailSectionDisclosure("Tags") { TaskTagsView }
      ├─ DetailSectionDisclosure("Time Entries") { TimeEntriesView }
      ├─ DetailSectionDisclosure("Subtasks") { TaskSubtasksView }
      └─ DetailSectionDisclosure("Dependencies") { TaskDependenciesView }
```

**Smart Defaults Logic (in init):**
```swift
if task.hasActiveTimer {
    // Execution mode - focus on time tracking
    isTimeTrackingExpanded = true
    isEntriesExpanded = true
} else if task.isCompleted {
    // Review mode - show results
    isTimeTrackingExpanded = true
    isEntriesExpanded = (task.timeEntries?.count ?? 0) > 0
} else if (task.subtasks?.count ?? 0) > 0 || (task.dependsOn?.count ?? 0) > 0 {
    // Planning mode with structure
    isSubtasksExpanded = true
    isDependenciesExpanded = true
} else {
    // Default mode - show essentials
    isTimeTrackingExpanded = true
}
```

### DetailSectionDisclosure.swift (Reusable Component)
```swift
struct DetailSectionDisclosure<Content: View, Summary: View>: View {
    let title: String
    let icon: String?
    @Binding var isExpanded: Bool
    let summary: () -> Summary    // Badge when collapsed
    let content: () -> Content     // Full view when expanded
}
```

**Key Features:**
- Smooth animations
- Summary badges in collapsed state
- Chevron indicators
- Haptic feedback
- Generic content support

---

## Existing Section Views (Can Be Reused in Tabs)

### TaskTimeTrackingView.swift
- Timer start/stop controls
- Estimate display
- Progress indicators
- Uses: `task.hasActiveTimer`, `task.totalTimeSpent`, `task.effectiveEstimate`

### TaskQuantityView.swift
- **QuantityProgressRow** component (NEW)
  - Shows "45.5/60 m² (76%)" with progress bar
  - Color-coded (blue/yellow/green)
  - Tappable to edit
- Quantity editor picker
- Productivity metrics (when completed)

### TaskPersonnelView.swift
- Expected personnel count setting
- Personnel count picker

### TaskTagsView.swift
- Tag assignment/removal
- Hierarchical tag filtering
- CompactTagSummary component

### TimeEntriesView.swift
- List of time entries
- Add manual entry button
- Personnel count per entry

### TaskSubtasksView.swift
- Subtask list with status
- Add subtask navigation

### TaskDependenciesView.swift
- Shows dependsOn and blockedBy relationships
- Edit mode for managing dependencies
- Blocking indicators

---

## Design Constraints & Principles

### User Requirements
1. **Phase-Based Workflow:** Plan everything → Execute → Review results
2. **Zero Distractions:** Execution tab must be minimal and focused
3. **Distinct Phases:** Rarely adjust plan during execution
4. **Quick Access:** Common actions must be easy to reach
5. **Scrolling Reduction:** ~60% less scrolling (primary goal of tabs)

### Technical Constraints
1. **Reuse Existing Views:** Don't rebuild what works
2. **SwiftUI TabView:** Native iOS pattern
3. **Smart Defaults:** Auto-select relevant tab based on task state
4. **Collapsible Sections:** Keep within tabs or replace with tabs?
5. **No Quick Actions in Detail:** Quick actions handled in TaskListView (swipe actions)

### Design Patterns in Codebase
- **@Bindable** for SwiftData models
- **Computed properties** for derived state
- **ViewBuilder** for flexible composition
- **DetailSectionDisclosure** for consistent sections
- **HapticManager** for feedback
- **DesignSystem.Spacing/Colors** for consistency

---

## Questions to Address in Planning

### 1. Tab Structure
**Proposed:**
- **📋 Plan Tab:** Estimates, personnel, dependencies, subtasks, dates
- **⚡ Execute Tab:** Timer controls, today's progress, quantity tracking, blockers
- **📈 Review Tab:** Actual vs expected, productivity, time breakdown

**Decisions Needed:**
- Tab names? (Plan/Execute/Review vs Schedule/Work/Results vs other?)
- Tab icons?
- Tab order? (Should most common be first, or workflow order?)

### 2. Content Organization

**Option A: Tabs Replace Collapsing**
- Each tab shows all content expanded
- Simpler implementation
- More scrolling within tabs

**Option B: Collapsing Within Tabs**
- Keep DetailSectionDisclosure in each tab
- More compact
- Maintains current interaction pattern

**Option C: Hybrid**
- Some tabs expanded (Execute), others collapsed (Plan)
- Based on usage patterns

### 3. Section Mapping

**Which sections go in which tab?**

| Section | Plan Tab? | Execute Tab? | Review Tab? |
|---------|-----------|--------------|-------------|
| Time Tracking | ? | ? | ? |
| Personnel | ? | ? | ? |
| Quantity | ? | ? | ? |
| Tags | ? | ? | ? |
| Time Entries | ? | ? | ? |
| Subtasks | ? | ? | ? |
| Dependencies | ? | ? | ? |
| Notes | ? | ? | ? |

### 4. Smart Tab Selection

**When opening TaskDetailView, which tab shows?**

Proposed logic:
```swift
var defaultTab: TabType {
    if task.hasActiveTimer { return .execute }
    if task.isCompleted { return .review }
    if task.status == .blocked { return .plan } // See blockers
    if task.status == .ready { return .execute } // Ready to start
    return .plan // Default for new tasks
}
```

Is this correct? Other factors to consider?

### 5. Cross-Tab Actions

**Should some actions be accessible from all tabs?**
- Timer controls (start/stop)
- Status changes
- Quick notes
- Priority adjustment

**Implementation options:**
- Floating action button
- Toolbar items (tab-specific or global?)
- Always-visible header area above tabs

### 6. Header Treatment

**Current:** TaskDetailHeaderView (title, status, priority, notes toggle)

**Options:**
- Keep above tabs (always visible)
- Move into first tab
- Split across tabs
- Redesign for tab context

### 7. Visual Hierarchy

**Tab UI Style:**
- Native TabView with page style?
- Segmented control at top?
- Custom tab bar?

**Placement:**
- Tabs at top (below header)?
- Tabs at bottom (iOS standard)?

### 8. Execution Tab Specifics

**Must be streamlined. What's essential?**

Current thinking:
- Large timer button (start/stop)
- Today's hours prominently displayed
- Current quantity progress (if applicable)
- Blocking status (if blocked)
- Quick quantity update

**What's NOT needed:**
- Dependencies (that's planning)
- Full time entries list? (or just today's?)
- Full subtask breakdown? (or just summary?)

### 9. Animation & Transitions

- Tab switching animation?
- Content transitions?
- Maintain scroll position per tab?

### 10. Edge Cases

- Task with no estimates → what shows in Review tab?
- Task with no quantity tracking → hide Quantity section or show "Not tracked"?
- Parent task vs subtask differences in tabs?

---

## Key Files to Review

### Core Detail View
- `/Views/Tasks/TaskDetailView.swift` - Current main implementation
- `/Views/Tasks/Components/DetailSectionDisclosure.swift` - Reusable section component
- `/Views/Tasks/Components/TaskDetailHeaderView.swift` - Header implementation

### Section Components (Potential Tab Content)
- `/Views/Tasks/TaskTimeTrackingView.swift`
- `/Views/Tasks/TaskQuantityView.swift` (includes QuantityProgressRow)
- `/Views/Tasks/TaskPersonnelView.swift`
- `/Views/Tasks/TaskTagsView.swift`
- `/Views/TimeTracking/TimeEntriesView.swift`
- `/Views/Tasks/TaskSubtasksView.swift`
- `/Views/Tasks/Components/TaskDependenciesView.swift`

### Data Model
- `/Models/Task.swift` - All task properties and computed helpers

### Reference
- `/Models/Badges.swift` - Badge components (might be useful in tabs)
- `/Utilities/DesignSystem.swift` - Spacing/colors constants

---

## Success Criteria

A successful tab implementation should:

1. ✅ **Reduce scrolling by ~60%**
2. ✅ **Streamline execution phase** (zero distractions)
3. ✅ **Maintain quick access** to common actions
4. ✅ **Auto-select relevant tab** based on task state
5. ✅ **Reuse existing components** where possible
6. ✅ **Feel native to iOS** (smooth, familiar)
7. ✅ **Scale to parent/subtask contexts** (works for both)
8. ✅ **Preserve all current functionality** (nothing lost)

---

## Suggested Planning Approach

### Phase 1: Content Mapping
Map each current section to appropriate tabs, considering:
- User workflow phase
- Information priority
- Related information grouping

### Phase 2: Tab Structure Design
Define:
- Tab names, icons, order
- Header treatment
- Cross-tab actions
- Visual hierarchy

### Phase 3: Execution Tab Deep Dive
Design the most critical tab first:
- What's absolutely essential?
- What can be summarized?
- What's distracting?

### Phase 4: Implementation Strategy
Determine:
- TabView or custom tabs?
- Collapsing within tabs?
- Migration path from current implementation
- State management approach

### Phase 5: Edge Cases & Polish
Address:
- Empty states
- Parent vs subtask differences
- Animation details
- Accessibility

---

## Developer Notes

### Current Smart Defaults Are Excellent
The existing context-aware expansion logic is sophisticated. Tab selection should build on this intelligence, not replace it.

### Collapsible Sections Are Production-Ready
DetailSectionDisclosure is well-tested and flexible. Strong candidate for reuse within tabs if needed.

### Time Entry Helpers Are Fresh
The `todayEntries`, `todayHours`, `activeTimerEntry` helpers were JUST added. Execution tab should showcase these.

### Blocking Analysis Is Powerful
The `blockingReasons` array provides actionable information. Planning/Execution tabs should surface this clearly.

### Quantity Tracking Is Visual
The new QuantityProgressRow with progress bar is excellent for at-a-glance status. Should be prominent in Execute/Review tabs.

---

## Open Questions for User

Before detailed planning, clarify:

1. **Collapsing preference:** Keep collapsible sections within tabs, or eliminate collapsing entirely (tabs are the organization)?

2. **Cross-tab actions:** Should timer controls be accessible from all tabs, or only Execute tab?

3. **Tab switching frequency:** During a work session, will you switch tabs often, or stay in Execute tab?

4. **Review tab timing:** When do you review? During work (quick check) or after completion (full analysis)?

5. **Planning updates:** You said "rarely adjust plan during execution" - but when you do, should Plan tab show what's changed?

---

## Next Steps for Planning Session

1. **Read this handoff** to understand context
2. **Review key files** (TaskDetailView.swift, Task.swift at minimum)
3. **Propose tab structure** with detailed content mapping
4. **Design Execution tab** in detail (most critical)
5. **Create implementation plan** with phases
6. **Identify risks/challenges** in the approach
7. **Generate mockup descriptions** or ASCII diagrams if helpful

**Goal:** Exit planning session with a clear, detailed specification ready for implementation.

---

## Branch Reminder

All work happens on:
**`claude/collapsible-detail-sections-01MFSx9P76dB9pHNVDetGMU4`**

Do NOT merge or switch branches during planning. This is still the active feature branch.

---

## Final Context Note

This handoff was created at the end of a session that successfully implemented:
- Collapsible sections (complete)
- Quantity tracking separation (complete)
- Tab foundation helpers (complete)

The codebase is in excellent shape. The tab planning session should focus on UX design and content organization, not technical capability - the foundation is solid.
