//
//  WatchProgressStore.swift
//  Developer
//

import Foundation

struct WatchProgress: Codable, Equatable, Sendable {
    var position: Double
    var duration: Double
    var isWatched: Bool
    var updatedAt: Date?

    var remaining: Double { max(duration - position, 0) }
}

@Observable
final class WatchProgressStore {
    private(set) var progress: [String: WatchProgress] = [:]
    private static let watchedThreshold: Double = 30
    static let defaultsKey = "watchProgress"
    private static let cloudWriteInterval: Duration = .seconds(30)

    private let defaults: UserDefaults
    private let cloud: CloudKeyValueStore?
    private var lastCloudWrite: ContinuousClock.Instant?
    private var pendingCloudWrite: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, cloud: CloudKeyValueStore? = nil) {
        self.defaults = defaults
        self.cloud = cloud
        progress = (Self.decode(defaults.data(forKey: Self.defaultsKey)) ?? [:])
            .filter { $0.value.isWatched || $0.value.position == 0 || $0.value.position >= 1 }

        if let cloud {
            cloud.synchronize()
            mergeFromCloud()
            observeCloudChanges()
        }
    }

    func progress(for sessionID: String) -> WatchProgress? {
        progress[sessionID]
    }

    var inProgressSessionIDs: [String] {
        progress
            .filter { !$0.value.isWatched && $0.value.position > 0 }
            .sorted { ($0.value.updatedAt ?? .distantPast) > ($1.value.updatedAt ?? .distantPast) }
            .map(\.key)
    }

    var historySessionIDs: [String] {
        progress
            .filter { $0.value.isWatched || $0.value.position > 0 }
            .sorted { ($0.value.updatedAt ?? .distantPast) > ($1.value.updatedAt ?? .distantPast) }
            .map(\.key)
    }

    func update(sessionID: String, position: Double, duration: Double) {
        guard duration > 0, position.isFinite else { return }
        let nearEnd = position >= duration - Self.watchedThreshold || position >= duration * 0.95
        let wasWatched = progress[sessionID]?.isWatched ?? false
        progress[sessionID] = WatchProgress(
            position: position, duration: duration, isWatched: wasWatched || nearEnd, updatedAt: .now
        )
        save(throttled: !(nearEnd && !wasWatched))
    }

    /// Writes any throttled progress to iCloud immediately, e.g. when playback stops.
    func syncToCloud() {
        guard pendingCloudWrite != nil else { return }
        writeToCloud()
    }

    func markWatched(sessionID: String, duration: Double) {
        progress[sessionID] = WatchProgress(position: duration, duration: duration, isWatched: true, updatedAt: .now)
        save()
    }

    func markUnwatched(sessionID: String) {
        let duration = progress[sessionID]?.duration ?? 0
        progress[sessionID] = WatchProgress(position: 0, duration: duration, isWatched: false, updatedAt: .now)
        save()
    }

    // MARK: Persistence and iCloud sync

    private func save(throttled: Bool = false) {
        guard let data = Self.encode(progress) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        guard cloud != nil else { return }

        guard throttled, let lastCloudWrite else {
            writeToCloud()
            return
        }
        let elapsed = ContinuousClock.now - lastCloudWrite
        if elapsed >= Self.cloudWriteInterval {
            writeToCloud()
        } else if pendingCloudWrite == nil {
            // Coalesce updates within the interval into one trailing write.
            pendingCloudWrite = Task { [weak self] in
                try? await Task.sleep(for: Self.cloudWriteInterval - elapsed)
                guard !Task.isCancelled else { return }
                self?.writeToCloud()
            }
        }
    }

    private func writeToCloud() {
        pendingCloudWrite?.cancel()
        pendingCloudWrite = nil
        lastCloudWrite = .now
        guard let cloud, let data = Self.encode(progress) else { return }
        guard cloud.data(forKey: Self.defaultsKey) != data else { return }
        cloud.set(data, forKey: Self.defaultsKey)
    }

    private func mergeFromCloud() {
        guard let remote = Self.decode(cloud?.data(forKey: Self.defaultsKey)) else {
            // Nothing in iCloud yet: upload what this device has.
            if !progress.isEmpty { save() }
            return
        }
        var merged = progress
        for (id, remoteEntry) in remote {
            let localDate = merged[id]?.updatedAt ?? .distantPast
            if (remoteEntry.updatedAt ?? .distantPast) >= localDate {
                merged[id] = remoteEntry
            }
        }
        // Only write back when the merge changes
        if merged != progress {
            progress = merged
            defaults.set(Self.encode(merged), forKey: Self.defaultsKey)
        }
        if merged != remote { writeToCloud() }
    }

    private func observeCloudChanges() {
        Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            )
            for await notification in changes {
                guard let self else { return }
                guard (notification.object as AnyObject?) === self.cloud else { continue }
                let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                guard keys.contains(Self.defaultsKey) else { continue }
                self.mergeFromCloud()
            }
        }
    }

    private static func encode(_ progress: [String: WatchProgress]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(progress)
    }

    private static func decode(_ data: Data?) -> [String: WatchProgress]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String: WatchProgress].self, from: data)
    }
}
