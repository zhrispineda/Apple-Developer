//
//  SearchView.swift
//  Developer
//

import SwiftUI

struct SearchView: View {
    var embedsInNavigationStack = true

    @AppStorage("recentSearches") private var recentSearchesStorage = ""
    @Environment(SessionStore.self) private var store
    @Environment(ContentStore.self) private var contentStore
    @Environment(NewsStore.self) private var newsStore
    @State private var searchText = ""
    @State private var scope: SearchScope = .all
    @State private var spotlightMatches = SpotlightMatches()
    @State private var spotlightQuery = ""
    private var indexStatus: SearchIndexStatus { .shared }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private static let maxRecentSearches = 10

    private var recentSearches: [String] {
        recentSearchesStorage.split(separator: "\n").map(String.init)
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usesWideRows: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    // MARK: Results

    private var allResults: [SearchResult] {
        let query = query
        guard !query.isEmpty else { return [] }
        let spotlight = spotlightQuery == query ? spotlightMatches : SpotlightMatches()
        let sessions = orderedSessions

        return collectionResults(query, spotlight)
            + videoResults(query, spotlight, sessions: sessions)
            + articleResults(query, spotlight)
            + newsResults(query, spotlight)
            + codeResults(spotlight, sessions: sessions)
    }

    private var orderedSessions: [WWDCSession] {
        var seen = Set<String>()
        return store.events.flatMap { store.sessions(in: $0) }.filter { seen.insert($0.id).inserted }
    }

    private func collectionResults(_ query: String, _ spotlight: SpotlightMatches) -> [SearchResult] {
        var seen = Set<DiscoverItemList.ID>()
        let ids = spotlight.ids(of: .collection)
        return (contentStore.sections(for: .discover) + contentStore.sections(for: .wwdc)).compactMap { section in
            guard case .itemList(let list) = section,
                  ids.contains(list.id) || SearchExcerpt.matches(list.title, query: query),
                  seen.insert(list.id).inserted
            else { return nil }
            let items = contentStore.items(for: list)
            guard !items.isEmpty else { return nil }
            return .collection(list, thumbnailURL: items.first?.thumbnailURL, itemCount: items.count)
        }
    }

    private func videoResults(_ query: String, _ spotlight: SpotlightMatches, sessions: [WWDCSession]) -> [SearchResult] {
        let ids = spotlight.ids(of: .video)
        var titleMatches: [WWDCSession] = []
        var otherMatches: [WWDCSession] = []
        for session in sessions {
            if SearchExcerpt.matches(session.title, query: query) || session.topics.contains(where: { SearchExcerpt.matches($0, query: query) }) {
                titleMatches.append(session)
            } else if ids.contains(session.id) {
                otherMatches.append(session)
            }
        }
        
        let listedIDs = Set(sessions.map(\.id))
        let feedOnly = ids.subtracting(listedIDs)
            .compactMap { contentStore.item(withID: $0) }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .map(\.session)
        return (titleMatches + otherMatches + feedOnly).map(SearchResult.video)
    }

    private func articleResults(_ query: String, _ spotlight: SpotlightMatches) -> [SearchResult] {
        let now = Date.now
        let ids = spotlight.ids(of: .article)
        let matches = (contentStore.feed?.items ?? []).filter { item in
            item.isArticle && item.isBrowsable && (item.publishedAt ?? .distantFuture) <= now
                && (ids.contains(item.id) || SearchExcerpt.matches(item.title, query: query) || SearchExcerpt.matches(item.summary, query: query))
        }
        return rankedByTitle(matches, query: query, title: \.title, date: { $0.publishedAt }).map(SearchResult.article)
    }

    private func newsResults(_ query: String, _ spotlight: SpotlightMatches) -> [SearchResult] {
        let ids = spotlight.ids(of: .news)
        let matches = newsStore.items.filter {
            ids.contains($0.id) || SearchExcerpt.matches($0.title, query: query) || SearchExcerpt.matches($0.summary, query: query)
        }
        return rankedByTitle(matches, query: query, title: \.title, date: { $0.date }).map(SearchResult.news)
    }

    private func codeResults(_ spotlight: SpotlightMatches, sessions: [WWDCSession]) -> [SearchResult] {
        let ids = spotlight.ids(of: .code)
        guard !ids.isEmpty else { return [] }
        let listed = sessions.filter { ids.contains($0.id) }
        let listedIDs = Set(listed.map(\.id))
        let feedOnly = ids.subtracting(listedIDs).compactMap { contentStore.item(withID: $0)?.session }
        return (listed + feedOnly).map(SearchResult.code)
    }

    private func rankedByTitle<Item>(_ items: [Item], query: String, title: (Item) -> String, date: (Item) -> Date?) -> [Item] {
        let newestFirst = items.sorted { (date($0) ?? .distantPast) > (date($1) ?? .distantPast) }
        let (titled, others) = newestFirst.reduce(into: ([Item](), [Item]())) { groups, item in
            if SearchExcerpt.matches(title(item), query: query) {
                groups.0.append(item)
            } else {
                groups.1.append(item)
            }
        }
        return titled + others
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack {
                content
                    .navigationDestination(for: Route.self) { route in
                        RouteView(route: route)
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if searchText.isEmpty {
                recentSearchesView
            } else {
                resultsView
            }
        }
        #if os(iOS)
        .navigationTitle("Search")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        #else
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .navigationTitle("")
        #endif
        .onSubmit(of: .search) { addRecentSearch(searchText) }
        .toolbar {
            if !query.isEmpty {
                ToolbarItem(placement: scopePickerPlacement) {
                    scopePicker
                }
            }
        }
        .task(id: "\(query)|\(indexStatus.isUpdating)") {
            guard !query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let query = query
            let matches = await SpotlightIndex.shared.search(query)
            guard !Task.isCancelled else { return }
            spotlightMatches = matches
            spotlightQuery = query
        }
        .task {
            await contentStore.load()
            if newsStore.items.isEmpty {
                await newsStore.load()
            }
        }
    }

    private var scopePickerPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarTrailing
        #endif
    }

    private var scopePicker: some View {
        let results = allResults
        return Picker("Filter", selection: $scope) {
            ForEach(SearchScope.allCases) { scope in
                let count = scope == .all ? results.count : results.count { $0.scope == scope }
                Text("\(scope.title) (\(count))").tag(scope)
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: Subviews

    @ViewBuilder
    private var recentSearchesView: some View {
        if recentSearches.isEmpty {
            ContentUnavailableView {
                Label("No Recent Searches", systemImage: "")
            } description: {
                Text("Recent searches will be added as you search for videos, articles, and more.")
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Recently Searched")
                            .font(.title3.bold())
                        Spacer()
                        Button("Clear") { recentSearchesStorage = "" }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                    .padding(.bottom, 4)

                    ForEach(Array(recentSearches.enumerated()), id: \.element) { index, query in
                        if index > 0 {
                            Divider()
                        }
                        Button {
                            searchText = query
                            addRecentSearch(query)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
    }

    private var resultsView: some View {
        let results = scope == .all ? allResults : allResults.filter { $0.scope == scope }
        return List(results) { result in
            NavigationLink(value: result.route) {
                SearchResultRow(result: result, query: query, isWide: usesWideRows)
            }
            .contextMenu {
                if let session = result.session {
                    ContentItemContextMenu(session: session)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .environment(\.defaultMinListRowHeight, 70)
        #else
        .listStyle(.plain)
        #endif
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if indexStatus.isUpdating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating search index…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(.bar)
            }
        }
    }

    // MARK: Recent searches

    private func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = [trimmed] + recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recentSearchesStorage = updated.prefix(Self.maxRecentSearches).joined(separator: "\n")
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let query: String
    let isWide: Bool

    enum Excerpt: Equatable {
        case none
        case text(String)
        case code(String)
    }

    private static var excerptCache: [String: Excerpt] = [:]
    private static let excerptCacheLimit = 1000

    @Environment(ContentStore.self) private var contentStore
    @State private var excerpt = Excerpt.none

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ContentItemThumbnail(url: thumbnailURL, width: ContentItemWideRow.thumbnailWidth)

            VStack(alignment: .leading, spacing: 4) {
                if isWide {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        title
                            .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                        Text(source)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 110, alignment: .leading)

                        status
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: 70, alignment: .trailing)

                        #if os(macOS)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(.tertiary)
                        #endif
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(source)
                        status
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    title
                }

                snippet
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, isWide ? 6 : 0)
        .task(id: query) { excerpt = await loadExcerpt() }
    }

    // MARK: Excerpt

    private func loadExcerpt() async -> Excerpt {
        let key = "\(result.id)|\(query)"
        if let cached = Self.excerptCache[key] { return cached }

        let excerpt: Excerpt
        switch result {
        case .collection:
            excerpt = .none
        case .video(let session):
            if SearchExcerpt.matches(session.title, query: query) {
                excerpt = .none
            } else {
                var paragraphs = await TranscriptStore.shared.paragraphs(for: session.id)
                if paragraphs == nil {
                    paragraphs = await WWDCCache.loadDetails(for: session.id)?.transcript
                }
                if let transcript = paragraphs.flatMap({ SearchExcerpt.transcript($0, query: query) }) {
                    excerpt = .text(transcript)
                } else {
                    excerpt = textExcerpt(contentStore.item(withID: session.id)?.summary)
                }
            }
        case .code(let session):
            var samples = contentStore.item(withID: session.id)?.codeSamples
            if samples == nil {
                samples = await WWDCCache.loadDetails(for: session.id)?.codeSamples
            }
            excerpt = SearchExcerpt.code(samples ?? [], query: query).map(Excerpt.code) ?? .none
        case .article(let item):
            excerpt = SearchExcerpt.matches(item.title, query: query)
                ? .none
                : textExcerpt(item.summary, orElse: contentStore.page(for: item)?.plainText)
        case .news(let item):
            excerpt = SearchExcerpt.matches(item.title, query: query)
                ? .none
                : textExcerpt(item.summary, orElse: item.plainText)
        }

        if Self.excerptCache.count >= Self.excerptCacheLimit {
            Self.excerptCache.removeAll()
        }
        Self.excerptCache[key] = excerpt
        return excerpt
    }

    private func textExcerpt(_ text: String?, orElse fallback: String? = nil) -> Excerpt {
        for candidate in [text, fallback].compactMap(\.self) {
            if let excerpt = SearchExcerpt.text(candidate, query: query) {
                return .text(excerpt)
            }
        }
        return .none
    }

    private var title: some View {
        Text(highlighting(query, in: titleText))
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var snippet: some View {
        switch excerpt {
        case .text(let text):
            Text(highlighting(query, in: text))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .code(let code):
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(code.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                    Text(highlighting(query, in: String(line)))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var status: some View {
        switch result {
        case .video(let session), .code(let session):
            ContentItemStatusText(session: session)
        case .collection(_, _, let itemCount):
            Text("\(itemCount) items")
        case .news(let item):
            Text(item.date, format: .dateTime.month(.abbreviated).day().year())
        case .article:
            EmptyView()
        }
    }

    private var titleText: String { result.title }

    private var source: String {
        switch result {
        case .collection: "Collection"
        case .video(let session), .code(let session): session.eventName
        case .article(let item): item.eventName.isEmpty ? "Articles" : item.eventName
        case .news: "News"
        }
    }

    private var thumbnailURL: URL? {
        switch result {
        case .collection(_, let url, _): url
        case .video(let session), .code(let session): session.thumbnailURL
        case .article(let item): item.thumbnailURL
        case .news(let item): item.imageURL
        }
    }
}

private func highlighting(_ query: String, in text: String) -> AttributedString {
    var attributed = AttributedString(text)
    for word in SearchExcerpt.words(in: query) {
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].foregroundColor = .accentColor
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
    }
    return attributed
}

#Preview {
    SearchView()
        .environment(SessionStore())
        .environment(ContentStore())
        .environment(NewsStore())
        .environment(WatchProgressStore())
        .environment(DownloadEngine())
        .environment(SynchronizedListManager())
}
