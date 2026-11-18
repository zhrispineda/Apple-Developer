//
//  CodeSnippetsPane.swift
//  Developer
//

import SwiftUI

struct CodeSnippetsPane: View {
    let samples: [CodeSample]
    let onSeek: (Double) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(samples) { sample in
                    Button {
                        onSeek(sample.start)
                    } label: {
                        Text("\(Text(formattedTimestamp(sample.start)).foregroundStyle(.tint)) - \(sample.title)")
                            .foregroundStyle(Color.primary)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    CodeSnippet(sample: sample)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

#Preview {
    CodeSnippetsPane(samples: [
        CodeSample(start: 92, title: "Declare an observable model", tokens: [
            .init(text: "@Observable", kind: "attr"),
            .init(text: "\n", kind: nil),
            .init(text: "class", kind: "keyword"),
            .init(text: " ", kind: nil),
            .init(text: "Library", kind: "title"),
            .init(text: " {\n    ", kind: nil),
            .init(text: "var", kind: "keyword"),
            .init(text: " books: [", kind: nil),
            .init(text: "Book", kind: "type"),
            .init(text: "] = []\n}", kind: nil)
        ]),
        CodeSample(start: 245, title: "Display the books in a list", tokens: [
            .init(text: "// Each row shows the book's title", kind: "comment"),
            .init(text: "\n", kind: nil),
            .init(text: "List", kind: "type"),
            .init(text: "(library.books) { book ", kind: nil),
            .init(text: "in", kind: "keyword"),
            .init(text: "\n    ", kind: nil),
            .init(text: "Text", kind: "type"),
            .init(text: "(book.title)\n        .", kind: nil),
            .init(text: "padding", kind: "function"),
            .init(text: "(", kind: nil),
            .init(text: "8", kind: "number"),
            .init(text: ")\n}", kind: nil)
        ])
    ]) { time in
        print("Seek to \(time)")
    }
}
