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
