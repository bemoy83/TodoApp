//
//  LazyView.swift
//  TodoApp
//
//  Utility view that defers creation of its content until body is evaluated.
//  Useful for NavigationLink destinations to prevent eager view creation.
//

import SwiftUI

/// A view that lazily creates its content.
/// Use this to wrap NavigationLink destinations to prevent eager view creation
/// which can cause performance issues or freezes with complex views.
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}
