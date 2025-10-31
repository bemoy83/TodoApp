//
//  SectionCardsPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI

#Preview("Section Cards") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Project Settings")
                    .font(DesignSystem.Typography.headline)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Tasks")
                        Spacer()
                        Text("12")
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }
            }
            .sectionCardStyle()
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Task Details")
                    .font(DesignSystem.Typography.headline)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Priority")
                        Spacer()
                        Text("High")
                            .foregroundStyle(DesignSystem.Colors.priorityHigh)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Due Date")
                        Spacer()
                        Text("Tomorrow")
                            .foregroundStyle(DesignSystem.Colors.secondary)
                    }
                }
            }
            .sectionCardStyle()
        }
        .padding(DesignSystem.Spacing.lg)
    }
    .background(DesignSystem.Colors.groupedBackground)
}
