import SwiftUI
import SwiftData

/// Redesigned quantity tracking view with clear planning vs progress separation
/// - Shows planned quantity (the plan)
/// - Shows completed quantity (actual progress)
/// - Visual progress indicators (percentage, progress bar, ratio)
/// - Single screen, card-based layout
struct TaskQuantityView: View {
    @Bindable var task: Task

    @State private var showingQuantityPicker = false
    @State private var editedQuantity: String = ""
    @State private var editedExpectedQuantity: String = ""
    @State private var editedUnit: UnitType = .none
    @State private var saveError: TaskActionAlert?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {

            // MARK: - Planning Section (Expected Quantity)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("PLANNED")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal)

                if let expected = task.expectedQuantity, task.isUnitQuantifiable {
                    // Show planned quantity
                    HStack {
                        Image(systemName: task.unitIcon)
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.info)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(formatQuantity(expected))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text(task.unitDisplayName)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Target quantity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                } else if task.isUnitQuantifiable {
                    // Unit set but no expected quantity
                    HStack {
                        Image(systemName: task.unitIcon)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No target set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Set expected quantity to track progress")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                } else {
                    // No unit selected
                    HStack {
                        Image(systemName: "number")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No unit selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Tap below to set up quantity tracking")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }

            // MARK: - Progress Section (Completed vs Planned)

            if task.hasQuantityProgress {
                Divider()
                    .padding(.horizontal)

                let completed = task.quantity ?? 0
                let expected = task.expectedQuantity!
                let progress = task.quantityProgress!
                let progressPercent = Int(min(progress, 1.0) * 100)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("COMPLETED")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        // "X of Y" ratio
                        HStack(spacing: 4) {
                            Text(formatQuantity(completed))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(progressColor(for: progress))

                            Text("of")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(formatQuantity(expected))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(task.unitDisplayName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal)

                    // Progress bar
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill (clamped at 100% for visual)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor(for: progress))
                                    .frame(width: geometry.size.width * min(progress, 1.0), height: 8)
                            }
                        }
                        .frame(height: 8)

                        // Percentage label
                        HStack {
                            Text("\(progressPercent)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(progressColor(for: progress))

                            Spacer()

                            // Over-completion warning
                            if progress > 1.0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                    Text("Over target")
                                        .font(.caption)
                                }
                                .foregroundStyle(.orange)
                            } else if let remaining = task.quantityRemaining, remaining > 0 {
                                Text("\(formatQuantity(remaining)) \(task.unitDisplayName) remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else if task.isUnitQuantifiable, let quantity = task.quantity, quantity > 0 {
                // Completed quantity without expected (no progress tracking)
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("COMPLETED")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.success)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(formatQuantity(quantity))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text(task.unitDisplayName)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            Text("No progress tracking (expected quantity not set)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            } else if task.expectedQuantity != nil && task.expectedQuantity! > 0 {
                // Expected set but no completed quantity yet
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("COMPLETED")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    HStack {
                        Image(systemName: "circle")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .frame(width: 28)

                        Text("No work logged yet")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }

            // MARK: - Task Type (if set)

            if let taskType = task.taskType {
                Divider()
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "tag.fill")
                        .font(.body)
                        .foregroundStyle(.purple)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(taskType)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("Task category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }

            // MARK: - Action Button

            Divider()
                .padding(.horizontal)

            Button {
                // Populate edit values
                editedExpectedQuantity = task.expectedQuantity.map { formatQuantity($0) } ?? ""
                editedQuantity = task.quantity.map { formatQuantity($0) } ?? ""
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

            // MARK: - Productivity Metrics (Completed Tasks)

            if let productivity = task.unitsPerHour, task.isCompleted {
                Divider()
                    .padding(.horizontal)

                ProductivitySection(
                    productivity: productivity,
                    unitDisplayName: task.unitDisplayName,
                    personHours: task.totalPersonHours
                )
            }
        }
        .detailCardStyle()
        .sheet(isPresented: $showingQuantityPicker) {
            QuantityPickerSheet(
                expectedQuantity: $editedExpectedQuantity,
                completedQuantity: $editedQuantity,
                unit: $editedUnit,
                taskType: task.taskType,
                onSave: {
                    // Save expected quantity
                    if let expected = Double(editedExpectedQuantity), expected > 0 {
                        task.expectedQuantity = expected
                    } else {
                        task.expectedQuantity = nil
                    }

                    // Save completed quantity
                    if let completed = Double(editedQuantity), completed > 0 {
                        task.quantity = completed
                    } else {
                        task.quantity = nil
                    }

                    // Save unit
                    task.unit = editedUnit

                    do {
                        try task.modelContext?.save()
                        HapticManager.success()
                    } catch {
                        saveError = TaskActionAlert(
                            title: "Save Failed",
                            message: "Could not save quantity: \(error.localizedDescription)",
                            actions: [AlertAction(title: "OK", role: .cancel, action: {})]
                        )
                    }
                },
                onRemove: (task.unit != .none || task.quantity != nil || task.expectedQuantity != nil) ? {
                    task.quantity = nil
                    task.expectedQuantity = nil
                    task.unit = .none
                    do {
                        try task.modelContext?.save()
                        HapticManager.success()
                    } catch {
                        saveError = TaskActionAlert(
                            title: "Save Failed",
                            message: "Could not remove quantity tracking: \(error.localizedDescription)",
                            actions: [AlertAction(title: "OK", role: .cancel, action: {})]
                        )
                    }
                } : nil
            )
        }
        .taskActionAlert(alert: $saveError)
    }

    // MARK: - Helper Methods

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func progressColor(for progress: Double) -> Color {
        if progress >= 1.0 {
            return DesignSystem.Colors.success
        } else if progress >= 0.75 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.info
        }
    }

    private var buttonText: String {
        if task.unit != .none || task.expectedQuantity != nil || task.quantity != nil {
            return "Edit Quantity"
        } else {
            return "Set Up Quantity Tracking"
        }
    }

    private var buttonIcon: String {
        if task.unit != .none || task.expectedQuantity != nil || task.quantity != nil {
            return "pencil.circle.fill"
        } else {
            return "plus.circle.fill"
        }
    }
}

// MARK: - Quantity Picker Sheet

private struct QuantityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var expectedQuantity: String
    @Binding var completedQuantity: String
    @Binding var unit: UnitType
    let taskType: String?
    let onSave: () -> Void
    let onRemove: (() -> Void)?

    @FocusState private var focusedField: Field?

    enum Field {
        case expected
        case completed
    }

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
                } footer: {
                    Text("Select the unit of measurement for this task (e.g., m², pieces, kg).")
                }

                if unit.isQuantifiable {
                    Section {
                        HStack {
                            TextField("Expected", text: $expectedQuantity)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .expected)

                            Text(unit.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Planned Quantity")
                    } footer: {
                        Text("The target amount you plan to complete (e.g., total area to paint, items to install).")
                    }

                    Section {
                        HStack {
                            TextField("Completed", text: $completedQuantity)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .completed)

                            Text(unit.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Completed Quantity")
                    } footer: {
                        Text("The amount of work already completed. Update this as you make progress.")
                    }
                }

                if let taskType = taskType {
                    Section {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.purple)
                            Text(taskType)
                        }
                    } header: {
                        Text("Task Category")
                    }
                }
            }
            .navigationTitle("Quantity Tracking")
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
                // Auto-focus expected field if both are empty
                if unit.isQuantifiable && expectedQuantity.isEmpty && completedQuantity.isEmpty {
                    focusedField = .expected
                }
            }
        }
    }
}

// MARK: - Productivity Section

private struct ProductivitySection: View {
    let productivity: Double
    let unitDisplayName: String
    let personHours: Double?

    private var formattedProductivity: String {
        String(format: "%.1f", productivity)
    }

    private var formattedPersonHours: String {
        guard let hours = personHours else { return "0.0" }
        return String(format: "%.1f", hours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("PRODUCTIVITY")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formattedProductivity) \(unitDisplayName)/person-hr")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.success)

                    Text("\(formattedPersonHours) person-hours tracked")
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

#Preview("With Progress Tracking") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Paint walls", expectedQuantity: 60.0, quantity: 45.5, unit: .squareMeters)

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

#Preview("Over Target") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install flooring", expectedQuantity: 100.0, quantity: 130.0, unit: .squareMeters)
    container.mainContext.insert(task)

    return TaskQuantityView(task: task)
        .modelContainer(container)
        .padding()
}

#Preview("Expected Set, No Progress") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Install flooring", expectedQuantity: 100.0, unit: .squareMeters)
    container.mainContext.insert(task)

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
