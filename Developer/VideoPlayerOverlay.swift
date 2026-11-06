//
//  VideoPlayerOverlay.swift
//  Developer
//

import SwiftUI

struct VideoPlayerOverlay: View {
    let url: URL?
    let isReady: Bool
    let onPlay: () -> Void

    var body: some View {
        Button {
            onPlay()
        } label: {
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
                    playIcon
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .clipped()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
        .accessibilityLabel("Play")
    }

    @ViewBuilder
    private var playIcon: some View {
        #if os(macOS)
        Image(systemName: "play.fill")
            .font(.system(size: 40))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 8)
        #else
        Image(systemName: "play.fill")
            .font(.system(size: 32))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(.black.opacity(0.6), in: .circle)
        #endif
    }
}

#Preview {
    VideoPlayerOverlay(url: URL(string: ""), isReady: true, onPlay: {})
}
