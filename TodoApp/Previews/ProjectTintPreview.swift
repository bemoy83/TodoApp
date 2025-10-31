//
//  ProjectTint.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI

#Preview("Project Tint - Light & Dark") {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Circle()
            .fill(DesignSystem.Colors.error)
                    .frame(width: 40, height: 40)
                
                Text("test")
                    .font(DesignSystem.Typography.title3)
                
                Text("This section has a subtle tint using the project color. The opacity adjusts automatically for dark mode.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
            .padding(DesignSystem.Spacing.xl)
            .projectTint(color: DesignSystem.Colors.error)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
            .background(DesignSystem.Colors.groupedBackground)
}
