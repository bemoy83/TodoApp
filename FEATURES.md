# TodoApp Feature List

## Quick Overview

**TodoApp** is a comprehensive exhibition and event management application designed for production teams who need to plan, track, and analyze complex projects with multiple tasks, crew requirements, and tight deadlines.

### Core Capabilities at a Glance

**Task Management**
- Hierarchical tasks with subtasks and dependencies
- Rich task properties: priority, dates, estimates, notes, quantities
- Drag-to-reorder, duplicate, archive functionality
- Advanced filtering and search

**Time Tracking & Estimation**
- Start/stop timers with crew size tracking
- Three estimation modes: Duration, Effort (person-hours), Quantity-based
- Live progress tracking with 30-second updates
- Historical accuracy analysis and learning

**Project Management**
- Color-coded projects with status tracking
- Budget management (estimated hours vs. actual)
- Crew planning with minimum personnel calculations
- Project health monitoring (On Track, Warning, Critical)

**Analytics & Reporting**
- KPI Dashboard with accuracy metrics and productivity rates
- 7 report types: Weekly, Monthly, Project Performance, Personnel Utilization, Task Efficiency, Budget Analysis, Task Type Efficiency
- Export to Markdown, Plain Text, or CSV
- Real-time analytics dashboard with attention-needed alerts

**Productivity Features**
- Task templates for common work types
- Custom units (m², meters, pieces, kg, liters)
- Task type analytics for improved estimates
- Tag system for organization (Resource, Phase, Location, Team, Vendor)

---

## Detailed Feature Reference

### 1. CORE TASK MANAGEMENT

#### Task Operations
- **CRUD**: Create, Read, Update, Delete tasks
- **Completion Tracking**: Mark complete/uncomplete with automatic completion date
- **Duplication**: Clone tasks with all properties
- **Archiving**: Archive completed tasks for cleaner views
- **Reordering**: Drag-to-reorder tasks with persistent ordering

**Location**: `TodoApp/Views/Tasks/AddTaskView.swift`, `TaskEditView.swift`, `TaskListView.swift`

#### Task Properties
Tasks include comprehensive metadata:
- **Basic**: Title, notes/description
- **Priority**: Urgent, High, Medium, Low (color-coded)
- **Dates**: Created, start, end, due, completed, archived
- **Estimation**: Time estimates in seconds (displayed as hours/minutes)
- **Resources**: Expected personnel count, effort hours (person-hours)
- **Productivity**: Quantity tracking, custom units, productivity rates
- **Organization**: Project assignment, tags, parent task

**Location**: `TodoApp/Models/Task.swift` (30+ computed properties)

#### Task Status System
Automatic status calculation (not manually set):
- **Ready**: No blockers, not completed
- **In Progress**: Active timer running
- **Blocked**: Has incomplete dependencies
- **Completed**: Marked as complete

Status is computed in real-time based on:
- Completion state
- Active timers
- Dependency resolution
- Blocking task detection

**Location**: `TodoApp/Models/Task.swift:status` (computed property)

---

### 2. TASK ORGANIZATION & HIERARCHY

#### Subtasks
One-level hierarchical structure:
- Subtasks cannot have their own subtasks (enforced)
- Inherit project from parent task
- Move between parents with validation
- Progress tracking (completion percentage)
- Inline expandable views in task lists
- Time and person-hours roll up recursively

**Features**:
- Query-based data architecture for real-time updates
- Subtask validation prevents circular relationships
- Automatic parent task updates when subtask changes

**Location**: `TodoApp/Views/Tasks/TaskExpandedSubtasksView.swift`, `Sheets/MoveToTaskSheet.swift`

#### Dependencies
Many-to-many task dependencies:
- Link tasks that must be completed in order
- Circular dependency prevention
- Automatic blocked status when dependencies incomplete
- Visual blocking dependency display
- Per-subtask dependency toggle (advanced)

**Validation**:
- Cannot depend on self
- Cannot create circular chains
- Prevents invalid dependency graphs

**Location**: `TodoApp/Views/Tasks/DependencyPickerView.swift`, `BlockingDependenciesView.swift`

#### Filtering & Search
- **Status Filters**: All, Active, Completed, Blocked
- **Archive Filters**: All, With Project, Without Project, With Subtasks
- **Search**: Native SwiftUI search with toolbar integration
- **Empty States**: Contextual messages based on filter state

