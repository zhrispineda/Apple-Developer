//
//  TranscriptPane.swift
//  Developer
//

import SwiftUI

struct TranscriptPane: View {
    let paragraphs: [TranscriptParagraph]?
    let clock: PlaybackClock
    let onSeek: (Double) -> Void

    private func activePosition(in paragraphs: [TranscriptParagraph]) -> (paragraphID: TranscriptParagraph.ID, sentenceStart: Double)? {
        let currentTime = clock.currentTime
        guard currentTime > 0,
              let paragraph = paragraphs.last(where: { $0.start <= currentTime }),
              let sentence = paragraph.sentences.last(where: { $0.start <= currentTime })
        else { return nil }
        return (paragraph.id, sentence.start)
    }

    var body: some View {
        if let paragraphs {
            if paragraphs.isEmpty {
                ContentUnavailableView(
                    "No Transcript",
                    systemImage: "text.page.slash",
                    description: Text("This session doesn't have a transcript.")
                )
            } else {
                let active = activePosition(in: paragraphs)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(paragraphs) { paragraph in
                                TranscriptText(
                                    paragraph: paragraph,
                                    activeSentenceStart: paragraph.id == active?.paragraphID ? active?.sentenceStart : nil
                                )
                                .contentShape(.rect)
                                .onTapGesture { onSeek(paragraph.start) }
                                .id(paragraph.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .onChange(of: active?.paragraphID) { _, id in
                        guard let id else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    let clock = PlaybackClock()
    clock.currentTime = 12
    return TranscriptPane(
        paragraphs: [
            TranscriptParagraph(sentences: [
                .init(start: 0, text: "Hello and welcome to WWDC."),
                .init(start: 4, text: "Today we're going to talk about what's new in SwiftUI.")
            ]),
            TranscriptParagraph(sentences: [
                .init(start: 10, text: "Let's start with a quick look at the transcript pane."),
                .init(start: 14, text: "Tap any paragraph to jump to that point in the video.")
            ]),
            TranscriptParagraph(sentences: [
                .init(start: 20, text: "The active sentence is highlighted as the video plays."),
                .init(start: 25, text: "And the pane scrolls to keep it in view.")
            ])
        ],
        clock: clock,
        onSeek: { _ in }
    )
}

#Preview("Empty") {
    TranscriptPane(paragraphs: [], clock: PlaybackClock(), onSeek: { _ in })
}

#Preview("Loading") {
    TranscriptPane(paragraphs: nil, clock: PlaybackClock(), onSeek: { _ in })
}
