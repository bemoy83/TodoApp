//
//  ButtonsPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI


#Preview("Buttons") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Primary Buttons")
                .font(DesignSystem.Typography.headline)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button("Save Changes") { }
                    .primaryButtonStyle()
                
                Button("Complete Task") { }
                    .primaryButtonStyle(color: DesignSystem.Colors.success)
                
                Button("Delete") { }
                    .primaryButtonStyle(color: DesignSystem.Colors.error)
                
                Button("Disabled") { }
                    .primaryButtonStyle(isEnabled: false)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Secondary Buttons")
                .font(DesignSystem.Typography.headline)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button("Cancel") { }
                    .secondaryButtonStyle()
                
                Button("View Details") { }
                    .secondaryButtonStyle(color: DesignSystem.Colors.info)
                
                Button("Remove") { }
                    .secondaryButtonStyle(color: DesignSystem.Colors.error)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Button Combinations")
                .font(DesignSystem.Typography.headline)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") { }
                    .secondaryButtonStyle()
                
                Button("Save") { }
                    .primaryButtonStyle()
            }
        }
    }
    .padding(DesignSystem.Spacing.xl)
}
