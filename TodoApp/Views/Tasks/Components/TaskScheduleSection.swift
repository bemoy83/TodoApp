import SwiftUI
import SwiftData

/// Schedule section content for TaskDetailView
/// Shows start/due dates, working window, estimate comparison, and date conflicts
struct TaskScheduleSection: View {
    @Bindable var task: Task

    @State private var dateEditItem: DateEditItem?

    // Identifiable wrapper for sheet presentation
    private struct DateEditItem: Identifiable {
        let id = UUID()
        let dateType: DateEditSheet.DateEditType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Date conflict warning (if applicable)
            if task.hasDateConflicts {
                dateConflictWarning
            }

            // Start date
            if let startDate = task.startDate {
                SharedDateRow(
                    icon: "play.circle.fill",
                    label: "Start",
                    date: startDate,
                    color: .blue,
                    isActionable: true,
                    showTime: true,
                    onTap: {
                        dateEditItem = DateEditItem(dateType: .start)
                        HapticManager.light()
                    }
                )
                .padding(.vertical, DesignSystem.Spacing.xs)
            }

            // Due date
            if let endDate = task.endDate {
                SharedDateRow(
                    icon: "flag.fill",
                    label: "Due",
                    date: endDate,
                    color: endDate < Date() && !task.isCompleted ? .red : .orange,
                    isActionable: true,
                    showTime: true,
                    onTap: {
                        dateEditItem = DateEditItem(dateType: .end)
                        HapticManager.light()
                    }
                )
                .padding(.vertical, DesignSystem.Spacing.xs)
            }

            // Working window summary (when both dates exist)
            if let startDate = task.startDate, let endDate = task.endDate {
                let availableHours = WorkHoursCalculator.calculateAvailableHours(from: startDate, to: endDate)
                workingWindowSummary(hours: availableHours)

                // Schedule vs Estimate comparison (when estimate exists)
                if let estimateSeconds = task.effectiveEstimate {
                    scheduleEstimateComparison(availableHours: availableHours, estimateSeconds: estimateSeconds)
                }
            }

            // Add missing date buttons
            if task.startDate == nil || task.endDate == nil {
                addDateButtons
            }
        }
        .padding(.horizontal)
        .sheet(item: $dateEditItem) { item in
            DateEditSheet(task: task, dateType: item.dateType)
        }
    }

    // MARK: - Add Date Buttons

    @ViewBuilder
    private var addDateButtons: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if task.startDate == nil {
                Button {
                    dateEditItem = DateEditItem(dateType: .start)
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        Text("Add Start Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)

                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if task.endDate == nil {
                Button {
                    dateEditItem = DateEditItem(dateType: .end)
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        Text("Add Due Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)

                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Date Conflict Warning

    @ViewBuilder
    private var dateConflictWarning: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.warning)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Date Conflict")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.warning)

                    if let message = task.dateConflictMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Project timeline reference
            if let project = task.project {
                projectTimelineReference(project: project)
            }

            // Quick fix actions
            quickFixActions
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.warning.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    @ViewBuilder
    private func projectTimelineReference(project: Project) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Project Timeline:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                if let projectStart = project.startDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(projectStart.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if let projectDue = project.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.caption2)
                        Text(projectDue.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private var quickFixActions: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation {
                    task.adjustToProjectDates()
                    HapticManager.success()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.caption)
                    Text("Fit to Project")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.info)
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }

            Button {
                withAnimation {
                    task.expandProjectToIncludeTask()
                    HapticManager.success()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                    Text("Expand Project")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.warning)
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }

            Spacer()
        }
    }

    // MARK: - Working Window Summary

    @ViewBuilder
    private func workingWindowSummary(hours: Double) -> some View {
        let workDays = hours / WorkHoursCalculator.workdayHours

        let daysText = workDays.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(workDays)) \(Int(workDays) == 1 ? "work day" : "work days")"
            : String(format: "%.1f work days", workDays)

        TaskRowIconValueLabel(
            icon: "clock.arrow.2.circlepath",
            label: "\(daysText) • \(String(format: "%.1f", hours)) work hours available",
            value: "Working Window",
            tint: .green
        )
        .padding(.top, DesignSystem.Spacing.xs)
    }

    // MARK: - Schedule vs Estimate

    private func scheduleEstimateComparison(availableHours: Double, estimateSeconds: Int) -> some View {
        let estimateHours = Double(estimateSeconds) / 3600.0
        let ratio = estimateHours / availableHours

        let status: ScheduleEstimateStatus = {
            if estimateHours > availableHours {
                return .insufficient
            } else if ratio >= 0.75 {
                return .tight
            } else {
                return .comfortable
            }
        }()

        let (icon, color, message): (String, Color, String) = {
            switch status {
            case .insufficient:
                return (
                    "exclamationmark.triangle.fill",
                    .red,
                    "Insufficient: Need \(String(format: "%.1f", estimateHours))h, only \(String(format: "%.1f", availableHours))h available"
                )
            case .tight:
                return (
                    "exclamationmark.triangle.fill",
                    .orange,
                    "Tight: Need \(String(format: "%.1f", estimateHours))h, have \(String(format: "%.1f", availableHours))h"
                )
            case .comfortable:
                let margin = availableHours - estimateHours
                return (
                    "checkmark.circle.fill",
                    .green,
                    "Good margin: Need \(String(format: "%.1f", estimateHours))h, \(String(format: "%.1f", margin))h buffer"
                )
            }
        }()

        return TaskRowIconValueLabel(
            icon: icon,
            label: message,
            value: "Time Planning",
            tint: color
        )
        .padding(.top, DesignSystem.Spacing.xs)
    }

}

