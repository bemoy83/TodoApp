//
//  DataStatisticsSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  DataStatisticsSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI

struct DataStatisticsSection: View {
    let totalProjects: Int
    let totalTasks: Int
    let totalTimeTracked: Int
    
    var body: some View {
        Section {
                VStack(spacing: DesignSystem.Spacing.md) {
                    StatRow(
                        icon: "folder.fill",
                        label: "Projects",
                        value: "\(totalProjects)",
                        color: DesignSystem.Colors.info
                    )
                    
                    Divider()
                    
                    StatRow(
                        icon: "checklist",
                        label: "Tasks",
                        value: "\(totalTasks)",
                        color: DesignSystem.Colors.taskInProgress
                    )
                    
                    Divider()
                    
                    StatRow(
                        icon: "clock.fill",
                        label: "Time Tracked",
                        value: formatMinutes(totalTimeTracked),
                        color: DesignSystem.Colors.warning
                    )
                }
            .listRowInsets(EdgeInsets(
                top: DesignSystem.Spacing.lg,
                leading: DesignSystem.Spacing.lg,
                bottom: DesignSystem.Spacing.lg ,
                trailing: DesignSystem.Spacing.lg
            ))
        } header: {
            Label("Data Statistics", systemImage: "chart.bar.fill")
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.lg))
                .foregroundStyle(color)
                .frame(width: DesignSystem.IconSize.xxl)
            
            Text(label)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.primary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundStyle(DesignSystem.Colors.secondary)
        }
    }
}