**Location**: `TodoApp/Models/Enums/TaskFilter.swift`, various list views

---

### 3. TIME TRACKING & ESTIMATION

#### Time Tracking
Comprehensive time entry system:
- **Start/Stop Timers**: One active timer per task
- **Personnel Count**: Track crew size per time entry
- **Visual Indicators**: Pulsing animation for active timers
- **Manual Entries**: Create/edit time entries retroactively
- **History View**: All time entries with edit/delete
- **Auto-Stop**: Timer stops when task marked complete

**Metrics**:
- Direct time (task only)
- Total time (recursive through subtasks)
- Today's tracked time
- Person-hours calculation (time × personnel)

**Location**: `TodoApp/Views/TimeTracking/TaskTimeTrackingView.swift`, `ManualTimeEntrySheet.swift`, `TimeEntriesView.swift`

#### Time Estimation Modes

**1. Duration Mode**
Manual time estimates set by user:
- Quick entry for simple tasks
- Can be overridden on parent tasks
- Used as baseline for progress tracking

**2. Effort Mode**
Person-hours based estimation:
- Set effort hours (e.g., 40 person-hours)
- Set expected personnel count (e.g., 5 people)
- Duration = Effort ÷ Personnel (40 ÷ 5 = 8 hours)
- Useful for crew planning

**3. Quantity Mode**
Productivity-based calculations:
- Set quantity (e.g., 45.5 m²)
- Set productivity rate (e.g., 2.5 m²/person-hour)
- Set personnel count (e.g., 3 people)
- Duration = Quantity ÷ (Rate × Personnel)
- Uses historical data to improve accuracy

**Estimate Inheritance**:
- Manual: User sets explicit estimate
- Calculated: Auto-sum from subtasks
- Override: Parent can override (must be ≥ subtask sum)

**Location**: `TodoApp/Views/Tasks/Forms/TaskComposerForm.swift`, `TodoApp/Utilities/EstimationLimits.swift`

#### Progress Tracking
Real-time progress monitoring:
- **Live Updates**: Every 30 seconds when timers active
- **Progress Bars**: 0-100%+ with color coding
- **Status Colors**:
  - Green (On Track): < 75% of estimate used
  - Orange (Warning): 75-100% of estimate used
  - Red (Over): > 100% of estimate used
- **Remaining Time**: Countdown display when timer active
- **Accuracy Tracking**: Compare actual vs. estimated for completed tasks

**Smart Features**:
- Adaptive urgency thresholds (1.5× estimate or 2h minimum)
- Smart countdown on due dates based on estimate
- Different formats for list vs. detail views

**Location**: Progress bar components throughout views

---

### 4. PROJECT MANAGEMENT

#### Project Operations
- **CRUD**: Create, Read, Update, Delete projects
- **Color Coding**: Custom hex colors for visual organization
- **Reordering**: Drag-to-reorder with persistent order
- **Status Tracking**: Planning, In Progress, Completed, On Hold
- **Timeline**: Start date and due date (event timeline)
- **Budget**: Estimated hours for the entire project

**Location**: `TodoApp/Views/Projects/ProjectListView.swift`, `ProjectDetailView.swift`, `AddProjectView.swift`

#### Project Analytics
Comprehensive project health metrics:
- **Time Tracking**: Total hours spent across all tasks
- **Task Completion**: Incomplete vs. completed count
- **Blockers**: Count of blocked tasks
- **Overdue**: Count of tasks past due date
- **Estimates**: Tasks missing estimates count
- **Budget Variance**: Task estimates vs. project budget
- **Planning Progress**: % of budget allocated to tasks

**Health Status** (automatic):
- **On Track**: Good progress, no major issues
- **Warning**: Some concerns (overdue tasks, budget issues)
- **Critical**: Severe issues requiring attention

**Location**: `TodoApp/Models/Project.swift` (computed properties), `ProjectDetailView.swift`

#### Crew Planning
Advanced resource planning recommendations:
- **Minimum Personnel**: Calculate crew size needed to meet deadline
- **Scenarios**:
  - Recommended: Minimum crew size
  - Safe: With 10% buffer
  - Buffer: With 25% buffer
- **Historical Learning**: Uses task type analytics for accuracy
- **Available Hours**: Calculation from now to deadline
- **Warnings**: Alerts when deadlines are unrealistic
- **Auto-Expand**: Expands automatically in critical situations

