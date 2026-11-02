//
//  WWDCCache.swift
//  Developer
//

import Foundation

nonisolated enum WWDCCache {
    private static let rootDirectory = URL.cachesDirectory.appending(path: "WWDC", directoryHint: .isDirectory)
    private static let sessionsFile = rootDirectory.appending(path: "sessions.json")
    private static let detailsDirectory = rootDirectory.appending(path: "Details", directoryHint: .isDirectory)

    static let imageSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 1024 * 1024 * 1024,
            directory: rootDirectory.appending(path: "Thumbnails", directoryHint: .isDirectory)
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    // MARK: Session list

    static func loadSessions() -> [WWDCSession]? {
        guard let data = try? Data(contentsOf: sessionsFile) else { return nil }
        return try? JSONDecoder().decode([WWDCSession].self, from: data)
    }

    static func saveSessions(_ sessions: [WWDCSession]) {
        save(sessions, to: sessionsFile)
    }

    // MARK: News

    private static let newsFile = rootDirectory.appending(path: "news.json")

    @concurrent
    static func loadNews() async -> [NewsItem]? {
        guard let data = try? Data(contentsOf: newsFile) else { return nil }
        return try? JSONDecoder().decode([NewsItem].self, from: data)
    }

    @concurrent
    static func saveNews(_ items: [NewsItem]) async {
        save(items, to: newsFile)
    }

    // MARK: Discover

    private static let discoverFile = rootDirectory.appending(path: "discover.json")

    @concurrent
    static func loadDiscover() async -> DiscoverFeed? {
        guard let data = try? Data(contentsOf: discoverFile) else { return nil }
        return try? JSONDecoder().decode(DiscoverFeed.self, from: data)
    }

    @concurrent
    static func saveDiscover(_ feed: DiscoverFeed) async {
        save(feed, to: discoverFile)
    }

    // MARK: Session details

    private static let memoryCache = NSCache<NSString, DetailsBox>()

    private final class DetailsBox: Sendable {
        let details: WWDCSessionDetails
        init(_ details: WWDCSessionDetails) { self.details = details }
    }

    @concurrent
    static func loadDetails(for sessionID: String) async -> WWDCSessionDetails? {
        if let box = memoryCache.object(forKey: sessionID as NSString) { return box.details }
        guard let data = try? Data(contentsOf: detailsFile(for: sessionID)),
              let details = try? JSONDecoder().decode(WWDCSessionDetails.self, from: data)
        else { return nil }
        memoryCache.setObject(DetailsBox(details), forKey: sessionID as NSString)
        return details
    }

    @concurrent
    static func saveDetails(_ details: WWDCSessionDetails, for sessionID: String) async {
        memoryCache.setObject(DetailsBox(details), forKey: sessionID as NSString)
        save(details, to: detailsFile(for: sessionID))
    }

    // MARK: Helpers

    private static func detailsFile(for sessionID: String) -> URL {
        detailsDirectory.appending(path: "\(sessionID).json")
    }

    private static func save(_ value: some Encodable, to file: URL) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: file, options: .atomic)
        } catch {
            print("Failed to write cache file \(file.lastPathComponent): \(error)")
        }
    }
}
