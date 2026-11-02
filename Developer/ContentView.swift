//
//  ContentView.swift
//  Developer
//

import SwiftUI

struct ContentView: View {
    @State private var store = SessionStore()
    @State private var progressStore = WatchProgressStore(cloud: .default)
    @State private var bookmarkStore = SynchronizedListManager(cloud: .default)
    @State private var newsStore = NewsStore()
    @State private var discoverStore = ContentStore()
    @State private var downloadStore = DownloadEngine()
    @State private var selectedTab: AppTab = .browse
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    enum AppTab: Hashable {
        case discover, browse, wwdc, account, search
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
        .environment(store)
        .environment(progressStore)
        .environment(bookmarkStore)
        .environment(newsStore)
        .environment(discoverStore)
        .environment(downloadStore)
        .task { await store.load() }
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

            Tab("WWDC", systemImage: "lanyardcard", value: .wwdc) {
                PlaceholderTabView(title: "WWDC", systemImage: "lanyardcard")
            }

            Tab("Account", systemImage: "person.crop.circle", value: .account) {
                AccountView()
            }

            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
    }
}

struct AccountView: View {
    var body: some View {
        NavigationStack {
            AccountList()
        }
    }
}

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon."))
                .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
