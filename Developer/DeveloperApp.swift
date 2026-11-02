//
//  DeveloperApp.swift
//  Developer
//

import SwiftUI
import AVFoundation

@main
struct DeveloperApp: App {
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
        }
    }
}
