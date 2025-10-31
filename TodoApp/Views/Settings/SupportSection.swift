//
//  SupportSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 12/10/2025.
//


//
//  SupportSection.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 11/10/2025.
//

import SwiftUI

struct SupportSection: View {
    var body: some View {
        Section {
            NavigationLink {
                PlaceholderView(
                    icon: "book.fill",
                    title: "Help & Documentation",
                    message: "Coming soon!"
                )
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundStyle(DesignSystem.Colors.info)
                    Text("Help & Documentation")
                }
            }
            
            NavigationLink {
                PlaceholderView(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    message: "Your privacy matters"
                )
            } label: {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(DesignSystem.Colors.success)
                    Text("Privacy Policy")
                }
            }
            
            NavigationLink {
                PlaceholderView(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    message: "Legal information"
                )
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(DesignSystem.Colors.secondary)
                    Text("Terms of Service")
                }
            }
        } header: {
            Label("Support", systemImage: "lifepreserver.fill")
        }
    }
}