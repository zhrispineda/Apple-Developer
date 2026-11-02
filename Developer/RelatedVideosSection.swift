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
