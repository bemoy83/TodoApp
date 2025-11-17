import SwiftUI
import SwiftData
internal import Combine

struct AnalyticsView: View {
    @Query private var allTasks: [Task]
    @Query private var allProjects: [Project]
    @Query private var allTimeEntries: [TimeEntry]

    @State private var showingProjectDetail: Project?
    @State private var showingProjectIssues: ProjectIssue?
    @State private var selectedTab = 0

    // Refresh timer for active timers
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var activeEventsData: ActiveEventsData {
        ActiveEventsData.calculate(from: allProjects, timeEntries: allTimeEntries)
    }

    private var projectAttention: ProjectAttentionNeeded {
        ProjectAttentionNeeded.calculate(from: allProjects)
    }

    private var upcomingEvents: UpcomingEventsData {
        UpcomingEventsData.calculate(from: allProjects)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Active Events Section
                    if !activeEventsData.activeProjects.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Active Events",
                                subtitle: "\(activeEventsData.activeProjects.count) \(activeEventsData.activeProjects.count == 1 ? "event" : "events") in progress",
                                icon: "hammer.fill",
                                iconColor: DesignSystem.Colors.info
                            )

                            activeEventsCards
                        }
                        .padding(.horizontal)
                    } else {
                        // No active events
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Active Events",
                                subtitle: "No events in progress"
                            )

                            noActiveEventsCard
                        }
                        .padding(.horizontal)
                    }

                    // Attention Needed Section
                    if projectAttention.hasIssues {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Attention Needed",
                                subtitle: "\(projectAttention.projectsNeedingAttention.count) \(projectAttention.projectsNeedingAttention.count == 1 ? "event" : "events")",
                                icon: "exclamationmark.triangle.fill",
                                iconColor: DesignSystem.Colors.warning
                            )

                            attentionNeededCards
                        }
                        .padding(.horizontal)
                    } else {
                        // All clear
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Attention Needed",
                                subtitle: "All clear"
                            )

                            allClearCard
                        }
                        .padding(.horizontal)
                    }

                    // Upcoming Events Section
                    if !upcomingEvents.upcomingProjects.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            SectionHeader(
                                title: "Upcoming Events",
                                subtitle: "Next \(upcomingEvents.upcomingProjects.count) \(upcomingEvents.upcomingProjects.count == 1 ? "event" : "events")",
                                icon: "calendar",
                                iconColor: Color(hex: "#AF52DE")
                            )

                            upcomingEventsCards
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Events")
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .sheet(item: $showingProjectDetail) { project in
                ProjectDetailView(project: project)
            }
            .sheet(item: $showingProjectIssues) { issue in
                ProjectIssuesDetailView(projectIssue: issue)
            }
        }
    }

    // MARK: - Active Events Cards

    private var activeEventsCards: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(activeEventsData.activeProjects) { project in
                EventCard(project: project) {
                    showingProjectDetail = project
                }
            }
        }
    }

    private var noActiveEventsCard: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.Colors.success)

            VStack(alignment: .leading, spacing: 4) {
                Text("No Active Events")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("All events are completed or on hold")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.success.opacity(0.1))
        )
        .designShadow(DesignSystem.Shadow.sm)
    }

    // MARK: - Attention Needed Cards

    private var attentionNeededCards: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(projectAttention.projectsNeedingAttention) { issue in
                ProjectAttentionCard(projectIssue: issue) {
                    showingProjectIssues = issue
                }
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

                Text("No events need immediate attention")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.success.opacity(0.1))
        )
        .designShadow(DesignSystem.Shadow.sm)
    }

    // MARK: - Upcoming Events Cards

    private var upcomingEventsCards: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(upcomingEvents.upcomingProjects) { project in
                Button(action: {
                    showingProjectDetail = project
                }) {
                    UpcomingEventCard(project: project)
                }
                .buttonStyle(.plain)
            }
        }
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
