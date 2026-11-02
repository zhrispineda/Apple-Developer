//
//  ContentItemVideoDetail.swift
//  Developer
//

import SwiftUI
import AVKit

struct ContentItemVideoDetail: View {
    enum InfoTab: String, CaseIterable, Identifiable {
        case about = "About"
        case transcript = "Transcript"
        case code = "Code"

        var id: Self { self }
    }

    private var availableTabs: [InfoTab] {
        details?.codeSamples?.isEmpty == false ? InfoTab.allCases : [.about, .transcript]
    }

    let session: WWDCSession

    @State private var details: WWDCSessionDetails?
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var selectedTab: InfoTab = .about
    @State private var clock = PlaybackClock()
    @State private var videoAspectRatio: CGFloat = 16 / 9
    @State private var hasStartedPlayback = false

    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(DownloadEngine.self) private var downloadStore

    private let service = WWDCVideoService()

    var body: some View {
        VStack(spacing: 0) {
            Color.black
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .overlay { playerArea }
                #if os(macOS)
                .clipShape(.rect(cornerRadius: 12))
                .padding([.horizontal, .top])
                #endif
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            Picker("Section", selection: $selectedTab) {
                ForEach(availableTabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 12)

            infoContent
                .frame(minHeight: 160)
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                let isBookmarked = bookmarkStore.isBookmarked(session.id)
                Button(
                    isBookmarked ? "Remove from Bookmarks" : "Add to Bookmarks",
                    systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                ) {
                    bookmarkStore.toggle(session.id)
                }

                VideoDownloadButton(session: session)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ContentItemContextMenu(session: session)
                    Link(destination: session.url) {
                        Label("View on developer.apple.com", systemImage: "safari")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .task(id: session.id) { await loadVideo() }
        .task(id: player) { await trackPlayback() }
        .onDisappear {
            player?.pause()
            saveProgress()
        }
    }

    // MARK: Subviews

    @ViewBuilder
    private var playerArea: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Video Unavailable", systemImage: "play.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await loadVideo() }
                }
            }
            .foregroundStyle(.white)
        } else if let player, hasStartedPlayback {
            ContentItemPlayer(player: player)
        } else {
            VideoPlayerOverlay(url: session.posterURL, isReady: player != nil) {
                startPlayback()
            }
        }
    }

    @ViewBuilder
    private var infoContent: some View {
        switch selectedTab {
        case .about:
            aboutView
        case .transcript:
            TranscriptPane(
                paragraphs: details.map { $0.transcript ?? [] },
                clock: clock,
                onSeek: seek(to:)
            )
        case .code:
            CodeSnippetsPane(samples: details?.codeSamples ?? [], onSeek: seek(to:))
        }
    }

    private var aboutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title)
                    .font(.title.bold())

                ContentItemMetadata(session: session, clock: clock)

                if let summary = details?.summary {
                    Text(summary)
                        .padding(.top, 4)
                }

                if let chapters = details?.chapters, !chapters.isEmpty {
                    VideoChaptersView(chapters: chapters, onSeek: seek(to:))
                        .padding(.top, 32)
                }

                if let resources = details?.resources, !resources.isEmpty {
                    RelatedResourcesView(resources: resources)
                        .padding(.top, 32)
                }

                if let relatedVideos = details?.relatedVideos, !relatedVideos.isEmpty {
                    RelatedVideosSection(relatedVideos: relatedVideos)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: Time

    private func trackPlayback() async {
        guard let player else { return }
        var tick = 0
        while !Task.isCancelled {
            let time = player.currentTime().seconds
            let newTime = time.isFinite ? time : 0
            if newTime != clock.currentTime { clock.currentTime = newTime }
            if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0,
               duration != clock.totalDuration {
                clock.totalDuration = duration
            }
            if let size = player.currentItem?.presentationSize, size.width > 0, size.height > 0 {
                let ratio = size.width / size.height
                if abs(ratio - videoAspectRatio) > 0.01 {
                    videoAspectRatio = ratio
                }
            }
            tick += 1
            if tick.isMultiple(of: 10) { saveProgress() }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func saveProgress() {
        let currentTime = clock.currentTime
        guard currentTime >= 1, let total = clock.totalDuration ?? session.durationSeconds else { return }
        progressStore.update(sessionID: session.id, position: currentTime, duration: total)
    }

    private func startPlayback() {
        guard let player else { return }
        hasStartedPlayback = true
        player.play()
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        clock.currentTime = seconds
        startPlayback()
    }

    // MARK: Loading

    private func loadVideo() async {
        guard player == nil || details == nil else { return }
        errorMessage = nil
        hasStartedPlayback = false

        var resolved = await WWDCCache.loadDetails(for: session.id)
        if resolved == nil || resolved?.transcript == nil || resolved?.chapters == nil || resolved?.codeSamples == nil
            || resolved?.resources == nil || resolved?.relatedVideos == nil {
            do {
                let fetched = try await service.fetchDetails(for: session)
                await WWDCCache.saveDetails(fetched, for: session.id)
                resolved = fetched
            } catch {
                if resolved == nil && downloadStore.fileURL(for: session.id) == nil {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }

        details = resolved
        guard let videoURL = downloadStore.fileURL(for: session.id) ?? resolved?.videoURL else {
            errorMessage = "No video was found for this session."
            return
        }
        let newPlayer = AVPlayer(url: videoURL)
        if let saved = progressStore.progress(for: session.id), !saved.isWatched, saved.position > 5 {
            await newPlayer.seek(to: CMTime(seconds: saved.position, preferredTimescale: 600))
        }
        player = newPlayer
    }
}

@Observable
final class PlaybackClock {
    var currentTime: Double = 0
    var totalDuration: Double?
}

#Preview {
    NavigationStack {
        ContentItemVideoDetail(session: WWDCSession(
            id: "wwdc2014-605",
            eventID: "wwdc2014",
            sessionNumber: 605,
            title: "Working with Metal: Advanced",
            topics: ["Graphics & Games"],
            duration: "53:52",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
        ))
    }
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    .environment(SessionStore())
}

#Preview("Chapters") {
    NavigationStack {
        ContentItemVideoDetail(session: WWDCSession(
            id: "tech-talks-111468",
            eventID: "tech-talks",
            sessionNumber: 111468,
            title: "Bring Touch to your Mac app",
            topics: ["SwiftUI & UI Frameworks"],
            duration: "13:19",
            thumbnailURL: nil,
            url: URL(string: "https://developer.apple.com/videos/play/tech-talks/111468/")!
        ))
    }
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    .environment(SessionStore())
    #if os(macOS)
    // A wide window, to check the video fills the width.
    .frame(width: 1000, height: 760)
    #endif
}
