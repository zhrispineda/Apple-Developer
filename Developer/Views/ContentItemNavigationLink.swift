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

#Preview {
    let item = ContentItem(
        id: "wwdc2014-605",
        eventID: "wwdc2014",
        eventName: "WWDC14",
        number: 605,
        type: "Video",
        title: "Advanced Graphics and Animations for iOS Apps",
        summary: "Hello",
        webURL: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!,
        startTime: nil,
        endTime: nil,
        publishedAt: nil,
        duration: 3540,
        videoURL: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/"),
        hasLiveStream: false,
        topics: [],
        thumbnailURL: nil,
        cardImageURL: nil,
        posterURL: nil,
        squareImageURL: nil
    )

    NavigationStack {
        ContentItemNavigationLink(item: item) {
            Text(item.title)
        }
        .padding()
    }
    .environment(ContentStore())
    .environment(NewsStore())
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
}
