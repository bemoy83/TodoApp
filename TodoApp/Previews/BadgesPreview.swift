//
//  BadgesPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI


#Preview("Badges") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Status Badges")
                .font(DesignSystem.Typography.headline)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Ready")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.taskReady)
                
                Text("In Progress")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.taskInProgress)
                
                Text("Blocked")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.taskBlocked)
                
                Text("Done")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.taskCompleted)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Count Badges")
                .font(DesignSystem.Typography.headline)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("5")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.info)
                
                Text("12")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.success)
                
                Text("3")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.warning)
                
                Text("0")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.error)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Priority Badges")
                .font(DesignSystem.Typography.headline)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Urgent")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.priorityUrgent)
                
                Text("High")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.priorityHigh)
                
                Text("Medium")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.priorityMedium)
                
                Text("Low")
                    .badgeStyle(backgroundColor: DesignSystem.Colors.priorityLow)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Custom Foreground")
                .font(DesignSystem.Typography.headline)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Dark")
                    .badgeStyle(
                        backgroundColor: Color.yellow,
                        foregroundColor: .black
                    )
                
                Text("Custom")
                    .badgeStyle(
                        backgroundColor: Color.purple.opacity(0.2),
                        foregroundColor: .purple
                    )
            }
        }
    }
    .padding(DesignSystem.Spacing.xl)
}