**Smart Filtering**:
- Only considers tasks within project timeline
- Excludes tasks outside start/end dates
- Identifies and flags date conflicts

**Location**: `TodoApp/Views/Projects/ProjectCrewPlanningCard.swift`

#### Date Constraints (Phase 2)
Hybrid date constraint system:
- Tasks have optional start/end dates
- Projects enforce timeline boundaries
- **Conflict Detection**: Tasks outside project dates flagged
- **Quick Fixes**:
  - Adjust task dates to match project
  - Expand project timeline to include tasks
- **Transparency**: Clear warnings about date mismatches

**Location**: Task and Project models, date validation utilities

---

### 5. ANALYTICS & REPORTING

#### Analytics Dashboard
Real-time overview with three sections:

**Active Events**:
- Active projects in progress (status: In Progress)
- Active personnel count (from running timers)
- Hours logged this week
- Person-hours this week

**Attention Needed**:
- Overdue tasks count
- Blocked tasks count
- Tasks without estimates
- Tasks nearing estimate (≥80% time used)
- Over-planned projects (tasks exceed budget)
- Date conflicts (tasks outside project timeline)

**Upcoming Events**:
- Next 5 upcoming projects by due date
- Quick navigation to project details

**Location**: `TodoApp/Views/Analytics/AnalyticsView.swift`

#### Report Generation
Seven comprehensive report types:

**1. Weekly Summary**
- Tasks completed last 7 days
- Total hours tracked
- Person-hours breakdown
- Project distribution

**2. Monthly Summary**
- Comprehensive 30-day analysis
- Project-by-project breakdown
- Task completion trends
- Resource utilization

**3. Project Performance**
- Detailed analysis of specific project
- Task completion status
- Time vs. estimates
- Budget tracking (3-tier)
- Overdue and blocked tasks

**4. Personnel Utilization**
- Person-hours across projects
- Person-hours across tasks
- Resource distribution analysis
- Team efficiency metrics

**5. Task Efficiency**
- Tasks completed vs. estimated
- Accuracy metrics per task
- Over/under estimation patterns
- Task type breakdown

**6. Budget Analysis**
- 3-tier tracking:
  - Budget: Project estimated hours
  - Planned: Sum of task estimates
  - Actual: Time tracked
- Variance analysis at all levels
- Planning accuracy

**7. Task Type Efficiency**
- Average time per task type (e.g., Carpet Installation)
- Quantity-based productivity rates
- Historical trends by type
- Efficiency recommendations

**Export Formats**:
- Markdown (.md)
- Plain Text (.txt)
- CSV (.csv)

**Date Ranges**:
- Last 7 Days
- Last 30 Days
- Last 3 Months
- All Time
- Custom Range

**Location**: `TodoApp/Services/ReportGenerator.swift`, `TodoApp/Views/Settings/TimeExportSheet.swift`

---

### 6. KPI DASHBOARD

#### Accuracy Metrics
Measure estimation quality:
- **MAPE**: Mean Absolute Percentage Error
- **Accuracy Score**: 0-100% (inverse of MAPE)
- **Task Type Breakdown**: Accuracy per category
- **Threshold Analysis**: Tasks within 20%, 40%, 60% of estimate

**Accuracy Ratings**:
- Excellent: ≥ 80%
- Good: 60-79%
- Needs Improvement: 40-59%
- Poor: < 40%

**Location**: `TodoApp/Views/KPI/KPIDashboardView.swift`

#### Work Breakdown
- Completed tasks by task type
- Time distribution analysis
- Category performance comparison
- Visual charts and graphs

#### Productivity Metrics
For quantity-based tasks:
- **Units per person-hour**: Productivity rate calculation
- **Task type efficiency**: Performance by category
- **Historical tracking**: Trends over time
- **Average rates**: Reference for future estimates

**Use Case**: Learn that your team installs 2.8 m² of carpet per person-hour, then use this for future estimates.

#### Date Ranges
- All Time
- This Week
- This Month
- Real-time calculation with progress indicators

**Location**: `TodoApp/Utilities/KPIManager.swift`, KPI dashboard views

---

### 7. TEMPLATES & PRODUCTIVITY

#### Task Templates
Reusable templates for common work types:
- Pre-filled task configuration
- Default productivity rates
- Quantity bounds (min/max)
- Quick task creation

