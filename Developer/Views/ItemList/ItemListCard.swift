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

#Preview {
    let item = ContentItem(
        id: "wwdc2014-605",
        eventID: "wwdc2014",
        eventName: "WWDC14",
        number: 605,
        type: "Video",
        title: "Advanced Graphics and Animations for iOS Apps",
        summary: "Hello",
        webURL: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/")!,
        startTime: nil,
        endTime: nil,
        publishedAt: nil,
        duration: 3540,
        videoURL: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/"),
        hasLiveStream: false,
        topics: [],
        thumbnailURL: nil,
        cardImageURL: nil,
        posterURL: nil,
        squareImageURL: nil
    )

    ItemListCard(item: item)
        .frame(width: 320)
        .padding()
        .environment(ContentStore())
        .environment(WatchProgressStore())
}
