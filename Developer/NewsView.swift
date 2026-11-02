//
//  NewsView.swift
//  Developer
//

import SwiftUI

@Observable
final class NewsStore {
    private(set) var items: [NewsItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service = NewsService()

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if items.isEmpty, let cached = await WWDCCache.loadNews() {
            items = cached
        }
        do {
            let fetched = try await service.fetchNews()
            items = fetched
            errorMessage = nil
            await WWDCCache.saveNews(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewsListView: View {
    @Environment(NewsStore.self) private var store
    @State private var searchText = ""

    private var items: [NewsItem] {
        guard !searchText.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedStandardContains(searchText) || $0.summary.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List(items) { item in
            NavigationLink(value: Route.news(item)) {
                NewsRow(item: item)
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        #else
        .listStyle(.plain)
        #endif
        .navigationTitle("News")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Find in News")
        .overlay {
            if store.isLoading && store.items.isEmpty {
                ProgressView("Fetching news…")
            } else if let errorMessage = store.errorMessage, store.items.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load News", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") { Task { await store.load() } }
                }
            } else if !searchText.isEmpty && items.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable { await store.load() }
        .task { if store.items.isEmpty { await store.load() } }
    }
}

struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NewsThumbnail(url: item.imageURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.date, format: .dateTime.month(.wide).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.summary)
                    .font(.callout)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            #if os(macOS)
            Image(systemName: "chevron.forward")
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
                .padding(.trailing, 6)
            #endif
        }
        .padding(.vertical, 4)
    }
}

struct NewsThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                    image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            } else {
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.6))
                    Image(systemName: "newspaper")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 82, height: 46)
        .clipShape(.rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

struct NewsArticleView: View {
    let item: NewsItem

    private var bodyBlocks: [NewsBlock] {
        var skippedHeader = false
        return item.blocks.filter { block in
            if case .image(let url) = block, url == item.imageURL, !skippedHeader {
                skippedHeader = true
                return false
            }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("NEWS AND UPDATES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)

                if let imageURL = item.imageURL {
                    NewsImage(url: imageURL)
                        .padding(.bottom, 12)
                }

                Text(item.title)
                    .font(.title2.bold())
                Text(item.date, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(bodyBlocks.enumerated()), id: \.offset) { _, block in
                        NewsBlockView(block: block)
                    }
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: 700, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: item.url)
                    Link(destination: item.url) {
                        Label("View on developer.apple.com", systemImage: "safari")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }
}

struct NewsImage: View {
    let url: URL

    var body: some View {
        AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Rectangle().fill(.quaternary).aspectRatio(16 / 9, contentMode: .fit)
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 6))
    }
}

struct NewsBlockView: View {
    let block: NewsBlock

    var body: some View {
        switch block {
        case .image(let url):
            NewsImage(url: url)
        case .heading(let runs):
            Text(Self.attributed(runs)).font(.title3.bold())
        case .paragraph(let runs):
            Text(Self.attributed(runs))
        case .listItem(let runs):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(Self.attributed(runs))
            }
            .padding(.leading, 8)
        case .divider:
            Divider()
        }
    }

    static func attributed(_ runs: [NewsRun]) -> AttributedString {
        runs.reduce(into: AttributedString()) { result, run in
            var piece = AttributedString(run.text)
            var font: Font = run.isCode ? .system(.body, design: .monospaced) : .body
            if run.isBold { font = font.bold() }
            if run.isItalic { font = font.italic() }
            piece.font = font
            if let link = run.link {
                piece.link = link
            }
            result += piece
        }
    }
}

#Preview("News") {
    @Previewable @State var store = NewsStore()
    NavigationStack {
        NewsListView()
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
    }
    .environment(store)
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    #if os(macOS)
    .frame(width: 1000, height: 700)
    #endif
}

#Preview("Article") {
    @Previewable @State var item: NewsItem?
    NavigationStack {
        if let item {
            NewsArticleView(item: item)
        } else {
            ProgressView()
        }
    }
    .task { item = await WWDCCache.loadNews()?.first }
    #if os(macOS)
    .frame(width: 1000, height: 700)
    #endif
}
