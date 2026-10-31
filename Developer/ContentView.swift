//
//  ContentView.swift
//  Developer
//

import SwiftUI

struct ContentView: View {
    @State private var store = SessionStore()
    
    var body: some View {
        Group {
            // First Launch:
            // Nothing is cached yet, showing a first-launch-only
            // `Compiling…` ProgressView while the app initiates
            if !store.hasCompletedInitialLoad {
                ProgressView("Compiling…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(macOS)
                    // Same minimum as the main layout, so the window doesn't open small.
                    .frame(minWidth: 900, minHeight: 560)
                    #endif
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView()
}
