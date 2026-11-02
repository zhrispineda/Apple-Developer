//
//  ItemListCard.swift
//  Developer
//

import SwiftUI

struct ItemListCard: View {
    let item: ContentItem

    @Environment(ContentStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.gray.opacity(0.15)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if let url = item.cardImageURL {
                        AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    badge.padding(8)
                }

            Text(item.title)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var badge: some View {
        if store.isLive(item) {
            LiveBadge()
        } else if item.videoURL != nil {
            ContentItemImagePlaybackStatusIndicator(session: item.session, progress: progressStore.progress(for: item.id))
        }
    }
}
