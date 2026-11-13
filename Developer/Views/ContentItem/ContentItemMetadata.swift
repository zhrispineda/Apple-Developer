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

#Preview {
    ContentItemMetadata(
        session: WWDCSession(
            id: "wwdc2014-605",
            eventID: "wwdc2014",
            sessionNumber: 605,
            title: "Working with Metal: Advanced",
            topics: ["Graphics & Games"],
            duration: "53:52",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
        ),
        clock: PlaybackClock()
    )
    .padding()
}

#Preview("In Progress") {
    let clock = PlaybackClock()
    clock.currentTime = 20 * 60

    return ContentItemMetadata(
        session: WWDCSession(
            id: "wwdc2014-605",
            eventID: "wwdc2014",
            sessionNumber: 605,
            title: "Working with Metal: Advanced",
            topics: ["Graphics & Games"],
            duration: "53:52",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
        ),
        clock: clock
    )
    .padding()
}
