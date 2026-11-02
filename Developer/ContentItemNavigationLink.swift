//
//  ContentItemNavigationLink.swift
//  Developer
//

import SwiftUI

struct ContentItemNavigationLink<Label: View>: View {
    let item: ContentItem
    @ViewBuilder let label: Label

    @Environment(ContentStore.self) private var store
    @Environment(NewsStore.self) private var newsStore

    var body: some View {
        Group {
            if store.isLive(item) || (item.hasLiveStream && item.videoURL == nil && !hasEnded) {
                NavigationLink(value: Route.live(item)) { label }
            } else if item.videoURL != nil {
                NavigationLink(value: Route.session(item.session)) { label }
                    .sessionContextMenu(for: item.session)
            } else if store.page(for: item) != nil {
                NavigationLink(value: Route.article(item)) { label }
                    .articleContextMenu(for: item)
            } else if let news = newsItem {
                NavigationLink(value: Route.news(news)) { label }
            } else {
                Link(destination: item.webURL) { label }
            }
        }
        .buttonStyle(.plain)
    }

    private var hasEnded: Bool {
        (item.endTime ?? .distantFuture) < store.now
    }

    /// The News feed's copy of this item, matched by the "?id=" key in its link.
    private var newsItem: NewsItem? {
        guard let key = item.webURL.newsArticleKey else { return nil }
        return newsStore.items.first { $0.url.newsArticleKey == key }
    }
}
