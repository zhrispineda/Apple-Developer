//
//  ContentItemRow.swift
//  Developer
//

import SwiftUI

struct ContentItemRow: View {
    let entry: ContentEntry

    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(DownloadEngine.self) private var downloadStore

    init(entry: ContentEntry) {
        self.entry = entry
    }

    init(session: WWDCSession) {
        self.init(entry: .video(session))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ContentItemThumbnail(url: entry.thumbnailURL, width: 112)
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
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            if case .downloading(let fraction) = downloadStore.state(for: entry.id) {
                Spacer(minLength: 0)
                VideoDownloadIndicatorStateView(progress: fraction)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Row item view for a session video in lists.
/// Shows session thumbnail, title, event, and video length or watch progress.
struct ContentItemWideRow: View {
    let entry: ContentEntry

    #if os(macOS)
    static let thumbnailWidth: CGFloat = 96
    #else
    static let thumbnailWidth: CGFloat = 112
    #endif

    @Environment(SynchronizedListManager.self) private var bookmarkStore

    init(entry: ContentEntry) {
        self.entry = entry
    }

    init(session: WWDCSession) {
        self.init(entry: .video(session))
    }

    var body: some View {
        HStack(spacing: 14) {
            ContentItemThumbnail(url: entry.thumbnailURL, width: Self.thumbnailWidth)

            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
                // The title fills the remaining width; the trailing columns keep their size.
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            if bookmarkStore.isBookmarked(entry.id) {
                Image(systemName: "bookmark.fill")
                    .frame(width: 20)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Bookmarked")
            }

            Text(entry.eventName)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 110, alignment: .leading)

            statusText
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 70, alignment: .trailing)

            #if os(macOS)
            Image(systemName: "chevron.forward")
                .foregroundStyle(.tertiary)
            #endif
        }
        .padding(.vertical, 6)
        .padding(.trailing, 6)
    }

    @ViewBuilder
    private var statusText: some View {
        if let session = entry.session {
            ContentItemStatusText(session: session)
        }
    }
}

struct ContentItemStatusText: View {
    let session: WWDCSession

    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(DownloadEngine.self) private var downloadStore

    var body: some View {
        let progress = progressStore.progress(for: session.id)
        if case .downloading(let fraction) = downloadStore.state(for: session.id) {
            VideoDownloadIndicatorStateView(progress: fraction)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            durationText(session, progress: progress)
        }
    }

    @ViewBuilder
    private func durationText(_ session: WWDCSession, progress: WatchProgress?) -> some View {
        let duration = progress?.duration ?? session.durationSeconds
        if let progress, progress.isWatched {
            Label(formattedMinutes(duration ?? progress.duration), systemImage: "checkmark")
                .labelStyle(.titleAndIcon)
        } else if let progress, progress.position > 0 {
            Text("\(formattedMinutes(progress.remaining)) left")
        } else if let duration {
            Text(formattedMinutes(duration))
        }
    }
}

#Preview("Row") {
    List {
        ContentItemRow(session: WWDCSession(
            id: "wwdc2014-605",
            eventID: "wwdc2014",
            sessionNumber: 605,
            title: "Working with Metal: Advanced",
            topics: ["Graphics & Games"],
            duration: "53:52",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
        ))
    }
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
}

#Preview("Wide row") {
    List {
        ContentItemWideRow(session: WWDCSession(
            id: "wwdc2014-605",
            eventID: "wwdc2014",
            sessionNumber: 605,
            title: "Working with Metal: Advanced",
            topics: ["Graphics & Games"],
            duration: "53:52",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
        ))
    }
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager(cloud: NSUbiquitousKeyValueStore.default))
    #if os(macOS)
    .frame(width: 700, height: 200)
    #endif
}
