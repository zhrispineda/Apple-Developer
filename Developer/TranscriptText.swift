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
