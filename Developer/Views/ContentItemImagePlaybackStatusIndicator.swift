//
//  ContentItemImagePlaybackStatusIndicator.swift
//  Developer
//

import SwiftUI

struct ContentItemImagePlaybackStatusIndicator: View {
    let session: WWDCSession
    let progress: WatchProgress?

    var body: some View {
        if let content {
            HStack(spacing: 3) {
                Image(systemName: content.symbol)
                    .imageScale(.small)
                Text(content.text)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(content.isWatched ? Color.black : Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                // Dark gray rather than pure black so it stays visible on dark thumbnails.
                content.isWatched ? Color.white : Color(white: 0.22).opacity(0.9),
                in: .rect(cornerRadius: 4)
            )
        }
    }

    private var content: (symbol: String, text: String, isWatched: Bool)? {
        let duration = progress?.duration ?? session.durationSeconds
        if let progress, progress.isWatched {
            return ("checkmark", formattedMinutes(duration ?? progress.duration), true)
        }
        if let progress, progress.position > 0 {
            return ("play.fill", "\(formattedMinutes(progress.remaining)) left", false)
        }
        guard let duration else { return nil }
        return ("play.fill", formattedMinutes(duration), false)
    }
}

#Preview {
    let session = WWDCSession(
        id: "wwdc2025-10001",
        eventID: "wwdc2025",
        sessionNumber: 10001,
        title: "What's new in SwiftUI",
        topics: ["SwiftUI & UI Frameworks"],
        duration: "24:37",
        thumbnailURL: nil,
        url: URL(string: "https://developer.apple.com/videos/play/wwdc2025/10001/")!
    )

    VStack(spacing: 12) {
        // Not started: shows the session's full duration.
        ContentItemImagePlaybackStatusIndicator(session: session, progress: nil)
        // In progress: shows time remaining.
        ContentItemImagePlaybackStatusIndicator(
            session: session,
            progress: WatchProgress(position: 600, duration: 1477, isWatched: false, updatedAt: .now)
        )
        // Watched: inverted style with a checkmark.
        ContentItemImagePlaybackStatusIndicator(
            session: session,
            progress: WatchProgress(position: 1477, duration: 1477, isWatched: true, updatedAt: .now)
        )
    }
    .padding()
    .background(.gray)
}
