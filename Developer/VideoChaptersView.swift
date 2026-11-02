//
//  VideoChaptersView.swift
//  Developer
//

import SwiftUI

struct VideoChaptersView: View {
    let chapters: [SessionChapter]
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters")
                .font(.title2.bold())

            VStack(spacing: 0) {
                ForEach(chapters) { chapter in
                    Button {
                        onSeek(chapter.start)
                    } label: {
                        HStack(spacing: 16) {
                            Text(formattedTimestamp(chapter.start))
                                .monospacedDigit()
                                .foregroundStyle(.tint)
                            Text(chapter.title)
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    if chapter.id != chapters.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.1), in: .rect(cornerRadius: 24))
        }
    }
}

#Preview("Chapters card") {
    ScrollView {
        VideoChaptersView(chapters: [
            SessionChapter(start: 0, title: "Introduction"),
            SessionChapter(start: 54, title: "Live Activities on Mac"),
            SessionChapter(start: 103, title: "Define the data model"),
            SessionChapter(start: 171, title: "Build the views"),
        ], onSeek: { _ in })
        .padding()
    }
}
