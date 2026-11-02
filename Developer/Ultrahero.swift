//
//  Ultrahero.swift
//  Developer
//

import SwiftUI

struct Ultrahero: View {
    let hero: DiscoverHero

    @Environment(ContentStore.self) private var store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var isStacked: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        if let item = hero.itemID.flatMap(store.item(withID:)) {
            ContentItemNavigationLink(item: item) { banner }
        } else {
            banner
        }
    }

    private var banner: some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(UltraheroLayout(aspectRatio: hero.aspectRatio))
        return layout {
            if isStacked {
                artwork.aspectRatio(hero.aspectRatio, contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(hero.title)
                    .font(.title.bold())
                    .foregroundStyle(.black)
                Text(hero.body)
                    .font(.title3)
                    .foregroundStyle(.black.opacity(0.65))
            }
            .multilineTextAlignment(.leading)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: isStacked ? nil : .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(white: 0.8), Color(white: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            if !isStacked { artwork }
        }
        .frame(maxWidth: .infinity)
        .background(.black)
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect)
    }

    private var artwork: some View {
        Color.black
            .overlay {
                if let url = hero.imageURL {
                    AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                }
            }
            .clipped()
    }
}

#Preview("Hero") {
    Ultrahero(hero: DiscoverHero(
        title: "Say hello to Touch on Mac",
        body: "Watch new developer videos, sign up for Group\u{00A0}Labs, and check out new articles and resources.",
        imageURL: URL(string: "https://devimages-cdn.apple.com/wwdc-services/articles/images/4310983B-86A3-4D1D-A9C3-1292AFFCAB35/2048.jpeg"),
        aspectRatio: 1.78,
        itemID: nil
    ))
    .padding()
    .environment(ContentStore())
    #if os(macOS)
    .frame(width: 1200)
    #endif
}
