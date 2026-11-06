//
//  WWDCVideoService.swift
//  Developer
//

import Foundation

nonisolated struct WWDCVideoService: Sendable {
    enum ServiceError: LocalizedError {
        case noSessionsFound

        var errorDescription: String? {
            "No WWDC sessions could be found on developer.apple.com."
        }
    }

    static let baseURL = URL(string: "https://developer.apple.com")!

    var session: URLSession = .shared

    func fetchAllSessions(fallback: [WWDCSession] = []) async throws -> [WWDCSession] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let events = WWDCEvent.allEvents(through: currentYear)
        let fallbackByEvent = Dictionary(grouping: fallback, by: \.eventID)

        let sessions = await withTaskGroup(of: [WWDCSession].self) { group in
            for event in events {
                group.addTask {
                    do {
                        return try await fetchSessions(for: event)
                    } catch {
                        return fallbackByEvent[event.id, default: []]
                    }
                }
            }
            return await group.reduce(into: []) { $0 += $1 }
        }

        guard !sessions.isEmpty else { throw ServiceError.noSessionsFound }
        return sessions
    }

    @concurrent
    func fetchDetails(for wwdcSession: WWDCSession) async throws -> WWDCSessionDetails {
        let (data, response) = try await session.data(from: wwdcSession.url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return Self.parseDetails(from: String(decoding: data, as: UTF8.self))
    }
    
    static func parseDetails(from html: String) -> WWDCSessionDetails {
        let hls = html.firstMatch(of: /https:\/\/(?:devstreaming-cdn|events-delivery)\.apple\.com\/[^"'\s]+\.m3u8/)
        let download = html.firstMatch(of: /https:\/\/devstreaming-cdn\.apple\.com\/[^"'\s?]+_hd[^"'\s?]*\.(?:mp4|mov)/)
        let videoURL = (hls ?? download).flatMap { URL(string: String($0.0)) }
        let downloadURL = download.flatMap { URL(string: String($0.0)) }

        let summary = html.firstMatch(of: /data-supplement-id="details".*?<p>(.*?)<\/p>/.dotMatchesNewlines())
            .map { decodeEntities(String($0.1)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        return WWDCSessionDetails(
            videoURL: videoURL,
            downloadURL: downloadURL,
            summary: summary,
            transcript: parseTranscript(from: html),
            chapters: parseChapters(from: html),
            codeSamples: parseCodeSamples(from: html),
            resources: parseResources(from: html),
            relatedVideos: parseRelatedVideos(from: html)
        )
    }

    private static func detailsSection(after heading: String, in html: String) -> Substring? {
        guard let start = html.range(of: heading) else { return nil }
        let rest = html[start.upperBound...]
        let ends = ["<h2>", #"data-supplement-id="transcript""#].compactMap { rest.range(of: $0)?.lowerBound }
        return rest[..<(ends.min() ?? rest.endIndex)]
    }

    static func parseResources(from html: String) -> [SessionResource] {
        guard let section = detailsSection(after: "<h2>Resources</h2>", in: html) else { return [] }
        return section.matches(of: /<li class="([a-z-]+)"><a href="([^"]+)"[^>]*>([^<]*)<\/a>/).compactMap { match in
            let title = decodeEntities(String(match.3)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty,
                  let url = URL(string: decodeEntities(String(match.2)), relativeTo: baseURL)?.absoluteURL
            else { return nil }
            let kind = SessionResource.Kind(rawValue: String(match.1)) ?? .document
            return SessionResource(title: title, url: url, kind: kind)
        }
    }

    static func parseRelatedVideos(from html: String) -> [RelatedVideo] {
        guard let section = detailsSection(after: "<h2>Related Videos</h2>", in: html) else { return [] }
        var seen = Set<String>()
        return section.matches(of: /<a href="\/videos\/play\/([a-z0-9-]+)\/(\d+)\/?"[^>]*>([^<]*)<\/a>/).compactMap { match in
            guard let number = Int(match.2) else { return nil }
            let video = RelatedVideo(
                eventID: String(match.1),
                sessionNumber: number,
                title: decodeEntities(String(match.3)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return seen.insert(video.id).inserted ? video : nil
        }
    }

    static func parseChapters(from html: String) -> [SessionChapter] {
        html.matches(of: /<li class="chapter-item" data-start-time="([\d.]+)">[^<]*<a[^>]*>([^<]*)<\/a>/)
            .compactMap { match in
                guard let start = Double(match.1) else { return nil }
                let title = decodeEntities(String(match.2)).trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? nil : SessionChapter(start: start, title: title)
            }
    }
    
    static func parseCodeSamples(from html: String) -> [CodeSample] {
        html.split(separator: #"<li class="sample-code-main-container">"#).dropFirst().compactMap { chunk in
            guard let header = chunk.firstMatch(of: /data-start-time="([\d.]+)">([^<]*)<\/a>/),
                  let start = Double(header.1),
                  let code = chunk.firstMatch(of: /<pre class="code-source"><code>(.*?)<\/code><\/pre>/.dotMatchesNewlines())
            else { return nil }
            let title = decodeEntities(String(header.2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return CodeSample(start: start, title: title, tokens: highlightTokens(from: String(code.1)))
        }
    }

    static func highlightTokens(from html: String) -> [CodeSample.Token] {
        var tokens: [CodeSample.Token] = []
        var kindStack: [String?] = []
        var remaining = Substring(html)

        func append(_ text: Substring) {
            guard !text.isEmpty else { return }
            let decoded = decodeEntities(String(text))
            let kind = kindStack.last ?? nil
            // Merge with the previous run when the kind matches, to keep token count low.
            if let last = tokens.last, last.kind == kind {
                tokens[tokens.count - 1] = CodeSample.Token(text: last.text + decoded, kind: kind)
            } else {
                tokens.append(CodeSample.Token(text: decoded, kind: kind))
            }
        }

        while let tag = remaining.firstMatch(of: /<span class="([^"]*)">|<\/span>|<[^>]+>/) {
            append(remaining[remaining.startIndex..<tag.range.lowerBound])
            if let classes = tag.1 {
                kindStack.append(syntaxKind(fromClasses: String(classes)))
            } else if tag.0 == "</span>" {
                _ = kindStack.popLast()
            }
            remaining = remaining[tag.range.upperBound...]
        }
        append(remaining)
        return tokens
    }

    private static func syntaxKind(fromClasses classes: String) -> String? {
        if classes.contains("class_") { return "class" }
        if classes.contains("function_") { return "function" }
        return classes.split(separator: " ")
            .first { $0.hasPrefix("syntax-") }
            .map { String($0.dropFirst("syntax-".count)) }
    }

    static func parseTranscript(from html: String) -> [TranscriptParagraph] {
        guard let start = html.range(of: #"<section id="transcript-content">"#),
              let end = html.range(of: "</section>", range: start.upperBound..<html.endIndex)
        else { return [] }

        return html[start.upperBound..<end.lowerBound]
            .split(separator: "</p><p>")
            .compactMap { chunk -> TranscriptParagraph? in
                let sentences = chunk.matches(of: /data-start="([\d.]+)">([^<]*)/).compactMap { match -> TranscriptParagraph.Sentence? in
                    let text = decodeEntities(String(match.2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let seconds = Double(match.1), !text.isEmpty else { return nil }
                    return TranscriptParagraph.Sentence(start: seconds, text: text)
                }
                return sentences.isEmpty ? nil : TranscriptParagraph(sentences: sentences)
            }
    }

    func fetchSessions(for event: WWDCEvent) async throws -> [WWDCSession] {
        let pageURL = Self.baseURL.appending(path: "videos/\(event.id)/")
        let (data, response) = try await session.data(from: pageURL)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let html = String(decoding: data, as: UTF8.self)
        return Self.parseSessions(from: html, eventID: event.id)
    }

    static func parseSessions(from html: String, eventID: String) -> [WWDCSession] {
        let cardPattern = /<a href="(\/videos\/play\/([a-z0-9-]+)\/(\d+)\/)" class="vc-card[^"]*"[^>]*>(.*?)<\/a>/
            .dotMatchesNewlines()

        var seen = Set<String>()
        var sessions: [WWDCSession] = []

        for match in html.matches(of: cardPattern) {
            // Listing pages can link to other events' videos; keep only this event's.
            guard match.2 == eventID,
                  let number = Int(match.3),
                  let url = URL(string: String(match.1), relativeTo: baseURL)?.absoluteURL
            else { continue }

            let id = "\(eventID)-\(number)"
            guard seen.insert(id).inserted else { continue }

            let body = match.4
            guard let rawTitle = body.firstMatch(of: /<h5 class="vc-card__title">(.*?)<\/h5>/)?.1 else { continue }

            let thumbnail = body.firstMatch(of: /class="vc-card__image"[^>]*src="([^"]+)"/)
                .flatMap { URL(string: String($0.1)) }
            let duration = body.firstMatch(of: /<span class="vc-card__duration">([^<]+)<\/span>/)
                .map { String($0.1).trimmingCharacters(in: .whitespaces) }
            // Topics are pipe-separated, e.g. "Developer Tools|Swift".
            let topics = body.firstMatch(of: /data-filter-topics="([^"]*)"/)
                .map { decodeEntities(String($0.1)).split(separator: "|").map(String.init) } ?? []

            sessions.append(WWDCSession(
                id: id,
                eventID: eventID,
                sessionNumber: number,
                title: decodeEntities(String(rawTitle)).trimmingCharacters(in: .whitespacesAndNewlines),
                topics: topics,
                duration: duration,
                thumbnailURL: thumbnail,
                url: url
            ))
        }
        return sessions
    }

    private static func decodeEntities(_ string: String) -> String {
        string
            .replacing("&nbsp;", with: " ")
            .replacing("&quot;", with: "\"")
            .replacing("&#039;", with: "'")
            .replacing("&#39;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }
}
