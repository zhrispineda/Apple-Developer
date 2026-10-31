//
//  ContentPage.swift
//  Developer
//

import Foundation

nonisolated struct ContentPage: Codable, Hashable, Sendable {
    let id: String
    let components: [ContentPageComponent]
}

nonisolated struct ContentPageComponent: Codable, Hashable, Sendable, Identifiable {
    enum Kind: Codable, Hashable, Sendable {
        /// The colored eyebrow above the title, e.g. "NEWS AND UPDATES".
        case category(text: String, lightColor: String?, darkColor: String?)
        case title(String)
        case date(Date)
        case header(String)
        case text(String, TextStyle?)
        case image(MediaResource)
        case gallery([MediaResource])
        case separator
        case spacer(Double)
        case pullQuote(quote: String, author: String?)
        case button(title: String, url: URL)
        case card(title: String, body: String, buttonTitle: String?, url: URL?)
        case contentItem(String)
        case itemList(title: String, itemIDs: [String])
        case resource(Int)
        case codeSnippet(CodeSample)
        case ultrahero(eyebrow: String?, title: String, body: String, image: MediaResource?)
    }

    let id: String
    let kind: Kind
}

nonisolated struct MediaResource: Codable, Hashable, Sendable {
    let baseURL: URL
    let aspectRatio: Double
    let caption: String
    let accessibilityDescription: String?

    func url(width: Int = 2048) -> URL {
        baseURL.appending(path: "\(width).jpeg")
    }
}

nonisolated struct TextStyle: Codable, Hashable, Sendable {
    var textStyle: String?
    var pointSize: Double?
    var weight: String?
    var color: String?
}

/// A documentation page, sample code project, or other link from the content feed.
nonisolated struct ContentResource: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    /// "documentation", "samplecode", "guide", "download", or "developerForum".
    let type: String
    let summary: String?
}

