import SwiftUI
import SwiftData
internal import Combine

struct AnalyticsView: View {
    @Query private var allTasks: [Task]
    @Query private var allProjects: [Project]
    @Query private var allTimeEntries: [TimeEntry]

    @State private var showingActiveTimersDetail = false
    @State private var showingOverdueTasksDetail = false
    @State private var showingBlockedTasksDetail = false
    @State private var showingNoEstimatesDetail = false
    @State private var showingNearingEstimateDetail = false

    // Refresh timer for active timers
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var todaysActivity: TodaysActivity {
        TodaysActivity.calculate(from: allTasks, timeEntries: allTimeEntries)
    }

    private var attentionNeeded: AttentionNeeded {
        AttentionNeeded.calculate(from: allTasks)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Today's Activity Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        SectionHeader(
                            title: "Today's Activity",
                            subtitle: formatDate(Date())
                        )

                        todaysActivityCards
                    }
                    .padding(.horizontal)

                    // Attention Needed Section
                    if attentionNeeded.hasIssues {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Attention Needed",
                                subtitle: "\(attentionNeeded.totalIssueCount) \(attentionNeeded.totalIssueCount == 1 ? "item" : "items")",
                                icon: "exclamationmark.triangle.fill",
                                iconColor: DesignSystem.Colors.warning
                            )

                            attentionNeededCards
                        }
                        .padding(.horizontal)
                    } else {
                        // No issues card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Attention Needed",
                                subtitle: "All clear"
                            )

                            allClearCard
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Analytics")
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .sheet(isPresented: $showingActiveTimersDetail) {
                ActiveTimersDetailView(tasks: allTasks.filter { $0.hasActiveTimer })
            }
            .sheet(isPresented: $showingOverdueTasksDetail) {
                TaskListDetailView(
                    title: "Overdue Tasks",
                    tasks: attentionNeeded.overdueTasks,
                    icon: "exclamationmark.triangle.fill",
                    color: DesignSystem.Colors.error
                )
            }
            .sheet(isPresented: $showingBlockedTasksDetail) {
                TaskListDetailView(
                    title: "Blocked Tasks",
                    tasks: attentionNeeded.blockedTasks,
                    icon: "hand.raised.fill",
                    color: DesignSystem.Colors.warning
                )
            }
            .sheet(isPresented: $showingNoEstimatesDetail) {
                TaskListDetailView(
                    title: "Missing Estimates",
                    tasks: attentionNeeded.tasksWithoutEstimates,
                    icon: "questionmark.circle.fill",
                    color: DesignSystem.Colors.warning
                )
            }
            .sheet(isPresented: $showingNearingEstimateDetail) {
                TaskListDetailView(
                    title: "Nearing Estimate",
                    tasks: attentionNeeded.tasksNearingEstimate,
                    icon: "gauge.with.dots.needle.67percent",
                    color: DesignSystem.Colors.warning
                )
            }
        }
    }

    // MARK: - Today's Activity Cards

    private var todaysActivityCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.md) {
            // Active Timers
            TappableStatCard(
                icon: "timer",
                value: "\(todaysActivity.activeTimers)",
                label: "Active Timers",
                subtitle: todaysActivity.activePersonnel > 0 ?
                    "\(todaysActivity.activePersonnel) \(todaysActivity.activePersonnel == 1 ? "person" : "people")" : nil,
                color: DesignSystem.Colors.info,
                onTap: todaysActivity.activeTimers > 0 ? {
                    showingActiveTimersDetail = true
                } : nil
            )

            // Tasks Completed
            TappableStatCard(
                icon: "checkmark.circle.fill",
                value: "\(todaysActivity.tasksCompletedToday)",
                label: "Completed",
                subtitle: todaysActivity.tasksCompletedToday == 1 ? "task" : "tasks",
                color: DesignSystem.Colors.success
            )

            // Hours Today
            TappableStatCard(
                icon: "clock.fill",
                value: String(format: "%.1f", todaysActivity.hoursLoggedToday),
                label: "Hours Logged",
                subtitle: "today",
                color: Color(hex: "#5856D6") // Indigo
            )

            // Person-Hours Today
            TappableStatCard(
                icon: "person.2.fill",
                value: String(format: "%.1f", todaysActivity.personHoursToday),
                label: "Person-Hours",
                subtitle: "today",
                color: Color(hex: "#AF52DE") // Purple
            )
        }
    }

    // MARK: - Attention Needed Cards

    private var attentionNeededCards: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if !attentionNeeded.overdueTasks.isEmpty {
                AttentionCard(
                    title: "Overdue Tasks",
                    count: attentionNeeded.overdueTasks.count,
                    icon: "exclamationmark.triangle.fill",
                    color: DesignSystem.Colors.error,
                    onTap: { showingOverdueTasksDetail = true }
                )
            }

            if !attentionNeeded.blockedTasks.isEmpty {
                AttentionCard(
                    title: "Blocked Tasks",
                    count: attentionNeeded.blockedTasks.count,
                    icon: "hand.raised.fill",
                    color: DesignSystem.Colors.warning,
                    onTap: { showingBlockedTasksDetail = true }
                )
            }

            if !attentionNeeded.tasksWithoutEstimates.isEmpty {
                AttentionCard(
                    title: "Missing Estimates",
                    count: attentionNeeded.tasksWithoutEstimates.count,
                    icon: "questionmark.circle.fill",
                    color: DesignSystem.Colors.warning,
                    onTap: { showingNoEstimatesDetail = true }
                )
            }

            if !attentionNeeded.tasksNearingEstimate.isEmpty {
                AttentionCard(
                    title: "Nearing Estimate",
                    count: attentionNeeded.tasksNearingEstimate.count,
                    icon: "gauge.with.dots.needle.67percent",
                    color: DesignSystem.Colors.warning,
                    onTap: { showingNearingEstimateDetail = true }
                )
            }
        }
    }

    private var allClearCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.Colors.success)

            VStack(alignment: .leading, spacing: 4) {
                Text("All Clear!")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("No tasks need immediate attention")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.success.opacity(0.1))
        )
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String
    var icon: String? = nil
    var iconColor: Color = DesignSystem.Colors.primary

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .modelContainer(for: [Task.self, Project.self, TimeEntry.self], inMemory: true)
}
