//
//  ContentPageView.swift
//  Developer
//

import SwiftUI

struct ContentPageView: View {
    @Environment(ContentStore.self) private var store
    @Environment(NewsStore.self) private var newsStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(store.sections) { section in
                    switch section {
                    case .hero(let hero):
                        Ultrahero(hero: hero)
                            .padding(.horizontal, DiscoverMetrics.margin)
                    case .itemList(let list):
                        RowView(list: list)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Discover")
        .overlay {
            if store.sections.isEmpty {
                if store.isLoading {
                    ProgressView()
                } else if let errorMessage = store.errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Load Discover", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await store.load(force: true) } }
                    }
                }
            }
        }
        .task { await store.load() }
        .task { await store.monitorLive() }
        .task { if newsStore.items.isEmpty { await newsStore.load() } }
    }
}

extension ContentPageView {
    struct ComponentView: View {
        let component: ContentPageComponent

        @Environment(ContentStore.self) private var store

        var body: some View {
            switch component.kind {
            case .category(let text, let lightColor, let darkColor):
                Text(text.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(lightHex: lightColor, darkHex: darkColor) ?? .secondary)
            case .title(let title):
                Text(title)
                    .font(.largeTitle.bold())
            case .date(let date):
                Text(date, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .header(let header):
                Text(header)
                    .font(.title2.bold())
                    .padding(.top, 8)
            case .text(let markdown, let style):
                MarkdownText(markdown: markdown, style: style)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .image(let image):
                VStack(alignment: .leading, spacing: 6) {
                    MediaResourceImage(resource: image)
                    if !image.caption.isEmpty {
                        MarkdownText(markdown: image.caption, style: TextStyle(textStyle: "caption", color: "secondary"))
                    }
                }
            case .gallery(let images):
                InlineImageGallery(images: images)
            case .separator:
                Divider()
            case .spacer(let height):
                // The feed's spacing is sized for the web page, between components
                // that have no spacing of their own; halve it to suit the stack's.
                Color.clear.frame(height: max(height / 2 - 14, 0))
            case .pullQuote(let quote, let author):
                PullQuote(quote: quote, author: author)
            case .button(let title, let url):
                URLButton(title: title, url: url)
            case .card(let title, let body, let buttonTitle, let url):
                Card(title: title, message: body, buttonTitle: buttonTitle, url: url)
            case .contentItem(let id):
                if let item = store.item(withID: id) {
                    ContentItemNavigationLink(item: item) {
                        ContentItemRow(entry: item.isArticle ? .article(item) : .video(item.session))
                            .contentShape(.rect)
                    }
                }
            case .itemList(let title, let ids):
                let items = ids.compactMap(store.item(withID:))
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !title.isEmpty {
                            Text(title)
                                .font(.title3.bold())
                        }
                        ForEach(items) { item in
                            ContentItemNavigationLink(item: item) {
                                ContentItemRow(entry: item.isArticle ? .article(item) : .video(item.session))
                                    .contentShape(.rect)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            case .resource(let id):
                if let resource = store.resource(withID: id) {
                    RelatedResourceRow(resource: resource)
                }
            case .codeSnippet(let sample):
                CodeSnippet(sample: sample)
            case .ultrahero(let eyebrow, let title, let body, let image):
                VStack(alignment: .leading, spacing: 8) {
                    if let image {
                        MediaResourceImage(resource: image)
                            .padding(.bottom, 4)
                    }
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.largeTitle.bold())
                    if !body.isEmpty {
                        MarkdownText(markdown: body, style: TextStyle(textStyle: "title3", color: "secondary"))
                    }
                }
            }
        }
    }
}


enum DiscoverMetrics {
    #if os(macOS)
    static let margin: CGFloat = 24
    static let cardWidth: CGFloat = 272
    static let wideCardWidth: CGFloat = 440
    #else
    static let margin: CGFloat = 20
    static let cardWidth: CGFloat = 260
    static let wideCardWidth: CGFloat = 330
    #endif
    static let spacing: CGFloat = 16
    static let rowLimit = 12
}

#Preview {
    NavigationStack {
        ContentPageView()
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
    }
    .environment(ContentStore())
    .environment(NewsStore())
    .environment(SessionStore())
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    #if os(macOS)
    .frame(width: 1200, height: 900)
    #endif
}
