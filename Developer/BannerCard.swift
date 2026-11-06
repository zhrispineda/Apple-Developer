//
//  BannerCard.swift
//  Developer
//

import SwiftUI

struct BannerCard: View {
    let banner: DiscoverBanner

    @Environment(ContentStore.self) private var store

    var body: some View {
        if let item = banner.itemID.flatMap(store.item(withID:)) {
            ContentItemNavigationLink(item: item) { card }
        } else {
            card
        }
    }

    private var card: some View {
        HStack(spacing: 12) {
            Color.black
                .frame(width: 44, height: 44)
                .overlay {
                    if let url = banner.imageURL {
                        AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.header)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                if !banner.body.isEmpty {
                    Text(banner.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .contentShape(.rect)
    }
}

extension ContentPageView {
    struct BannerSection: View {
        let group: DiscoverBannerGroup

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if let title = group.title, !title.isEmpty {
                    Text(title)
                        .font(.title2.bold())
                }
                switch group.layout {
                case .stack:
                    VStack(spacing: DiscoverMetrics.spacing) {
                        ForEach(group.banners) { BannerCard(banner: $0) }
                    }
                case .grid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: DiscoverMetrics.cardWidth), spacing: DiscoverMetrics.spacing)],
                              spacing: DiscoverMetrics.spacing) {
                        ForEach(group.banners) { BannerCard(banner: $0) }
                    }
                }
            }
            .padding(.horizontal, DiscoverMetrics.margin)
        }
    }
}

#Preview("Banner") {
    BannerCard(banner: DiscoverBanner(
        id: "preview",
        header: "Let us know what you think",
        body: "Share your thoughts on this year's conference.",
        imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/articles/images/185D1D2C-3ECB-43A5-BB02-37BF9686368C/256.jpeg"),
        itemID: nil
    ))
    .padding()
    .environment(ContentStore())
    .environment(NewsStore())
}
