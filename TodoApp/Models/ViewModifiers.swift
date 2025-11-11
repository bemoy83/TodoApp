//
//  ViewModifiers.swift
//  TodoApp
//
//  Reusable view modifiers for consistent styling
//

import SwiftUI
import UIKit // for UIAccessibility

// MARK: - Card Modifiers

/// Standard card style with background and shadow
struct CardModifier: ViewModifier {
    var backgroundColor: Color = DesignSystem.Colors.background
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.md
    var shadow: ShadowStyle = DesignSystem.Shadow.sm
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .designShadow(shadow)
    }
}

/// Modern detail card style (used in TaskDetailHeaderView)
struct DetailCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color(DesignSystem.Colors.secondaryGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.xl)
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

extension View {
    func cardStyle(
        backgroundColor: Color = DesignSystem.Colors.background,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        shadow: ShadowStyle = DesignSystem.Shadow.sm
    ) -> some View {
        modifier(CardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }
    
    func detailCardStyle() -> some View {
        modifier(DetailCardModifier())
    }
}

// MARK: - Stat Card Style

/// Style for project stats display cards
struct StatCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.secondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
            .designShadow(DesignSystem.Shadow.sm)
    }
}

extension View {
    func statCardStyle() -> some View {
        modifier(StatCardModifier())
    }
}

// MARK: - Section Card Style

/// Style for grouped content sections
struct SectionCardModifier: ViewModifier {
    var padding: CGFloat = DesignSystem.Spacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DesignSystem.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }
}

extension View {
    func sectionCardStyle(padding: CGFloat = DesignSystem.Spacing.lg) -> some View {
        modifier(SectionCardModifier(padding: padding))
    }
}

// MARK: - Badge Style

/// Small badge for counts, status indicators, etc.
struct BadgeModifier: ViewModifier {
    var backgroundColor: Color
    var foregroundColor: Color = .white
    
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.caption)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
}

extension View {
    func badgeStyle(
        backgroundColor: Color,
        foregroundColor: Color = .white
    ) -> some View {
        modifier(BadgeModifier(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor
        ))
    }
}

// MARK: - Button Styles

/// Primary action button style
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = DesignSystem.Colors.taskInProgress
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyBold)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(isEnabled ? color : color.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.circle))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

/// Secondary button style (outlined)
struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = DesignSystem.Colors.taskInProgress
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(color, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

extension View {
    func primaryButtonStyle(
        color: Color = DesignSystem.Colors.taskInProgress,
        isEnabled: Bool = true
    ) -> some View {
        buttonStyle(PrimaryButtonStyle(color: color, isEnabled: isEnabled))
    }
    
    func secondaryButtonStyle(color: Color = DesignSystem.Colors.taskInProgress) -> some View {
        buttonStyle(SecondaryButtonStyle(color: color))
    }
}

// MARK: - Project Color Picker

struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 44, height: 44)
                
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(color)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Empty State Style

/// Style for empty state views
struct EmptyStateModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignSystem.Spacing.huge)
            .padding(.vertical, DesignSystem.Spacing.massive)
    }
}

extension View {
    func emptyStateStyle() -> some View {
        modifier(EmptyStateModifier())
    }
}

// MARK: - Project Color Tint

/// Apply project color as a subtle tint
struct ProjectTintModifier: ViewModifier {
    let color: Color
    let opacity: Double
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                color.opacity(
                    colorScheme == .dark ? opacity * 0.5 : opacity
                )
            )
    }
}

extension View {
    func projectTint(color: Color, opacity: Double = 0.1) -> some View {
        modifier(ProjectTintModifier(color: color, opacity: opacity))
    }
}

// MARK: - Pulsing Animation

/// Pulsing animation for active timer indicators
struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    /// Applies PulsingModifier only when active and motion is allowed.
    @ViewBuilder
    func pulsingAnimation(active: Bool) -> some View {
        if active && !UIAccessibility.isReduceMotionEnabled {
            self.modifier(PulsingModifier())
        } else {
            self
        }
    }
}

// MARK: - Stat Card

/// Non-tappable stat card for displaying metrics
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let subtitle: String?
    let color: Color

    init(
        icon: String,
        value: String,
        label: String,
        subtitle: String? = nil,
        color: Color
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.subtitle = subtitle
        self.color = color
    }

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
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .statCardStyle()
    }
}

// MARK: - Tappable Stat Card

/// Tappable wrapper for stat cards (analytics use case)
struct TappableStatCard: View {
    let icon: String
    let value: String
    let label: String
    let subtitle: String?
    let color: Color
    let onTap: (() -> Void)?

    init(
        icon: String,
        value: String,
        label: String,
        subtitle: String? = nil,
        color: Color,
        onTap: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.subtitle = subtitle
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            if let onTap = onTap {
                HapticManager.light()
                onTap()
            }
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.tertiary)
                    }
                }
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(value)
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.primary)
                    Text(label)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .statCardStyle()
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - Attention Card

/// Compact horizontal card for attention-needed items
struct AttentionCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.light()
            onTap()
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.primary)

                    Text("\(count) \(count == 1 ? "task" : "tasks")")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(Color(UIColor.systemBackground))
            )
            .designShadow(DesignSystem.Shadow.sm)
        }
        .buttonStyle(.plain)
    }
}
