import SwiftUI
import SwiftData

// MARK: - Unified Subtask Row Content
/// Shared UI component for subtask display across different views
/// Supports both compact (inline expansion) and detailed (detail view) styles
struct SubtaskRowContent: View {
    @Bindable var subtask: Task
    let style: SubtaskRowStyle
    
    enum SubtaskRowStyle {
        case compact   // Inline expansion in TaskListView
        case detailed  // Detail view in TaskSubtasksView
        
        var showMetadata: Bool {
            switch self {
            case .compact: return true
            case .detailed: return true
            }
        }
        
        var titleFont: Font {
            switch self {
            case .compact: return .subheadline
            case .detailed: return .subheadline
            }
        }
        
        var titleColor: Color {
            switch self {
            case .compact: return .secondary
            case .detailed: return .primary
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title with optional priority
            HStack(spacing: 4) {
                if subtask.priority <= 1, style.showMetadata {
                    Image(systemName: Priority(rawValue: subtask.priority)?.icon ?? "")
                        .font(.caption2)
                        .foregroundStyle(Priority(rawValue: subtask.priority)?.color ?? .gray)
                }
                
                Text(subtask.title)
                    .font(style.titleFont)
                    .fontWeight(subtask.isCompleted ? .regular : .medium)
                    .strikethrough(subtask.isCompleted)
                    .foregroundStyle(subtask.isCompleted ? Color.secondary.opacity(0.6) : style.titleColor)
                    .lineLimit(1)
            }
            
            // Metadata row (only in detailed style)
            if style.showMetadata {
                HStack(spacing: 8) {
                    // Due date (if soon/overdue)
                    if let dueDate = subtask.dueDate ?? subtask.parentTask?.dueDate {
                        let cal = Calendar.current
                        if dueDate < Date() || cal.isDateInToday(dueDate) || cal.isDateInTomorrow(dueDate) {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(dueDate.smartFormatted)
                                    .font(.caption2)
                            }
                            .foregroundStyle(dueDate < Date() ? .red : .secondary)
                        }
                    }
                    
                    // Time spent (if any)
                    if subtask.totalTimeSpent > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatMinutes(subtask.totalTimeSpent))
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatMinutes(_ seconds: Int) -> String {
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Subtask Status Icon Button
/// Reusable status toggle button for subtasks
struct SubtaskStatusButton: View {
    @Bindable var subtask: Task
    let action: () -> Void
    let size: StatusButtonSize
    
    enum StatusButtonSize {
        case compact
        case standard
        
        var font: Font {
            switch self {
            case .compact: return .callout
            case .standard: return .title3
            }
        }
        
        var frameWidth: CGFloat {
            switch self {
            case .compact: return DesignSystem.Spacing.xl
            case .standard: return 44
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: subtask.status.icon)
                .font(size.font)
                .foregroundStyle(statusColor)
                .frame(width: size.frameWidth)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch subtask.status {
        case .blocked: return DesignSystem.Colors.taskBlocked
        case .ready: return DesignSystem.Colors.taskReady
        case .inProgress: return DesignSystem.Colors.taskInProgress
        case .completed: return DesignSystem.Colors.taskCompleted
        }
    }
}
