//
//  TranscriptText.swift
//  Developer
//

import SwiftUI

struct TranscriptText: View {
    let paragraph: TranscriptParagraph
    let activeSentenceStart: Double?
    var searchText: String = ""
    /// Index of the current find match within this paragraph, if it's in this paragraph.
    var currentMatchIndex: Int?

    var body: some View {
        Text(attributedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedText: AttributedString {
        var text = Self.attributedText(for: paragraph, activeSentenceStart: activeSentenceStart)
        for (index, range) in Self.matchRanges(of: searchText, in: text).enumerated() {
            if index == currentMatchIndex {
                text[range].backgroundColor = .yellow
                text[range].foregroundColor = .black
            } else {
                text[range].backgroundColor = .yellow.opacity(0.3)
            }
        }
        return text
    }

    static func attributedText(for paragraph: TranscriptParagraph, activeSentenceStart: Double?) -> AttributedString {
        paragraph.sentences.reduce(into: AttributedString()) { result, sentence in
            var run = AttributedString(sentence.text + " ")
            run.foregroundColor = sentence.start == activeSentenceStart ? .primary : .secondary
            result += run
        }
    }

    static func matchRanges(of query: String, in text: AttributedString) -> [Range<AttributedString.Index>] {
        guard !query.isEmpty else { return [] }
        var ranges: [Range<AttributedString.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text[searchStart...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }
}

#Preview {
    TranscriptText(
        paragraph: TranscriptParagraph(sentences: [
            .init(start: 0, text: "Hello and welcome to WWDC."),
            .init(start: 4, text: "Today we're going to talk about what's new in SwiftUI."),
            .init(start: 9, text: "Let's get started.")
        ]),
        activeSentenceStart: 4,
        searchText: "to",
        currentMatchIndex: 1
    )
    .frame(width: 400)
    .padding()
}
