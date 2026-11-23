//
//  ContentView.swift
//  Developer
//

import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) private var store
    @State private var progressStore = WatchProgressStore(cloud: NSUbiquitousKeyValueStore.default)
    @State private var bookmarkStore = SynchronizedListManager(cloud: NSUbiquitousKeyValueStore.default)
    @State private var playlistStore = PlaylistStore(cloud: NSUbiquitousKeyValueStore.default)
    @State private var notesStore = NotesStore(cloud: NSUbiquitousKeyValueStore.default)
    @State private var isCreatingPlaylist = false
    @State private var pendingPlaylistSessionID: String?
    @State private var newsStore = NewsStore()
    @State private var discoverStore = ContentStore()
    @State private var downloadStore = DownloadEngine.shared
    @State private var cloudMonitor = CloudSyncMonitor()
    @State private var selectedTab: AppTab = .discover
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    enum AppTab: Hashable {
        case discover, browse, wwdc, library, search
    }
    
    var body: some View {
        Group {
            // First Launch:
            // Nothing is cached yet, showing a first-launch-only
            // `Compiling…` ProgressView while the app initiates
            if !store.hasCompletedInitialLoad {
                ProgressView("Compiling…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(macOS)
                    .frame(minWidth: 900, minHeight: 560)
                    #endif
            } else {
                mainView
            }
        }
        .asyncImageURLSession(WWDCCache.imageSession)
        .downloadErrorAlert()
        .playlistTitleAlert("New Playlist", isPresented: $isCreatingPlaylist, confirmLabel: "Create") { title in
            playlistStore.create(title: title, sessionIDs: pendingPlaylistSessionID.map { [$0] } ?? [])
        }
        .environment(\.newPlaylist, NewPlaylistAction { sessionID in
            pendingPlaylistSessionID = sessionID
            isCreatingPlaylist = true
        })
        .environment(progressStore)
        .environment(bookmarkStore)
        .environment(playlistStore)
        .environment(notesStore)
        .environment(newsStore)
        .environment(discoverStore)
        .environment(downloadStore)
        .environment(cloudMonitor)
        .task { await store.load() }
        .task {
            await discoverStore.load()
            await newsStore.load()
        }
        .task(id: searchIndexInputs) {
            guard store.hasCompletedInitialLoad, discoverStore.feed != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let documents = SpotlightIndex.documents(sessions: store.sessions, contentStore: discoverStore, news: newsStore.items)
            await SpotlightIndex.shared.update(with: documents)
        }
    }

    private var searchIndexInputs: [AnyHashable] {
        [store.sessions.count, discoverStore.feed?.fetchedAt, newsStore.items.count]
    }
    
    @ViewBuilder
    private var mainView: some View {
        #if os(macOS)
        // The Mac uses a sidebar layout instead of a tab bar.
        AdaptiveSplitView()
        #else
        // So does iPad, whenever it has the width (not in narrow multitasking).
        if horizontalSizeClass == .regular {
            AdaptiveSplitView()
        } else {
            tabView
        }
        #endif
    }
    
    private var tabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "star", value: .discover) {
                NavigationStack {
                    ContentPageView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }

            Tab("Browse", systemImage: "rectangle.stack", value: .browse) {
                BrowseView()
            }

            Tab("WWDC", image: "wwdc.badge", value: .wwdc) {
                NavigationStack {
                    ContentPageView(root: .wwdc)
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }

            Tab("Library", systemImage: "film.stack", value: .library) {
                LibraryView()
            }

            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
}
