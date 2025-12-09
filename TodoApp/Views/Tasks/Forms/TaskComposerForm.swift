import SwiftUI
import SwiftData

/// A reusable, stateless form that mirrors TaskEditView's options.
/// It binds to "draft" fields supplied by a caller (Add or Edit screens).
struct TaskComposerForm: View {
    // Draft bindings
    @Binding var title: String
    @Binding var notes: String
    @Binding var hasNotes: Bool
    @Binding var selectedProject: Project?
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date
    @Binding var priority: Int
    @Binding var selectedTagIds: Set<UUID>

    // Grouped estimation state (replaces 13 individual bindings)
    @Binding var estimation: TaskEstimator.EstimationState

    // Context
    let isSubtask: Bool
    let parentTask: Task?
    let editingTask: Task?

    // Query all tasks to calculate subtask estimates without accessing relationships
    @Query(filter: #Predicate<Task> { task in
        !task.isArchived
    }, sort: \Task.order) private var allTasks: [Task]

    // Query projects and templates to pass to child views
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \TaskTemplate.order) private var templates: [TaskTemplate]
    @Query(sort: \Tag.order) private var allTags: [Tag]

    @State private var showingDateValidationAlert = false
    @State private var showingTagPicker = false
    @State private var showingEstimateValidationAlert = false
    @State private var estimateValidationMessage = ""

    // MARK: - Computed Properties

    private var inheritedProject: Project? {
        parentTask?.project
    }

    private var selectedTags: [Tag] {
        allTags.filter { selectedTagIds.contains($0.id) }
    }

    /// Schedule context consolidating 6 date-related parameters
    private var scheduleContext: ScheduleContext {
        ScheduleContext(
            hasDueDate: hasDueDate,
            dueDate: dueDate,
            hasStartDate: hasStartDate,
            startDate: startDate,
            hasEndDate: hasEndDate,
            endDate: endDate
        )
    }

    /// Personnel is auto-calculated (read-only) when in certain modes
    private var personnelIsAutoCalculated: Bool {
        switch estimation.mode {
        case .duration:
            return false
        case .effort:
            return false
        case .quantity:
            return estimation.quantityCalculationMode == .calculatePersonnel
        }
    }

    private var parentStartDate: Date? {
        parentTask?.startDate
    }

    private var parentDueDate: Date? {
        parentTask?.effectiveDeadline
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
        ScrollViewReader { proxy in
            Form {
                titleSection
                notesSection
                dueDateSection
                prioritySection
                projectSection

                // Only show tags section in creation mode (not editing)
                if editingTask == nil {
                    tagsSection
                }

                personnelSection
                estimateSection
                    .id("estimateSection")
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
            .onChange(of: estimation.hasEstimate) { oldValue, newValue in
                // When estimate section expands, maintain focus on estimate section
                if newValue && !oldValue {
                    proxy.scrollTo("estimateSection", anchor: .top)
                }
            }
            .onChange(of: estimation.hasPersonnel) { oldValue, newValue in
                // When personnel section expands, maintain focus on estimate section
                if newValue && !oldValue {
                    proxy.scrollTo("estimateSection", anchor: .top)
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(selectedTagIds: $selectedTagIds)
            }
        }
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
            Toggle("Add Notes", isOn: $hasNotes)

            if hasNotes {
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
    }

    private var projectSection: some View {
        TaskComposerProjectSection(
            selectedProject: $selectedProject,
            isSubtask: isSubtask,
            inheritedProject: inheritedProject,
            projects: projects
        )
    }

    private var dueDateSection: some View {
        TaskComposerDueDateSection(
            hasDueDate: $hasDueDate,
            dueDate: $dueDate,
            hasStartDate: $hasStartDate,
            startDate: $startDate,
            hasEndDate: $hasEndDate,
            endDate: $endDate,
            showingValidationAlert: $showingDateValidationAlert,
            isSubtask: isSubtask,
            parentStartDate: parentStartDate,
            parentEndDate: parentDueDate,
            selectedProject: selectedProject, // Real-time project conflict detection
            onDateChange: validateSubtaskDueDate
        )
    }

    private var estimateSection: some View {
        TaskComposerEstimateSection(
            estimation: $estimation,
            isSubtask: isSubtask,
            parentSubtaskEstimateTotal: parentSubtaskEstimateTotal,
            taskSubtaskEstimateTotal: taskSubtaskEstimateTotal,
            schedule: scheduleContext,
            templates: templates,
            allTasks: allTasks,
            callbacks: DetailedEstimationCallbacks(
                onEstimateChange: validateEstimate,
                onEffortChange: updateDurationFromEffort,
                onQuantityChange: updateFromQuantityCalculation,
                onPersonnelChange: { /* No-op for now */ }
            )
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

    private var tagsSection: some View {
        Section("Tags") {
            if selectedTags.isEmpty {
                Button {
                    showingTagPicker = true
                } label: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.blue)
                        Text("Add Tags")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                // Show selected tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags) { tag in
                            TagChip(
                                tag: tag,
                                onRemove: {
                                    selectedTagIds.remove(tag.id)
                                    HapticManager.light()
                                }
                            )
                        }
                    }
                }

                // Add more button
                Button {
                    showingTagPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Manage Tags")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private var personnelSection: some View {
        TaskComposerPersonnelSection(
            hasPersonnel: $estimation.hasPersonnel,
            expectedPersonnelCount: $estimation.expectedPersonnelCount,
            unifiedEstimationMode: $estimation.mode,
            personnelIsAutoCalculated: personnelIsAutoCalculated,
            quantityCalculationMode: estimation.quantityCalculationMode
        )
    }

    // MARK: - Helper Methods

    /// Update duration fields from effort calculation
    private func updateDurationFromEffort() {
        guard estimation.mode == .effort,
              estimation.effortHours > 0,
              let personnel = estimation.expectedPersonnelCount, personnel > 0 else {
            return
        }

        // Calculate duration: effort / personnel
        let durationHours = estimation.effortHours / Double(personnel)
        let totalSeconds = Int(durationHours * 3600)

        // Update duration fields
        estimation.estimateHours = totalSeconds / 3600
        estimation.estimateMinutes = (totalSeconds % 3600) / 60
        estimation.hasEstimate = true
    }

    /// Update fields from quantity calculation
    private func updateFromQuantityCalculation() {
        guard estimation.mode == .quantity,
              let qty = Double(estimation.quantity), qty > 0,
              let rate = estimation.productivityRate, rate > 0 else {
            return
        }

        switch estimation.quantityCalculationMode {
        case .calculateDuration:
            guard let personnel = estimation.expectedPersonnelCount, personnel > 0 else { return }
            let durationHours = (qty / rate) / Double(personnel)
            let totalSeconds = Int(durationHours * 3600)

            estimation.estimateHours = totalSeconds / 3600
            estimation.estimateMinutes = (totalSeconds % 3600) / 60
            estimation.hasEstimate = true
            estimation.hasPersonnel = true

        case .calculatePersonnel:
            let totalDurationHours = Double(estimation.estimateHours) + (Double(estimation.estimateMinutes) / 60.0)
            guard totalDurationHours > 0 else { return }

            let personnel = Int(ceil((qty / rate) / totalDurationHours))
            estimation.expectedPersonnelCount = max(1, personnel)
            estimation.hasPersonnel = true
            estimation.hasEstimate = true

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
            estimateHours: estimation.estimateHours,
            estimateMinutes: estimation.estimateMinutes,
            subtaskTotalMinutes: taskSubtaskEstimateTotal,
            hasCustomEstimate: estimation.hasCustomEstimate,
            isSubtask: isSubtask
        )

        if !result.isValid, let message = result.errorMessage {
            estimateValidationMessage = message
            showingEstimateValidationAlert = true
        }
    }

    private func resetToSubtaskTotal() {
        guard let total = taskSubtaskEstimateTotal else { return }
        estimation.estimateHours = total / 60
        estimation.estimateMinutes = (total % 60)

        // Round minutes to nearest 15
        let roundedMinutes = ((estimation.estimateMinutes + 7) / 15) * 15
        estimation.estimateMinutes = roundedMinutes
        if roundedMinutes >= 60 {
            estimation.estimateHours += 1
            estimation.estimateMinutes = 0
        }
    }
}

// MARK: - Tag Chip

private struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.caption2)
            Text(tag.name)
                .font(.caption)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tagColor.opacity(0.15))
        .foregroundStyle(tagColor)
        .clipShape(Capsule())
    }

    private var tagColor: Color {
        tag.colorValue
    }
}
