//
//  DownloadedView.swift
//  Developer
//

import SwiftUI

struct DownloadedView: View {
    @Environment(DownloadEngine.self) private var downloadStore

    var body: some View {
        let sessions = downloadStore.sessions
        FilteredContentView(title: "Downloaded", sessions: sessions)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Videos you download will appear here.")
                    )
                }
            }
    }
}

extension View {
    func removeDownloadConfirmation(isPresented: Binding<Bool>, sessionID: String) -> some View {
        modifier(RemoveDownloadConfirmation(isPresented: isPresented, sessionID: sessionID))
    }

    func downloadErrorAlert() -> some View {
        modifier(DownloadErrorAlert())
    }
}

private struct RemoveDownloadConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let sessionID: String

    @Environment(DownloadEngine.self) private var downloadStore

    private var message: String {
        #if os(macOS)
        "Remove this download from your computer?"
        #else
        "Remove this download from your \(UIDevice.current.localizedModel)?"
        #endif
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(message, isPresented: $isPresented, titleVisibility: .visible) {
            Button("Remove Download", role: .destructive) {
                downloadStore.remove(sessionID)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct DownloadErrorAlert: ViewModifier {
    @Environment(DownloadEngine.self) private var downloadStore

    func body(content: Content) -> some View {
        content.alert(
            "Couldn't Download Video",
            isPresented: Binding { downloadStore.errorMessage != nil } set: { if !$0 { downloadStore.errorMessage = nil } }
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadStore.errorMessage ?? "")
        }
    }
}

#Preview {
    DownloadedView()
}
