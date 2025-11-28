//
//  SharedDetailComponents.swift
//  TodoApp
//
//  Shared reusable components for detail views
//  Reduces code duplication between TaskDetailView and ProjectDetailView
//

import SwiftUI
import SwiftData

// MARK: - Protocols

/// Protocol for items that have an editable title
protocol TitledItem: AnyObject {
    var title: String { get set }
}

// MARK: - Shared Title Section

/// Reusable title section with inline editing
/// Used in both TaskDetailHeaderView and ProjectHeaderView
struct SharedTitleSection<T: TitledItem>: View {
    @Bindable var item: T
    @Binding var isEditing: Bool
    @Binding var editedTitle: String
    let placeholder: String

    init(item: T, isEditing: Binding<Bool>, editedTitle: Binding<String>, placeholder: String = "Title") {
        self._item = Bindable(wrappedValue: item)
        self._isEditing = isEditing
        self._editedTitle = editedTitle
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Title")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isEditing {
                HStack {
                    TextField(placeholder, text: $editedTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .textFieldStyle(.plain)

                    Button("Done") {
                        item.title = editedTitle
                        isEditing = false
                        HapticManager.success()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            } else {
                Button {
                    isEditing = true
                } label: {
                    HStack {
                        Text(item.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "pencil.circle.fill")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Shared Date Row

/// Reusable date row component for displaying and editing dates
/// Supports tap-to-edit pattern with increased tap targets
struct SharedDateRow: View {
    let icon: String
    let label: String
    let date: Date
    let color: Color
    var isActionable: Bool = false
    var showTime: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if isActionable && onTap != nil {
                Button(action: { onTap?() }) {
                    dateRowContent
                }
                .buttonStyle(.plain)
            } else {
                dateRowContent
            }
        }
    }

    private var dateRowContent: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if showTime {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } else {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if isActionable && onTap != nil {
                Image(systemName: "pencil.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared Notes Section

/// Reusable expandable notes section
/// Used in both Task and Project detail views
struct SharedNotesSection: View {
    let notes: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(DesignSystem.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Info Hint View

/// Reusable info hint component for explaining smart defaults and other features
/// Displays an info icon with explanatory text
struct InfoHintView: View {
    let message: String
    var icon: String = "info.circle.fill"
    var iconColor: Color = DesignSystem.Colors.info

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)

            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
// Mock classes for preview
private class MockTitledItem: TitledItem, ObservableObject {
    var title: String

    init(title: String) {
        self.title = title
    }
}

#Preview("Title Section") {
    @Previewable @State var isEditing = false
    @Previewable @State var editedTitle = "Sample Title"

    let mockItem = MockTitledItem(title: "Sample Title")

    SharedTitleSection(
        item: mockItem,
        isEditing: $isEditing,
        editedTitle: $editedTitle,
        placeholder: "Enter title"
    )
    .detailCardStyle()
    .padding()
}

#Preview("Date Row - Display Only") {
    SharedDateRow(
        icon: "calendar",
        label: "Created",
        date: Date(),
        color: .secondary,
        isActionable: false,
        showTime: false
    )
    .padding()
}

#Preview("Date Row - Editable") {
    SharedDateRow(
        icon: "flag.fill",
        label: "Due",
        date: Date(),
        color: .orange,
        isActionable: true,
        showTime: true,
        onTap: { print("Tapped!") }
    )
    .padding()
}

#Preview("Notes Section") {
    @Previewable @State var isExpanded = true

    SharedNotesSection(
        notes: "This is a sample note with some detailed information about the task or project. It can be quite long and will be truncated when collapsed.",
        isExpanded: $isExpanded
    )
    .detailCardStyle()
    .padding()
}

#Preview("Info Hint") {
    VStack(spacing: 16) {
        InfoHintView(
            message: "Start dates automatically default to 7:00 AM (start of workday)"
        )

        InfoHintView(
            message: "Due dates automatically default to 3:00 PM (end of workday)"
        )

        InfoHintView(
            message: "This is a warning message",
            icon: "exclamationmark.triangle.fill",
            iconColor: .orange
        )
    }
    .padding()
}
#endif
