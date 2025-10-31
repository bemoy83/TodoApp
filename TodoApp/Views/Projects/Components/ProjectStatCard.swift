//
//  ProjectStatCard.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


import SwiftUI

struct ProjectStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(value)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.primary)
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .statCardStyle()
    }
}
