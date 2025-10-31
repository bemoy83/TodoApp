//
//  MetaLabel.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//


import SwiftUI

/// Small capsule of "icon + caption text" styled as secondary, used across rows.
public struct MetaLabel: View {
    let text: String
    let systemImage: String

    public init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.secondary)
    }
}
