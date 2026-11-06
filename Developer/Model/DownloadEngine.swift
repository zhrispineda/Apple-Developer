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
    }

    static let shared = DownloadEngine()

    nonisolated static let backgroundSessionIdentifier = "\(Bundle.main.bundleIdentifier ?? "Developer").downloads"

    private(set) var records: [String: DownloadRecord] = [:]
    private var active: [String: ActiveDownload] = [:]
    var errorMessage: String?

    @ObservationIgnored private var pending: [String: WWDCSession] = [:]
    @ObservationIgnored private var backgroundEventsContinuations: [CheckedContinuation<Void, Never>] = []

    @ObservationIgnored private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        return URLSession(configuration: configuration, delegate: SessionDelegate(engine: self), delegateQueue: .main)
    }()

    private let service = WWDCVideoService()

    private nonisolated static let directory = URL.applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
    private nonisolated static let indexFile = directory.appending(path: "index.json")
    private nonisolated static let pendingFile = directory.appending(path: "pending.json")

    init() {
        if let data = try? Data(contentsOf: Self.indexFile),
           let saved = try? JSONDecoder().decode([String: DownloadRecord].self, from: data) {
            records = saved.filter { FileManager.default.fileExists(atPath: Self.fileURL(named: $0.value.fileName).path) }
        }
        if let data = try? Data(contentsOf: Self.pendingFile),
           let saved = try? JSONDecoder().decode([String: WWDCSession].self, from: data) {
            pending = saved
            active = saved.mapValues { ActiveDownload(session: $0) }
        }
        Task { await reconnectTasks() }
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
        if pending.removeValue(forKey: sessionID) != nil { savePending() }
    }

    func remove(_ sessionID: String) {
        cancel(sessionID)
        guard let record = records.removeValue(forKey: sessionID) else { return }
        try? FileManager.default.removeItem(at: Self.fileURL(named: record.fileName))
        saveIndex()
    }

    func handleBackgroundEvents() async {
        _ = urlSession
        await withCheckedContinuation { backgroundEventsContinuations.append($0) }
    }

    private func start(_ session: WWDCSession) async {
        do {
            let remoteURL = try await downloadURL(for: session)
            guard active[session.id] != nil else { return }

            let task = urlSession.downloadTask(with: remoteURL)
            task.taskDescription = session.id
            active[session.id]?.task = task
            pending[session.id] = session
            savePending()
            task.resume()
        } catch {
            let wasCancelled = active[session.id] == nil
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

    private func reconnectTasks() async {
        let tasks = await urlSession.allTasks.compactMap { $0 as? URLSessionDownloadTask }
        var liveIDs = Set<String>()
        for task in tasks {
            guard let id = task.taskDescription else { continue }
            guard active[id] != nil else {
                task.cancel()
                continue
            }
            liveIDs.insert(id)
            active[id]?.task = task
            if task.countOfBytesExpectedToReceive > 0 {
                active[id]?.progress = Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive)
            }
        }
        
        let orphaned = pending.keys.filter { !liveIDs.contains($0) && active[$0]?.task == nil }
        guard !orphaned.isEmpty else { return }
        for id in orphaned {
            pending[id] = nil
            active[id] = nil
        }
        savePending()
    }

    // MARK: Session events

    fileprivate func task(_ task: URLSessionDownloadTask, didWrite totalWritten: Int64, of totalExpected: Int64) {
        guard let id = task.taskDescription, totalExpected > 0, let current = active[id]?.progress else { return }
        let fraction = Double(totalWritten) / Double(totalExpected)
        
        if fraction - current >= 0.005 || fraction >= 1 {
            active[id]?.progress = fraction
        }
    }

    fileprivate func task(_ task: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = task.taskDescription, let session = pending[id] else { return }
        if let http = task.response as? HTTPURLResponse, http.statusCode != 200 {
            return fail(id, with: URLError(.badServerResponse))
        }
        let pathExtension = task.originalRequest?.url?.pathExtension ?? ""
        let fileName = "\(id).\(pathExtension.isEmpty ? "mp4" : pathExtension)"
        do {
            try Self.moveIntoPlace(location, to: Self.fileURL(named: fileName))
        } catch {
            return fail(id, with: error)
        }
        active[id] = nil
        pending[id] = nil
        savePending()
        records[id] = DownloadRecord(session: session, fileName: fileName, downloadedAt: .now)
        saveIndex()
    }

    fileprivate func task(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription else { return }
        fail(id, with: error)
    }

    fileprivate func sessionDidFinishEvents() {
        let continuations = backgroundEventsContinuations
        backgroundEventsContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func fail(_ sessionID: String, with error: Error) {
        guard pending.removeValue(forKey: sessionID) != nil else { return }
        savePending()
        active[sessionID] = nil
        if (error as? URLError)?.code != .cancelled {
            errorMessage = error.localizedDescription
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

    private func savePending() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(pending).write(to: Self.pendingFile, options: .atomic)
        } catch {
            print("Failed to save pending downloads: \(error)")
        }
    }

    enum DownloadError: LocalizedError {
        case noDownloadableVideo

        var errorDescription: String? {
            "This video isn‘t available to download."
        }
    }
}

private nonisolated final class SessionDelegate: NSObject, URLSessionDownloadDelegate {
    private weak let engine: DownloadEngine?

    init(engine: DownloadEngine) {
        self.engine = engine
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        MainActor.assumeIsolated {
            engine?.task(downloadTask, didWrite: totalBytesWritten, of: totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        MainActor.assumeIsolated {
            engine?.task(downloadTask, didFinishDownloadingTo: location)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            engine?.task(task, didCompleteWithError: error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            engine?.sessionDidFinishEvents()
        }
    }
}
