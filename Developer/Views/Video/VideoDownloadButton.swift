//
//  VideoDownloadButton.swift
//  Developer
//

import SwiftUI

/// A view of a download button.
/// Downloading displays progress while also acting as a stop button until complete.
struct VideoDownloadButton: View {
    let session: WWDCSession

    @Environment(DownloadEngine.self) private var downloadStore
    @State private var isConfirmingRemoval = false

    var body: some View {
        Group {
            switch downloadStore.state(for: session.id) {
            case .notDownloaded:
                Button("Download", systemImage: "arrow.down") {
                    downloadStore.download(session)
                }
            case .downloading(let progress):
                Button {
                    downloadStore.cancel(session.id)
                } label: {
                    VideoDownloadIndicatorStateView(progress: progress)
                }
                .accessibilityLabel("Stop Download")
            case .downloaded:
                Button("Remove Download", systemImage: "arrow.down.circle.fill") {
                    isConfirmingRemoval = true
                }
            }
        }
        .removeDownloadConfirmation(isPresented: $isConfirmingRemoval, sessionID: session.id)
    }
}

#Preview {
    VideoDownloadButton(session: WWDCSession(
        id: "wwdc2025-256",
        eventID: "wwdc2025",
        sessionNumber: 256,
        title: "What's new in SwiftUI",
        topics: ["SwiftUI & UI Frameworks"],
        duration: "25:54",
        thumbnailURL: nil,
        url: URL(string: "https://developer.apple.com/videos/play/wwdc2025/256/")!
    ))
    .padding()
    .environment(DownloadEngine())
}
