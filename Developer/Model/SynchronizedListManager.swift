//
//  SynchronizedListManager.swift
//  Developer
//

import Foundation

@Observable
final class SynchronizedListManager {
    private(set) var bookmarkedIDs: Set<String>

    private static let defaultsKey = "bookmarkedSessions"
    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?

    init(defaults: UserDefaults = .standard, cloud: NSUbiquitousKeyValueStore? = nil) {
        self.defaults = defaults
        self.cloud = cloud
        bookmarkedIDs = Set(defaults.stringArray(forKey: Self.defaultsKey) ?? [])

        if let cloud {
            cloud.synchronize()
            // First sync on this device: combine with any bookmarks already in iCloud.
            if let remote = cloud.array(forKey: Self.defaultsKey) as? [String] {
                bookmarkedIDs.formUnion(remote)
            }
            save()
            observeCloudChanges()
        }
    }

    func isBookmarked(_ sessionID: String) -> Bool {
        bookmarkedIDs.contains(sessionID)
    }

    func toggle(_ sessionID: String) {
        if bookmarkedIDs.remove(sessionID) == nil {
            bookmarkedIDs.insert(sessionID)
        }
        save()
    }

    private func save() {
        let ids = Array(bookmarkedIDs)
        defaults.set(ids, forKey: Self.defaultsKey)
        cloud?.set(ids, forKey: Self.defaultsKey)
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
                let remote = cloud.array(forKey: Self.defaultsKey) as? [String] ?? []
                self.bookmarkedIDs = Set(remote)
                self.defaults.set(remote, forKey: Self.defaultsKey)
            }
        }
    }
}
