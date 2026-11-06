//
//  ContentItem.swift
//  Developer
//

import Foundation

nonisolated struct ContentItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let eventID: String
    let eventName: String
    let number: Int
    let type: String
    let title: String
    let summary: String
    let webURL: URL
    let startTime: Date?
    let endTime: Date?
    let publishedAt: Date?
    let duration: Double?
    let videoURL: URL?
    let hasLiveStream: Bool
    let topics: [String]
    let thumbnailURL: URL?
    let cardImageURL: URL?
    let posterURL: URL?
    let squareImageURL: URL?
    var articleID: String? = nil

    var isArticle: Bool { type == "Article" }

    func isLive(in feed: LiveVideosFeed, at date: Date) -> Bool {
        guard feed.streamURL(for: id) != nil else { return false }
        return (startTime ?? .distantPast) <= date && date <= (endTime ?? .distantFuture)
    }
    
    var session: WWDCSession {
        WWDCSession(
            id: id,
            eventID: eventID,
            sessionNumber: number,
            title: title,
            topics: topics,
            duration: duration.map(formattedClockDuration),
            thumbnailURL: thumbnailURL,
            url: webURL
        )
    }
}

/// A tab whose page is laid out by the feed (`articles.json`).
nonisolated enum RootPage: String, Codable, Hashable, Sendable {
    /// `discoverTabRoot`
    case discover
    /// `eventTabRoot`
    case wwdc

    var title: String {
        switch self {
        case .discover: "Discover"
        case .wwdc: "WWDC"
        }
    }
}

nonisolated struct DiscoverHero: Codable, Hashable, Sendable {
    let title: String
    let body: String
    let imageURL: URL?
    let aspectRatio: Double
    let itemID: String?
    var eyebrow: String? = nil
}

nonisolated struct DiscoverBanner: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let header: String
    let body: String
    let imageURL: URL?
    let itemID: String?
}

nonisolated struct DiscoverBannerGroup: Codable, Hashable, Sendable, Identifiable {
    enum Layout: String, Codable, Sendable {
        case stack
        case grid
    }

    let id: String
    let title: String?
    let layout: Layout
    let banners: [DiscoverBanner]
}

nonisolated struct DiscoverItemList: Codable, Hashable, Sendable, Identifiable {
    enum Layout: String, Codable, Sendable {
        case card
        case wideCard
    }

    let id: String
    let title: String
    let layout: Layout
    let itemTypes: [String]?
    let eventIDs: [String]?
    let liveOnly: Bool
    let itemIDs: [String]?
    let showsSeeAll: Bool
}

nonisolated enum DiscoverSection: Codable, Hashable, Sendable, Identifiable {
    case hero(DiscoverHero)
    case itemList(DiscoverItemList)
    case banners(DiscoverBannerGroup)

    var id: String {
        switch self {
        case .hero(let hero): "hero-\(hero.title)"
        case .itemList(let list): list.id
        case .banners(let group): group.id
        }
    }
}

nonisolated struct DiscoverFeed: Codable, Sendable {
    static let currentFormatVersion = 3

    var items: [ContentItem]
    var sections: [DiscoverSection]
    var wwdcSections: [DiscoverSection] = []
    /// Events whose `sortOrder` lists items oldest first (e.g. `groupedPublishDateAscending`).
    var ascendingEventIDs: Set<String> = []
    var pages: [String: ContentPage] = [:]
    var resources: [Int: ContentResource] = [:]
    var formatVersion: Int? = DiscoverFeed.currentFormatVersion
    var contentsETag: String?
    var pageETag: String?
    var fetchedAt: Date

    func sections(for root: RootPage) -> [DiscoverSection] {
        switch root {
        case .discover: sections
        case .wwdc: wwdcSections
        }
    }
}

nonisolated struct LiveVideosFeed: Codable, Hashable, Sendable {
    var streams: [String: URL] = [:]

    func streamURL(for itemID: String) -> URL? { streams[itemID] }
}
