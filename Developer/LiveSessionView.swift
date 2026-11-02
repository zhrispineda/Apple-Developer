//
//  LiveSessionView.swift
//  Developer
//

import SwiftUI
import AVKit

struct LiveSessionView: View {
    let item: ContentItem

    @Environment(ContentStore.self) private var store
    @State private var player: AVPlayer?

    private var streamURL: URL? {
        store.isLive(item) ? store.live.streamURL(for: item.id) : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.black
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { playerArea }
                    #if os(macOS)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding([.horizontal, .top])
                    #endif

                info
                    .frame(maxWidth: 960, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: item.webURL) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                    Link(destination: item.webURL) {
                        Label("View on developer.apple.com", systemImage: "safari")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .task { await store.monitorLive() }
        .onChange(of: streamURL) { _, url in
            if let url, player != nil { player?.replaceCurrentItem(with: AVPlayerItem(url: url)) }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var playerArea: some View {
        if let player {
            ContentItemPlayer(player: player)
        } else if streamURL != nil {
            VideoPlayerOverlay(url: item.posterURL, isReady: true, onPlay: startPlayback)
        } else {
            ZStack {
                if let url = item.posterURL {
                    AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                    .opacity(0.5)
                }
                Text(statusMessage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: .capsule)
            }
            .clipped()
        }
    }

    private var statusMessage: String {
        if let start = item.startTime, store.now < start {
            "Live stream starts \(start.formatted(.relative(presentation: .named)))"
        } else {
            "This live stream has ended"
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.title.bold())

            HStack(spacing: 8) {
                if store.isLive(item) { LiveBadge() }
                Text(scheduleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(item.summary)
                .padding(.top, 8)
                .textSelection(.enabled)
        }
    }

    private var scheduleText: String {
        guard let start = item.startTime, let end = item.endTime, start <= end else { return item.eventName }
        let interval = (start..<end).formatted(.interval.weekday(.wide).month(.wide).day().hour().minute())
        return "\(item.eventName) • \(interval)"
    }

    private func startPlayback() {
        guard let streamURL else { return }
        let newPlayer = AVPlayer(url: streamURL)
        player = newPlayer
        newPlayer.play()
    }
}

struct LiveBadge: View {
    var body: some View {
        Text("LIVE")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.red, in: .capsule)
            .accessibilityLabel("Live")
    }
}
