import SwiftUI
import SwiftData

/// Unified Work section combining Quantity tracking and Productivity insights
/// Shows output progress and live productivity metrics when applicable
struct TaskWorkView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    @State private var showingQuantityPicker = false
    @State private var editedExpectedQuantity: String = ""
    @State private var editedQuantity: String = ""
    @State private var editedUnit: UnitType = .none
    @State private var saveError: TaskActionAlert?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // MARK: - Output Section
            outputSection

            // MARK: - Productivity Section (conditional)
            if task.hasLiveProductivityInsights && !task.isCompleted {
                Divider()
                    .padding(.horizontal)

                productivitySection
            }

            // MARK: - Completed Task Productivity (historical)
            if let productivity = task.unitsPerHour, task.isCompleted {
                Divider()
                    .padding(.horizontal)

                completedProductivitySection(productivity: productivity)
            }
        }
        .sheet(isPresented: $showingQuantityPicker) {
            quantityPickerSheet
        }
        .taskActionAlert(alert: $saveError)
        .onAppear {
            syncEditedValues()
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section header
            Text("OUTPUT")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            if task.unit.isQuantifiable || task.expectedQuantity != nil {
                // Has quantity tracking
                quantityContent
            } else {
                // No quantity set - show setup prompt
                emptyStateView
            }
        }
    }

    private var quantityContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Target row
            if let expected = task.expectedQuantity {
                HStack {
                    Image(systemName: "target")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(formatQuantity(expected)) \(task.unitDisplayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Button {
                        showingQuantityPicker = true
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }

            // Completed row with progress
            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.body)
                    .foregroundStyle(progressColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let expected = task.expectedQuantity, expected > 0 {
                        let completed = task.quantity ?? 0
                        let progress = task.quantityProgress ?? 0
                        Text("\(formatQuantity(completed))/\(formatQuantity(expected)) \(task.unitDisplayName) (\(Int(progress * 100))%)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else if let completed = task.quantity {
                        Text("\(formatQuantity(completed)) \(task.unitDisplayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("Not started")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if task.expectedQuantity == nil {
                    Button {
                        showingQuantityPicker = true
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            // Progress bar
            if let progress = task.quantityProgress {
                QuantityProgressBar(progress: progress)
                    .padding(.horizontal)
            }
        }
    }

    private var emptyStateView: some View {
        Button {
            showingQuantityPicker = true
            HapticManager.selection()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(.blue)

                Text("Set up quantity tracking")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Productivity Section (In-Progress)

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("PRODUCTIVITY")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            // Current rate
            if let currentRate = task.liveProductivityRate {
                HStack {
                    Image(systemName: "speedometer")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(formatRate(currentRate)) \(task.unitDisplayName)/person-hr")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Required rate
            if let requiredRate = task.requiredProductivityRate {
                HStack {
                    Image(systemName: "target")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Required rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(formatRate(requiredRate)) \(task.unitDisplayName)/person-hr")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }

            // Pace status
            if let status = task.productivityPaceStatus {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: status.icon)
                        .font(.body)
                        .foregroundStyle(status.color)
                        .frame(width: 28)

                    Text(status.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(status.color)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(status.color.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Completed Productivity Section

    private func completedProductivitySection(productivity: Double) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("PRODUCTIVITY")
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
                    Text("\(formatRate(productivity)) \(task.unitDisplayName)/person-hr")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.success)

                    if let personHours = task.totalPersonHours {
                        Text("\(String(format: "%.1f", personHours)) person-hours tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Quantity Picker Sheet

    private var quantityPickerSheet: some View {
        NavigationStack {
            Form {
                Section("Unit Type") {
                    Picker("Unit", selection: $editedUnit) {
                        ForEach(UnitType.allCases, id: \.self) { unit in
                            HStack {
                                Image(systemName: unit.icon)
                                Text(unit.displayName)
                            }
                            .tag(unit)
                        }
                    }
                }

                if editedUnit.isQuantifiable {
                    Section("Target Quantity") {
                        TextField("Expected", text: $editedExpectedQuantity)
                            .keyboardType(.decimalPad)
                    }

                    Section("Completed Quantity") {
                        TextField("Completed", text: $editedQuantity)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Edit Output")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingQuantityPicker = false
                        syncEditedValues()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveQuantityChanges()
                        showingQuantityPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var progressColor: Color {
        guard let progress = task.quantityProgress else { return .secondary }
        if progress >= 1.0 {
            return DesignSystem.Colors.success
        }
        return .secondary
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatRate(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func syncEditedValues() {
        editedUnit = task.unit
        editedExpectedQuantity = task.expectedQuantity.map { formatQuantity($0) } ?? ""
        editedQuantity = task.quantity.map { formatQuantity($0) } ?? ""
    }

    private func saveQuantityChanges() {
        task.unit = editedUnit

        if let expected = Double(editedExpectedQuantity), expected > 0 {
            task.expectedQuantity = expected
        } else {
            task.expectedQuantity = nil
        }

        if let completed = Double(editedQuantity), completed > 0 {
            task.quantity = completed
        } else {
            task.quantity = nil
        }

        do {
            try modelContext.save()
            HapticManager.success()
        } catch {
            saveError = TaskActionAlert(
                title: "Save Failed",
                message: "Could not save changes: \(error.localizedDescription)",
                actions: [AlertAction(title: "OK", role: .cancel, action: {})]
            )
        }
    }
}

// MARK: - Quantity Progress Bar

private struct QuantityProgressBar: View {
    let progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1.0)
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return DesignSystem.Colors.success
        }
        return .blue
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))

                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Summary Badge Helper

extension TaskWorkView {
    /// Returns summary text for collapsed state
    static func summaryText(for task: Task) -> String {
        // Show quantity progress if available
        if task.hasQuantityProgress {
            let completed = task.quantity ?? 0
            let expected = task.expectedQuantity!
            let progress = task.quantityProgress!
            let progressPercent = Int(progress * 100)

            // Add pace indicator if available
            if let status = task.productivityPaceStatus, !task.isCompleted {
                return "\(formatQuantity(completed))/\(formatQuantity(expected)) (\(progressPercent)%) • \(status.label)"
            }

            return "\(formatQuantity(completed))/\(formatQuantity(expected)) \(task.unitDisplayName) (\(progressPercent)%)"
        } else if task.unit != .none, let quantity = task.quantity {
            return "\(formatQuantity(quantity)) \(task.unitDisplayName)"
        } else if task.expectedQuantity != nil {
            return "0/\(formatQuantity(task.expectedQuantity!)) \(task.unitDisplayName) (0%)"
        }
        return "Not set"
    }

    /// Returns summary color for collapsed state
    static func summaryColor(for task: Task) -> Color {
        // Prioritize pace status color for in-progress tasks
        if let status = task.productivityPaceStatus, !task.isCompleted {
            return status.color
        }

        if task.hasQuantityProgress {
            let progress = task.quantityProgress!
            return progress >= 1.0 ? DesignSystem.Colors.success : .secondary
        }
        return .secondary
    }

    /// Returns true if summary should use tertiary style (not set state)
    static func summaryIsTertiary(for task: Task) -> Bool {
        !task.hasQuantityProgress &&
        !(task.unit != .none && task.quantity != nil) &&
        task.expectedQuantity == nil
    }

    private static func formatQuantity(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Previews

#Preview("With Progress and Productivity") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Install Carpet", priority: 1, createdDate: Date())
    task.unit = .squareMeters
    task.expectedQuantity = 60
    task.quantity = 45
    task.timeEstimate = 8 * 3600 // 8 hours
    task.expectedPersonnelCount = 2

    // Add some time entries
    let entry = TimeEntry(
        startTime: Date().addingTimeInterval(-3600 * 3),
        endTime: Date(),
        personnelCount: 2
    )
    entry.task = task
    task.timeEntries = [entry]

    container.mainContext.insert(task)

    ScrollView {
        TaskWorkView(task: task)
    }
    .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, configurations: config)

    let task = Task(title: "Review documents")
    container.mainContext.insert(task)

    ScrollView {
        TaskWorkView(task: task)
    }
    .modelContainer(container)
}

#Preview("Completed Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Task.self, TimeEntry.self, configurations: config)

    let task = Task(title: "Paint walls", priority: 1, createdDate: Date())
    task.unit = .squareMeters
    task.expectedQuantity = 100
    task.quantity = 100
    task.completedDate = Date()

    let entry = TimeEntry(
        startTime: Date().addingTimeInterval(-3600 * 5),
        endTime: Date(),
        personnelCount: 2
    )
    entry.task = task
    task.timeEntries = [entry]

    container.mainContext.insert(task)

    ScrollView {
        TaskWorkView(task: task)
    }
    .modelContainer(container)
}
