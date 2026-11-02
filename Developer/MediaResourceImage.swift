//
//  MediaResourceImage.swift
//  Developer
//

import SwiftUI

struct MediaResourceImage: View {
    let resource: MediaResource
    var width: Int = 2048
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(request: URLRequest(url: resource.url(width: width), cachePolicy: .returnCacheDataElseLoad)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .aspectRatio(resource.aspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityElement()
        .accessibilityLabel(resource.accessibilityDescription ?? "")
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(resource.accessibilityDescription == nil)
    }
}
