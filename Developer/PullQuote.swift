//
//  PullQuote.swift
//  Developer
//

import SwiftUI

struct PullQuote: View {
    let quote: String
    let author: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(markdown: "“\(quote)”")
                .font(.title2.weight(.semibold))
            if let author {
                MarkdownText(markdown: "— \(author)", style: TextStyle(textStyle: "subheadline", color: "secondary"))
            }
        }
        .padding(.leading, 16)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(.tint)
                .frame(width: 3)
        }
        .padding(.vertical, 8)
    }
}
