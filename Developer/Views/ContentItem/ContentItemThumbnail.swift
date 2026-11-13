//
//  ContentItemThumbnail.swift
//  Developer
//

import SwiftUI

struct ContentItemThumbnail: View {
    let url: URL?
    let width: CGFloat

    init(url: URL?, width: CGFloat) {
        self.url = url
        self.width = width
    }

    init(session: WWDCSession, width: CGFloat) {
        self.init(url: session.thumbnailURL, width: width)
    }

    var body: some View {
        Group {
            if let thumbnailURL = url {
                AsyncImage(request: URLRequest(url: thumbnailURL, cachePolicy: .returnCacheDataElseLoad)) { image in
                    image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: width, height: width * 9 / 16)
        .clipShape(.rect(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

#Preview("Thumbnail") {
    HStack(spacing: 16) {
        ContentItemThumbnail(
            url: URL(string: "https://devimages-cdn.apple.com/wwdc-services/articles/images/4310983B-86A3-4D1D-A9C3-1292AFFCAB35/2048.jpeg"),
            width: 160
        )
        ContentItemThumbnail(url: nil, width: 160)
    }
    .padding()
}
