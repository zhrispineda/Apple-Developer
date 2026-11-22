//
//  DeveloperApp.swift
//  Developer
//

import SwiftUI
import AVFoundation

@main
struct DeveloperApp: App {
    /// Shared between the main window and the Settings window.
    @State private var sessionStore = SessionStore()

    init() {
        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
        }
        .commands {
            TranscriptCommands()
        }
        #if !os(macOS)
        .backgroundTask(.urlSession(DownloadEngine.backgroundSessionIdentifier)) {
            await DownloadEngine.shared.handleBackgroundEvents()
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(sessionStore)
        }
        #endif
    }
}
