//
//  ContentItemPlainDetail.swift
//  Developer
//

import SwiftUI

struct ContentItemPlainDetail: View {
    let item: ContentItem

    @Environment(ContentStore.self) private var store
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(\.openRoute) private var openRoute
    @State private var linkedRoute: Route?

    var body: some View {
        ScrollView {
            content
                .textSelection(.enabled)
                .frame(maxWidth: 700, alignment: .leading)
                .padding()
                .frame(maxWidth: .infinity)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let route = store.route(for: url), route != .article(item) else { return .systemAction }
            if let openRoute {
                openRoute(route)
            } else {
                linkedRoute = route
            }
            return .handled
        })
        .navigationDestination(item: $linkedRoute) { RouteView(route: $0) }
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                let isBookmarked = bookmarkStore.isBookmarked(item.id)
                Button(
                    isBookmarked ? "Remove from Bookmarks" : "Add to Bookmarks",
                    systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                ) {
                    bookmarkStore.toggle(item.id)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: item.webURL)
                    Link(destination: item.webURL) {
                        Label("View on developer.apple.com", systemImage: "safari")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .task { await store.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let page = store.page(for: item) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(page.components) { component in
                    ContentPageView.ComponentView(component: component)
                }
            }
        } else if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.title)
                    .font(.largeTitle.bold())
                if let date = item.publishedAt {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(item.summary)
                Link("Read on developer.apple.com", destination: item.webURL)
            }
        }
    }
}

#Preview {
    @Previewable @State var store = ContentStore()
    let item = store.feed?.items.first { store.page(for: $0) != nil }

    NavigationStack {
        if let item {
            ContentItemPlainDetail(item: item)
        } else {
            ProgressView()
        }
    }
    .task { await store.load() }
    .environment(store)
    .environment(NewsStore())
    .environment(SessionStore())
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    #if os(macOS)
    .frame(width: 900, height: 900)
    #endif
}

