//
//  RelatedResourceRow.swift
//  Developer
//

import SwiftUI

struct RelatedResourceRow: View {
    let resource: ContentResource

    private var systemImage: String {
        switch resource.type {
        case "samplecode": "chevron.left.forwardslash.chevron.right"
        case "download": "arrow.down.circle"
        case "guide": "book"
        case "developerForum": "bubble.left.and.bubble.right"
        default: "doc.text"
        }
    }

    var body: some View {
        Link(destination: resource.url) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title)
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if let summary = resource.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    List {
        RelatedResourceRow(resource: ContentResource(
            id: 1,
            title: "Building a document-based app with SwiftUI",
            url: URL(string: "https://developer.apple.com/documentation/swiftui")!,
            type: "samplecode",
            summary: "Create, save, and open documents in a multiplatform app."
        ))
        RelatedResourceRow(resource: ContentResource(
            id: 2,
            title: "Human Interface Guidelines",
            url: URL(string: "https://developer.apple.com/design/human-interface-guidelines")!,
            type: "guide",
            summary: nil
        ))
        RelatedResourceRow(resource: ContentResource(
            id: 3,
            title: "Developer Forums",
            url: URL(string: "https://developer.apple.com/forums")!,
            type: "developerForum",
            summary: "Ask questions and discuss topics with other developers."
        ))
    }
}