**Default Templates**:
1. **Carpet Installation**: m² tracking, 2.5 m²/person-hour
2. **Booth Wall Setup**: m² tracking, 3.0 m²/person-hour
3. **Furniture Assembly**: pieces tracking, 4.0 pcs/person-hour
4. **Material Delivery**: kg tracking, 150.0 kg/person-hour
5. **Paint/Finish Work**: m² tracking, 4.0 m²/person-hour

**Template Features**:
- **Import/Export**: JSON format for sharing
- **Statistics**: Usage tracking and performance
- **Conflict Resolution**: Handle duplicate imports
- **Customization**: Create your own templates

**Location**: `TodoApp/Models/TaskTemplate.swift`, `Views/Templates/`, `Utilities/TemplateImporter.swift`

#### Custom Units
User-defined measurement units:

**System Units**:
- None (non-quantifiable tasks)
- m² (square meters)
- m (meters)
- pcs (pieces)
- kg (kilograms)
- L (liters)

**Custom Units**:
- Create your own (e.g., "booths", "panels", "pallets")
- Display name and icon (SF Symbols)
- Quantifiable vs. non-quantifiable flag
- Persistent across app

**Location**: `TodoApp/Models/CustomUnit.swift`, `Views/Units/UnitsListView.swift`

#### Productivity Tracking
Learn from historical data:
- **Quantity Tracking**: Record actual quantities completed (e.g., 45.5 m²)
- **Task Type Categorization**: Group similar work
- **Custom Rates**: Override default productivity rates
- **Historical Analytics**: Analyze past performance
- **Default Rates**: System provides starting points:
  - m²: 3.0 per person-hour
  - m: 5.0 per person-hour
  - pcs: 4.0 per person-hour
  - kg: 150.0 per person-hour
  - L: 20.0 per person-hour

**Use**: App learns your team's actual productivity and suggests better estimates over time.

**Location**: `TodoApp/Utils/TaskTypeAnalytics.swift`, productivity calculation utilities

---

### 8. TAGS & ORGANIZATION

#### Tag System
Many-to-many flexible tagging:

**Tag Categories**:
1. **Resource**: Carpet, Walls, Furniture, Electrical, Lighting, Audio, Signage
2. **Phase**: Setup, Teardown, Maintenance
3. **Location**: Hall A, Hall B, Hall C, Outdoor, Loading Dock
4. **Team**: Carpentry, Electrical, Logistics, Decoration
5. **Vendor**: For external contractor tracking
6. **Custom**: User-defined categories

**Tag Properties**:
- **Name**: Display label
- **Icon**: SF Symbol for visual identification
- **Color**: Custom hex color
- **Category**: Organizational group
- **System Tag**: Cannot be deleted (core tags)

**Features**:
- Tag picker for task assignment
- Multiple tags per task
- Tag count badges
- Compact tag summary in list views
- Tag management view (create, edit, delete custom tags)

**Location**: `TodoApp/Models/Tag.swift`, `Views/Tags/TagManagementView.swift`

---

### 9. ARCHIVE & DATA MANAGEMENT

#### Archive System
Clean up without losing history:
- **Archive Completed Tasks**: Remove from main view
- **Archive Date Tracking**: When task was archived
- **Filter Options**:
  - All archived tasks
  - With project
  - Without project
  - With subtasks
- **Search**: Find specific archived tasks
- **Unarchive**: Restore to active tasks
- **Delete**: Permanently remove archived tasks

**Safety**:
- Archiving is non-destructive (can be undone)
- Relationships preserved
- Time tracking data maintained

**Location**: `TodoApp/Views/Archive/ArchiveView.swift`, `Utilities/ArchiveManager.swift`

#### Data Management
Admin tools for data maintenance:

**Clear All Data**:
- Safety confirmation required
- Removes all tasks, projects, time entries
- Preserves system data (units, tags)
- Non-reversible

**Fix Task Order**:
- Utility for existing databases
- Assigns sequential order to unordered tasks
- One-time migration helper

**Data Seeding**:
- Initialize system units on first launch
- Create default tags for common use cases
- Ensures consistent starting state

**Data Migration**:
- Schema change handlers
- `dueDate` → `endDate` migration
- Template to custom unit migration
- Automatic on app update

**Relationship Cleanup**:
- Removes dangling references before deletion
- Prevents "future" crashes from invalid data
- SwiftData relationship management

**Location**: `TodoApp/Utilities/DataSeeder.swift`, settings view, migration utilities

