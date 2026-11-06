//
//  FeedFetcher.swift
//  Developer
//

import Foundation

nonisolated struct FeedFetcher: Sendable {
    static let feedBaseURL = URL(string: "https://devimages-cdn.apple.com/wwdc-services/w9f43630/73A40F02-6975-439F-BA6E-F5C834BFEAC5")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        return URLSession(configuration: configuration)
    }()

    @concurrent
    func fetchFeed(updating cached: DiscoverFeed?) async throws -> DiscoverFeed {
        let cached = cached?.formatVersion == DiscoverFeed.currentFormatVersion ? cached : nil
        async let contents = Self.fetch("contents.json", etag: cached?.contentsETag)
        async let page = Self.fetch("articles.json", etag: cached?.pageETag)
        let (contentsResult, pageResult) = try await (contents, page)

        var feed = cached ?? DiscoverFeed(items: [], sections: [], fetchedAt: .now)
        if let data = contentsResult.data {
            (feed.items, feed.resources, feed.ascendingEventIDs) = try Self.parseContents(data)
            feed.contentsETag = contentsResult.etag
        }
        if let data = pageResult.data {
            (feed.sections, feed.wwdcSections) = try Self.parseRootPages(data)
            feed.pages = try Self.parseArticles(data)
            feed.pageETag = pageResult.etag
        }
        feed.formatVersion = DiscoverFeed.currentFormatVersion
        feed.fetchedAt = .now
        return feed
    }

    @concurrent
    func fetchLiveVideos() async throws -> LiveVideosFeed {
        guard let data = try await Self.fetch("videos_live.json", etag: nil).data else { return LiveVideosFeed() }
        return try Self.parseLiveVideos(data)
    }

    private static func fetch(_ file: String, etag: String?) async throws -> (data: Data?, etag: String?) {
        var request = URLRequest(url: feedBaseURL.appending(path: file))
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        switch http?.statusCode {
        case 304: return (nil, etag)
        case 200, nil: return (data, http?.value(forHTTPHeaderField: "ETag"))
        default: throw URLError(.badServerResponse)
        }
    }

    // MARK: Parsing

    private struct RawContents: Decodable {
        struct Event: Decodable {
            let id: String
            let name: String
            let imagesPath: String?
            let sortOrder: String?
        }
        
        struct Topic: Decodable {
            let id: Int
            let title: String
        }
        
        struct Content: Decodable {
            struct Media: Decodable {
                let hls: URL?
                let duration: Double?
            }
            
            let id: String
            let eventId: String
            let eventContentId: Int
            let staticContentId: Int
            let webPermalink: URL
            let title: String
            let description: String?
            let type: String
            let startTime: String?
            let endTime: String?
            let originalPublishingDate: String?
            let topicIds: [Int]?
            let images: [String]?
            let media: Media?
            let hasLiveStream: Bool?
            let articleID: String?
        }
        
        struct Resource: Decodable {
            let id: Int
            let title: String
            let url: URL
            let resource_type: String?
            let description: String?
        }
        
        let events: [Event]
        let topics: [Topic]
        let contents: [Content]
        let resources: [Resource]?
    }

    static func parseContents(_ data: Data) throws -> (items: [ContentItem], resources: [Int: ContentResource], ascendingEventIDs: Set<String>) {
        let raw = try JSONDecoder().decode(RawContents.self, from: data)
        let resources = Dictionary(
            (raw.resources ?? []).map {
                ($0.id, ContentResource(id: $0.id, title: $0.title, url: $0.url, type: $0.resource_type ?? "", summary: $0.description))
            },
            uniquingKeysWith: { first, _ in first }
        )
        let events = Dictionary(raw.events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let topics = Dictionary(raw.topics.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })

        let items = raw.contents.map { content in
            let event = events[content.eventId]
            func image(_ type: String, _ size: String) -> URL? {
                guard let path = event?.imagesPath, content.images?.contains(type) == true else { return nil }
                let id = content.staticContentId
                return URL(string: "\(path)/\(id)/\(id)_\(type)_\(size)_2x.jpg")
            }
            return ContentItem(
                id: content.id,
                eventID: content.eventId,
                eventName: event?.name ?? content.eventId,
                number: content.eventContentId,
                type: content.type,
                title: content.title,
                summary: content.description ?? "",
                webURL: content.webPermalink,
                startTime: parseDate(content.startTime),
                endTime: parseDate(content.endTime),
                publishedAt: parseDate(content.originalPublishingDate),
                duration: content.media?.duration,
                videoURL: content.media?.hls,
                hasLiveStream: content.hasLiveStream ?? false,
                topics: (content.topicIds ?? []).compactMap { topics[$0] },
                thumbnailURL: image("wide", "250x141"),
                cardImageURL: image("wide", "466x262"),
                posterURL: image("wide", "900x506"),
                squareImageURL: image("square", "162x162"),
                articleID: content.articleID
            )
        }
        let ascendingEventIDs = Set(raw.events.filter { $0.sortOrder?.hasSuffix("Ascending") == true }.map(\.id))
        return (items, resources, ascendingEventIDs)
    }

    private struct RawArticles: Decodable {
        struct ImageStore: Decodable {
            let path: String
        }
        
        struct Page: Decodable {
            struct Localization: Decodable {
                let sections: [Section]
            }
            
            struct Section: Decodable {
                let id: String
                let title: String?
                let layoutStyle: String?
                let components: [Component]?
            }
            
            let localizations: [String: Localization]
        }
        
        struct Component: Decodable {
            struct Ultrahero: Decodable {
                struct Image: Decodable {
                    let id: String
                    let aspectRatio: Double?
                }
                
                let image: Image?
                let eyebrowText: String?
                let titleText: String?
                let bodyText: String?
                let contentItemID: String?
            }

            struct Banner: Decodable {
                let header: String?
                let body: String?
                let image: Ultrahero.Image?
                let activityID: String?
            }
            
            struct ItemList: Decodable {
                struct Filter: Decodable {
                    let itemTypes: [String]?
                    let projectIDs: [String]?
                    let options: Int?
                }
                
                struct SummaryContent: Decodable {
                    struct Predefined: Decodable {
                        let itemIDs: [String]
                    }
                    let predefined: Predefined?
                }
                
                let title: String
                let filter: Filter?
                let summaryLayout: String?
                let summaryContent: SummaryContent?
                let summaryAlwaysShowsSeeAllButton: Bool?
            }
            
            let id: String
            let type: String
            let ultrahero: Ultrahero?
            let itemList: ItemList?
            let banner: Banner?
        }

        let imageStore: ImageStore
        let discoverTabRoot: Page
        /// The WWDC tab.
        let eventTabRoot: Page?
    }

    private static let liveNowFilterOption = 16

    static func parseRootPages(_ data: Data) throws -> (discover: [DiscoverSection], wwdc: [DiscoverSection]) {
        let raw = try JSONDecoder().decode(RawArticles.self, from: data)
        return (
            sections(of: raw.discoverTabRoot, imageStore: raw.imageStore.path),
            raw.eventTabRoot.map { sections(of: $0, imageStore: raw.imageStore.path) } ?? []
        )
    }

    private static func sections(of root: RawArticles.Page, imageStore: String) -> [DiscoverSection] {
        guard let page = root.localizations["eng"] ?? root.localizations.values.first else { return [] }

        return page.sections.flatMap { section -> [DiscoverSection] in
            let components = section.components ?? []
            let banners = components.compactMap { component -> DiscoverBanner? in
                guard component.type == "banner", let banner = component.banner, let header = banner.header else { return nil }
                return DiscoverBanner(
                    id: component.id,
                    header: cleanText(header),
                    body: cleanText(banner.body ?? ""),
                    imageURL: banner.image.flatMap { URL(string: "\(imageStore)/\($0.id)/256.jpeg") },
                    itemID: banner.activityID
                )
            }
            let others = components.compactMap { discoverSection(for: $0, imageStore: imageStore) }
            guard !banners.isEmpty else { return others }
            let group = DiscoverBannerGroup(
                id: section.id,
                title: section.title.map(cleanText),
                layout: section.layoutStyle == "grid" ? .grid : .stack,
                banners: banners
            )
            return [.banners(group)] + others
        }
    }

    private static func discoverSection(for component: RawArticles.Component, imageStore: String) -> DiscoverSection? {
        switch component.type {
        case "ultrahero":
            guard let hero = component.ultrahero, let title = hero.titleText else { return nil }
            return .hero(DiscoverHero(
                title: cleanText(title),
                body: cleanText(hero.bodyText ?? ""),
                imageURL: hero.image.flatMap { URL(string: "\(imageStore)/\($0.id)/2048.jpeg") },
                aspectRatio: hero.image?.aspectRatio ?? 16 / 9,
                itemID: hero.contentItemID,
                eyebrow: hero.eyebrowText.map(cleanText)
            ))
        case "itemList":
            guard let list = component.itemList else { return nil }
            return .itemList(DiscoverItemList(
                id: component.id,
                title: list.title,
                layout: list.summaryLayout == "wideCard" ? .wideCard : .card,
                itemTypes: list.filter?.itemTypes,
                eventIDs: list.filter?.projectIDs,
                liveOnly: (list.filter?.options ?? 0) & liveNowFilterOption != 0,
                itemIDs: list.summaryContent?.predefined?.itemIDs,
                showsSeeAll: list.summaryAlwaysShowsSeeAllButton ?? false
            ))
        default:
            return nil
        }
    }

    static func parseArticles(_ data: Data) throws -> [String: ContentPage] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let articles = root["articles"] as? [[String: Any]]
        else { return [:] }
        let imageStore = (root["imageStore"] as? [String: Any])?["path"] as? String ?? ""

        var pages: [String: ContentPage] = [:]
        for article in articles {
            guard let id = article["id"] as? String,
                  let localizations = article["localizations"] as? [String: Any],
                  let page = (localizations["eng"] ?? localizations.values.first) as? [String: Any]
            else { continue }

            let rawComponents: [[String: Any]]
            if let sections = page["sections"] as? [[String: Any]] {
                rawComponents = sections.flatMap { $0["components"] as? [[String: Any]] ?? [] }
            } else if let detail = page["detailComponents"] as? [[String: Any]] {
                rawComponents = detail
            } else {
                rawComponents = flattenedComponents(page["rootColumn"] ?? [])
            }
            let components = rawComponents.compactMap { component($0, imageStore: imageStore) }
            pages[id] = ContentPage(id: id, components: components)
        }
        return pages
    }

    private static func flattenedComponents(_ node: Any) -> [[String: Any]] {
        if let array = node as? [Any] { return array.flatMap(flattenedComponents) }
        guard let dict = node as? [String: Any] else { return [] }
        if let component = dict["component"] as? [String: Any] { return [component] }
        if let row = dict["row"] { return flattenedComponents(row) }
        return flattenedComponents(dict["items"] ?? dict["columns"] ?? [])
    }

    private static func component(_ raw: [String: Any], imageStore: String) -> ContentPageComponent? {
        guard let id = raw["id"] as? String, let type = raw["type"] as? String else { return nil }
        func media(_ value: Any?) -> MediaResource? {
            guard var dict = value as? [String: Any] else { return nil }
            if let nested = dict["mediaResource"] as? [String: Any] { dict = nested }
            guard let imageID = dict["id"] as? String, dict["isPlaceholder"] as? Bool != true,
                  let baseURL = URL(string: "\(imageStore)/\(imageID)")
            else { return nil }
            return MediaResource(
                baseURL: baseURL,
                aspectRatio: dict["aspectRatio"] as? Double ?? 16 / 9,
                caption: cleanText(dict["caption"] as? String ?? ""),
                accessibilityDescription: dict["mediaDescription"] as? String
            )
        }
        
        let value = raw[type]

        let kind: ContentPageComponent.Kind?
        
        switch type {
        case "category":
            let category = value as? [String: Any]
            kind = (category?["text"] as? String).map {
                .category(text: $0, lightColor: category?["lightColor"] as? String, darkColor: category?["darkColor"] as? String)
            }
        case "title":
            kind = (value as? String).map { .title(cleanText($0)) }
        case "date":
            kind = parseDate(value as? String).map { .date($0) }
        case "header":
            kind = (value as? String).map { .header(cleanText($0)) }
        case "text":
            kind = (value as? String).map { .text(cleanText($0), textStyle(raw["modifiers"])) }
        case "image":
            kind = media(value).map { .image($0) }
        case "gallery":
            let images = (value as? [Any] ?? []).compactMap(media)
            kind = images.isEmpty ? nil : .gallery(images)
        case "separator":
            kind = .separator
        case "fixedSpacer":
            kind = (value as? Double).map { .spacer($0) }
        case "pullQuote":
            let quote = value as? [String: Any]
            kind = (quote?["quote"] as? String).map {
                .pullQuote(quote: cleanText($0), author: (quote?["author"] as? String).map(cleanText))
            }
        case "urlButton":
            let button = value as? [String: Any]
            if let title = button?["title"] as? String, let url = (button?["url"] as? String).flatMap(URL.init(string:)) {
                kind = .button(title: cleanText(title), url: url)
            } else {
                kind = nil
            }
        case "button":
            let button = value as? [String: Any]
            let reference = button?["contentReference"] as? [String: Any]
            let label = flattenedComponents(button?["rootColumn"] ?? [])
                .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined(separator: " ")
            if let url = (reference?["url"] as? String).flatMap(URL.init(string:)), !label.isEmpty {
                kind = .button(title: cleanText(label), url: url)
            } else {
                kind = nil
            }
        case "card":
            let card = value as? [String: Any]
            let button = card?["button"] as? [String: Any]
            kind = (card?["title"] as? String).map {
                .card(
                    title: cleanText($0),
                    body: cleanText(card?["body"] as? String ?? ""),
                    buttonTitle: button?["title"] as? String,
                    url: (button?["url"] as? String).flatMap(URL.init(string:))
                )
            }
        case "activity":
            kind = (value as? String).map { .contentItem($0) }
        case "itemList":
            let list = value as? [String: Any]
            let ids = ((list?["summaryContent"] as? [String: Any])?["predefined"] as? [String: Any])?["itemIDs"] as? [String]
            if let ids, !ids.isEmpty {
                kind = .itemList(title: cleanText(list?["title"] as? String ?? ""), itemIDs: ids)
            } else {
                kind = nil
            }
        case "resource":
            kind = (value as? Int).map { .resource($0) }
        case "codeSnippet":
            let snippet = value as? [String: Any]
            let tokens = (snippet?["html"] as? String).map(WWDCVideoService.highlightTokens(from:))
                ?? (snippet?["code"] as? String).map { [CodeSample.Token(text: $0, kind: nil)] }
            kind = tokens.map { .codeSnippet(CodeSample(start: 0, title: "", tokens: $0)) }
        case "ultrahero":
            let hero = value as? [String: Any]
            kind = (hero?["titleText"] as? String).map {
                .ultrahero(
                    eyebrow: hero?["eyebrowText"] as? String,
                    title: cleanText($0),
                    body: cleanText(hero?["bodyText"] as? String ?? ""),
                    image: media(hero?["image"])
                )
            }
        default:
            kind = nil
        }
        return kind.map { ContentPageComponent(id: id, kind: $0) }
    }

    private static func textStyle(_ value: Any?) -> TextStyle? {
        guard let modifiers = value as? [String: Any] else { return nil }
        let font = modifiers["font"] as? [String: Any]
        let size = font?["size"] as? [String: Any]
        let custom = (modifiers["color"] as? [String: Any])?["custom"] as? [String: Any]
        let style = TextStyle(
            textStyle: modifiers["textStyle"] as? String
                ?? (size?["dynamic"] as? [String: Any])?["textStyle"] as? String,
            pointSize: (size?["fixed"] as? [String: Any])?["pointSize"] as? Double,
            weight: modifiers["weight"] as? String ?? font?["weight"] as? String,
            color: custom?["system"] as? String ?? custom?["lightColor"] as? String
        )
        return style == TextStyle() ? nil : style
    }

    private struct RawLiveVideos: Decodable {
        struct Stream: Decodable {
            let streamURL: URL
        }
        let liveSessions: [String: Stream]?
    }

    static func parseLiveVideos(_ data: Data) throws -> LiveVideosFeed {
        let raw = try JSONDecoder().decode(RawLiveVideos.self, from: data)
        return LiveVideosFeed(streams: (raw.liveSessions ?? [:]).mapValues(\.streamURL))
    }

    private static func parseDate(_ string: String?) -> Date? {
        string.flatMap { try? Date($0, strategy: .iso8601) }
    }

    private static func cleanText(_ text: String) -> String {
        text.replacing("&nbsp;", with: "\u{00A0}")
            .replacing("&amp;", with: "&")
            .replacing("&rsquo;", with: "’")
    }
}
