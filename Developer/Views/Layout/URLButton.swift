//
//  URLButton.swift
//  Developer
//

import SwiftUI

/// A view of a URL button that opens links.
struct URLButton: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Text(title)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    URLButton(title: "Example", url: URL(string: "https://apple.com")!)
}
