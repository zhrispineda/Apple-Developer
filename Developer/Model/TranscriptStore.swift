//
//  TranscriptStore.swift
//  Developer
//

import Foundation

/// Keeps a local copy of every video transcript so search can index them.
///
/// Mirrors the feed's own scheme: `transcript-manifest-eng.json` lists an ETag per transcript
/// plus a digest of all of them. The first sync (or one with many changes) downloads the digest
/// in a single request; later syncs only fetch the transcripts whose ETag changed.
actor TranscriptStore {
    static let shared = TranscriptStore()

    nonisolated private struct RemoteManifest: Decodable {
        struct Entry: Decodable {
            let etag: String
            let url: URL
        }

        let digest: Entry
        let individual: [String: Entry]
    }

    nonisolated private struct LocalManifest: Codable {
        var manifestETag: String?
        /// Transcript ETags by session ID, for the transcripts saved on disk.
        var etags: [String: String] = [:]
    }

    private static let manifestURL = FeedFetcher.feedBaseURL.appending(path: "transcript-manifest-eng.json")
    /// Above this many changed transcripts, one digest download beats individual requests.
    private static let digestThreshold = 40

    private let directory = URL.applicationSupportDirectory.appending(path: "Transcripts", directoryHint: .isDirectory)
    private var manifestFile: URL { directory.appending(path: "manifest.json") }
    private lazy var local: LocalManifest = {
        guard let data = try? Data(contentsOf: manifestFile) else { return LocalManifest() }
        return (try? JSONDecoder().decode(LocalManifest.self, from: data)) ?? LocalManifest()
    }()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    /// Transcript ETags by session ID, for every transcript saved locally.
    var etags: [String: String] { local.etags }

    func paragraphs(for sessionID: String) -> [TranscriptParagraph]? {
        guard let data = try? Data(contentsOf: file(for: sessionID)) else { return nil }
        return try? JSONDecoder().decode([TranscriptParagraph].self, from: data)
    }

    /// Brings the local transcripts up to date with the feed.
    /// - Returns: The IDs of transcripts that were added, changed, or removed.
    @discardableResult
    func refresh() async throws -> Set<String> {
        var request = URLRequest(url: Self.manifestURL)
        if let etag = local.manifestETag, !local.etags.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        if http?.statusCode == 304 { return [] }
        guard http?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let remote = try JSONDecoder().decode(RemoteManifest.self, from: data)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let changed = remote.individual.filter { local.etags[$0.key] != $0.value.etag }
        let removed = Set(local.etags.keys).subtracting(remote.individual.keys)

        if changed.count > Self.digestThreshold {
            let (digestData, _) = try await session.data(from: remote.digest.url)
            let transcripts = try JSONDecoder().decode([String: WWDCVideoService.FeedTranscript].self, from: digestData)
            for (id, entry) in changed {
                guard let transcript = transcripts[id] else { continue }
                save(WWDCVideoService.paragraphs(from: transcript.transcript), for: id, etag: entry.etag)
            }
        } else {
            for (id, entry) in changed {
                do {
                    let (data, _) = try await session.data(from: entry.url)
                    let transcripts = try JSONDecoder().decode([String: WWDCVideoService.FeedTranscript].self, from: data)
                    guard let transcript = transcripts[id] else { continue }
                    save(WWDCVideoService.paragraphs(from: transcript.transcript), for: id, etag: entry.etag)
                } catch {
                    print("Failed to download transcript \(id): \(error)")
                }
            }
        }

        for id in removed {
            try? FileManager.default.removeItem(at: file(for: id))
            local.etags[id] = nil
        }

        local.manifestETag = http?.value(forHTTPHeaderField: "ETag")
        saveManifest()
        print("Synced transcripts: \(changed.count) updated (\(changed.count > Self.digestThreshold ? "digest" : "individually")), \(removed.count) removed.")
        return Set(changed.keys).union(removed)
    }

    // MARK: Files

    private func file(for sessionID: String) -> URL {
        directory.appending(path: "\(sessionID).json")
    }

    private func save(_ paragraphs: [TranscriptParagraph], for sessionID: String, etag: String) {
        do {
            try JSONEncoder().encode(paragraphs).write(to: file(for: sessionID), options: .atomic)
            local.etags[sessionID] = etag
        } catch {
            print("Failed to save transcript \(sessionID): \(error)")
        }
    }

    private func saveManifest() {
        do {
            try JSONEncoder().encode(local).write(to: manifestFile, options: .atomic)
        } catch {
            print("Failed to save transcript manifest: \(error)")
        }
    }
}
