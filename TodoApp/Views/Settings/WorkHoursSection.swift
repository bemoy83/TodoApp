//
//  WorkHoursSection.swift
//  TodoApp
//
//  Work hours configuration for smart scheduling and time tracking
//

import SwiftUI

struct WorkHoursSection: View {
    @Binding var workdayStartHour: Int
    @Binding var workdayEndHour: Int

    private var workdayHours: Int {
        max(1, workdayEndHour - workdayStartHour)
    }

    private var isValidConfiguration: Bool {
        workdayEndHour > workdayStartHour
    }

    var body: some View {
        Section {
            // Start Hour Picker
            Picker("Workday Start", selection: $workdayStartHour) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .foregroundStyle(DesignSystem.Colors.info)
                        Text(formatHour(hour))
                    }
                    .tag(hour)
                }
            }

            // End Hour Picker
            Picker("Workday End", selection: $workdayEndHour) {
                ForEach(0..<24, id: \.self) { hour in
                    HStack {
                        Image(systemName: "sunset.fill")
                            .foregroundStyle(DesignSystem.Colors.warning)
                        Text(formatHour(hour))
                    }
                    .tag(hour)
                }
            }

            // Summary Row
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(isValidConfiguration ? DesignSystem.Colors.success : DesignSystem.Colors.error)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Work Hours")
                        .font(.subheadline)

                    if isValidConfiguration {
                        Text("\(workdayHours) hours per day (\(formatHour(workdayStartHour)) - \(formatHour(workdayEndHour)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Invalid: End time must be after start time")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.error)
                    }
                }

                Spacer()
            }

        } header: {
            Label("Work Hours", systemImage: "clock.fill")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Default work hours for scheduling and time tracking")
                    .font(DesignSystem.Typography.caption)

                Text("• Start dates default to workday start")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("• Due dates default to workday end")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("• Work hours are used for multi-day time calculations")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    Form {
        WorkHoursSection(workdayStartHour: .constant(7), workdayEndHour: .constant(15))
    }
}
