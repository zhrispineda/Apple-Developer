//
//  ContentItemContextMenuModifier.swift
//  Developer
//

import SwiftUI

extension View {
    func sessionContextMenu(for session: WWDCSession) -> some View {
        contextMenu { ContentItemContextMenu(session: session) }
    }
}

struct ContentItemContextMenu: View {
    let session: WWDCSession

    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(DownloadEngine.self) private var downloadStore

    private var isWatched: Bool {
        progressStore.progress(for: session.id)?.isWatched ?? false
    }

    var body: some View {
        Section {
            ShareLink(item: session.url) {
                Label("Share…", systemImage: "square.and.arrow.up")
            }

            Button("Copy Link", systemImage: "link") {
                copyLink()
            }

            if bookmarkStore.isBookmarked(session.id) {
                Button("Remove from Bookmarks", systemImage: "bookmark.slash") {
                    bookmarkStore.toggle(session.id)
                }
            } else {
                Button("Add to Bookmarks", systemImage: "bookmark") {
                    bookmarkStore.toggle(session.id)
                }
            }

            if isWatched {
                Button("Mark as Unwatched", systemImage: "square") {
                    progressStore.markUnwatched(sessionID: session.id)
                }
            } else {
                Button("Mark as Watched", systemImage: "checkmark.square") {
                    let duration = progressStore.progress(for: session.id)?.duration ?? session.durationSeconds ?? 1
                    progressStore.markWatched(sessionID: session.id, duration: duration)
                }
            }

            switch downloadStore.state(for: session.id) {
            case .notDownloaded:
                Button("Download", systemImage: "arrow.down") {
                    downloadStore.download(session)
                }
            case .downloading:
                Button("Stop Download", systemImage: "stop.circle") {
                    downloadStore.cancel(session.id)
                }
            case .downloaded:
                // A menu can't host the confirmation, and choosing Remove is already deliberate.
                Button("Remove Download", systemImage: "trash", role: .destructive) {
                    downloadStore.remove(session.id)
                }
            }
        }
    }

    private func copyLink() {
        #if canImport(UIKit)
        UIPasteboard.general.url = session.url
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.url.absoluteString, forType: .string)
        #endif
    }
}
