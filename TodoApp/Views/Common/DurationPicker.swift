import SwiftUI

/// Custom duration picker for hours and minutes
/// Replaces the DatePicker hack with a proper duration input
struct DurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    let maxHours: Int
    let showValidation: Bool

    @State private var validationError: String?

    // MARK: - Initialization

    init(
        hours: Binding<Int>,
        minutes: Binding<Int>,
        maxHours: Int = EstimationLimits.maxDurationHours,
        showValidation: Bool = true
    ) {
        self._hours = hours
        self._minutes = minutes
        self.maxHours = maxHours
        self.showValidation = showValidation
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Pickers
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Hours picker
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Hours", selection: $hours) {
                        ForEach(0...maxHours, id: \.self) { hour in
                            Text("\(hour)")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                }

                Text(":")
                    .font(.title)
                    .foregroundStyle(.secondary)

                // Minutes picker
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text(String(format: "%02d", minute))
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                }
            }

            // Duration summary
            durationSummaryView

            // Validation error if any
            if showValidation, let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .onChange(of: hours) { _, _ in validateDuration() }
        .onChange(of: minutes) { _, _ in validateDuration() }
        .onAppear { validateDuration() }
    }

    // MARK: - Subviews

    private var durationSummaryView: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(formattedDuration)
                .font(.title2)
                .fontWeight(.semibold)

            if totalMinutes > 0 {
                Text(durationDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Computed Properties

    private var totalMinutes: Int {
        (hours * 60) + minutes
    }

    private var formattedDuration: String {
        if hours == 0 && minutes == 0 {
            return "No duration set"
        } else if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) \(hours == 1 ? "hour" : "hours")"
        } else {
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        }
    }

    private var durationDetails: String {
        let total = totalMinutes
        if total >= 1440 { // >= 1 day
            let days = total / 1440
            let remainingHours = (total % 1440) / 60
            if remainingHours > 0 {
                return "\(days) \(days == 1 ? "day" : "days"), \(remainingHours)h"
            } else {
                return "\(days) \(days == 1 ? "day" : "days")"
            }
        } else if total >= 60 { // >= 1 hour
            return "Total: \(total) minutes"
        } else {
            return ""
        }
    }

    // MARK: - Validation

    private func validateDuration() {
        guard showValidation else {
            validationError = nil
            return
        }

        let result = InputValidator.validateDuration(hours: hours, minutes: minutes)
        withAnimation {
            validationError = result.error?.message
        }
    }

    /// Whether the current duration is valid
    var isValid: Bool {
        InputValidator.validateDuration(hours: hours, minutes: minutes).isValid
    }

    /// Total duration in seconds
    var totalSeconds: Int {
        (hours * 3600) + (minutes * 60)
    }
}

// MARK: - Sheet Wrapper

/// Duration picker presented as a sheet
struct DurationPickerSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var isPresented: Bool

    let title: String
    let maxHours: Int
    let onDone: () -> Void

    init(
        hours: Binding<Int>,
        minutes: Binding<Int>,
        isPresented: Binding<Bool>,
        title: String = "Set Duration",
        maxHours: Int = EstimationLimits.maxDurationHours,
        onDone: @escaping () -> Void = {}
    ) {
        self._hours = hours
        self._minutes = minutes
        self._isPresented = isPresented
        self.title = title
        self.maxHours = maxHours
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text(title)
                    .font(.headline)
                    .padding(.top, DesignSystem.Spacing.md)

                DurationPicker(hours: $hours, minutes: $minutes, maxHours: maxHours)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Inline Duration Input

/// Compact inline duration input (alternative to sheet)
struct InlineDurationInput: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    let maxHours: Int

    init(
        hours: Binding<Int>,
        minutes: Binding<Int>,
        maxHours: Int = EstimationLimits.maxDurationHours
    ) {
        self._hours = hours
        self._minutes = minutes
        self.maxHours = maxHours
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Hours
            HStack(spacing: 4) {
                TextField("0", value: $hours, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .onChange(of: hours) { _, newValue in
                        hours = EstimationLimits.clampDurationHours(newValue)
                    }

                Text("h")
                    .foregroundStyle(.secondary)
            }

            // Minutes
            HStack(spacing: 4) {
                TextField("0", value: $minutes, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .onChange(of: minutes) { _, newValue in
                        minutes = max(0, min(newValue, 59))
                    }

                Text("m")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Duration Picker") {
    @Previewable @State var hours = 2
    @Previewable @State var minutes = 30

    VStack {
        DurationPicker(hours: $hours, minutes: $minutes)
            .padding()

        Divider()

        Text("Selected: \(hours)h \(minutes)m")
            .font(.caption)
    }
}

#Preview("Duration Picker - Long Duration") {
    @Previewable @State var hours = 48
    @Previewable @State var minutes = 15

    VStack {
        DurationPicker(hours: $hours, minutes: $minutes)
            .padding()
    }
}

#Preview("Duration Picker Sheet") {
    @Previewable @State var hours = 3
    @Previewable @State var minutes = 45
    @Previewable @State var showSheet = true

    Button("Show Duration Picker") {
        showSheet = true
    }
    .sheet(isPresented: $showSheet) {
        DurationPickerSheet(
            hours: $hours,
            minutes: $minutes,
            isPresented: $showSheet
        )
    }
}

#Preview("Inline Duration Input") {
    @Previewable @State var hours = 4
    @Previewable @State var minutes = 20

    VStack(spacing: 20) {
        InlineDurationInput(hours: $hours, minutes: $minutes)

        Text("Duration: \(hours)h \(minutes)m")
            .font(.caption)
    }
    .padding()
}
