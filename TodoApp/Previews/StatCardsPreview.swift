//
//  CardsPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI

#Preview("Stat Cards") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
            ],
            spacing: DesignSystem.Spacing.md
        ) {
            // Stat Card 1
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.success)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("24")
                        .font(DesignSystem.Typography.title2)
                    Text("Completed")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .statCardStyle()
            
            // Stat Card 2
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("12h 30m")
                        .font(DesignSystem.Typography.title2)
                    Text("Time Spent")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .statCardStyle()
            
            // Stat Card 3
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.error)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("3")
                        .font(DesignSystem.Typography.title2)
                    Text("Active")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .statCardStyle()
            
            // Stat Card 4
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.taskBlocked)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("5")
                        .font(DesignSystem.Typography.title2)
                    Text("Blocked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .statCardStyle()
        }
        .padding(DesignSystem.Spacing.lg)
    }
    .background(DesignSystem.Colors.groupedBackground)
}
