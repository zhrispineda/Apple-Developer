//
//  TranscriptPane.swift
//  Developer
//

import SwiftUI

struct TranscriptPane: View {
    let paragraphs: [TranscriptParagraph]?
    let clock: PlaybackClock
    @Binding var isSearching: Bool
    let onSeek: (Double) -> Void

    private struct Match: Equatable {
        let paragraphID: TranscriptParagraph.ID
        let indexInParagraph: Int
    }

    @State private var query = ""
    @State private var matches: [Match] = []
    @State private var currentMatchIndex = 0
    @FocusState private var isSearchFieldFocused: Bool

    private var currentMatch: Match? {
        matches.indices.contains(currentMatchIndex) ? matches[currentMatchIndex] : nil
    }

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
                let searchText = isSearching ? query : ""
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        if isSearching {
                            findBar
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(paragraphs) { paragraph in
                                    TranscriptText(
                                        paragraph: paragraph,
                                        activeSentenceStart: paragraph.id == active?.paragraphID ? active?.sentenceStart : nil,
                                        searchText: searchText,
                                        currentMatchIndex: currentMatch?.paragraphID == paragraph.id ? currentMatch?.indexInParagraph : nil
                                    )
                                    .contentShape(.rect)
                                    .onTapGesture { onSeek(paragraph.start) }
                                    .id(paragraph.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                    .onChange(of: active?.paragraphID) { _, id in
                        guard let id, !isSearching else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: currentMatch) { _, match in
                        guard let match else { return }
                        withAnimation { proxy.scrollTo(match.paragraphID, anchor: .center) }
                    }
                }
                .onChange(of: query, initial: true) { updateMatches(in: paragraphs) }
                .onChange(of: paragraphs) { updateMatches(in: paragraphs) }
                .onChange(of: isSearching) { updateMatches(in: paragraphs) }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var findBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find in Transcript", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onSubmit { showMatch(offset: 1) }
                    .onKeyPress(.escape) {
                        isSearching = false
                        return .handled
                    }

                if !query.isEmpty {
                    Text(matches.count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Button("Clear", systemImage: "xmark.circle.fill") { query = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: .capsule)

            ControlGroup {
                Button("Previous Match", systemImage: "chevron.left") { showMatch(offset: -1) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Next Match", systemImage: "chevron.right") { showMatch(offset: 1) }
                    .keyboardShortcut("g", modifiers: .command)
            }
            .fixedSize()
            .disabled(matches.isEmpty)

            Button("Done") { isSearching = false }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .onAppear { isSearchFieldFocused = true }
    }

    private func updateMatches(in paragraphs: [TranscriptParagraph]) {
        currentMatchIndex = 0
        guard isSearching, !query.isEmpty else {
            matches = []
            return
        }
        matches = paragraphs.flatMap { paragraph in
            let text = TranscriptText.attributedText(for: paragraph, activeSentenceStart: nil)
            let count = TranscriptText.matchRanges(of: query, in: text).count
            return (0..<count).map { Match(paragraphID: paragraph.id, indexInParagraph: $0) }
        }
    }

    private func showMatch(offset: Int) {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + offset + matches.count) % matches.count
    }
}

// MARK: - Find in Transcript Command

struct FindInTranscriptAction: Equatable {
    let sessionID: WWDCSession.ID
    let perform: () -> Void

    func callAsFunction() { perform() }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.sessionID == rhs.sessionID }
}

extension FocusedValues {
    @Entry var findInTranscript: FindInTranscriptAction?
}

struct TranscriptCommands: Commands {
    @FocusedValue(\.findInTranscript) private var findInTranscript

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Button("Find in Transcript…") { findInTranscript?() }
                .keyboardShortcut("f")
                .disabled(findInTranscript == nil)
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
        isSearching: .constant(true),
        onSeek: { _ in }
    )
}

#Preview("Empty") {
    TranscriptPane(paragraphs: [], clock: PlaybackClock(), isSearching: .constant(false), onSeek: { _ in })
}

#Preview("Loading") {
    TranscriptPane(paragraphs: nil, clock: PlaybackClock(), isSearching: .constant(false), onSeek: { _ in })
}
