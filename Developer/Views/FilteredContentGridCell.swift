//
//  FilteredContentGridCell.swift
//  Developer
//

import SwiftUI

struct FilteredContentGridCell: View {
    let entry: ContentEntry
    let width: CGFloat

    @Environment(WatchProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ContentItemThumbnail(url: entry.thumbnailURL, width: width)
                .overlay(alignment: .bottomTrailing) {
                    if let session = entry.session {
                        ContentItemImagePlaybackStatusIndicator(session: session, progress: progressStore.progress(for: session.id))
                            .padding(4)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.eventName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(.rect)
    }
}

#Preview {
    let session = WWDCSession(
        id: "wwdc2025-10001",
        eventID: "wwdc2025",
        sessionNumber: 10001,
        title: "What's new in H",
        topics: ["SwiftUI & UI Frameworks"],
        duration: "24:37",
        thumbnailURL: nil,
        url: URL(string: "https://developer.apple.com/videos/play/wwdc2025/10001/")!
    )

    FilteredContentGridCell(entry: .video(session), width: 250)
        .padding()
        .environment(WatchProgressStore())
}
