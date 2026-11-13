//
//  RelatedVideosSection.swift
//  Developer
//

import SwiftUI

struct RelatedVideosSection: View {
    let relatedVideos: [RelatedVideo]

    @Environment(SessionStore.self) private var store

    var body: some View {
        let related = relatedVideos.compactMap(store.session(for:))
        if !related.isEmpty {
            RelatedVideosView(sessions: related)
                .padding(.top, 32)
        }
    }
}

struct RelatedVideosView: View {
    let sessions: [WWDCSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related")
                .font(.title2.bold())

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    NavigationLink(value: Route.session(session)) {
                        HStack(spacing: 16) {
                            ContentItemThumbnail(session: session, width: 120)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)
                                Text(session.eventName)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sessionContextMenu(for: session)

                    if session.id != sessions.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.1), in: .rect(cornerRadius: 24))
        }
    }
}

#Preview("RelatedVideosView") {
    NavigationStack {
        ScrollView {
            RelatedVideosView(sessions: [
                WWDCSession(
                    id: "wwdc2014-605",
                    eventID: "wwdc2014",
                    sessionNumber: 605,
                    title: "Working with Metal: Advanced",
                    topics: ["Graphics & Games"],
                    duration: "53:52",
                    thumbnailURL: nil,
                    url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!
                ),
                WWDCSession(
                    id: "wwdc2014-604",
                    eventID: "wwdc2014",
                    sessionNumber: 604,
                    title: "Working with Metal: Fundamentals",
                    topics: ["Graphics & Games"],
                    duration: "57:32",
                    thumbnailURL: nil,
                    url: URL(string: "https://developer.apple.com/videos/play/wwdc2014/604/")!
                ),
            ])
            .padding()
        }
    }
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
}

#Preview("RelatedVideosSection") {
    @Previewable @State var store = SessionStore()

    NavigationStack {
        ScrollView {
            RelatedVideosSection(relatedVideos: [
                RelatedVideo(eventID: "wwdc2023", sessionNumber: 10149, title: "Discover Observation in SwiftUI"),
                RelatedVideo(eventID: "wwdc2021", sessionNumber: 10022, title: "Demystify SwiftUI"),
                RelatedVideo(eventID: "wwdc2020", sessionNumber: 10040, title: "Data Essentials in SwiftUI"),
            ])
            .padding()
        }
    }
    .task { await store.load() }
    .asyncImageURLSession(WWDCCache.imageSession)
    .environment(store)
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
}
