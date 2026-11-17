//
//  VideoPlayerOverlay.swift
//  Developer
//

import SwiftUI

/// A view overlay on top of videos that displays loading progress and a play button.
struct VideoPlayerOverlay: View {
    let url: URL?
    let isReady: Bool
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.black
            
            if let url {
                AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.black
                }
            }

            if isReady {
                Button {
                    onPlay()
                } label: {
                    playIcon
                        .background(.regularMaterial, in: .circle)
                        .environment(\.colorScheme, .dark)
                }
                .buttonStyle(PlayButtonStyle())
                .accessibilityLabel("Play")
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var playIcon: some View {
        #if os(macOS)
        Image(systemName: "play.fill")
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
        #else
        Image(systemName: "play.fill")
            .font(.system(size: 32))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
        #endif
    }
}

private struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.5, bounce: 0.4), value: configuration.isPressed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
    }
}

#Preview {
    VideoPlayerOverlay(url: URL(string: ""), isReady: true, onPlay: {})
}
