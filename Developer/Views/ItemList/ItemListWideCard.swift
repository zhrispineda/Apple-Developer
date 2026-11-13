//
//  ItemListWideCard.swift
//  Developer
//

import SwiftUI

struct ItemListWideCard: View {
    let item: ContentItem

    var body: some View {
        HStack(spacing: 16) {
            Color.gray.opacity(0.15)
                .frame(width: 64, height: 64)
                .overlay {
                    if let url = item.squareImageURL {
                        AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let date = item.publishedAt {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minHeight: 96)
        .background(Color.gray.opacity(0.1), in: .rect(cornerRadius: 16))
        .contentShape(.rect)
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
        publishedAt: .now,
        duration: 3540,
        videoURL: URL(string: "https://developer.apple.com/videos/play/wwdc2014/605/"),
        hasLiveStream: false,
        topics: [],
        thumbnailURL: nil,
        cardImageURL: nil,
        posterURL: nil,
        squareImageURL: nil
    )

    ItemListWideCard(item: item)
        .frame(width: 400)
        .padding()
}
