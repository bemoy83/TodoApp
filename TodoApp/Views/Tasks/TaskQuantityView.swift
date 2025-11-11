import SwiftUI
import SwiftData

/// Interactive quantity/unit tracking view for productivity measurement
struct TaskQuantityView: View {
    @Bindable var task: Task

    @State private var showingQuantityPicker = false
    @State private var editedQuantity: String = ""
    @State private var editedUnit: UnitType = .none

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header
            Text("Quantity Tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Current quantity and unit display
                if task.unit.isQuantifiable, let quantity = task.quantity {
                    // Has quantity set
                    Button {
                        editedQuantity = String(format: "%.1f", quantity)
                        editedUnit = task.unit
                        showingQuantityPicker = true
                        HapticManager.selection()
                    } label: {
                        HStack {
                            Image(systemName: task.unit.icon)
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.info)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(formatQuantity(quantity)) \(task.unit.displayName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("Work completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal)
                } else if task.unit.isQuantifiable {
                    // Unit set but no quantity
                    Button {
                        editedQuantity = ""
                        editedUnit = task.unit
                        showingQuantityPicker = true
                        HapticManager.selection()
                    } label: {
                        HStack {
                            Image(systemName: task.unit.icon)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(task.unit.displayName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("Tap to add quantity")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Warning: unit set but no quantity
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .frame(width: 28)

                        Text("Add quantity to track productivity")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                    Divider()
                        .padding(.horizontal)
                } else {
                    // No unit set
                    Text("No unit selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // Action button
                Button {
                    editedQuantity = task.quantity.map { String(format: "%.1f", $0) } ?? ""
                    editedUnit = task.unit
                    showingQuantityPicker = true
                    HapticManager.selection()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: buttonIcon)
                            .font(.body)
                            .foregroundStyle(.blue)

                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Productivity metrics (only show if has data)
                if let productivity = task.unitsPerHour {
                    Divider()
                        .padding(.horizontal)

                    ProductivitySection(
                        productivity: productivity,
                        unit: task.unit,
                        trackedHours: task.totalTrackedTimeHours
                    )
                }
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingQuantityPicker) {
            QuantityPickerSheet(
                quantity: $editedQuantity,
                unit: $editedUnit,
                onSave: {
                    if let value = Double(editedQuantity), value > 0 {
                        task.quantity = value
                        task.unit = editedUnit
                    } else if editedUnit.isQuantifiable {
                        // Unit selected but no valid quantity
                        task.quantity = nil
                        task.unit = editedUnit
                    } else {
                        // No unit selected, clear both
                        task.quantity = nil
                        task.unit = .none
                    }
                    try? task.modelContext?.save()
                    HapticManager.success()
                },
                onRemove: (task.unit != .none || task.quantity != nil) ? {
                    task.quantity = nil
                    task.unit = .none
                    try? task.modelContext?.save()
                    HapticManager.success()
                } : nil
            )
        }
    }

    // MARK: - Helper Methods

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private var buttonText: String {
        if task.unit != .none {
            return "Edit Quantity"
        } else {
            return "Add Quantity"
        }
    }

    private var buttonIcon: String {
        if task.unit != .none {
            return "pencil.circle.fill"
        } else {
            return "plus.circle.fill"
        }
    }
}

// MARK: - Quantity Picker Sheet

private struct QuantityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var quantity: String
    @Binding var unit: UnitType
    let onSave: () -> Void
    let onRemove: (() -> Void)?

    @FocusState private var isQuantityFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Unit", selection: $unit) {
                        ForEach(UnitType.allCases, id: \.self) { unitType in
                            HStack {
                                Image(systemName: unitType.icon)
                                Text(unitType.displayName)
                            }
                            .tag(unitType)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Unit Type")
                }

                if unit.isQuantifiable {
                    Section {
                        HStack {
                            TextField("Quantity", text: $quantity)
                                .keyboardType(.decimalPad)
                                .focused($isQuantityFocused)

                            Text(unit.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Amount Completed")
                    } footer: {
                        Text("Enter the total amount of work completed for this task.")
                    }
                }
            }
            .navigationTitle("Set Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let onRemove = onRemove {
                    Button(role: .destructive) {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Remove Quantity Tracking", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding()
                }
            }
            .onAppear {
                if unit.isQuantifiable && quantity.isEmpty {
                    isQuantityFocused = true
                }
            }
        }
    }
}

// MARK: - Productivity Section

private struct ProductivitySection: View {
    let productivity: Double
    let unit: UnitType
    let trackedHours: Double?

    private var formattedProductivity: String {
        String(format: "%.1f", productivity)
    }

    private var formattedHours: String {
        guard let hours = trackedHours else { return "0.0" }
        return String(format: "%.1f", hours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Productivity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formattedProductivity) \(unit.displayName)/hr")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.success)

                    Text("Based on \(formattedHours) hrs tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Preview

#Preview("With Quantity Set") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Paint walls", quantity: 45.5, unit: .squareMeters)

    let entry = TimeEntry(
        startTime: Date().addingTimeInterval(-7200),
        endTime: Date(),
        personnelCount: 2,
        task: task
    )

    container.mainContext.insert(task)
    container.mainContext.insert(entry)

    return TaskQuantityView(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("Unit Set, No Quantity") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install flooring", unit: .squareMeters)
    container.mainContext.insert(task)

    return TaskQuantityView(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("No Unit Set") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Review documents")
    container.mainContext.insert(task)

    return TaskQuantityView(task: task)
        .modelContainer(container)
        .padding()
}
