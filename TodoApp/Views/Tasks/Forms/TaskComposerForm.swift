import SwiftUI
import SwiftData

/// A reusable, stateless form that mirrors TaskEditView's options.
/// It binds to "draft" fields supplied by a caller (Add or Edit screens).
struct TaskComposerForm: View {
    // Draft bindings
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedProject: Project?
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var priority: Int

    // Time estimate bindings
    @Binding var hasEstimate: Bool
    @Binding var estimateHours: Int
    @Binding var estimateMinutes: Int
    @Binding var hasCustomEstimate: Bool

    // Personnel bindings
    @Binding var hasPersonnel: Bool
    @Binding var expectedPersonnelCount: Int?

    // Unified calculator bindings
    @Binding var unifiedEstimationMode: TaskEstimator.UnifiedEstimationMode
    @Binding var effortHours: Double
    @Binding var quantity: String
    @Binding var unit: UnitType
    @Binding var taskType: String?
    @Binding var quantityCalculationMode: TaskEstimator.QuantityCalculationMode
    @Binding var productivityRate: Double?

    // Context
    let isSubtask: Bool
    let parentTask: Task?
    let editingTask: Task?

    // Query all tasks to calculate subtask estimates without accessing relationships
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    @State private var showingDateValidationAlert = false
    @State private var showingEstimateValidationAlert = false
    @State private var estimateValidationMessage = ""

    // MARK: - Computed Properties

    private var inheritedProject: Project? {
        parentTask?.project
    }

    /// Personnel is auto-calculated (read-only) when in certain modes
    private var personnelIsAutoCalculated: Bool {
        switch unifiedEstimationMode {
        case .duration:
            return false
        case .effort:
            return false
        case .quantity:
            return quantityCalculationMode == .calculatePersonnel
        }
    }

    private var parentDueDate: Date? {
        parentTask?.dueDate
    }

    // Calculate subtask estimate total using @Query (avoids accessing relationships)
    // Returns total in MINUTES for display purposes
    private var taskSubtaskEstimateTotal: Int? {
        guard let task = editingTask else { return nil }
        let subtasks = allTasks.filter { $0.parentTask?.id == task.id }
        guard !subtasks.isEmpty else { return nil }

        let totalSeconds = subtasks.compactMap { $0.estimatedSeconds }.reduce(0, +)
        return totalSeconds / 60
    }

    // For subtasks: show parent's total using @Query
    // Returns total in MINUTES for display purposes
    private var parentSubtaskEstimateTotal: Int? {
        guard let parent = parentTask else { return nil }
        let subtasks = allTasks.filter { $0.parentTask?.id == parent.id }
        guard !subtasks.isEmpty else { return nil }

        let totalSeconds = subtasks.compactMap { $0.estimatedSeconds }.reduce(0, +)
        return totalSeconds / 60
    }

    // MARK: - Body

