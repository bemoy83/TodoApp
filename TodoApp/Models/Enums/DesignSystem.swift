//
//  DesignSystem.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//


//
//  DesignSystem.swift
//  TodoApp
//
//  Design system for consistent styling across the app
//

import SwiftUI

// MARK: - Design System

enum DesignSystem {
    
    // MARK: - Colors
    
    enum Colors {
        // Task Status Colors
        static let taskReady = Color.gray
        static let taskInProgress = Color.blue
        static let taskBlocked = Color.red
        static let taskCompleted = Color.green
        
        // Priority Colors
        static let priorityUrgent = Color.red
        static let priorityHigh = Color.orange
        static let priorityMedium = Color.blue
        static let priorityLow = Color.gray
        
        // Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Active Timer
        static let timerActive = Color.red
        
        // Background Layers (adapt to light/dark mode automatically)
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
        
        // Text Colors
        static let primary = Color.primary
        static let secondary = Color.secondary
        
        // Borders and Separators
        static let separator = Color(.separator)
        static let border = Color(.separator).opacity(0.5)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 40
        static let massive: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let circle: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let xs = ShadowStyle(
            color: .black.opacity(0.03),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let sm = ShadowStyle(
            color: .black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let md = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let lg = ShadowStyle(
            color: .black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let xl = ShadowStyle(
            color: .black.opacity(0.15),
            radius: 24,
            x: 0,
            y: 12
        )
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Body
        static let headline = Font.headline
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)
        static let bodyMedium = Font.body.weight(.medium)
        
        // Supporting
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let huge: CGFloat = 44
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6)
    }
    
    // MARK: - Layout
    
    enum Layout {
        // List row insets
        static let listRowInsets = EdgeInsets(
            top: Spacing.xs,
            leading: Spacing.lg,
            bottom: Spacing.xs,
            trailing: Spacing.lg
        )
        
        // Card padding
        static let cardPadding = Spacing.lg
        
        // Section spacing
        static let sectionSpacing = Spacing.xxxl
        
        // Minimum touch target
        static let minTouchTarget: CGFloat = 44
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    /// Apply a design system shadow
    func designShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
