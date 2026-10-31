//
//  ContentItem.swift
//  Developer
//

import Foundation

/// A video, session, article, or news item from the Developer app's content feed.
nonisolated struct ContentItem: Codable, Hashable, Sendable, Identifiable {
    /// e.g. "wwdc2026-102" or "meet-with-apple-284", matching `WWDCSession.id`.
    let id: String
    /// e.g. "wwdc2026", "tech-talks", "articles", or "news".
    let eventID: String
    let eventName: String
    /// The item's number within its event, e.g. 102.
    let number: Int
    /// "Video", "Session", "Get-Together", "Article", "Special Event", etc.
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

/// The Discover tab's large banner.
nonisolated struct DiscoverHero: Codable, Hashable, Sendable {
    let title: String
    let body: String
    let imageURL: URL?
    let aspectRatio: Double
    let itemID: String?
}

/// A titled row on the Discover tab, such as "On Now" or "Recent videos".
nonisolated struct DiscoverItemList: Codable, Hashable, Sendable, Identifiable {
    enum Layout: String, Codable, Sendable {
        /// Thumbnail cards with the title below.
        case card
        /// Wide tiles with a square image, title, and date (used for news).
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

    var id: String {
        switch self {
        case .hero(let hero): "hero-\(hero.title)"
        case .itemList(let list): list.id
        }
    }
}

nonisolated struct DiscoverFeed: Codable, Sendable {
    static let currentFormatVersion = 2

    var items: [ContentItem]
    var sections: [DiscoverSection]
    var pages: [String: ContentPage] = [:]
    var resources: [Int: ContentResource] = [:]
    var formatVersion: Int? = DiscoverFeed.currentFormatVersion
    var contentsETag: String?
    var pageETag: String?
    var fetchedAt: Date
}

nonisolated struct LiveVideosFeed: Codable, Hashable, Sendable {
    var streams: [String: URL] = [:]

    func streamURL(for itemID: String) -> URL? { streams[itemID] }
}
