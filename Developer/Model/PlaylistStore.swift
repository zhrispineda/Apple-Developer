//
//  PlaylistStore.swift
//  Developer
//

import Foundation

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var sessionIDs: [String]
    var updatedAt: Date
}

@Observable
final class PlaylistStore {
    private(set) var playlists: [Playlist] = []

    static let defaultsKey = "playlists"
    private let defaults: UserDefaults
    private let cloud: CloudKeyValueStore?

    init(defaults: UserDefaults = .standard, cloud: CloudKeyValueStore? = nil) {
        self.defaults = defaults
        self.cloud = cloud
        playlists = Self.decode(defaults.data(forKey: Self.defaultsKey)) ?? []

        if let cloud {
            cloud.synchronize()
            
            if let remote = Self.decode(cloud.data(forKey: Self.defaultsKey)) {
                var merged = remote
                for local in playlists {
                    if let index = merged.firstIndex(where: { $0.id == local.id }) {
                        if local.updatedAt > merged[index].updatedAt { merged[index] = local }
                    } else {
                        merged.append(local)
                    }
                }
                playlists = merged
            }
            save()
            observeCloudChanges()
        }
    }

    func playlist(withID id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    @discardableResult
    func create(title: String, sessionIDs: [String] = []) -> Playlist {
        let playlist = Playlist(id: UUID(), title: Self.cleaned(title), sessionIDs: sessionIDs, updatedAt: .now)
        playlists.append(playlist)
        save()
        return playlist
    }

    func rename(_ id: UUID, to title: String) {
        edit(id) { $0.title = Self.cleaned(title) }
    }

    func delete(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func contains(_ sessionID: String, in id: UUID) -> Bool {
        playlist(withID: id)?.sessionIDs.contains(sessionID) ?? false
    }

    func toggle(_ sessionID: String, in id: UUID) {
        edit(id) { playlist in
            if let index = playlist.sessionIDs.firstIndex(of: sessionID) {
                playlist.sessionIDs.remove(at: index)
            } else {
                playlist.sessionIDs.append(sessionID)
            }
        }
    }

    func remove(_ sessionIDs: Set<String>, from id: UUID) {
        edit(id) { $0.sessionIDs.removeAll { sessionIDs.contains($0) } }
    }

    func setSessionIDs(_ sessionIDs: [String], in id: UUID) {
        edit(id) { $0.sessionIDs = sessionIDs }
    }

    private func edit(_ id: UUID, _ change: (inout Playlist) -> Void) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        change(&playlists[index])
        playlists[index].updatedAt = .now
        save()
    }

    private static func cleaned(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled Playlist") : trimmed
    }

    // MARK: Persistence and iCloud sync

    private func save() {
        guard let data = Self.encode(playlists) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        cloud?.set(data, forKey: Self.defaultsKey)
    }

    private func observeCloudChanges() {
        Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            )
            for await notification in changes {
                guard let self, let cloud = self.cloud,
                      (notification.object as AnyObject?) === cloud else { continue }
                let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                guard keys.contains(Self.defaultsKey) else { continue }
                let data = cloud.data(forKey: Self.defaultsKey)
                self.playlists = Self.decode(data) ?? []
                self.defaults.set(data, forKey: Self.defaultsKey)
            }
        }
    }

    private static func encode(_ playlists: [Playlist]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(playlists)
    }

    private static func decode(_ data: Data?) -> [Playlist]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([Playlist].self, from: data)
    }
}
