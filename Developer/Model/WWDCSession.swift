//
//  WWDCSession.swift
//  Developer
//

import Foundation

/// A video collection on developer.apple.com, such as a WWDC year or Tech Talks.
nonisolated struct WWDCEvent: Identifiable, Hashable, Sendable {
    /// Path component on developer.apple.com, e.g. "wwdc2024" or "tech-talks".
    let id: String
    let name: String
    let systemImage: String

    static func wwdc(_ year: Int) -> WWDCEvent {
        WWDCEvent(id: "wwdc\(year)", name: "WWDC\(String(year).suffix(2))", systemImage: "lanyardcard.fill")
    }

    static let meetWithApple = WWDCEvent(id: "meet-with-apple", name: "Meet with Apple", systemImage: "lanyardcard.fill")
    static let techTalks = WWDCEvent(id: "tech-talks", name: "Tech Talks", systemImage: "rectangle.inset.filled.and.person.filled")

    /// Ongoing series (Tech Talks, Meet with Apple) are listed oldest-first on
    /// developer.apple.com, so the app reverses them to show the newest at the top.
    /// WWDC years keep the site's curated order (Keynote first).
    var showsNewestFirst: Bool {
        self == .techTalks || self == .meetWithApple
    }

    /// The earliest WWDC that still has videos on developer.apple.com.
    static let firstWWDCYear = 2014

    /// Looks up an event from its ID, e.g. "wwdc2024" or "tech-talks".
    static func event(withID id: String) -> WWDCEvent? {
        if let year = id.wholeMatch(of: /wwdc(\d{4})/).flatMap({ Int($0.1) }) {
            return wwdc(year)
        }
        return [meetWithApple, techTalks].first { $0.id == id }
    }

    /// Every event the app knows about, from the current year's WWDC back to the first.
    static func allEvents(through currentYear: Int) -> [WWDCEvent] {
        [.meetWithApple, .techTalks] + (firstWWDCYear...currentYear).reversed().map(wwdc)
    }
}

/// A single session video listed on developer.apple.com.
struct WWDCSession: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let eventID: String
    let sessionNumber: Int
    let title: String
    /// Topic names exactly as on developer.apple.com, e.g. ["Developer Tools", "Swift"].
    let topics: [String]
    let duration: String?
    let thumbnailURL: URL?
    let url: URL

    /// All topics joined for display and search, e.g. "Developer Tools, Swift".
    var topic: String? {
        topics.isEmpty ? nil : topics.joined(separator: ", ")
    }

    /// A larger version of the thumbnail for the player's poster frame.
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

/// Playback details scraped from a session's own page. These are fetched lazily
/// when a session is opened, because fetching 1K+ pages up front would be slow.
nonisolated struct WWDCSessionDetails: Codable, Sendable {
    /// HLS stream URL (preferred) or a direct MP4/MOV download as a fallback.
    let videoURL: URL?
    /// The HD MP4/MOV file, for saving offline. `nil` in details cached before
    /// downloads were supported, which makes the download refetch the page.
    var downloadURL: URL? = nil
    let summary: String?
    /// The session transcript. Empty when the session has none; `nil` only for
    /// details cached before transcripts were supported, which triggers a refetch.
    let transcript: [TranscriptParagraph]?
    /// Chapters and code samples, which newer sessions have. Like `transcript`,
    /// empty means none and `nil` means cached before support was added.
    var chapters: [SessionChapter]?
    var codeSamples: [CodeSample]?
    /// Links from the Resources section and videos from Related Videos. Like
    /// `transcript`, empty means none and `nil` means cached before support was added.
    var resources: [SessionResource]?
    var relatedVideos: [RelatedVideo]?
}

nonisolated struct TranscriptParagraph: Codable, Hashable, Sendable, Identifiable {
    struct Sentence: Codable, Hashable, Sendable {
        /// Offset into the video, in seconds, where this sentence starts.
        let start: Double
        let text: String
    }

    let sentences: [Sentence]

    var id: Double { start }
    var start: Double { sentences.first?.start ?? 0 }
}

nonisolated struct CodeSample: Codable, Hashable, Sendable, Identifiable {
    /// A run of code text with its syntax kind, e.g. "keyword", "type", "comment".
    /// `kind` is nil for plain text.
    struct Token: Codable, Hashable, Sendable {
        let text: String
        let kind: String?
    }

    /// Offset into the video, in seconds, where the code is discussed.
    let start: Double
    let title: String
    let tokens: [Token]

    var id: String { "\(start)-\(title)" }
    var code: String { tokens.map(\.text).joined() }
}

/// A chapter marker in a session video.
nonisolated struct SessionChapter: Codable, Hashable, Sendable, Identifiable {
    /// Offset into the video, in seconds.
    let start: Double
    let title: String

    var id: Double { start }
}

/// A link in a session's Resources section, e.g. documentation or slides.
nonisolated struct SessionResource: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        /// Documentation, articles, and other web pages.
        case document
        /// Downloadable files such as sample code projects or slides.
        case download
    }

    let title: String
    let url: URL
    let kind: Kind

    var id: URL { url }
}

/// A video listed under a session's Related Videos, identified by its event and
/// number so it can be matched to a loaded `WWDCSession`.
nonisolated struct RelatedVideo: Codable, Hashable, Sendable, Identifiable {
    let eventID: String
    let sessionNumber: Int
    let title: String

    var id: String { "\(eventID)-\(sessionNumber)" }
}
