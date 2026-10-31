//
//  NewsItem.swift
//  Developer
//

import Foundation

/// A Developer News article from https://developer.apple.com/news/.
struct NewsItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let url: URL
    let date: Date
    /// The article's first image, used as its thumbnail and header.
    let imageURL: URL?
    /// The first paragraph as plain text, shown in the list.
    let summary: String
    let blocks: [NewsBlock]

    // Identity is the article ID.
    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One block of an article body.
enum NewsBlock: Codable, Sendable {
    case image(URL)
    case heading([NewsRun])
    case paragraph([NewsRun])
    case listItem([NewsRun])
    case divider
}

/// A run of inline text with its styling.
struct NewsRun: Codable, Sendable {
    var text: String
    var link: URL?
    var isBold = false
    var isItalic = false
    var isCode = false
}
