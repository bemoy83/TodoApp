//
//  ColorPickerPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 19/10/2025.
//

import SwiftUI

#Preview("Color Grid") {
    let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30"]
    HStack(spacing: 16) {
        ForEach(colors, id: \.self) { hex in
            ColorButton(color: hex, isSelected: hex == "#34C759") { }
        }
    }
    .padding()
}
