//
//  ContentItemMetadata.swift
//  Developer
//

import SwiftUI

struct ContentItemMetadata: View {
    let session: WWDCSession
    let clock: PlaybackClock

    var body: some View {
        Text("\(session.eventName) • \(timeDescription)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var timeDescription: String {
        guard let total = clock.totalDuration ?? session.durationSeconds else { return "" }
        let currentTime = clock.currentTime
        return currentTime >= 1 ? "\(formattedMinutes(total - currentTime)) left" : formattedMinutes(total)
    }
}
