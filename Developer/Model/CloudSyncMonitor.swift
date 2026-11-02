//
//  CloudSyncMonitor.swift
//  Developer
//

import Foundation

@Observable
final class CloudSyncMonitor {
    struct Event: Identifiable {
        let id = UUID()
        let date: Date
        let reason: Reason
        let keys: [String]
    }

    enum Reason {
        case serverChange, initialSync, quotaViolation, accountChange, unknown(Int)

        init(rawValue: Int?) {
            switch rawValue {
            case NSUbiquitousKeyValueStoreServerChange: self = .serverChange
            case NSUbiquitousKeyValueStoreInitialSyncChange: self = .initialSync
            case NSUbiquitousKeyValueStoreQuotaViolationChange: self = .quotaViolation
            case NSUbiquitousKeyValueStoreAccountChange: self = .accountChange
            default: self = .unknown(rawValue ?? -1)
            }
        }

        var description: String {
            switch self {
            case .serverChange: "Server change"
            case .initialSync: "Initial sync"
            case .quotaViolation: "Quota exceeded"
            case .accountChange: "iCloud account changed"
            case .unknown(let value): "Unknown (\(value))"
            }
        }

        var isProblem: Bool {
            if case .quotaViolation = self { return true }
            return false
        }
    }

    static let quotaBytes = 1024 * 1024

    let store: NSUbiquitousKeyValueStore
    private(set) var events: [Event] = []
    private(set) var lastSynchronizeSucceeded: Bool?
    private(set) var lastSynchronizeDate: Date?

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        synchronize()
        observeChanges()
    }

    func synchronize() {
        lastSynchronizeSucceeded = store.synchronize()
        lastSynchronizeDate = .now
    }

    var usedBytes: Int {
        store.dictionaryRepresentation.reduce(0) { total, entry in
            let valueSize = (try? PropertyListSerialization.data(
                fromPropertyList: entry.value, format: .binary, options: 0
            ))?.count ?? 0
            return total + entry.key.utf8.count + valueSize
        }
    }

    var keys: [String] { store.dictionaryRepresentation.keys.sorted() }

    private func observeChanges() {
        Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            )
            for await notification in changes {
                guard let self, (notification.object as AnyObject?) === self.store else { continue }
                let info = notification.userInfo
                let event = Event(
                    date: .now,
                    reason: Reason(rawValue: info?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int),
                    keys: info?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                )
                self.events.insert(event, at: 0)
                if self.events.count > 50 { self.events.removeLast() }
            }
        }
    }
}
