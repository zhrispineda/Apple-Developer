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