    var body: some View {
        Form {
            titleSection
            notesSection
            projectSection
            dueDateSection
            estimateSection
            prioritySection
            personnelSection
        }
        .alert("Invalid Due Date", isPresented: $showingDateValidationAlert) {
            Button("OK") {
                if let parentDue = parentDueDate {
                    dueDate = parentDue
                }
            }
        } message: {
            if let parentDue = parentDueDate {
                Text("Subtask due date cannot be later than parent's due date (\(parentDue.formatted(date: .abbreviated, time: .shortened))).")
            }
        }
        .alert("Invalid Time Estimate", isPresented: $showingEstimateValidationAlert) {
            Button("OK") {
                resetToSubtaskTotal()
            }
        } message: {
            Text(estimateValidationMessage)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Section Views

    private var titleSection: some View {
        Section("Task Details") {
            TextField("Title", text: $title)
                .font(DesignSystem.Typography.body)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add notes...")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.secondary.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextEditor(text: $notes)
                    .font(DesignSystem.Typography.body)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .opacity(notes.isEmpty ? 0.25 : 1)
            }
            .frame(height: 100)
        }
    }

    private var projectSection: some View {
        TaskComposerProjectSection(
            selectedProject: $selectedProject,
            isSubtask: isSubtask,
            inheritedProject: inheritedProject
        )
    }

    private var dueDateSection: some View {
        TaskComposerDueDateSection(
            hasDueDate: $hasDueDate,
            dueDate: $dueDate,
            showingValidationAlert: $showingDateValidationAlert,
            isSubtask: isSubtask,
            parentDueDate: parentDueDate,
            onDateChange: validateSubtaskDueDate
        )
    }

    private var estimateSection: some View {
        TaskComposerEstimateSection(
            unifiedEstimationMode: $unifiedEstimationMode,
            hasEstimate: $hasEstimate,
            estimateHours: $estimateHours,
            estimateMinutes: $estimateMinutes,
            hasCustomEstimate: $hasCustomEstimate,
            effortHours: $effortHours,
            hasPersonnel: $hasPersonnel,
            expectedPersonnelCount: $expectedPersonnelCount,
            hasDueDate: $hasDueDate,
            dueDate: dueDate,
            taskType: $taskType,
            unit: $unit,
            quantity: $quantity,
            quantityCalculationMode: $quantityCalculationMode,
            productivityRate: $productivityRate,
            isSubtask: isSubtask,
            parentSubtaskEstimateTotal: parentSubtaskEstimateTotal,
            taskSubtaskEstimateTotal: taskSubtaskEstimateTotal,
            onEstimateValidation: validateEstimate,
            onEffortUpdate: updateDurationFromEffort,
            onQuantityUpdate: updateFromQuantityCalculation
        )
    }

    private var prioritySection: some View {
        Section("Priority") {
            Picker("Priority Level", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { p in
                    HStack {
                        Circle()
                            .fill(p.color)
                            .frame(width: 12, height: 12)
                        Text(p.label)
                    }
                    .tag(p.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var personnelSection: some View {
        TaskComposerPersonnelSection(
            hasPersonnel: $hasPersonnel,
            expectedPersonnelCount: $expectedPersonnelCount,
            unifiedEstimationMode: $unifiedEstimationMode,
            personnelIsAutoCalculated: personnelIsAutoCalculated,
            quantityCalculationMode: quantityCalculationMode
        )
    }

    // MARK: - Helper Methods

    /// Update duration fields from effort calculation
    private func updateDurationFromEffort() {
        guard unifiedEstimationMode == .effort,
              effortHours > 0,
              let personnel = expectedPersonnelCount, personnel > 0 else {
            return
        }

        // Calculate duration: effort / personnel
        let durationHours = effortHours / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        // Update duration fields
        estimateHours = totalSeconds / 3600
        estimateMinutes = (totalSeconds % 3600) / 60
        hasEstimate = true
    }

    /// Update fields from quantity calculation
    private func updateFromQuantityCalculation() {
        guard unifiedEstimationMode == .quantity,
              let qty = Double(quantity), qty > 0,
              let rate = productivityRate, rate > 0 else {
            return
        }

        switch quantityCalculationMode {
        case .calculateDuration:
            guard let personnel = expectedPersonnelCount, personnel > 0 else { return }
            let durationHours = (qty / rate) / Double(personnel)
            let totalSeconds = Int(durationHours * 3600)

            estimateHours = totalSeconds / 3600
            estimateMinutes = (totalSeconds % 3600) / 60
            hasEstimate = true
            hasPersonnel = true

        case .calculatePersonnel:
            let totalDurationHours = Double(estimateHours) + (Double(estimateMinutes) / 60.0)
            guard totalDurationHours > 0 else { return }

            let personnel = Int(ceil((qty / rate) / totalDurationHours))
            expectedPersonnelCount = max(1, personnel)
            hasPersonnel = true
            hasEstimate = true

        case .manualEntry:
            break
        }
    }

    private func validateSubtaskDueDate(_ newDate: Date) {
        let result = TaskFormValidator.validateSubtaskDueDate(
            subtaskDate: newDate,
            parentDate: parentDueDate,
            isSubtask: isSubtask
        )

        if !result.isValid {
            showingDateValidationAlert = true
        }
    }

    private func validateEstimate() {
        let result = TaskFormValidator.validateCustomEstimate(
            estimateHours: estimateHours,
            estimateMinutes: estimateMinutes,
            subtaskTotalMinutes: taskSubtaskEstimateTotal,
            hasCustomEstimate: hasCustomEstimate,
            isSubtask: isSubtask
        )

        if !result.isValid, let message = result.errorMessage {
            estimateValidationMessage = message
            showingEstimateValidationAlert = true
        }
    }

    private func resetToSubtaskTotal() {
        guard let total = taskSubtaskEstimateTotal else { return }
        estimateHours = total / 60
        estimateMinutes = (total % 60)

        // Round minutes to nearest 15
        let roundedMinutes = ((estimateMinutes + 7) / 15) * 15
        estimateMinutes = roundedMinutes
        if roundedMinutes >= 60 {
            estimateHours += 1
            estimateMinutes = 0
        }
    }
}
