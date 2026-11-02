//
//  DownloadEngine.swift
//  Developer
//

import Foundation

nonisolated struct DownloadRecord: Codable, Sendable {
    let session: WWDCSession
    let fileName: String
    let downloadedAt: Date
}

@Observable
final class DownloadEngine {
    enum State: Equatable {
        case notDownloaded
        case downloading(Double)
        case downloaded
    }

    private struct ActiveDownload {
        let session: WWDCSession
        var progress: Double = 0
        var task: URLSessionDownloadTask?
        var pollTask: Task<Void, Never>?
    }

    private(set) var records: [String: DownloadRecord] = [:]
    private var active: [String: ActiveDownload] = [:]
    var errorMessage: String?

    private let service = WWDCVideoService()

    /// Application Support rather than Caches: downloads are the user's choice and
    /// shouldn't be purged by the system. They're excluded from backups.
    private nonisolated static let directory = URL.applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
    private nonisolated static let indexFile = directory.appending(path: "index.json")

    init() {
        if let data = try? Data(contentsOf: Self.indexFile),
           let saved = try? JSONDecoder().decode([String: DownloadRecord].self, from: data) {
            records = saved.filter { FileManager.default.fileExists(atPath: Self.fileURL(named: $0.value.fileName).path) }
        }
    }

    // MARK: Queries

    func state(for sessionID: String) -> State {
        if let download = active[sessionID] { return .downloading(download.progress) }
        return records[sessionID] != nil ? .downloaded : .notDownloaded
    }

    func isDownloaded(_ sessionID: String) -> Bool { records[sessionID] != nil }

    func fileURL(for sessionID: String) -> URL? {
        records[sessionID].map { Self.fileURL(named: $0.fileName) }
    }
    var sessions: [WWDCSession] {
        let downloading = active.values.map(\.session).sorted { $0.title < $1.title }
        let finished = records.values.sorted { $0.downloadedAt > $1.downloadedAt }.map(\.session)
        return downloading + finished
    }

    // MARK: Actions

    func download(_ session: WWDCSession) {
        guard state(for: session.id) == .notDownloaded else { return }
        active[session.id] = ActiveDownload(session: session)
        Task { await start(session) }
    }

    func cancel(_ sessionID: String) {
        guard let download = active.removeValue(forKey: sessionID) else { return }
        download.task?.cancel()
        download.pollTask?.cancel()
    }

    func remove(_ sessionID: String) {
        cancel(sessionID)
        guard let record = records.removeValue(forKey: sessionID) else { return }
        try? FileManager.default.removeItem(at: Self.fileURL(named: record.fileName))
        saveIndex()
    }

    private func start(_ session: WWDCSession) async {
        do {
            let remoteURL = try await downloadURL(for: session)
            guard active[session.id] != nil else { return }

            let fileName = "\(session.id).\(remoteURL.pathExtension.isEmpty ? "mp4" : remoteURL.pathExtension)"
            let destination = Self.fileURL(named: fileName)
            let fileURL = try await transfer(from: remoteURL, to: destination, sessionID: session.id)
            guard active.removeValue(forKey: session.id) != nil else {
                try? FileManager.default.removeItem(at: fileURL)
                return
            }
            records[session.id] = DownloadRecord(session: session, fileName: fileName, downloadedAt: .now)
            saveIndex()
        } catch {
            let wasCancelled = active[session.id] == nil || (error as? URLError)?.code == .cancelled
            active[session.id]?.pollTask?.cancel()
            active[session.id] = nil
            if !wasCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func downloadURL(for session: WWDCSession) async throws -> URL {
        if let cached = await WWDCCache.loadDetails(for: session.id)?.downloadURL {
            return cached
        }
        let details = try await service.fetchDetails(for: session)
        await WWDCCache.saveDetails(details, for: session.id)
        if let url = details.downloadURL { return url }
        throw DownloadError.noDownloadableVideo
    }

    private func transfer(from remoteURL: URL, to destination: URL, sessionID: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: remoteURL) { location, response, error in
                if let error { return continuation.resume(throwing: error) }
                guard let location else { return continuation.resume(throwing: URLError(.badServerResponse)) }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    return continuation.resume(throwing: URLError(.badServerResponse))
                }
                do {
                    try Self.moveIntoPlace(location, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            active[sessionID]?.task = task
            active[sessionID]?.pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    let fraction = task.progress.fractionCompleted
                    if self?.active[sessionID]?.progress != fraction {
                        self?.active[sessionID]?.progress = fraction
                    }
                }
            }
            task.resume()
        }
    }

    private nonisolated static func moveIntoPlace(_ location: URL, to destination: URL) throws {
        let manager = FileManager.default
        var directory = Self.directory
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.moveItem(at: location, to: destination)
    }

    private nonisolated static func fileURL(named fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    private func saveIndex() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: Self.indexFile, options: .atomic)
        } catch {
            print("Failed to save downloads index: \(error)")
        }
    }

    enum DownloadError: LocalizedError {
        case noDownloadableVideo

        var errorDescription: String? {
            "This video isn‘t available to download."
        }
    }
}
