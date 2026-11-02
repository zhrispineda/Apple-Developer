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
