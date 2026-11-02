//
//  WWDCSession.swift
//  Developer
//

import Foundation

nonisolated struct WWDCEvent: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String

    static func wwdc(_ year: Int) -> WWDCEvent {
        WWDCEvent(id: "wwdc\(year)", name: "WWDC\(String(year).suffix(2))", systemImage: "lanyardcard.fill")
    }

    static let meetWithApple = WWDCEvent(id: "meet-with-apple", name: "Meet with Apple", systemImage: "lanyardcard.fill")
    static let techTalks = WWDCEvent(id: "tech-talks", name: "Tech Talks", systemImage: "rectangle.inset.filled.and.person.filled")

    var showsNewestFirst: Bool {
        self == .techTalks || self == .meetWithApple
    }

    static let firstWWDCYear = 2014
    static func event(withID id: String) -> WWDCEvent? {
        if let year = id.wholeMatch(of: /wwdc(\d{4})/).flatMap({ Int($0.1) }) {
            return wwdc(year)
        }
        return [meetWithApple, techTalks].first { $0.id == id }
    }

    static func allEvents(through currentYear: Int) -> [WWDCEvent] {
        [.meetWithApple, .techTalks] + (firstWWDCYear...currentYear).reversed().map(wwdc)
    }
}

struct WWDCSession: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let eventID: String
    let sessionNumber: Int
    let title: String
    let topics: [String]
    let duration: String?
    let thumbnailURL: URL?
    let url: URL

    var topic: String? {
        topics.isEmpty ? nil : topics.joined(separator: ", ")
    }

    var posterURL: URL? {
        guard let thumbnailURL else { return nil }
        let large = thumbnailURL.absoluteString.replacing("_250x141_2x", with: "_900x506_2x")
        return URL(string: large) ?? thumbnailURL
    }

    var eventName: String {
        WWDCEvent.event(withID: eventID)?.name ?? eventID
    }

    var durationSeconds: Double? {
        guard let parts = duration?.split(separator: ":").compactMap({ Double($0) }), !parts.isEmpty else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
}

nonisolated struct WWDCSessionDetails: Codable, Sendable {
    let videoURL: URL?
    var downloadURL: URL? = nil
    let summary: String?
    let transcript: [TranscriptParagraph]?
    var chapters: [SessionChapter]?
    var codeSamples: [CodeSample]?
    var resources: [SessionResource]?
    var relatedVideos: [RelatedVideo]?
}

nonisolated struct TranscriptParagraph: Codable, Hashable, Sendable, Identifiable {
    struct Sentence: Codable, Hashable, Sendable {
        let start: Double
        let text: String
    }

    let sentences: [Sentence]

    var id: Double { start }
    var start: Double { sentences.first?.start ?? 0 }
}

nonisolated struct CodeSample: Codable, Hashable, Sendable, Identifiable {
    struct Token: Codable, Hashable, Sendable {
        let text: String
        let kind: String?
    }

    let start: Double
    let title: String
    let tokens: [Token]

    var id: String { "\(start)-\(title)" }
    var code: String { tokens.map(\.text).joined() }
}

nonisolated struct SessionChapter: Codable, Hashable, Sendable, Identifiable {
    let start: Double
    let title: String

    var id: Double { start }
}

nonisolated struct SessionResource: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case document
        case download
    }

    let title: String
    let url: URL
    let kind: Kind

    var id: URL { url }
}

nonisolated struct RelatedVideo: Codable, Hashable, Sendable, Identifiable {
    let eventID: String
    let sessionNumber: Int
    let title: String

    var id: String { "\(eventID)-\(sessionNumber)" }
}
