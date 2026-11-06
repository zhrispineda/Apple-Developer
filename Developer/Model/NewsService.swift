//
//  NewsService.swift
//  Developer
//

import Foundation

nonisolated struct NewsService: Sendable {
    static let feedURL = URL(string: "https://developer.apple.com/news/rss/news.rss")!

    var session: URLSession = .shared

    @concurrent
    func fetchNews() async throws -> [NewsItem] {
        let (data, response) = try await session.data(from: Self.feedURL)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return Self.parseFeed(data)
    }

    static func parseFeed(_ data: Data) -> [NewsItem] {
        let delegate = RSSParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items.compactMap(makeItem)
    }

    private static func makeItem(from raw: RSSParserDelegate.RawItem) -> NewsItem? {
        guard let url = URL(string: raw.link.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let blocks = parseBlocks(fromHTML: raw.description)
        let summary = blocks.lazy.compactMap { block -> String? in
            if case .paragraph(let runs) = block {
                let text = runs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            }
            return nil
        }.first ?? ""
        let imageURL = blocks.lazy.compactMap { block -> URL? in
            if case .image(let url) = block { return url }
            return nil
        }.first

        return NewsItem(
            id: raw.guid.isEmpty ? url.absoluteString : raw.guid,
            title: raw.title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            date: pubDateFormatter.date(from: raw.pubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .distantPast,
            imageURL: imageURL,
            summary: summary,
            blocks: blocks
        )
    }

    private static let pubDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    static func parseBlocks(fromHTML html: String) -> [NewsBlock] {
        let pattern = /<img[^>]*?src="([^"]+)"|<h[1-6][^>]*>(.*?)<\/h[1-6]>|<li[^>]*>(.*?)<\/li>|<p[^>]*>(.*?)<\/p>|<hr\b/
            .dotMatchesNewlines()
            .ignoresCase()

        return html.matches(of: pattern).compactMap { match -> NewsBlock? in
            if let src = match.1 {
                return URL(string: decodeEntities(String(src))).map(NewsBlock.image)
            }
            if let heading = match.2 {
                let runs = parseRuns(String(heading))
                return runs.isEmpty ? nil : .heading(runs)
            }
            if let item = match.3 {
                let runs = parseRuns(String(item))
                return runs.isEmpty ? nil : .listItem(runs)
            }
            if let paragraph = match.4 {
                let runs = parseRuns(String(paragraph))
                return runs.isEmpty ? nil : .paragraph(runs)
            }
            return .divider
        }
    }

    static func parseRuns(_ html: String) -> [NewsRun] {
        var runs: [NewsRun] = []
        var link: URL?
        var boldDepth = 0, italicDepth = 0, codeDepth = 0
        var remaining = Substring(html)

        func append(_ raw: Substring) {
            let text = decodeEntities(String(raw))
                .replacing(/\s+/, with: " ")
            guard !text.isEmpty else { return }
            runs.append(NewsRun(text: text, link: link, isBold: boldDepth > 0, isItalic: italicDepth > 0, isCode: codeDepth > 0))
        }

        while let tag = remaining.firstMatch(of: /<(\/?)([a-zA-Z0-9]+)([^>]*)>/) {
            append(remaining[remaining.startIndex..<tag.range.lowerBound])
            let isClosing = !tag.1.isEmpty
            switch tag.2.lowercased() {
            case "a":
                if isClosing {
                    link = nil
                } else if let href = tag.3.firstMatch(of: /href="([^"]*)"/)?.1 {
                    link = URL(string: decodeEntities(String(href)), relativeTo: URL(string: "https://developer.apple.com"))?.absoluteURL
                }
            case "strong", "b": boldDepth = max(boldDepth + (isClosing ? -1 : 1), 0)
            case "em", "i", "cite": italicDepth = max(italicDepth + (isClosing ? -1 : 1), 0)
            case "code": codeDepth = max(codeDepth + (isClosing ? -1 : 1), 0)
            case "br": runs.append(NewsRun(text: "\n"))
            default: break
            }
            remaining = remaining[tag.range.upperBound...]
        }
        append(remaining)

        // Trim whitespace.
        if let first = runs.first { runs[0].text = String(first.text.drop { $0 == " " }) }
        if let last = runs.last { runs[runs.count - 1].text = String(last.text.reversed().drop { $0 == " " }.reversed()) }
        return runs.filter { !$0.text.isEmpty }
    }

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        let named: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
            "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "mdash": "—", "ndash": "–",
            "hellip": "…", "trade": "™", "reg": "®", "copy": "©",
        ]
        return string.replacing(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
            let entity = String(match.1)
            if entity.hasPrefix("#x"), let code = UInt32(entity.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
            if entity.hasPrefix("#"), let code = UInt32(entity.dropFirst()), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
            return named[entity] ?? String(match.0)
        }
    }
}

nonisolated private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    struct RawItem {
        var title = "", link = "", guid = "", description = "", pubDate = ""
    }

    private(set) var items: [RawItem] = []
    private var current: RawItem?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" { current = RawItem() }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard current != nil else { return }
        switch elementName {
        case "title": current?.title = text
        case "link": current?.link = text
        case "guid": current?.guid = text
        case "description": current?.description = text
        case "pubDate": current?.pubDate = text
        case "item":
            if let current { items.append(current) }
            current = nil
        default: break
        }
        text = ""
    }
}
