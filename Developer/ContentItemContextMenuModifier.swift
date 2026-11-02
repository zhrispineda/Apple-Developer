//
//  ContentItemContextMenuModifier.swift
//  Developer
//

import SwiftUI

extension View {
    func sessionContextMenu(for session: WWDCSession) -> some View {
        contextMenu { ContentItemContextMenu(session: session) }
    }

    func articleContextMenu(for item: ContentItem) -> some View {
        contextMenu { ArticleContextMenu(item: item) }
    }
}

struct ContentItemContextMenu: View {
    let session: WWDCSession

    @Environment(WatchProgressStore.self) private var progressStore
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
                copyLink(session.url)
            }

            BookmarkMenuButton(id: session.id)

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
}

struct ArticleContextMenu: View {
    let item: ContentItem

    var body: some View {
        Section {
            ShareLink(item: item.webURL) {
                Label("Share…", systemImage: "square.and.arrow.up")
            }

            Button("Copy Link", systemImage: "link") {
                copyLink(item.webURL)
            }

            BookmarkMenuButton(id: item.id)
        }
    }
}

/// Adds or removes a session or article from Bookmarks.
struct BookmarkMenuButton: View {
    let id: String

    @Environment(SynchronizedListManager.self) private var bookmarkStore

    var body: some View {
        if bookmarkStore.isBookmarked(id) {
            Button("Remove from Bookmarks", systemImage: "bookmark.slash") {
                bookmarkStore.toggle(id)
            }
        } else {
            Button("Add to Bookmarks", systemImage: "bookmark") {
                bookmarkStore.toggle(id)
            }
        }
    }
}

private func copyLink(_ url: URL) {
    #if canImport(UIKit)
    UIPasteboard.general.url = url
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(url.absoluteString, forType: .string)
    #endif
}
