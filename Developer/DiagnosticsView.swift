//
//  DiagnosticsView.swift
//  Developer
//

import SwiftUI

struct DiagnosticsView: View {
    @Environment(CloudSyncMonitor.self) private var cloudMonitor
    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(NewsStore.self) private var newsStore
    @Environment(ContentStore.self) private var contentStore
    @Environment(DownloadEngine.self) private var downloadStore

    @State private var probes: [ServiceProbe.Result] = []
    @State private var isProbing = false
    @State private var storage: StorageUsage?

    var body: some View {
        Form {
            iCloudSection
            syncEventsSection
            servicesSection
            dataSection
            appInfoSection
            deviceSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: report) {
                    Label("Share Diagnostics", systemImage: "square.and.arrow.up")
                }
            }
        }
        .task { await runProbes() }
        .task { storage = await StorageUsage.measure() }
        .refreshable {
            cloudMonitor.synchronize()
            await runProbes()
            storage = await StorageUsage.measure()
        }
    }

    // MARK: iCloud

    private var iCloudSection: some View {
        Section {
            LabeledContent("Key-Value Store") {
                StatusLabel(kvsStatus.text, status: kvsStatus.status)
            }
            if let date = cloudMonitor.lastSynchronizeDate {
                LabeledContent("Last Sync Request", value: date.formatted(date: .omitted, time: .standard))
            }
            LabeledContent("Storage Used") {
                let used = cloudMonitor.usedBytes
                Text("\(used.formatted(.byteCount(style: .file))) of \(CloudSyncMonitor.quotaBytes.formatted(.byteCount(style: .file)))")
                    .foregroundStyle(used > CloudSyncMonitor.quotaBytes * 9 / 10 ? .orange : .secondary)
            }
            LabeledContent("Watch Progress", value: "\(progressStore.progress.count) local · \(cloudProgressCount.map(String.init) ?? "–") iCloud")
            LabeledContent("Bookmarks", value: "\(bookmarkStore.bookmarkedIDs.count) local · \(cloudBookmarkCount.map(String.init) ?? "–") iCloud")
            LabeledContent("Keys in iCloud", value: cloudMonitor.keys.isEmpty ? "None" : cloudMonitor.keys.joined(separator: ", "))
            Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                cloudMonitor.synchronize()
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Watch progress and bookmarks sync through the iCloud key-value store. iCloud delivers changes to other devices on its own schedule, usually within a few minutes.")
        }
    }

    private var kvsStatus: (text: String, status: StatusLabel.Status) {
        switch cloudMonitor.lastSynchronizeSucceeded {
        case true?: ("Available", .ok)
        case false?: ("Unavailable", .error)
        case nil: ("Unknown", .warning)
        }
    }

    private var cloudProgressCount: Int? {
        guard let data = cloudMonitor.store.data(forKey: WatchProgressStore.defaultsKey),
              let decoded = try? JSONDecoder().decode([String: WatchProgress].self, from: data)
        else { return nil }
        return decoded.count
    }

    private var cloudBookmarkCount: Int? {
        (cloudMonitor.store.array(forKey: SynchronizedListManager.defaultsKey) as? [String])?.count
    }

    private var syncEventsSection: some View {
        Section {
            if cloudMonitor.events.isEmpty {
                Text("No changes received from iCloud since launch.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cloudMonitor.events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            StatusLabel(event.reason.description, status: event.reason.isProblem ? .error : .ok)
                            Spacer()
                            Text(event.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.secondary)
                        }
                        if !event.keys.isEmpty {
                            Text(event.keys.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("iCloud Activity")
        }
    }

    // MARK: Services

    private var servicesSection: some View {
        Section {
            ForEach(ServiceProbe.Endpoint.allCases, id: \.self) { endpoint in
                LabeledContent(endpoint.name) {
                    if let result = probes.first(where: { $0.endpoint == endpoint }) {
                        StatusLabel(result.summary, status: result.status)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            Button("Check Again", systemImage: "arrow.clockwise") {
                Task { await runProbes() }
            }
            .disabled(isProbing)
        } header: {
            Text("Services")
        }
    }

    private func runProbes() async {
        isProbing = true
        probes = []
        probes = await ServiceProbe.checkAll()
        isProbing = false
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            LabeledContent("Videos") {
                storeStatus(count: sessionStore.sessions.count, isLoading: sessionStore.isLoading, error: sessionStore.errorMessage)
            }
            LabeledContent("Events", value: "\(sessionStore.events.count)")
            LabeledContent("News") {
                storeStatus(count: newsStore.items.count, isLoading: newsStore.isLoading, error: newsStore.errorMessage)
            }
            LabeledContent("Discover") {
                storeStatus(count: contentStore.feed?.items.count ?? 0, isLoading: contentStore.isLoading, error: contentStore.errorMessage)
            }
            if let fetchedAt = contentStore.feed?.fetchedAt {
                LabeledContent("Discover Updated", value: fetchedAt.formatted(.relative(presentation: .named)))
            }
            LabeledContent("Downloads", value: "\(downloadStore.records.count)")
            LabeledContent("Downloads Size", value: storage?.downloads.formatted(.byteCount(style: .file)) ?? "…")
            LabeledContent("Cache Size", value: storage?.caches.formatted(.byteCount(style: .file)) ?? "…")
        } header: {
            Text("Data")
        }
    }

    private func storeStatus(count: Int, isLoading: Bool, error: String?) -> some View {
        Group {
            if isLoading {
                StatusLabel("Loading…", status: .warning)
            } else if let error {
                StatusLabel(count > 0 ? "\(count) cached · \(error)" : error, status: .error)
            } else {
                StatusLabel("\(count) items", status: count > 0 ? .ok : .warning)
            }
        }
    }

    // MARK: App and device

    private var appInfoSection: some View {
        Section("App") {
            ForEach(AppInfo.appRows, id: \.0) { row in
                LabeledContent(row.0, value: row.1)
                    .textSelection(.enabled)
            }
        }
    }

    private var deviceSection: some View {
        Section("Device") {
            ForEach(AppInfo.deviceRows, id: \.0) { row in
                LabeledContent(row.0, value: row.1)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Report

    private var report: String {
        var lines = ["Developer Diagnostics — \(Date.now.formatted(.iso8601))", ""]
        lines.append("[iCloud]")
        lines.append("Key-Value Store: \(kvsStatus.text)")
        lines.append("Storage Used: \(cloudMonitor.usedBytes) bytes")
        lines.append("Watch Progress: \(progressStore.progress.count) local, \(cloudProgressCount.map(String.init) ?? "none") iCloud")
        lines.append("Bookmarks: \(bookmarkStore.bookmarkedIDs.count) local, \(cloudBookmarkCount.map(String.init) ?? "none") iCloud")
        lines.append("Keys: \(cloudMonitor.keys.joined(separator: ", "))")
        for event in cloudMonitor.events {
            lines.append("  \(event.date.formatted(.iso8601)) \(event.reason.description) \(event.keys.joined(separator: ","))")
        }
        lines.append("")
        lines.append("[Services]")
        for result in probes {
            lines.append("\(result.endpoint.name): \(result.summary)")
        }
        lines.append("")
        lines.append("[Data]")
        lines.append("Videos: \(sessionStore.sessions.count)\(sessionStore.errorMessage.map { " (\($0))" } ?? "")")
        lines.append("News: \(newsStore.items.count)\(newsStore.errorMessage.map { " (\($0))" } ?? "")")
        lines.append("Discover: \(contentStore.feed?.items.count ?? 0)\(contentStore.errorMessage.map { " (\($0))" } ?? "")")
        lines.append("Downloads: \(downloadStore.records.count)")
        lines.append("")
        lines.append("[App]")
        lines += AppInfo.appRows.map { "\($0.0): \($0.1)" }
        lines.append("")
        lines.append("[Device]")
        lines += AppInfo.deviceRows.map { "\($0.0): \($0.1)" }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Status label

struct StatusLabel: View {
    enum Status { case ok, warning, error }

    let text: String
    let status: Status

    init(_ text: String, status: Status) {
        self.text = text
        self.status = status
    }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
    }

    private var symbol: String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch status {
        case .ok: .green
        case .warning: .orange
        case .error: .red
        }
    }
}

// MARK: - Service probes

nonisolated enum ServiceProbe {
    enum Endpoint: CaseIterable, Sendable {
        case videos, news, discover, live

        var name: String {
            switch self {
            case .videos: "WWDC Videos"
            case .news: "News Feed"
            case .discover: "Discover Feed"
            case .live: "Live Videos"
            }
        }

        var url: URL {
            switch self {
            case .videos: WWDCVideoService.baseURL.appending(path: "videos/")
            case .news: NewsService.feedURL
            case .discover: FeedFetcher.feedBaseURL.appending(path: "contents.json")
            case .live: FeedFetcher.feedBaseURL.appending(path: "videos_live.json")
            }
        }
    }

    struct Result: Sendable {
        let endpoint: Endpoint
        let statusCode: Int?
        let latency: Duration
        let errorDescription: String?

        var status: StatusLabel.Status {
            guard let statusCode else { return .error }
            return (200..<400).contains(statusCode) ? .ok : .error
        }

        var summary: String {
            if let errorDescription { return errorDescription }
            let ms = Int(latency.components.seconds * 1000 + latency.components.attoseconds / 1_000_000_000_000_000)
            return "HTTP \(statusCode ?? 0) · \(ms) ms"
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    @concurrent
    static func checkAll() async -> [Result] {
        await withTaskGroup(of: Result.self) { group in
            for endpoint in Endpoint.allCases {
                group.addTask { await check(endpoint) }
            }
            var results: [Result] = []
            for await result in group { results.append(result) }
            return results
        }
    }

    private static func check(_ endpoint: Endpoint) async -> Result {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "HEAD"
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode
            return Result(endpoint: endpoint, statusCode: code, latency: clock.now - start, errorDescription: nil)
        } catch {
            return Result(endpoint: endpoint, statusCode: nil, latency: clock.now - start, errorDescription: error.localizedDescription)
        }
    }
}

// MARK: - Storage usage

nonisolated struct StorageUsage: Sendable {
    let caches: Int
    let downloads: Int

    @concurrent
    static func measure() async -> StorageUsage {
        StorageUsage(
            caches: size(of: .cachesDirectory.appending(path: "WWDC", directoryHint: .isDirectory)),
            downloads: size(of: .applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory))
        )
    }

    private static func size(of directory: URL) -> Int {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += values.totalFileAllocatedSize ?? 0
        }
        return total
    }
}

// MARK: - App and device info

enum AppInfo {
    static var appRows: [(String, String)] {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "–"
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif
        return [
            ("Name", name),
            ("Version", "\(version) (\(build))"),
            ("Bundle ID", Bundle.main.bundleIdentifier ?? "–"),
            ("Configuration", configuration),
            ("Minimum OS", info["MinimumOSVersion"] as? String ?? info["LSMinimumSystemVersion"] as? String ?? "–"),
        ]
    }

    static var deviceRows: [(String, String)] {
        let process = ProcessInfo.processInfo
        return [
            ("Model", modelIdentifier),
            ("System", "\(platformName) \(process.operatingSystemVersionString)"),
            ("Memory", Int64(process.physicalMemory).formatted(.byteCount(style: .memory))),
            ("Processors", "\(process.activeProcessorCount)"),
            ("Low Power Mode", process.isLowPowerModeEnabled ? "On" : "Off"),
            ("Thermal State", thermalState(process.thermalState)),
            ("Locale", Locale.current.identifier),
            ("Time Zone", TimeZone.current.identifier),
        ]
    }

    private static var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(visionOS)
        "visionOS"
        #else
        "iOS"
        #endif
    }

    private static var modelIdentifier: String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #else
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (Simulator)"
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        #endif
    }

    private static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
    }
    .environment(CloudSyncMonitor())
    .environment(WatchProgressStore())
    .environment(SynchronizedListManager())
    .environment(SessionStore())
    .environment(NewsStore())
    .environment(ContentStore())
    .environment(DownloadEngine())
}
