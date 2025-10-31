//
//  DataManagementSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  DataManagementSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI

struct DataManagementSection: View {
    let isClearing: Bool
    let isFixingOrder: Bool
    let showFixOrderButton: Bool
    let onExport: () -> Void
    let onClearData: () -> Void
    let onFixOrder: () -> Void
    
    var body: some View {
        Section {
            // Export Data (placeholder)
            Button(action: onExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DesignSystem.Colors.info)
                    Text("Export Data")
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            
            // Fix Task Order (only show if needed)
            if showFixOrderButton {
                Button(action: onFixOrder) {
                    HStack {
                        if isFixingOrder {
                            ProgressView()
                                .tint(DesignSystem.Colors.warning)
                        } else {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .foregroundStyle(DesignSystem.Colors.warning)
                        }
                        Text("Fix Task Order")
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                }
                .disabled(isFixingOrder)
            }
            
            // Clear All Data (destructive)
            Button(role: .destructive, action: onClearData) {
                HStack {
                    if isClearing {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text("Clear All Data")
                }
            }
            .disabled(isClearing)
        } header: {
            Label("Data Management", systemImage: "externaldrive.fill")
        } footer: {
            if showFixOrderButton {
                Text("Fix Task Order assigns order values to existing tasks. Clear All Data will permanently delete all projects, tasks, and time entries.")
                    .font(DesignSystem.Typography.caption)
            } else {
                Text("Clear all data will permanently delete all projects, tasks, and time entries")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.error)
            }
        }
    }
}