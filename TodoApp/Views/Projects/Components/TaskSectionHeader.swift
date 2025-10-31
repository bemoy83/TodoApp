//
//  TaskSectionHeader.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


import SwiftUI

struct TaskSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(iconColor)
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.primary)
            Text("(\(count))")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.secondary)
            Spacer()
        }
        .textCase(nil) // prevent automatic uppercasing
    }
}
