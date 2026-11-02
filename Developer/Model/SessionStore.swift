//
//  SessionStore.swift
//  Developer
//

import Foundation

@Observable
final class SessionStore {
    private(set) var sessions: [WWDCSession] = [] {
        didSet { sessionsByEvent = Dictionary(grouping: sessions, by: \.eventID) }
    }
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasCompletedInitialLoad = false

    private(set) var sessionsByEvent: [String: [WWDCSession]] = [:]

    private let service = WWDCVideoService()

    var events: [WWDCEvent] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let wwdcs = (WWDCEvent.firstWWDCYear...currentYear).reversed()
            .map(WWDCEvent.wwdc)
            .filter { sessionsByEvent[$0.id] != nil }
        let others = [WWDCEvent.meetWithApple, .techTalks].filter { sessionsByEvent[$0.id] != nil }
        return Array(wwdcs.prefix(1)) + others + wwdcs.dropFirst()
    }

    func sessions(in event: WWDCEvent) -> [WWDCSession] {
        let sessions = sessionsByEvent[event.id, default: []]
        return event.showsNewestFirst ? sessions.reversed() : sessions
    }

    func sessions(topic: String) -> [WWDCSession] {
        events.flatMap { sessions(in: $0) }.filter { $0.topics.contains(topic) }
    }

    func sessions(withIDs ids: Set<String>) -> [WWDCSession] {
        guard !ids.isEmpty else { return [] }
        return events.flatMap { sessions(in: $0) }.filter { ids.contains($0.id) }
    }

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
