//
//  SettingsView.swift
//  Developer
//

import SwiftUI

enum SettingsKey {
    static let prefersHDVideo = "prefersHDVideo"
    static let streamsOnPersonalHotspot = "streamsOnPersonalHotspot"
    static let downloadsOnPersonalHotspot = "downloadsOnPersonalHotspot"
    static let sendsDiagnostics = "sendsDiagnostics"
    static let notifiesAboutNewsHighlights = "notifiesAboutNewsHighlights"
    static let notifiesAboutFeaturedStories = "notifiesAboutFeaturedStories"
    static let notifiesAboutWWDC = "notifiesAboutWWDC"
    static let notifiesAboutTechTalks = "notifiesAboutTechTalks"
}
#if os(macOS)
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            
            Tab("Notifications", systemImage: "bell.badge") {
                NotificationSettingsView()
            }
            
            Tab("Preferred Topics", systemImage: "square.grid.3x3.fill") {
                PreferredTopicsSettingsPane()
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.prefersHDVideo) private var prefersHDVideo = true
    @AppStorage(SettingsKey.streamsOnPersonalHotspot) private var streamsOnPersonalHotspot = false
    @AppStorage(SettingsKey.downloadsOnPersonalHotspot) private var downloadsOnPersonalHotspot = false
    @AppStorage(SettingsKey.sendsDiagnostics) private var sendsDiagnostics = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Prefer HD videos", isOn: $prefersHDVideo)

            Divider()

            Toggle("Stream videos while using a Personal Hotspot", isOn: $streamsOnPersonalHotspot)
            Toggle("Download videos while using a Personal Hotspot", isOn: $downloadsOnPersonalHotspot)

            Divider()

            Toggle("Automatically send diagnostics and usage", isOn: $sendsDiagnostics)
            Text("Help Apple improve the Developer app by automatically sending diagnostic and usage data. For details, see the updated Software License Agreement in the Help menu.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsPane()
    }
}

private struct NotificationSettingsView: View {
    @AppStorage(SettingsKey.notifiesAboutNewsHighlights) private var newsHighlights = true
    @AppStorage(SettingsKey.notifiesAboutFeaturedStories) private var featuredStories = true
    @AppStorage(SettingsKey.notifiesAboutWWDC) private var wwdc = true
    @AppStorage(SettingsKey.notifiesAboutTechTalks) private var techTalks = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send me notifications about:")
            Toggle("News Highlights", isOn: $newsHighlights)
            Toggle("Featured Stories", isOn: $featuredStories)
            Toggle("WWDC", isOn: $wwdc)
            Toggle("Tech Talks", isOn: $techTalks)

            Spacer()
                .frame(height: 40)

            Text("If you’re signed in to the Apple Developer app, your notification settings are synchronized across all devices where you’re signed in with the same Apple Account. If you’re not signed in, notification settings are per device.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsPane()
    }
}

private struct PreferredTopicsSettingsPane: View {
    @Environment(SessionStore.self) private var store
    @AppStorage(PreferredTopics.storageKey) private var preferredTopicsStorage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose which topics to include in lists when the filter is active:")
            Table(store.topics) {
                TableColumn("Preferred Topics") { topic in
                    Toggle(isOn: PreferredTopics.binding(for: topic, in: $preferredTopicsStorage)) {
                        Label(topic.name, systemImage: topic.systemImage)
                    }
                }
            }
            .tableStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 290)
        }
        .settingsPane()
    }
}

private extension View {
    func settingsPane() -> some View {
        frame(width: 420, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
    }
}

#Preview {
    SettingsView()
        .environment(SessionStore())
}
#endif