// MARK: - Schedule Estimate Status

private enum ScheduleEstimateStatus {
    case insufficient
    case tight
    case comfortable
}

// MARK: - Summary Badge Helper

extension TaskScheduleSection {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        // Check for date conflict first
        let warningPrefix = task.hasDateConflicts ? "⚠️ " : ""

        guard task.startDate != nil || task.endDate != nil else {
            return "Not set"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if let start = task.startDate, let end = task.endDate {
            // Both dates - show range and duration
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            let hours = WorkHoursCalculator.calculateAvailableHours(from: start, to: end)
            let days = hours / WorkHoursCalculator.workdayHours
            let daysStr = days < 1 ? "<1d" : "\(Int(days.rounded()))d"
            return "\(warningPrefix)\(startStr)-\(endStr) • \(daysStr)"
        } else if let end = task.endDate {
            // Only due date
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
            if task.isCompleted {
                return "\(warningPrefix)Due \(formatter.string(from: end))"
            } else if daysUntil < 0 {
                return "\(warningPrefix)Overdue by \(abs(daysUntil))d"
            } else if daysUntil == 0 {
                return "\(warningPrefix)Due today"
            } else if daysUntil == 1 {
                return "\(warningPrefix)Due tomorrow"
            } else {
                return "\(warningPrefix)Due in \(daysUntil)d"
            }
        } else if let start = task.startDate {
            // Only start date
            return "\(warningPrefix)Starts \(formatter.string(from: start))"
        }

        return "Not set"
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        if task.hasDateConflicts {
            return DesignSystem.Colors.warning
        }

        guard let end = task.endDate, !task.isCompleted else {
            return .secondary
        }

        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        if daysUntil < 0 {
            return DesignSystem.Colors.error
        } else if daysUntil <= 1 {
            return DesignSystem.Colors.warning
        }
        return .secondary
    }
}

// MARK: - Preview

#Preview("With Dates") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let task = Task(title: "Install Carpet")
    task.startDate = Date()
    task.endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
    task.estimatedSeconds = 7200 // 2 hours
    container.mainContext.insert(task)
    return ScrollView {
        TaskScheduleSection(task: task)
    }
    .padding()
    .modelContainer(container)
}

#Preview("No Dates") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)
    let task = Task(title: "Install Carpet")
    container.mainContext.insert(task)
    return ScrollView {
        TaskScheduleSection(task: task)
    }
    .padding()
    .modelContainer(container)
}