---

### 10. ADVANCED FEATURES

#### Task Composer Form
Sophisticated task creation interface (437 lines):

**Calculation Modes**:

1. **Duration Mode**: Calculate from quantity + personnel
   - Input: Quantity, productivity rate, personnel count
   - Output: Calculated duration
   - Use: "I need to install 50 m² with 3 people"

2. **Personnel Mode**: Calculate from quantity + duration
   - Input: Quantity, productivity rate, duration
   - Output: Calculated personnel needed
   - Use: "I need to install 50 m² in 4 hours"

3. **Manual Mode**: Manual entry with reference rates
   - Input: All fields manually
   - Display: Reference productivity rates from history
   - Use: "I want full control"

**Real-time Calculations**:
- Live productivity rate updates
- Validation as you type
- Input limits and bounds
- Reference data from templates

**Multi-section Form**:
- Project assignment
- Due date picker
- Estimate mode selector
- Priority selector
- Personnel count
- Quantity and unit
- Notes

**Location**: `TodoApp/Views/Tasks/Forms/TaskComposerForm.swift`

#### Task Actions System
Centralized action routing and execution:

**Architecture**:
- **TaskActionRouter**: Routes actions to sheets/alerts
- **TaskActionExecutor**: Validates and executes actions
- **TaskActionAlert**: Confirmation and error handling

**Supported Actions**:
- Complete/Uncomplete task
- Delete task (with confirmation)
- Duplicate task (all properties copied)
- Edit task (open edit sheet)
- Move to parent (change task hierarchy)
- Change priority (quick picker)
- Set due date (date picker)
- Archive/Unarchive
- Start/Stop timer

