import SwiftUI
import SwiftData

/// Displays and manages time entries for a task
/// Phase 1: Read-only display
/// Future phases: Delete, edit, and manual entry creation
struct TimeEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    @State private var showingManualEntrySheet = false
    @State private var editingEntry: TimeEntry?

    private var sortedEntries: [TimeEntry] {
        (task.timeEntries ?? []).sorted { $0.startTime > $1.startTime }
    }

    private var hasEntries: Bool {
        !(task.timeEntries ?? []).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Text("Time Entries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showingManualEntrySheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.taskInProgress)
                }
            }
            .padding(.horizontal)

            if hasEntries {
                List {
                    ForEach(sortedEntries) { entry in
                        TimeEntryRow(entry: entry, task: task, onEdit: {
                            editingEntry = entry
                        }, onDelete: {
                            deleteEntry(entry)
                        })
                        .listRowInsets(EdgeInsets(
                            top: DesignSystem.Spacing.xs,
                            leading: DesignSystem.Spacing.md,
                            bottom: DesignSystem.Spacing.xs,
                            trailing: DesignSystem.Spacing.md
                        ))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if entry.endTime != nil { // Only allow delete for completed entries
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(sortedEntries.count) * 60) // Approximate height per row
                .scrollDisabled(true)
            } else {
                EmptyEntriesView()
                    .padding(.horizontal)
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingManualEntrySheet) {
            ManualTimeEntrySheet(task: task)
        }
        .sheet(item: $editingEntry) { entry in
            EditTimeEntrySheet(entry: entry)
        }
    }

    // MARK: - Actions

    private func deleteEntry(_ entry: TimeEntry) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
        HapticManager.success()
    }
}

// MARK: - Time Entry Row

private struct TimeEntryRow: View {
    let entry: TimeEntry
    let task: Task
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    private var isActiveTimer: Bool {
        TimeEntryManager.isActiveTimer(entry)
    }

    private var formattedDuration: String {
        TimeEntryManager.formatDuration(for: entry, showSeconds: false)
    }

    private var formattedPersonHours: String {
        TimeEntryManager.formatPersonHours(for: entry)
    }

    private var formattedDate: String {
        TimeEntryManager.formatRelativeDate(entry.startTime)
    }

    private var formattedTimeRange: String {
        TimeEntryManager.formatTimeRange(for: entry)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Timer indicator
            Image(systemName: isActiveTimer ? "timer" : "clock.fill")
                .font(.body)
                .foregroundStyle(isActiveTimer ? DesignSystem.Colors.timerActive : .secondary)
                .frame(width: 28)
                .pulsingAnimation(active: isActiveTimer)

            VStack(alignment: .leading, spacing: 2) {
                // Date
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Time range
                Text(formattedTimeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Personnel badge (only show when > 1)
                if entry.personnelCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(entry.personnelCount) people · \(formattedPersonHours)")
                            .font(.caption2)
                    }
                    .foregroundStyle(DesignSystem.Colors.info)
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Duration badge
            Text(formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isActiveTimer ? DesignSystem.Colors.timerActive : .primary)

            // Action menu
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(isActiveTimer)

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(isActiveTimer)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .contentShape(Rectangle())
        .alert("Delete Time Entry?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This time entry (\(formattedDuration)) will be permanently deleted.")
        }
    }
}

// MARK: - Empty State

private struct EmptyEntriesView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No time entries yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start the timer to track time on this task")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
}
