//
//  ContentStore.swift
//  Developer
//

import Foundation

@Observable
final class ContentStore {
    private(set) var feed: DiscoverFeed? {
        didSet { rebuildIndexes() }
    }
    private(set) var live = LiveVideosFeed()
    private(set) var now = Date.now
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private static let feedRefreshInterval: TimeInterval = 300
    private static let liveRefreshInterval: Duration = .seconds(60)

    @ObservationIgnored private var itemsByID: [String: ContentItem] = [:]
    @ObservationIgnored private var itemsByList: [DiscoverItemList.ID: [ContentItem]] = [:]
    @ObservationIgnored private var liveFetchedAt: Date?
    @ObservationIgnored private var itemsByWebKey: [String: ContentItem] = [:]
    @ObservationIgnored private var groupsByTopic: [String: [ContentItemGroup]] = [:]

    private let service = FeedFetcher()

    func sections(for root: RootPage) -> [DiscoverSection] { feed?.sections(for: root) ?? [] }

    func item(withID id: String) -> ContentItem? { itemsByID[id] }

    func isLive(_ item: ContentItem) -> Bool { item.isLive(in: live, at: now) }

    func page(for item: ContentItem) -> ContentPage? {
        item.articleID.flatMap { feed?.pages[$0] }
    }

    func resource(withID id: Int) -> ContentResource? { feed?.resources[id] }

    func groups(topic: String) -> [ContentItemGroup]? {
        guard let feed else { return nil }
        if let cached = groupsByTopic[topic] { return cached }
        let now = Date.now
        let groups = feed.items
            .filter { $0.isBrowsable && $0.topics.contains(topic) && ($0.publishedAt ?? .distantFuture) <= now }
            .groupedByPublicationYear()
        groupsByTopic[topic] = groups
        return groups
    }

    func route(for url: URL) -> Route? {
        guard let key = Self.webKey(for: url), let item = itemsByWebKey[key] else { return nil }
        if page(for: item) != nil { return .article(item) }
        if item.videoURL != nil { return .session(item.session) }
        return nil
    }

    private static func webKey(for url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.hasSuffix("developer.apple.com") == true
        else { return nil }
        var path = components.path.lowercased()
        while path.hasSuffix("/") { path.removeLast() }
        let id = components.queryItems?.first { $0.name == "id" }?.value
        return id.map { "\(path)?id=\($0)" } ?? path
    }

    func items(for list: DiscoverItemList) -> [ContentItem] {
        guard list.liveOnly else { return itemsByList[list.id] ?? [] }
        return live.streams.keys.sorted().compactMap { itemsByID[$0] }.filter(isLive)
    }

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    func load(force: Bool = false) async {
        if let loadTask {
            await loadTask.value
            guard force, errorMessage != nil else { return }
        }
        let task = Task { await performLoad(force: force) }
        loadTask = task
        await task.value
        if loadTask == task { loadTask = nil }
    }

    private func performLoad(force: Bool) async {
        isLoading = true
        defer { isLoading = false }

        if feed == nil, let cached = await WWDCCache.loadDiscover() {
            feed = cached
        }
        if !force, let feed, Date.now.timeIntervalSince(feed.fetchedAt) < Self.feedRefreshInterval {
            return
        }
        do {
            let fetched = try await service.fetchFeed(updating: feed)
            feed = fetched
            errorMessage = nil
            await WWDCCache.saveDiscover(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLive(force: Bool = false) async {
        if !force, let liveFetchedAt, Date.now.timeIntervalSince(liveFetchedAt) < 30 { return }
        liveFetchedAt = .now
        if let fetched = try? await service.fetchLiveVideos(), fetched != live {
            live = fetched
        }
        now = .now
    }

    func monitorLive() async {
        while !Task.isCancelled {
            await refreshLive()
            try? await Task.sleep(for: Self.liveRefreshInterval)
        }
    }

    private func rebuildIndexes() {
        let items = feed?.items ?? []
        itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        itemsByWebKey = Dictionary(
            items.compactMap { item in Self.webKey(for: item.webURL).map { ($0, item) } },
            uniquingKeysWith: { first, _ in first }
        )
        groupsByTopic = [:]

        let now = Date.now
        let published = items
            .filter { ($0.publishedAt ?? .distantFuture) <= now }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

        var lists: [DiscoverItemList.ID: [ContentItem]] = [:]
        let allSections = sections(for: .discover) + sections(for: .wwdc)
        let ascendingEventIDs = feed?.ascendingEventIDs ?? []
        for case .itemList(let list) in allSections where !list.liveOnly {
            if let ids = list.itemIDs {
                lists[list.id] = ids.compactMap { itemsByID[$0] }
            } else {
                let matches = published.filter { item in
                    (list.itemTypes?.contains(item.type) ?? true)
                        && (list.eventIDs?.contains(item.eventID) ?? true)
                        && (item.type == "Article" || item.videoURL != nil)
                }
                
                // Lists drawn only from oldest-first events (WWDC, Meet with Apple)
                // read in schedule order, e.g. Keynote first; the rest stay newest first.
                let isAscending = list.eventIDs.map { !$0.isEmpty && $0.allSatisfy(ascendingEventIDs.contains) } ?? false
                lists[list.id] = isAscending ? matches.sorted(by: Self.scheduleOrder) : matches
            }
        }
        itemsByList = lists
    }

    nonisolated private static func scheduleOrder(_ lhs: ContentItem, _ rhs: ContentItem) -> Bool {
        let lhsKey = (lhs.publishedAt ?? .distantFuture, lhs.startTime ?? .distantFuture, lhs.number)
        let rhsKey = (rhs.publishedAt ?? .distantFuture, rhs.startTime ?? .distantFuture, rhs.number)
        return lhsKey < rhsKey
    }
}
