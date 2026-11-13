//
//  TranscriptText.swift
//  Developer
//

import SwiftUI

struct TranscriptText: View {
    let paragraph: TranscriptParagraph
    let activeSentenceStart: Double?

    var body: some View {
        Text(attributedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedText: AttributedString {
        paragraph.sentences.reduce(into: AttributedString()) { result, sentence in
            var run = AttributedString(sentence.text + " ")
            run.foregroundColor = sentence.start == activeSentenceStart ? .primary : .secondary
            result += run
        }
    }
}

#Preview {
    TranscriptText(
        paragraph: TranscriptParagraph(sentences: [
            .init(start: 0, text: "Hello and welcome to WWDC."),
            .init(start: 4, text: "Today we're going to talk about what's new in SwiftUI."),
            .init(start: 9, text: "Let's get started.")
        ]),
        activeSentenceStart: 4
    )
    .frame(width: 400)
    .padding()
}
