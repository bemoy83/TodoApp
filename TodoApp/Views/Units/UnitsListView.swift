import SwiftUI
import SwiftData

/// List view for managing custom units
struct UnitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomUnit.order) private var units: [CustomUnit]

    @State private var showingAddUnit = false
    @State private var unitToEdit: CustomUnit?
    @State private var unitToDelete: CustomUnit?
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            // System Units Section
            Section {
                ForEach(systemUnits) { unit in
                    UnitRow(unit: unit, isSystem: true)
                }
            } header: {
                Text("System Units")
            } footer: {
                Text("Built-in units that cannot be deleted")
            }

            // Custom Units Section
            if !customUnits.isEmpty {
                Section {
                    ForEach(customUnits) { unit in
                        UnitRow(unit: unit, isSystem: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    unitToDelete = unit
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    unitToEdit = unit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    unitToEdit = unit
                                } label: {
                                    Label("Edit Unit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    unitToDelete = unit
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete Unit", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Custom Units")
                } footer: {
                    Text("Units you've created for your specific needs")
                }
            }
        }
        .navigationTitle("Units")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddUnit = true
                } label: {
                    Label("Add Unit", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddUnit) {
            UnitFormView(unit: nil)
        }
        .sheet(item: $unitToEdit) { unit in
            UnitFormView(unit: unit)
        }
        .alert("Delete Unit?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let unit = unitToDelete {
                    deleteUnit(unit)
                }
            }
        } message: {
            if let unit = unitToDelete,
               let templateCount = unit.templates?.count, templateCount > 0 {
                Text("This unit is used by \(templateCount) template(s). Deleting it will remove the unit from those templates.")
            } else {
                Text("Are you sure you want to delete this unit? This action cannot be undone.")
            }
        }
    }

    // MARK: - Computed Properties

    private var systemUnits: [CustomUnit] {
        units.filter { $0.isSystem }
    }

    private var customUnits: [CustomUnit] {
        units.filter { !$0.isSystem }
    }

    // MARK: - Actions

    private func deleteUnit(_ unit: CustomUnit) {
        HapticManager.warning()
        modelContext.delete(unit)
        try? modelContext.save()
        HapticManager.success()
    }
}

// MARK: - Unit Row

struct UnitRow: View {
    let unit: CustomUnit
    let isSystem: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: unit.icon)
                .font(.title3)
                .foregroundStyle(isSystem ? .blue : .purple)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name)
                    .font(.body)

                if let rate = unit.defaultProductivityRate {
                    Text("\(String(format: "%.1f", rate)) \(unit.name)/person-hr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !unit.isQuantifiable {
                Text("Non-quantifiable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Units List") {
    NavigationStack {
        UnitsListView()
            .modelContainer(for: [CustomUnit.self, TaskTemplate.self], inMemory: true)
    }
}
