//
//  ContentItemPlayer.swift
//  Developer
//

import SwiftUI
import AVKit

#if os(macOS)
struct ContentItemPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
        view.allowsVideoFrameAnalysis = true
        view.updatesNowPlayingInfoCenter = true
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}
#else
struct ContentItemPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.allowsVideoFrameAnalysis = true
        controller.updatesNowPlayingInfoCenter = true
        controller.player = player
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
#endif

private extension URL {
    static let previewStream = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!
}

#Preview("AVPlayerView") {
    ContentItemPlayer(player: AVPlayer(url: .previewStream))
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(width: 640)
}

#Preview("AVPlayerViewController") {
    ContentItemPlayer(player: AVPlayer(url: .previewStream))
        .aspectRatio(16 / 9, contentMode: .fit)
}
