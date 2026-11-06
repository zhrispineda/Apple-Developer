//
//  AdaptiveSplitView.swift
//  Developer
//

import SwiftUI

struct AdaptiveSplitView: View {
    enum SidebarItem: Hashable {
        case search, discover, wwdc
        case news, bookmarks, downloaded, continueWatching
        case topic(WWDCTopic)
        case event(WWDCEvent)
        case diagnostics
    }
    
    struct Location: Hashable {
        var selection: SidebarItem?
        var path: [Route] = []
    }

    @Environment(SessionStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore
    @State private var history = BrowserNavigationState(current: Location(selection: .discover))
    private var location: Location { history.current }
    @AppStorage("sidebarBrowseExpanded") private var browseExpanded = true
    @AppStorage("sidebarTopicsExpanded") private var topicsExpanded = true
    @AppStorage("sidebarEventsExpanded") private var eventsExpanded = true

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            NavigationStack(path: pathBinding) {
                detailRoot
                    #if os(iOS)
                    .toolbar { historyButtons }
                    #endif
                    .navigationDestination(for: Route.self) { route in
                        RouteView(route: route)
                            .navigationBarBackButtonHidden()
                            #if os(iOS)
                            .toolbar { historyButtons }
                            #endif
                    }
            }
            .environment(\.openRoute, OpenRouteAction { route in
                pathBinding.wrappedValue = location.path + [route]
            })
        }
        #if os(macOS)
        .toolbar { historyButtons }
        .frame(minWidth: 900, minHeight: 560)
        #endif
    }

    private var historyButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Back", systemImage: "chevron.backward") { history.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!history.canGoBack)
            Button("Forward", systemImage: "chevron.forward") { history.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!history.canGoForward)
        }
    }

    // MARK: Navigation history

    private var selectionBinding: Binding<SidebarItem?> {
        Binding {
            location.selection
        } set: { newSelection in
            guard newSelection != location.selection else { return }
            history.navigate(to: Location(selection: newSelection))
        }
    }

    private var pathBinding: Binding<[Route]> {
        Binding {
            location.path
        } set: { newPath in
            guard newPath != location.path else { return }
            if newPath.count < location.path.count, Array(location.path.prefix(newPath.count)) == newPath {
                history.goBack(to: Location(selection: location.selection, path: newPath))
            } else {
                history.navigate(to: Location(selection: location.selection, path: newPath))
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section {
                Label("Search", systemImage: "magnifyingglass").tag(SidebarItem.search)
                Label("Discover", systemImage: "star").tag(SidebarItem.discover)
                Label("WWDC", image: "wwdc.badge").tag(SidebarItem.wwdc)
            }

            Section("Browse", isExpanded: $browseExpanded) {
                Label("News", systemImage: "newspaper").tag(SidebarItem.news)
                Label("Bookmarks", systemImage: "bookmark").tag(SidebarItem.bookmarks)
                Label("Downloaded", systemImage: "arrow.down.circle").tag(SidebarItem.downloaded)
                // Only while at least one video is partly watched.
                if hasVideosInProgress {
                    Label("Continue Watching", systemImage: "play.circle").tag(SidebarItem.continueWatching)
                }
            }

            if !store.topics.isEmpty {
                Section("Topics", isExpanded: $topicsExpanded) {
                    ForEach(store.topics) { topic in
                        Label(topic.name, systemImage: topic.systemImage).tag(SidebarItem.topic(topic))
                    }
                }
            }

            if !store.events.isEmpty {
                Section("Events", isExpanded: $eventsExpanded) {
                    ForEach(store.events) { event in
                        Label {
                            Text(event.name)
                        } icon: {
                            Image(symbol: event.systemImage)
                        }
                        .tag(SidebarItem.event(event))
                    }
                }
            }

            Section("Debug") {
                Label("Settings", systemImage: "gearshape").tag(SidebarItem.diagnostics)
            }
        }
    }

    private var hasVideosInProgress: Bool {
        !store.sessions(orderedByIDs: progressStore.inProgressSessionIDs).isEmpty
    }

    // MARK: Detail

    @ViewBuilder
    private var detailRoot: some View {
        switch location.selection {
        case .search:
            SearchView(embedsInNavigationStack: false)
        case .discover:
            ContentPageView()
        case .wwdc:
            ContentPageView(root: .wwdc)
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
        case .event(let event):
            FilteredContentView(title: event.name, sessions: store.sessions(in: event), shareURL: event.pageURL, shareLabel: "Share Event…")
        case .diagnostics:
            DiagnosticsView()
        case nil:
            ContentUnavailableView("Select an Item", systemImage: "sidebar.left")
        }
    }
}

#Preview {
    @Previewable @State var store = SessionStore()

    AdaptiveSplitView()
        .asyncImageURLSession(WWDCCache.imageSession)
        .environment(store)
        .environment(WatchProgressStore())
        .environment(SynchronizedListManager())
        .environment(NewsStore())
        .environment(ContentStore())
        .environment(DownloadEngine())
        .environment(CloudSyncMonitor())
        .task { await store.load() }
}
