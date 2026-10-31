//
//  SessionStore.swift
//  Developer
//

import Foundation

/// Shared source of session videos for every tab. Shows the cached list
/// immediately, then refreshes from developer.apple.com.
@Observable
final class SessionStore {
    private(set) var sessions: [WWDCSession] = [] {
        didSet { sessionsByEvent = Dictionary(grouping: sessions, by: \.eventID) }
    }
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasCompletedInitialLoad = false

    /// Sessions per event, in the order they appear on developer.apple.com.
    private(set) var sessionsByEvent: [String: [WWDCSession]] = [:]

    private let service = WWDCVideoService()

    /// Events that have videos, ordered like the Developer app: the latest WWDC,
    /// then Meet with Apple and Tech Talks, then earlier WWDCs, newest first.
    var events: [WWDCEvent] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let wwdcs = (WWDCEvent.firstWWDCYear...currentYear).reversed()
            .map(WWDCEvent.wwdc)
            .filter { sessionsByEvent[$0.id] != nil }
        let others = [WWDCEvent.meetWithApple, .techTalks].filter { sessionsByEvent[$0.id] != nil }
        return Array(wwdcs.prefix(1)) + others + wwdcs.dropFirst()
    }

    /// An event's sessions in display order: newest first for ongoing series,
    /// the site's curated order for WWDC years.
    func sessions(in event: WWDCEvent) -> [WWDCSession] {
        let sessions = sessionsByEvent[event.id, default: []]
        return event.showsNewestFirst ? sessions.reversed() : sessions
    }

    /// Sessions tagged with `topic`, grouped by event in Browse order.
    func sessions(topic: String) -> [WWDCSession] {
        events.flatMap { sessions(in: $0) }.filter { $0.topics.contains(topic) }
    }

    /// Sessions with the given IDs, grouped by event in Browse order.
    func sessions(withIDs ids: Set<String>) -> [WWDCSession] {
        guard !ids.isEmpty else { return [] }
        return events.flatMap { sessions(in: $0) }.filter { ids.contains($0.id) }
    }

    /// Sessions with the given IDs, in the order given. IDs that aren't loaded are skipped.
    func sessions(orderedByIDs ids: [String]) -> [WWDCSession] {
        guard !ids.isEmpty else { return [] }
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    func session(for related: RelatedVideo) -> WWDCSession? {
        sessionsByEvent[related.eventID]?.first { $0.sessionNumber == related.sessionNumber }
    }

    var allTopics: Set<String> {
        Set(sessions.flatMap(\.topics))
    }

    var topics: [WWDCTopic] {
        let available = allTopics
        let known = WWDCTopic.known.filter { available.contains($0.name) }
        let knownNames = Set(WWDCTopic.known.map(\.name))
        let extra = available.subtracting(knownNames).sorted()
            .map { WWDCTopic(name: $0, systemImage: "tag") }
        return known + extra
    }

    func search(_ query: String) -> [WWDCSession] {
        guard !query.isEmpty else { return [] }
        return events.flatMap { sessions(in: $0) }.filter {
            $0.title.localizedStandardContains(query)
                || ($0.topic?.localizedStandardContains(query) ?? false)
        }
    }

    /// Shows the cached list immediately (if any), then refreshes from the network
    /// and saves the result. On failure, cached sessions stay on screen.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasCompletedInitialLoad = true
        }

        if sessions.isEmpty, let cached = WWDCCache.loadSessions() {
            sessions = cached
            hasCompletedInitialLoad = true
        }

        do {
            let fetched = try await service.fetchAllSessions(fallback: sessions)
            sessions = fetched
            errorMessage = nil
            WWDCCache.saveSessions(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
