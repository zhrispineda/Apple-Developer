//
//  ContentItemGroup.swift
//  Developer
//

import Foundation

enum ContentEntry: Identifiable, Hashable {
    case video(WWDCSession)
    case article(ContentItem)

    var id: String {
        switch self {
        case .video(let session): session.id
        case .article(let item): item.id
        }
    }

    var title: String {
        switch self {
        case .video(let session): session.title
        case .article(let item): item.title
        }
    }

    var eventName: String {
        switch self {
        case .video(let session): session.eventName
        case .article(let item): item.eventName
        }
    }

    var thumbnailURL: URL? {
        switch self {
        case .video(let session): session.thumbnailURL
        case .article(let item): item.thumbnailURL
        }
    }

    var topics: [String] {
        switch self {
        case .video(let session): session.topics
        case .article(let item): item.topics
        }
    }

    var session: WWDCSession? {
        if case .video(let session) = self { session } else { nil }
    }

    var route: Route {
        switch self {
        case .video(let session): .session(session)
        case .article(let item): .article(item)
        }
    }
}

struct ContentItemGroup: Identifiable, Hashable {
    let id: String
    let title: String?
    let entries: [ContentEntry]

    init(id: String, title: String?, entries: [ContentEntry]) {
        self.id = id
        self.title = title
        self.entries = entries
    }

    init(sessions: [WWDCSession]) {
        self.init(id: "all", title: nil, entries: sessions.map(ContentEntry.video))
    }
}
