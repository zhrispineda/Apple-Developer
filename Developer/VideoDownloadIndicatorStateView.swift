//
//  VideoDownloadIndicatorStateView.swift
//  Developer
//

import SwiftUI

struct VideoDownloadIndicatorStateView: View {
    let progress: Double
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: progress)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.tint)
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Downloading")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
