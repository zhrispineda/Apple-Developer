//
//  VideoDownloadButton.swift
//  Developer
//

import SwiftUI

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
