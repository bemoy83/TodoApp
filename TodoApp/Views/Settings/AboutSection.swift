//
//  AboutSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  AboutSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI

struct AboutSection: View {
    let onShowToast: (String) -> Void
    
    var body: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
            
            Button {
                onShowToast("Thank you for your support! ❤️")
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Rate App")
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
            
            Button {
                onShowToast("Feedback feature coming soon!")
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(DesignSystem.Colors.info)
                    Text("Send Feedback")
                        .foregroundStyle(DesignSystem.Colors.primary)
                }
            }
        } header: {
            Label("About", systemImage: "info.circle.fill")
        }
    }
}