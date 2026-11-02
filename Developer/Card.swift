//
//  Card.swift
//  Developer
//

import SwiftUI

struct Card: View {
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var url: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if !message.isEmpty {
                MarkdownText(markdown: message, style: TextStyle(color: "secondary"))
            }
            if let buttonTitle, let url {
                URLButton(title: buttonTitle, url: url)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }
}
