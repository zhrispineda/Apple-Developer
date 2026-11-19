//
//  NotesStore.swift
//  Developer
//

import Foundation

struct SessionNote: Codable, Equatable, Sendable {
    var text: String
    var updatedAt: Date

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@Observable
final class NotesStore {
    private(set) var notes: [String: SessionNote] = [:]

    static let defaultsKey = "sessionNotes"
    private static let cloudWriteDelay: Duration = .seconds(3)

    private let defaults: UserDefaults
    private let cloud: CloudKeyValueStore?
    private var pendingCloudWrite: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, cloud: CloudKeyValueStore? = nil) {
        self.defaults = defaults
        self.cloud = cloud
        notes = Self.decode(defaults.data(forKey: Self.defaultsKey)) ?? [:]

        if let cloud {
            cloud.synchronize()
            mergeFromCloud()
            observeCloudChanges()
        }
    }

    func text(for sessionID: String) -> String {
        notes[sessionID]?.text ?? ""
    }

    func hasNote(for sessionID: String) -> Bool {
        !(notes[sessionID]?.isEmpty ?? true)
    }

    func note(for sessionID: String) -> SessionNote? {
        notes[sessionID].flatMap { $0.isEmpty ? nil : $0 }
    }

    var sessionIDsWithNotes: [String] {
        notes
            .filter { !$0.value.isEmpty }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .map(\.key)
    }

    func setText(_ text: String, for sessionID: String) {
        guard text != notes[sessionID]?.text else { return }
        
        if notes[sessionID] == nil && text.isEmpty { return }
        notes[sessionID] = SessionNote(text: text, updatedAt: .now)
        save()
    }

    func deleteNote(for sessionID: String) {
        setText("", for: sessionID)
        syncToCloud()
    }

    func syncToCloud() {
        guard pendingCloudWrite != nil else { return }
        writeToCloud()
    }

    // MARK: Persistence and iCloud sync

    private func save() {
        defaults.set(Self.encode(notes), forKey: Self.defaultsKey)
        guard cloud != nil, pendingCloudWrite == nil else { return }
        
        pendingCloudWrite = Task { [weak self] in
            try? await Task.sleep(for: Self.cloudWriteDelay)
            guard !Task.isCancelled else { return }
            self?.writeToCloud()
        }
    }

    private func writeToCloud() {
        pendingCloudWrite?.cancel()
        pendingCloudWrite = nil
        guard let cloud, let data = Self.encode(notes) else { return }
        guard cloud.data(forKey: Self.defaultsKey) != data else { return }
        cloud.set(data, forKey: Self.defaultsKey)
    }

    private func mergeFromCloud() {
        guard let remote = Self.decode(cloud?.data(forKey: Self.defaultsKey)) else {
            if !notes.isEmpty { writeToCloud() }
            return
        }
        var merged = notes
        for (id, remoteNote) in remote where remoteNote.updatedAt >= (merged[id]?.updatedAt ?? .distantPast) {
            merged[id] = remoteNote
        }
        if merged != notes {
            notes = merged
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

    private static func encode(_ notes: [String: SessionNote]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(notes)
    }

    private static func decode(_ data: Data?) -> [String: SessionNote]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String: SessionNote].self, from: data)
    }
}
