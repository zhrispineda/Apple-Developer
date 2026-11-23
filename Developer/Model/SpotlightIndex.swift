//
//  SpotlightIndex.swift
//  Developer
//

import CoreSpotlight
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// One searchable thing: a video, the code in a video, an article, a news post, or a collection.
nonisolated struct SearchDocument: Sendable {
    enum Kind: String, Sendable {
        case collection, video, article, news, code
    }

    let kind: Kind
    let id: String
    let title: String
    var summary = ""
    var keywords: [String] = []
    /// Full text to search. Videos leave this empty; their transcript is read from `TranscriptStore`.
    var body = ""
    var date: Date?

    var identifier: String { "\(kind.rawValue)/\(id)" }
}

/// IDs of the documents a Spotlight query matched, by kind.
nonisolated struct SpotlightMatches: Sendable {
    var ids: [SearchDocument.Kind: Set<String>] = [:]

    func ids(of kind: SearchDocument.Kind) -> Set<String> { ids[kind] ?? [] }
}

/// Whether the index is being updated, for showing progress in search.
@Observable
final class SearchIndexStatus {
    static let shared = SearchIndexStatus()
    fileprivate(set) var isUpdating = false
}

/// An app-private Core Spotlight index of all content, including every video transcript.
///
/// Only documents whose content (or transcript ETag) changed since the last update are reindexed,
/// so after the first run updates are cheap. Queries run against Spotlight's inverted index
/// instead of scanning text, which keeps searching fast.
actor SpotlightIndex {
    static let shared = SpotlightIndex()

    /// Bump to rebuild the index after changing what gets indexed.
    private static let schemaVersion = 1
    private static let batchSize = 200
    private static let searchedAttributes = ["title", "contentDescription", "keywords", "textContent"]

    nonisolated private struct State: Codable {
        var version = SpotlightIndex.schemaVersion
        /// Content fingerprints by document identifier, for everything in the index.
        var fingerprints: [String: String] = [:]
    }

    private let index = CSSearchableIndex(name: "DeveloperContent")
    private let stateFile = URL.applicationSupportDirectory.appending(path: "SearchIndex/state.json")
    private lazy var state: State = {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return State(version: 0) }
        return state
    }()
    private var isUpdating = false

    // MARK: Indexing

    /// Syncs transcripts, then indexes new or changed documents and removes ones that are gone.
    func update(with documents: [SearchDocument]) async {
        guard !isUpdating else { return }
        isUpdating = true
        await setStatus(true)
        defer { isUpdating = false }

        do {
            try await TranscriptStore.shared.refresh()
        } catch {
            print("Failed to refresh transcripts: \(error)")
        }
        let transcriptETags = await TranscriptStore.shared.etags

        do {
            if state.version != Self.schemaVersion {
                try await index.deleteAllSearchableItems()
                state = State()
            }

            let start = ContinuousClock.now
            var indexedCount = 0
            var current: [String: String] = [:]
            var batch: [(item: CSSearchableItem, fingerprint: String)] = []
            for document in documents where current[document.identifier] == nil {
                let transcriptETag = document.kind == .video ? transcriptETags[document.id] : nil
                let fingerprint = Self.fingerprint(of: document, transcriptETag: transcriptETag)
                current[document.identifier] = fingerprint
                guard state.fingerprints[document.identifier] != fingerprint else { continue }

                indexedCount += 1
                batch.append((await searchableItem(for: document), fingerprint))
                if batch.count >= Self.batchSize {
                    try await commit(batch)
                    batch = []
                }
                if Task.isCancelled { break }
            }
            try await commit(batch)

            let removed = Array(Set(state.fingerprints.keys).subtracting(current.keys))
            if !Task.isCancelled, !removed.isEmpty {
                try await index.deleteSearchableItems(withIdentifiers: removed)
                removed.forEach { state.fingerprints[$0] = nil }
                saveState()
            }
            print("Search index updated: \(indexedCount) of \(current.count) documents reindexed, \(removed.count) removed, in \(ContinuousClock.now - start).")
        } catch {
            print("Failed to update search index: \(error)")
        }
        await setStatus(false)
    }

    private func commit(_ batch: [(item: CSSearchableItem, fingerprint: String)]) async throws {
        guard !batch.isEmpty else { return }
        try await index.indexSearchableItems(batch.map(\.item))
        for (item, fingerprint) in batch {
            state.fingerprints[item.uniqueIdentifier] = fingerprint
        }
        saveState()
    }

    private func searchableItem(for document: SearchDocument) async -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: document.kind == .video ? .movie : .text)
        attributes.displayName = document.title
        // Code documents only match on their code, not the video's title.
        if document.kind != .code {
            attributes.title = document.title
            attributes.contentDescription = document.summary
            attributes.keywords = document.keywords
        }
        if document.kind == .video {
            let paragraphs = await TranscriptStore.shared.paragraphs(for: document.id) ?? []
            attributes.textContent = paragraphs.flatMap(\.sentences).map(\.text).joined(separator: " ")
        } else {
            attributes.textContent = document.body
        }
        attributes.contentCreationDate = document.date
        return CSSearchableItem(uniqueIdentifier: document.identifier, domainIdentifier: document.kind.rawValue, attributeSet: attributes)
    }

    private static func fingerprint(of document: SearchDocument, transcriptETag: String?) -> String {
        let fields = [document.title, document.summary, document.keywords.joined(separator: ","), document.body, transcriptETag ?? ""]
        let digest = SHA256.hash(data: Data(fields.joined(separator: "\u{1F}").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func saveState() {
        do {
            try FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: stateFile, options: .atomic)
        } catch {
            print("Failed to save search index state: \(error)")
        }
    }

    private func setStatus(_ isUpdating: Bool) async {
        await MainActor.run { SearchIndexStatus.shared.isUpdating = isUpdating }
    }

    // MARK: Searching

    /// Finds documents where every word of `query` prefixes a word in the title, description,
    /// keywords, or text (transcript, code, or body), ignoring case and diacritics.
    func search(_ query: String) async -> SpotlightMatches {
        let clauses = query.split(whereSeparator: \.isWhitespace).compactMap { word -> String? in
            let escaped = String(word)
                .replacing("\\", with: "\\\\")
                .replacing("\"", with: "\\\"")
                .replacing("*", with: "")
            guard !escaped.isEmpty else { return nil }
            let fields = Self.searchedAttributes.map { "\($0) == \"\(escaped)*\"cdw" }
            return "(" + fields.joined(separator: " || ") + ")"
        }
        guard !clauses.isEmpty else { return SpotlightMatches() }

        let context = CSSearchQueryContext()
        context.fetchAttributes = []
        let spotlightQuery = CSSearchQuery(queryString: clauses.joined(separator: " && "), queryContext: context)

        var matches = SpotlightMatches()
        do {
            for try await result in spotlightQuery.results {
                if Task.isCancelled {
                    spotlightQuery.cancel()
                    break
                }
                let parts = result.item.uniqueIdentifier.split(separator: "/", maxSplits: 1)
                guard parts.count == 2, let kind = SearchDocument.Kind(rawValue: String(parts[0])) else { continue }
                matches.ids[kind, default: []].insert(String(parts[1]))
            }
        } catch {
            print("Spotlight search failed for \"\(query)\": \(error)")
        }
        return matches
    }
}

// MARK: - Documents

extension SpotlightIndex {
    /// Everything search should find, built from the app's stores.
    @MainActor
    static func documents(sessions: [WWDCSession], contentStore: ContentStore, news: [NewsItem]) -> [SearchDocument] {
        var documents: [SearchDocument] = []
        let now = Date.now
        let items = (contentStore.feed?.items ?? []).filter { ($0.publishedAt ?? .distantPast) <= now }

        var feedVideoIDs = Set<String>()
        for item in items {
            if item.isArticle, item.isBrowsable {
                documents.append(SearchDocument(
                    kind: .article, id: item.id, title: item.title, summary: item.summary,
                    keywords: item.topics, body: contentStore.page(for: item)?.plainText ?? "", date: item.publishedAt
                ))
            } else if item.videoURL != nil {
                feedVideoIDs.insert(item.id)
                documents.append(SearchDocument(
                    kind: .video, id: item.id, title: item.title, summary: item.summary,
                    keywords: item.topics + [item.eventName], date: item.publishedAt
                ))
                if let code = item.codeSamples, !code.isEmpty {
                    documents.append(SearchDocument(
                        kind: .code, id: item.id, title: item.title,
                        body: code.map(\.code).joined(separator: "\n\n"), date: item.publishedAt
                    ))
                }
            }
        }

        // Older sessions that only the video list (not the feed) knows about.
        for session in sessions where !feedVideoIDs.contains(session.id) {
            documents.append(SearchDocument(kind: .video, id: session.id, title: session.title, keywords: session.topics + [session.eventName]))
        }

        for case .itemList(let list) in contentStore.sections(for: .discover) + contentStore.sections(for: .wwdc) where !list.liveOnly {
            documents.append(SearchDocument(kind: .collection, id: list.id, title: list.title))
        }

        for item in news {
            documents.append(SearchDocument(kind: .news, id: item.id, title: item.title, summary: item.summary, body: item.plainText, date: item.date))
        }
        return documents
    }
}

nonisolated extension ContentPage {
    /// The readable text of the page, for search.
    var plainText: String {
        components.compactMap { component -> String? in
            switch component.kind {
            case .title(let text), .header(let text), .text(let text, _): text
            case .pullQuote(let quote, _): quote
            case .card(let title, let body, _, _): "\(title)\n\(body)"
            case .ultrahero(_, let title, let body, _): "\(title)\n\(body)"
            default: nil
            }
        }
        .joined(separator: "\n")
    }
}

nonisolated extension NewsItem {
    /// The readable text of the post, for search.
    var plainText: String {
        blocks.compactMap { block -> String? in
            switch block {
            case .heading(let runs), .paragraph(let runs), .listItem(let runs): runs.map(\.text).joined()
            case .image, .divider: nil
            }
        }
        .joined(separator: "\n")
    }
}
