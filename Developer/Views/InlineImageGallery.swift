//
//  InlineImageGallery.swift
//  Developer
//

import SwiftUI

struct InlineImageGallery: View {
    let images: [MediaResource]

    private static let height: CGFloat = 220

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(images, id: \.baseURL) { image in
                    VStack(alignment: .leading, spacing: 6) {
                        MediaResourceImage(resource: image, width: 1024)
                            .frame(height: Self.height)
                        if !image.caption.isEmpty {
                            MarkdownText(markdown: image.caption, style: TextStyle(textStyle: "caption", color: "secondary"))
                                .frame(width: Self.height * image.aspectRatio, alignment: .leading)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    let baseURL = URL(string: "https://devimages-cdn.apple.com/wwdc-services/articles/images/4310983B-86A3-4D1D-A9C3-1292AFFCAB35")!

    InlineImageGallery(images: [
        MediaResource(
            baseURL: baseURL,
            aspectRatio: 16 / 9,
            caption: "A caption with **bold** text.",
            accessibilityDescription: "Preview image"
        ),
        MediaResource(
            baseURL: baseURL.appending(path: "square"),
            aspectRatio: 1,
            caption: "",
            accessibilityDescription: nil
        ),
        MediaResource(
            baseURL: baseURL.appending(path: "portrait"),
            aspectRatio: 3 / 4,
            caption: "A longer caption that wraps across multiple lines beneath a portrait image.",
            accessibilityDescription: nil
        )
    ])
    .padding()
}
