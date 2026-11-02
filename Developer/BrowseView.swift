//
//  BrowseView.swift
//  Developer
//

import SwiftUI

enum BrowseDestination: Hashable {
    case news, bookmarks, downloaded, continueWatching
    case topic(WWDCTopic)
}

struct BrowseView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore

    private var topics: [WWDCTopic] { store.topics }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    browseRow("News", systemImage: "newspaper", value: BrowseDestination.news)
                        .listRowSeparator(.hidden, edges: .top)
                    browseRow("Bookmarks", systemImage: "bookmark", value: BrowseDestination.bookmarks)
                    browseRow("Downloaded", systemImage: "arrow.down.circle", value: BrowseDestination.downloaded)
                    if !store.sessions(orderedByIDs: progressStore.inProgressSessionIDs).isEmpty {
                        browseRow("Continue Watching", systemImage: "play.circle", value: BrowseDestination.continueWatching)
                    }
                }

                if !topics.isEmpty {
                    Section {
                        ForEach(topics) { topic in
                            browseRow(topic.name, systemImage: topic.systemImage, value: BrowseDestination.topic(topic))
                        }
                    } header: {
                        sectionHeader("Topics")
                    }
                }

                if !store.events.isEmpty {
                    Section {
                        ForEach(store.events) { event in
                            browseRow(event.name, systemImage: event.systemImage, value: event)
                        }
                    } header: {
                        sectionHeader("Events")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Browse")
            .navigationDestination(for: BrowseDestination.self) { destination in
                destinationView(for: destination)
            }
            .navigationDestination(for: WWDCEvent.self) { event in
                FilteredContentView(title: event.name, sessions: store.sessions(in: event), shareURL: event.pageURL, shareLabel: "Share Event…")
            }
            .navigationDestination(for: Route.self) { route in
                RouteView(route: route)
            }
            .overlay {
                if store.isLoading && store.sessions.isEmpty {
                    ProgressView("Fetching videos…")
                } else if let errorMessage = store.errorMessage, store.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Videos", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await store.load() }
                        }
                    }
                }
            }
            .refreshable { await store.load() }
        }
    }

    // MARK: Rows

    private func browseRow(_ title: String, systemImage: String, value: some Hashable) -> some View {
        NavigationLink(value: value) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.primary)
            .textCase(nil)
    }

    @ViewBuilder
    private func destinationView(for destination: BrowseDestination) -> some View {
        switch destination {
        case .news:
            NewsListView()
        case .bookmarks:
            BookmarksView()
        case .downloaded:
            DownloadedView()
        case .continueWatching:
            ContinueWatchingView()
        case .topic(let topic):
            TopicContentView(topic: topic)
        }
    }
}

struct BookmarksView: View {
    @Environment(SessionStore.self) private var store
    @Environment(ContentStore.self) private var contentStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore

    var body: some View {
        let ids = bookmarkStore.bookmarkedIDs
        let sessions = store.sessions(withIDs: ids)
        let articles = ids
            .compactMap(contentStore.item(withID:))
            .filter(\.isArticle)
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        let entries = sessions.map(ContentEntry.video) + articles.map(ContentEntry.article)
        FilteredContentView(title: "Bookmarks", groups: [ContentItemGroup(id: "all", title: nil, entries: entries)])
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Touch and hold a video or article, then choose Add to Bookmarks.")
                    )
                }
            }
            .task { await contentStore.load() }
    }
}

struct ContinueWatchingView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore

    var body: some View {
        let sessions = store.sessions(orderedByIDs: progressStore.inProgressSessionIDs)
        FilteredContentView(title: "Continue Watching", sessions: sessions)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Continue",
                        systemImage: "play.circle",
                        description: Text("Videos you start watching will appear here.")
                    )
                }
            }
    }
}

struct PlaceholderListView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

#Preview("Browse") {
    @Previewable @State var store = SessionStore()

    BrowseView()
        .environment(store)
        .environment(WatchProgressStore())
        .environment(DownloadEngine())
        .environment(SynchronizedListManager())
        .environment(NewsStore())
        .environment(ContentStore())
        .task { await store.load() }
}
