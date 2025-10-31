//
//  AppSettingsSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  AppSettingsSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI

struct AppSettingsSection: View {
    @Binding var appearanceMode: Int
    @Binding var defaultPriority: Int
    @Binding var showCompletedByDefault: Bool
    @Binding var compactViewMode: Bool
    
    private var appearanceModeOptions: [String] {
        ["System", "Light", "Dark"]
    }
    
    var body: some View {
        Section {
            // Appearance
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(0..<appearanceModeOptions.count, id: \.self) { index in
                    HStack {
                        Image(systemName: appearanceIcon(for: index))
                            .foregroundStyle(DesignSystem.Colors.secondary)
                        Text(appearanceModeOptions[index])
                    }
                    .tag(index)
                }
            }
            
            // Default Priority
            Picker("Default Priority", selection: $defaultPriority) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    HStack {
                        Circle()
                            .fill(priority.color)
                            .frame(width: 12, height: 12)
                        Text(priority.label)
                    }
                    .tag(priority.rawValue)
                }
            }
            
            // Show Completed Tasks
            Toggle(isOn: $showCompletedByDefault) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(DesignSystem.Colors.taskCompleted)
                    Text("Show Completed Tasks")
                }
            }
            
            // Compact View Mode
            Toggle(isOn: $compactViewMode) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "rectangle.compress.vertical")
                        .foregroundStyle(DesignSystem.Colors.info)
                    Text("Compact View Mode")
                }
            }
        } header: {
            Label("App Settings", systemImage: "gearshape.fill")
        } footer: {
            Text("Customize how the app looks and behaves")
                .font(DesignSystem.Typography.caption)
        }
    }
    
    private func appearanceIcon(for mode: Int) -> String {
        switch mode {
        case 0: return "circle.lefthalf.filled" // System
        case 1: return "sun.max.fill"           // Light
        case 2: return "moon.fill"              // Dark
        default: return "circle.lefthalf.filled"
        }
    }
}