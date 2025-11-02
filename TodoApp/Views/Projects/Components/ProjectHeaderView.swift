//
//  ProjectHeaderView.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


import SwiftUI

struct ProjectHeaderView: View {
    let project: Project
    let totalTasks: Int
    let completedTasks: Int
    let totalTimeSpent: Int
    let activeTimers: Int

    private var completionPercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Color + Title + Progress
            VStack(spacing: DesignSystem.Spacing.lg) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 80, height: 80)
                    .designShadow(
                        ShadowStyle(
                            color: Color(hex: project.color).opacity(0.3),
                            radius: 12, x: 0, y: 4
                        )
                    )

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(project.title)
                        .font(DesignSystem.Typography.title2)
                        .multilineTextAlignment(.center)

                    if totalTasks > 0 {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("\(completedTasks) of \(totalTasks) completed")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.secondary)
                                Spacer()
                                Text("\(Int(completionPercentage * 100))%")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color(hex: project.color))
                            }
                            ProgressView(value: completionPercentage)
                                .tint(Color(hex: project.color))
                                .scaleEffect(y: 1.5)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xxxl)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            // 2x2 stats grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                ],
                spacing: DesignSystem.Spacing.md
            ) {
                ProjectStatCard(icon: "checklist",
                                value: "\(totalTasks)",
                                label: "Tasks",
                                color: DesignSystem.Colors.info)
                ProjectStatCard(icon: "checkmark.circle.fill",
                                value: "\(completedTasks)",
                                label: "Done",
                                color: DesignSystem.Colors.success)
                ProjectStatCard(icon: "clock.fill",
                                value: totalTimeSpent.formattedTime(),
                                label: "Time",
                                color: DesignSystem.Colors.warning)
                ProjectStatCard(icon: "timer",
                                value: "\(activeTimers)",
                                label: "Active",
                                color: DesignSystem.Colors.timerActive)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
}
