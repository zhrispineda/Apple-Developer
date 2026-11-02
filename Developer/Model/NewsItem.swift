//
//  NewsItem.swift
//  Developer
//

import Foundation

struct NewsItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let url: URL
    let date: Date
    let imageURL: URL?
    let summary: String
    let blocks: [NewsBlock]

    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum NewsBlock: Codable, Sendable {
    case image(URL)
    case heading([NewsRun])
    case paragraph([NewsRun])
    case listItem([NewsRun])
    case divider
}

struct NewsRun: Codable, Sendable {
    var text: String
    var link: URL?
    var isBold = false
    var isItalic = false
    var isCode = false
}
