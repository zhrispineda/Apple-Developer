//
//  DeveloperTests.swift
//  DeveloperTests
//

import Foundation
import Testing
@testable import Developer

/// Verifies that watch progress and bookmarks for the entire video catalog fit
/// within the iCloud key-value store's limits, so sync can't silently break.
@MainActor
@Suite("iCloud key-value store capacity")
struct CloudStorageCapacityTests {

    @Test("Marking every video as watched stays within iCloud limits")
    func markingEveryVideoWatched() async throws {
        let catalog = try await Catalog.sessions()
        let cloud = QuotaEnforcingKeyValueStore()
        let store = WatchProgressStore(defaults: .ephemeral(), cloud: cloud)

        for session in catalog {
            store.markWatched(sessionID: session.id, duration: session.durationSeconds ?? 3600)
        }

        #expect(cloud.rejectedWrites.isEmpty, "iCloud rejected writes: \(cloud.rejectedWrites)")
        #expect(cloud.keyCount <= QuotaEnforcingKeyValueStore.maxKeys)

        let synced = try #require(cloud.watchProgress())
        #expect(synced.count == catalog.count)
        let allWatched = synced.values.allSatisfy { $0.isWatched }
        #expect(allWatched)

        cloud.logUsage(label: "\(catalog.count) videos watched")
    }

    @Test("Partly watching every video stays within iCloud limits")
    func partlyWatchingEveryVideo() async throws {
        // In-progress positions are fractional seconds, which encode longer
        // than the whole-number durations used when marking watched.
        let catalog = try await Catalog.sessions()
        let cloud = QuotaEnforcingKeyValueStore()
        let store = WatchProgressStore(defaults: .ephemeral(), cloud: cloud)

        for session in catalog {
            let duration = (session.durationSeconds ?? 3600) + 0.123456789
            store.update(sessionID: session.id, position: duration / 3 + 0.987654321, duration: duration)
        }

        #expect(cloud.rejectedWrites.isEmpty, "iCloud rejected writes: \(cloud.rejectedWrites)")
        #expect(cloud.watchProgress()?.count == catalog.count)
        cloud.logUsage(label: "\(catalog.count) videos in progress")
    }

    @Test("Watching and bookmarking every video together leaves ample headroom")
    func watchingAndBookmarkingEverything() async throws {
        // Watch progress and bookmarks share one 1 MB quota.
        let catalog = try await Catalog.sessions()
        let cloud = QuotaEnforcingKeyValueStore()
        let progress = WatchProgressStore(defaults: .ephemeral(), cloud: cloud)
        let bookmarks = SynchronizedListManager(defaults: .ephemeral(), cloud: cloud)

        for session in catalog {
            let duration = (session.durationSeconds ?? 3600) + 0.123456789
            progress.update(sessionID: session.id, position: duration / 3 + 0.987654321, duration: duration)
            bookmarks.toggle(session.id)
        }

        #expect(cloud.rejectedWrites.isEmpty, "iCloud rejected writes: \(cloud.rejectedWrites)")
        #expect(bookmarks.bookmarkedIDs.count == catalog.count)

        // Fail long before the real limit so catalog growth (or a bulkier
        // encoding) gets noticed while there's still time to react.
        let usage = Double(cloud.totalBytes) / Double(QuotaEnforcingKeyValueStore.maxTotalBytes)
        #expect(usage < 0.5, "Using \(Int(usage * 100))% of the iCloud quota")
        cloud.logUsage(label: "\(catalog.count) videos in progress and bookmarked")
    }

    @Test("A second device receives every watched video from iCloud")
    func secondDeviceReceivesEverything() async throws {
        let catalog = try await Catalog.sessions()
        let cloud = QuotaEnforcingKeyValueStore()
        let firstDevice = WatchProgressStore(defaults: .ephemeral(), cloud: cloud)
        for session in catalog {
            firstDevice.markWatched(sessionID: session.id, duration: session.durationSeconds ?? 3600)
        }

        // A fresh install with no local data, sharing the same iCloud store.
        let secondDevice = WatchProgressStore(defaults: .ephemeral(), cloud: cloud)

        #expect(secondDevice.progress.count == catalog.count)
        #expect(catalog.allSatisfy { secondDevice.progress(for: $0.id)?.isWatched == true })
    }
}

// MARK: - Catalog

@MainActor
private enum Catalog {
    private static var cached: [WWDCSession]?

    /// The real, current video catalog, falling back to the app's on-disk
    /// cache when offline.
    static func sessions() async throws -> [WWDCSession] {
        if let cached { return cached }
        let fallback = WWDCCache.loadSessions() ?? []
        let sessions = (try? await WWDCVideoService().fetchAllSessions(fallback: fallback)) ?? fallback
        try #require(!sessions.isEmpty, "Couldn't load the video catalog from the network or cache")
        cached = sessions
        return sessions
    }
}

// MARK: - Fake iCloud store

/// An in-memory stand-in for `NSUbiquitousKeyValueStore` that enforces the
/// documented limits: 1,024 keys, 1 MB total, 1 MB per value, and 64-byte keys.
/// Writes that would exceed a limit are rejected, as iCloud would.
@MainActor
private final class QuotaEnforcingKeyValueStore: CloudKeyValueStore {
    static let maxKeys = 1024
    static let maxTotalBytes = 1024 * 1024
    static let maxValueBytes = 1024 * 1024
    static let maxKeyBytes = 64

    private var values: [String: Any] = [:]
    private(set) var rejectedWrites: [String] = []

    var keyCount: Int { values.count }
    var totalBytes: Int { Self.totalSize(of: values) }

    func set(_ value: Any?, forKey key: String) {
        guard let value else {
            values[key] = nil
            return
        }
        var proposed = values
        proposed[key] = value
        guard key.utf8.count <= Self.maxKeyBytes,
              proposed.count <= Self.maxKeys,
              Self.size(of: value) <= Self.maxValueBytes,
              Self.totalSize(of: proposed) <= Self.maxTotalBytes
        else {
            rejectedWrites.append(key)
            return
        }
        values = proposed
    }

    func data(forKey key: String) -> Data? { values[key] as? Data }
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func synchronize() -> Bool { true }

    func watchProgress() -> [String: WatchProgress]? {
        data(forKey: WatchProgressStore.defaultsKey)
            .flatMap { try? JSONDecoder().decode([String: WatchProgress].self, from: $0) }
    }

    func logUsage(label: String) {
        let percent = Double(totalBytes) / Double(Self.maxTotalBytes) * 100
        print("\(label): \(totalBytes.formatted(.byteCount(style: .file))) in \(keyCount) keys (\(percent.formatted(.number.precision(.fractionLength(1))))% of quota)")
    }

    private static func size(of value: Any) -> Int {
        if let data = value as? Data { return data.count }
        return (try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0))?.count ?? 0
    }

    private static func totalSize(of values: [String: Any]) -> Int {
        values.reduce(0) { $0 + $1.key.utf8.count + size(of: $1.value) }
    }
}

// MARK: - Helpers

private extension UserDefaults {
    /// A throwaway defaults domain so tests never touch the app's real data.
    static func ephemeral() -> UserDefaults {
        let name = "DeveloperTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
