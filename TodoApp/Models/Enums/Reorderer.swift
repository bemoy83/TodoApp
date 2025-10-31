//
//  Reorderer.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 16/10/2025.
//


import SwiftUI
import SwiftData

enum Reorderer {
    /// Generic reorder helper: sorts by a provided key, moves, renumbers, saves, and does haptics.
    static func reorder<T>(
        items: [T],
        currentOrder: (T) -> Int,          // how to read current order for sorting (map Int? to Int if needed)
        setOrder: (T, Int) -> Void,        // how to write the new order back
        from source: IndexSet,
        to destination: Int,
        save: () throws -> Void            // persistence closure (e.g., { try modelContext.save() })
    ) {
        HapticManager.selection()

        // Work on the same references; SwiftData models are class instances.
        var list = items.sorted { currentOrder($0) < currentOrder($1) }
        list.move(fromOffsets: source, toOffset: destination)

        for (index, element) in list.enumerated() {
            setOrder(element, index)
        }

        do {
            try save()
            HapticManager.light()
        } catch {
            // Optional: add your logging here
        }
    }
}
