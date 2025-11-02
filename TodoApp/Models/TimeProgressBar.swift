//
//  TimeProgressBar.swift
//  TodoApp
//
//  Reusable time progress bar component
//

import SwiftUI

/// Displays a horizontal progress bar for time tracking
struct TimeProgressBar: View {
    let progress: Double
    let status: TimeEstimateStatus?
    let height: CGFloat
    let showPercentage: Bool

    init(
        progress: Double,
        status: TimeEstimateStatus? = nil,
        height: CGFloat = 4,
        showPercentage: Bool = true
    ) {
        self.progress = progress
        self.status = status
        self.height = height
        self.showPercentage = showPercentage
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: height)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(status?.color ?? .blue)
                        .frame(
                            width: min(geometry.size.width * progress, geometry.size.width),
                            height: height
                        )
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: height)

            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(percentageFont)
                    .foregroundStyle(status?.color ?? .secondary)
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private var cornerRadius: CGFloat {
        height / 2
    }

    private var percentageFont: Font {
        if height >= 8 {
            return .caption
        } else {
            return .caption2
        }
    }
}

#Preview("List View Style") {
    VStack(spacing: 16) {
        TimeProgressBar(progress: 0.3, status: .onTrack, height: 4)
        TimeProgressBar(progress: 0.75, status: .warning, height: 4)
        TimeProgressBar(progress: 1.2, status: .over, height: 4)
    }
    .padding()
}

#Preview("Detail View Style") {
    VStack(spacing: 16) {
        TimeProgressBar(progress: 0.3, status: .onTrack, height: 8)
        TimeProgressBar(progress: 0.75, status: .warning, height: 8)
        TimeProgressBar(progress: 1.2, status: .over, height: 8)
    }
    .padding()
}

#Preview("Without Percentage") {
    VStack(spacing: 16) {
        TimeProgressBar(progress: 0.3, status: .onTrack, height: 8, showPercentage: false)
        TimeProgressBar(progress: 0.75, status: .warning, height: 8, showPercentage: false)
        TimeProgressBar(progress: 1.2, status: .over, height: 8, showPercentage: false)
    }
    .padding()
}