**Validation**:
- Context checking (e.g., can't complete if blocked)
- Relationship validation
- State consistency checks
- Error messages for invalid actions

**Location**: `TodoApp/Utilities/Actions/` (TaskActionRouter, TaskActionExecutor, TaskActionAlert)

#### Smart Calculations

**Work Hours Calculator**:
- Respects configurable workday hours (default: 7 AM - 3 PM)
- Calculates available work hours from now to deadline
- Accounts for weekends and non-work hours
- Used in crew planning calculations

**Minimum Personnel Calculator**:
- Formula: `effort_hours ÷ available_hours` (rounded up)
- Factors in workday constraints
- Provides buffer scenarios (10%, 25%)
- Warns when timeline is impossible

**Productivity Rate Estimation**:
- Uses historical task type data
- Calculates average units/person-hour
- Variance analysis for reliability
- Fallback to default rates

**Quantity Validation**:
- Type checking (integers vs. decimals)
- Min/max bounds from templates
- Parsing and formatting
- Error handling

**Location**: Work hours utilities, calculation view models, quantity validation utilities

---

### 11. UI/UX FEATURES

#### Design System
Centralized design tokens for consistency:

**Colors**:
- Semantic: success, warning, error, info
- Task Status: ready, inProgress, blocked, completed
- Priority: urgent, high, medium, low
- Neutral scale: N50 (lightest) to N900 (darkest)

**Spacing Scale**:
- XXS: 2pt
- XS: 4pt
- S: 8pt
- M: 12pt
- L: 16pt
- XL: 20pt
- XXL: 24pt
- Huge: 32pt
- Massive: 48pt

**Typography**:
- Standardized text styles
- Semantic sizing (heading, body, caption, etc.)
- Weight variations

**Animations**:
- Quick: 0.2s
- Standard: 0.3s
- Smooth: 0.4s
- Spring: Spring animation preset

**Constants**:
- Corner radius: 8pt, 12pt
- Shadow styles: Light, Medium, Heavy
- Minimum touch target: 44pt

**Location**: `TodoApp/Models/Enums/DesignSystem.swift`

#### Badges & Indicators
Visual status communication:

**Status Badge**:
- Color-coded (ready, in progress, blocked, completed)
- Tappable with action menu
- Icon + label

**Priority Badge**:
- Color-coded (urgent, high, medium, low)
- Tappable with picker menu
- Icon + label

**Project Badge**:
- Color dot + project name
- Tappable to view project
- Compact format

**Due Date Badge**:
- Smart countdown (e.g., "in 2 days", "tomorrow", "overdue")
- Adaptive urgency thresholds
- Color changes based on urgency
- Clock icon

**Subtasks Badge**:
- Shows count or progress percentage
- Format: "X subtasks" or "X/Y complete"
- Tappable to expand

**Time Estimate Badge**:
- Format: "2h 30m / 4h" (actual / estimated)
- Color-coded by status (on track, warning, over)
- Shows remaining time when timer active
- Progress bar integration

**Remaining Time Badge**:
- Countdown when timer active
- Format: "1h 30m remaining"
- Updates in real-time
- Warning colors as time runs out

**Date Conflict Badge**:
- Warning icon + "Date Conflict"
- Shown when task dates outside project timeline
- Tappable for quick fixes

**Tag Badges**:
- Colored capsules with icons
- Wraps on multiple lines
- Compact summary in list view
- Full display in detail view

**Location**: Badge components throughout `Views/Common/`, inline in various views

#### UI Components

**Cards**:
- Consistent card styling
- Background colors and shadows
- Padding and corner radius
- Sectioned layouts

**Progress Bars**:
- Two types: Time estimate OR subtask completion
- 0-100%+ range with overflow handling
- Color-coded by status
- Smooth animations

**Expandable Sections**:
- Disclosure groups for subtasks, dependencies, etc.
- Persistent expansion state
- Smooth animations
- Header badges show counts

**Flow Layout**:
- Badge wrapping on narrow screens
- Responsive to screen size
- Maintains readability

**Empty States**:
- Contextual messages based on filter/state
- Friendly illustrations/icons
- Actionable hints
- Different messages for different contexts

**Toast Notifications**:
- Success/error feedback
- Auto-dismiss with timing
- Non-blocking
- Positioned at top

**Haptic Feedback**:
- Success, warning, error patterns
- Selection feedback
- Impact feedback (light, medium, heavy)
- Throughout all interactions

**Location**: `TodoApp/Models/Enums/HapticManager.swift`, common view components

#### Interaction Patterns

**Swipe Actions**:
- **Leading**: Complete (green checkmark)
- **Trailing**: More actions menu
- Destructive actions require confirmation
- Haptic feedback on swipe

**Context Menus**:
- Long-press on task rows
- Quick access to common actions
- Organized by frequency
- Icons for visual scanning

**Drag-to-Reorder**:
- Edit mode in lists
- Visual drag handles
- Persistent order
- Haptic feedback on drop

**Inline Editing**:
- Quick edit for common properties
- Title editing in detail view
- Priority picker in badge
- Status picker in badge
- No need to open full edit sheet

**View Optimization**:
- **Detail View**: Sectioned, optimized for interaction
- **List View**: Compact, optimized for scanning
- Different layouts for different contexts
- Performance-optimized queries

**Location**: Throughout task list and detail views

#### Navigation

**Tab Bar** (Main navigation):
1. **Tasks**: Task list with filters
2. **Projects**: Project list and details
3. **Analytics**: Dashboard and reports
4. **KPIs**: Metrics and performance
5. **Settings**: Configuration and data management

**Navigation Stacks**:
- Deep linking support
- Back navigation
- Title management
- Toolbar consistency

**Sheets**:
- Modal presentation for creation/editing
- Dismissible
- Form-based layouts
- Validation before dismiss

**Detail Views**:
- Drill-down navigation
- Breadcrumb context
- Related item links
- Quick actions in toolbar

**Location**: `TodoApp/TodoAppApp.swift`, main tab view, navigation stacks in feature views

---

### 12. SETTINGS & CONFIGURATION

#### Appearance Settings
- **Appearance Mode**: Light / Dark / Auto (system)
- **Compact View**: Toggle for denser list layouts

#### Task Defaults
- **Default Priority**: Set default priority for new tasks (Urgent/High/Medium/Low)
- **Show Completed by Default**: Toggle completed tasks visibility in lists

#### Work Hours Configuration
Used for crew planning calculations:
- **Workday Start Hour**: Default 7:00 AM
- **Workday End Hour**: Default 3:00 PM
- **Purpose**: Calculate available work hours between now and deadline

#### Data Statistics
Read-only app metrics:
- Total projects count
- Total tasks count
- Total time tracked (hours)

#### Navigation Links
Quick access to management views:
- **Archived Tasks**: View/manage archived tasks
- **Task Templates**: Create/edit/import templates
- **Custom Units**: Manage measurement units
- **Tags**: Manage tag library

#### Data Management
- **Clear All Data**: Nuclear option (requires confirmation)
- **Fix Task Order**: One-time utility for migration

**Location**: `TodoApp/Views/Settings/SettingsView.swift`

---

### 13. DATA MODELS & TECHNICAL ARCHITECTURE

#### SwiftData Models
Core data entities:

**Task** (`TodoApp/Models/Task.swift`):
- 20+ stored properties
- 30+ computed properties
- Relationships: project, parentTask, subtasks, dependencies, timeEntries, tags
- Complex status calculation
- Recursive time aggregation

**Project** (`TodoApp/Models/Project.swift`):
- Basic properties: title, color, status, dates, budget
- Computed health status
- Analytics properties (incomplete, blocked, overdue counts)
- Relationships: tasks

**TimeEntry** (`TodoApp/Models/TimeEntry.swift`):
- Start time, end time, duration
- Personnel count for person-hours
- Relationship: task
- Computed person-hours

**TaskTemplate** (`TodoApp/Models/TaskTemplate.swift`):
- Reusable task configuration
- Default rates and bounds
- Import/export support

**CustomUnit** (`TodoApp/Models/CustomUnit.swift`):
- User-defined units
- Display name, icon, abbreviation
- Quantifiable flag

**Tag** (`TodoApp/Models/Tag.swift`):
- Many-to-many with tasks
- Category, icon, color
- System vs. custom tags

#### Technical Patterns

**Query-Based Architecture**:
- All relationship-dependent views use `@Query` instead of `@Bindable`
- Ensures real-time updates across model contexts
- Prevents stale data in UI
- Example: Subtask lists always show current state

**MVVM Pattern**:
- View Models for complex logic:
  - `ProductivityRateViewModel`: Calculate rates from history
  - `TaskComposerCalculatorViewModel`: Handle estimation modes
  - `QuantityCalculationViewModel`: Parse and validate quantities
- Separation of concerns
- Testable business logic

**Centralized Services**:
- **TaskService**: Common task operations
- **ReportGenerator**: All report types (900+ lines)
- **SubtaskAggregator**: Recursive time/person-hour aggregation
- Reusable across views

**Utilities**:
- **Formatters**: Duration, quantity, date/time
- **DateTimeHelper**: Work hours, deadline calculations
- **InputValidator**: Quantity parsing, bounds checking
- **EstimationLimits**: Min/max values for estimates
- **ArchiveManager**: Archive operations
- **DataSeeder**: Initialize system data

**View Modifiers**:
- Reusable styling (cards, badges, sections)
- Consistent design application
- DRY principle

**Reusable Components**:
- Shared time tracking views
- Badge components
- Progress bars
- Empty states
- Form sections

**Location**: Throughout codebase, organized by feature

#### Data Persistence

**SwiftData with ModelContainer**:
- Automatic persistence
- Type-safe queries
- Relationship management
- Transaction handling

**Relationship Management**:
- Nullify rules: Remove reference on delete (e.g., task.project)
- Cascade rules: Delete related entities (e.g., task's time entries)
- Orphan cleanup: Prevent dangling references

**Migration Support**:
- Schema versioning
- Field migrations (e.g., `dueDate` → `endDate`)
- Data transformations
- Backwards compatibility

**Safe Deletion**:
- Cleanup before deletion
- Relationship traversal
- Prevent crashes from invalid references
- Transaction safety

**Location**: Model definitions, `TodoApp/TodoAppApp.swift` (ModelContainer setup)

---

## KEY TECHNICAL APPROACHES

### 1. Query-Based Views
**Problem**: SwiftData model contexts can become out of sync
**Solution**: Use `@Query` for all relationship-dependent views
**Benefit**: Real-time updates, no stale data

### 2. Time Precision
**Problem**: Seconds matter for accurate tracking
**Solution**: Store in seconds, display in minutes/hours
**Benefit**: Precision without cluttered UI

### 3. Computed Status
**Problem**: Manually set status becomes incorrect
**Solution**: Calculate status from state (completion, timers, dependencies)
**Benefit**: Always accurate, single source of truth

### 4. Recursive Aggregation
**Problem**: Need total time including subtasks
**Solution**: Recursive functions traverse subtask tree
**Benefit**: Accurate totals, handles arbitrary depth

### 5. Validation Throughout
**Problem**: Invalid data causes crashes and bugs
**Solution**: Validate at input, save, and action execution
**Benefit**: Robust app, good error messages

### 6. Haptic Feedback
**Problem**: Touch interfaces lack tactile confirmation
**Solution**: Haptic feedback for all actions
**Benefit**: Better user experience, action confidence

### 7. Design System
**Problem**: Inconsistent styling across app
**Solution**: Centralized design tokens
**Benefit**: Consistent look, easy to update

### 8. Modular Architecture
**Problem**: Monolithic files are hard to maintain
**Solution**: 168 Swift files organized by feature
**Benefit**: Easy to navigate, parallel development

### 9. Reusable Components
**Problem**: Duplicate code, inconsistent behavior
**Solution**: Shared UI components, utilities, view modifiers
**Benefit**: DRY, consistent UX, faster development

### 10. Historical Learning
**Problem**: Estimates are guesses
**Solution**: Task type analytics learn from actual data
**Benefit**: Better estimates over time, improved planning

---

## FILE STRUCTURE SUMMARY

```
TodoApp/
├── Models/
│   ├── Task.swift (core model, 30+ computed properties)
│   ├── Project.swift (with health status)
│   ├── TimeEntry.swift (with personnel count)
│   ├── TaskTemplate.swift (reusable configurations)
│   ├── CustomUnit.swift (user-defined units)
│   ├── Tag.swift (many-to-many organization)
│   └── Enums/
│       ├── Priority.swift
│       ├── TaskFilter.swift
│       ├── DesignSystem.swift (design tokens)
│       └── HapticManager.swift
│
├── Views/
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   ├── TaskDetailView.swift
│   │   ├── AddTaskView.swift
│   │   ├── TaskEditView.swift
│   │   ├── Forms/
│   │   │   └── TaskComposerForm.swift (437 lines)
│   │   ├── Sheets/
│   │   │   └── MoveToTaskSheet.swift
│   │   └── TaskExpandedSubtasksView.swift
│   │
│   ├── Projects/
│   │   ├── ProjectListView.swift
│   │   ├── ProjectDetailView.swift
│   │   ├── AddProjectView.swift
│   │   └── ProjectCrewPlanningCard.swift
│   │
│   ├── Analytics/
│   │   └── AnalyticsView.swift (dashboard)
│   │
│   ├── KPI/
│   │   └── KPIDashboardView.swift (metrics)
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── TimeExportSheet.swift
│   │
│   ├── Templates/
│   │   ├── TemplateListView.swift
│   │   └── TemplateStatisticsView.swift
│   │
│   ├── Tags/
│   │   └── TagManagementView.swift
│   │
│   ├── Archive/
│   │   └── ArchiveView.swift
│   │
│   ├── TimeTracking/
│   │   ├── TaskTimeTrackingView.swift
│   │   ├── ManualTimeEntrySheet.swift
│   │   └── TimeEntriesView.swift
│   │
│   └── Common/ (reusable components)
│
├── Services/
│   ├── ReportGenerator.swift (900+ lines, 7 report types)
│   └── SubtaskAggregator.swift
│
├── Utilities/
│   ├── Actions/
│   │   ├── TaskActionRouter.swift
│   │   ├── TaskActionExecutor.swift
│   │   └── TaskActionAlert.swift
│   ├── ArchiveManager.swift
│   ├── DataSeeder.swift
│   ├── EstimationLimits.swift
│   ├── KPIManager.swift
│   ├── TemplateImporter.swift
│   └── TemplateExporter.swift
│
├── ViewModels/
│   ├── ProductivityRateViewModel.swift
│   ├── TaskComposerCalculatorViewModel.swift
│   └── QuantityCalculationViewModel.swift
│
└── Utils/
    └── TaskTypeAnalytics.swift
```

Total: 168 Swift files organized by feature area

---

## DEVELOPMENT PHILOSOPHY

**TodoApp** is built for **exhibition and event production teams** who need:
- Complex task hierarchies with dependencies
- Accurate crew size planning
- Real-time progress tracking
- Historical learning from past work
- Detailed analytics and reporting

**Not just a todo app** - it's a comprehensive production management tool that helps teams:
1. **Plan**: Estimate work with historical accuracy
2. **Execute**: Track time and progress in real-time
3. **Learn**: Analyze performance and improve estimates
4. **Report**: Generate detailed reports for clients/stakeholders

Built with **SwiftUI + SwiftData** for native iOS performance and modern declarative UI.

---

*This document reflects the complete feature set of TodoApp as of the current codebase state.*
