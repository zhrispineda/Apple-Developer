//
//  SearchResult.swift
//  Developer
//

import Foundation

/// The kinds of content the search filter menu can narrow results to.
nonisolated enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case all, collections, videos, articles, news, code

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Results"
        case .collections: "Collections"
        case .videos: "Videos"
        case .articles: "Articles"
        case .news: "News"
        case .code: "Code"
        }
    }
}

enum SearchResult: Identifiable, Hashable {
    /// A curated item list from the Discover or WWDC pages.
    case collection(DiscoverItemList, thumbnailURL: URL?, itemCount: Int)
    /// A video whose title, description, topics, or transcript match.
    case video(WWDCSession)
    case article(ContentItem)
    case news(NewsItem)
    /// A video with a code sample that matches.
    case code(WWDCSession)

    var id: String {
        switch self {
        case .collection(let list, _, _): "collection-\(list.id)"
        case .video(let session): "video-\(session.id)"
        case .article(let item): "article-\(item.id)"
        case .news(let item): "news-\(item.id)"
        case .code(let session): "code-\(session.id)"
        }
    }

    var scope: SearchScope {
        switch self {
        case .collection: .collections
        case .video: .videos
        case .article: .articles
        case .news: .news
        case .code: .code
        }
    }

    var route: Route {
        switch self {
        case .collection(let list, _, _): .discoverList(list)
        case .video(let session), .code(let session): .session(session)
        case .article(let item): .article(item)
        case .news(let item): .news(item)
        }
    }

    var session: WWDCSession? {
        switch self {
        case .video(let session), .code(let session): session
        default: nil
        }
    }

    var title: String {
        switch self {
        case .collection(let list, _, _): list.title
        case .video(let session), .code(let session): session.title
        case .article(let item): item.title
        case .news(let item): item.title
        }
    }
}

/// Builds the short excerpt shown under a result, around the first match.
nonisolated enum SearchExcerpt {
    private static let transcriptSentences = 4
    private static let codeContextLines = 1
    private static let textExcerptLength = 280

    /// The words of a query, longest first, since the longest is the most distinctive to locate.
    static func words(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init).sorted { $0.count > $1.count }
    }

    static func matches(_ text: String, query: String) -> Bool {
        let words = words(in: query)
        return !words.isEmpty && words.allSatisfy { text.localizedStandardContains($0) }
    }

    /// The first sentence containing the query, followed by a few sentences of context.
    static func transcript(_ paragraphs: [TranscriptParagraph], query: String) -> String? {
        for word in words(in: query) {
            for paragraph in paragraphs {
                let sentences = paragraph.sentences
                guard let index = sentences.firstIndex(where: { $0.text.localizedStandardContains(word) }) else { continue }
                let end = min(index + transcriptSentences, sentences.count)
                return sentences[index..<end]
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: " ")
            }
        }
        return nil
    }

    /// The first matching line of code with a line of context on either side, dedented.
    static func code(_ samples: [CodeSample], query: String) -> String? {
        for word in words(in: query) {
            for sample in samples {
                let lines = sample.code.split(separator: "\n", omittingEmptySubsequences: false)
                guard let index = lines.firstIndex(where: { $0.localizedStandardContains(word) }) else { continue }
                let start = max(index - codeContextLines, 0)
                let end = min(index + codeContextLines + 1, lines.count)
                let context = lines[start..<end]
                let indent = context
                    .filter { !$0.allSatisfy(\.isWhitespace) }
                    .map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }
                    .min() ?? 0
                return context.map { $0.dropFirst(indent) }.joined(separator: "\n")
            }
        }
        return nil
    }

    /// Prose around the first match, starting at the beginning of its sentence.
    static func text(_ text: String, query: String) -> String? {
        for word in words(in: query) {
            guard let match = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            var start = text[..<match.lowerBound].lastIndex(where: { ".!?\n".contains($0) })
                .map { text.index(after: $0) } ?? text.startIndex
            let leadingContext = textExcerptLength / 3
            let prefix = text.distance(from: start, to: match.lowerBound) > leadingContext ? "…" : ""
            if !prefix.isEmpty {
                start = text.index(match.lowerBound, offsetBy: -leadingContext / 2)
            }
            let excerpt = text[start...].prefix(textExcerptLength)
            return prefix + excerpt.trimmingCharacters(in: .whitespacesAndNewlines).replacing("\n", with: " ")
        }
        return nil
    }
}
