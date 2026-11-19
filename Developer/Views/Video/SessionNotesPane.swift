//
//  SessionNotesPane.swift
//  Developer
//

import SwiftUI

/// The Notes tab of a session video: a Markdown editor with a rendered preview.
/// Timestamps such as `5:41` in the preview jump the video to that time.
struct SessionNotesPane: View {
    let sessionID: String
    let clock: PlaybackClock
    let onSeek: (Double) -> Void

    @Environment(NotesStore.self) private var notesStore
    @State private var isEditing = false
    @State private var selection: TextSelection?
    @FocusState private var isEditorFocused: Bool

    private var text: Binding<String> {
        Binding { notesStore.text(for: sessionID) } set: { notesStore.setText($0, for: sessionID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            if isEditing {
                editor
            } else {
                Divider()
                preview
            }
        }
        .onAppear { isEditing = !notesStore.hasNote(for: sessionID) }
        .onChange(of: sessionID) { isEditing = !notesStore.hasNote(for: sessionID) }
        .onDisappear { notesStore.syncToCloud() }
    }

    private var controls: some View {
        HStack {
            if isEditing {
                Button("Insert Timestamp", systemImage: "clock") {
                    insertTimestamp()
                }
                .help("Insert the current playback time")
            } else {
                Text("Tap a timestamp to jump to it")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
                isEditorFocused = isEditing
                if !isEditing { notesStore.syncToCloud() }
            }
            .fontWeight(.semibold)
            .disabled(isEditing && !notesStore.hasNote(for: sessionID))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    /// Where the text editor draws its first line within its frame. iOS insets the
    /// text; the Mac only pads the line horizontally. The placeholder matches these.
    #if os(macOS)
    private static let editorTextInset = EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
    #else
    private static let editorTextInset = EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)
    #endif
    private static let fieldPadding: CGFloat = 10

    private var editor: some View {
        TextEditor(text: text, selection: $selection)
            .font(.body)
            .focused($isEditorFocused)
            .scrollContentBackground(.hidden)
            .padding(Self.fieldPadding)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text("Write notes using Markdown: **bold**, *italic*, # headings, - lists, and timestamps like 5:41.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(Self.editorTextInset)
                        .padding(Self.fieldPadding)
                        .allowsHitTesting(false)
                }
            }
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isEditorFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), lineWidth: 1)
            }
            .padding(.horizontal)
            .padding(.bottom)
    }

    private var preview: some View {
        ScrollView {
            MarkdownNoteView(markdown: text.wrappedValue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .environment(\.openURL, OpenURLAction { url in
            if let seconds = NoteTimestamp.seconds(from: url) {
                onSeek(seconds)
                return .handled
            }
            return .systemAction
        })
    }

    private func insertTimestamp() {
        var note = text.wrappedValue
        let stamp = formattedTimestamp(clock.currentTime) + " "
        if case .selection(let range) = selection?.indices,
           range.lowerBound >= note.startIndex, range.upperBound <= note.endIndex {
            let offset = note.distance(from: note.startIndex, to: range.lowerBound)
            note.replaceSubrange(range, with: stamp)
            let cursor = note.index(note.startIndex, offsetBy: offset + stamp.count)
            text.wrappedValue = note
            selection = TextSelection(insertionPoint: cursor)
        } else {
            if !note.isEmpty && !note.hasSuffix("\n") { note += "\n" }
            text.wrappedValue = note + stamp
        }
        isEditorFocused = true
    }
}

// MARK: - Timestamps

enum NoteTimestamp {
    private static let scheme = "developer-note-timestamp"

    nonisolated(unsafe) private static let pattern = /\b(?:(\d{1,2}):)?(\d{1,2}):([0-5]\d)\b/

    static func url(for seconds: Int) -> URL? {
        URL(string: "\(scheme):\(seconds)")
    }

    static func seconds(from url: URL) -> Double? {
        guard url.scheme == scheme else { return nil }
        return Double(url.absoluteString.dropFirst(scheme.count + 1))
    }

    static func linkTimestamps(in string: inout AttributedString) {
        let plain = String(string.characters)
        for match in plain.matches(of: pattern) {
            let (_, hours, minutes, secs) = match.output
            guard let minutes = Int(minutes), let secs = Int(secs) else { continue }
            let hourValue = hours.flatMap { Int($0) } ?? 0
            if hours != nil && minutes >= 60 { continue }
            if plain[match.range.upperBound...].first == ":" { continue }
            if match.range.lowerBound > plain.startIndex,
               plain[plain.index(before: match.range.lowerBound)] == ":" { continue }
            guard let url = url(for: hourValue * 3600 + minutes * 60 + secs) else { continue }

            let start = plain.distance(from: plain.startIndex, to: match.range.lowerBound)
            let length = plain.distance(from: match.range.lowerBound, to: match.range.upperBound)
            let lower = string.characters.index(string.startIndex, offsetBy: start)
            let upper = string.characters.index(lower, offsetBy: length)
            let range = lower..<upper

            let isCode = string[range].inlinePresentationIntent?.contains(.code) ?? false
            guard string[range].link == nil, !isCode else { continue }
            string[range].link = url
        }
    }
}

// MARK: - Markdown Rendering

/// Renders block-level Markdown (headings, lists, quotes, code blocks, rules) for notes.
/// `Text` only supports inline Markdown, so blocks are laid out here and each block's
/// inline content is styled with `AttributedString`.
struct MarkdownNoteView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(MarkdownBlock.parse(markdown)) { block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 6 : 2)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(Self.inline(text))
        case .listItem(let marker, let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch marker {
                case .bullet:
                    Text(verbatim: "•")
                case .number(let number):
                    Text(verbatim: "\(number).").monospacedDigit()
                case .task(let isDone):
                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                Text(Self.inline(text))
                    .strikethrough(marker == .task(isDone: true))
                    .foregroundStyle(marker == .task(isDone: true) ? .secondary : .primary)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .quote(let text):
            HStack(spacing: 10) {
                Capsule()
                    .fill(.tint)
                    .frame(width: 3)
                Text(Self.inline(text))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let code):
            ScrollView(.horizontal) {
                Text(verbatim: code)
                    .font(.callout.monospaced())
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8))
        case .rule:
            Divider()
        }
    }

    private static func inline(_ text: String) -> AttributedString {
        var string = MarkdownText.attributedString(from: text)
        NoteTimestamp.linkTimestamps(in: &string)
        return string
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        default: .headline
        }
    }
}

struct MarkdownBlock: Identifiable {
    enum ListMarker: Equatable {
        case bullet, number(String), task(isDone: Bool)
    }

    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case listItem(ListMarker, text: String, indent: Int)
        case quote(String)
        case code(String)
        case rule
    }

    let id: Int
    let kind: Kind

    /// The note's text without Markdown syntax, for one-line previews.
    static func plainText(_ markdown: String) -> String {
        parse(markdown).compactMap { block -> String? in
            switch block.kind {
            case .heading(_, let text), .paragraph(let text), .listItem(_, let text, _), .quote(let text):
                String(MarkdownText.attributedString(from: text).characters)
            case .code(let code):
                code
            case .rule:
                nil
            }
        }
        .joined(separator: " ")
        .replacing("\n", with: " ")
    }

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var kinds: [Kind] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]?

        func flush() {
            if !paragraph.isEmpty { kinds.append(.paragraph(paragraph.joined(separator: "\n"))) }
            if !quote.isEmpty { kinds.append(.quote(quote.joined(separator: "\n"))) }
            paragraph = []
            quote = []
        }

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks keep their lines verbatim.
            if trimmed.hasPrefix("```") {
                if let lines = code {
                    kinds.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    flush()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(line)
                continue
            }

            let indent = line.prefix { $0 == " " || $0 == "\t" }
                .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2

            if trimmed.isEmpty {
                flush()
            } else if let match = trimmed.wholeMatch(of: /(#{1,6})\s+(.*)/) {
                flush()
                kinds.append(.heading(level: match.1.count, text: String(match.2)))
            } else if trimmed.wholeMatch(of: /(-\s*){3,}|(\*\s*){3,}|(_\s*){3,}/) != nil {
                flush()
                kinds.append(.rule)
            } else if let match = trimmed.wholeMatch(of: /[-*+]\s+\[([ xX])\]\s+(.*)/) {
                flush()
                kinds.append(.listItem(.task(isDone: match.1 != " "), text: String(match.2), indent: indent))
            } else if let match = trimmed.wholeMatch(of: /[-*+]\s+(.*)/) {
                flush()
                kinds.append(.listItem(.bullet, text: String(match.1), indent: indent))
            } else if let match = trimmed.wholeMatch(of: /(\d+)[.)]\s+(.*)/) {
                flush()
                kinds.append(.listItem(.number(String(match.1)), text: String(match.2), indent: indent))
            } else if let match = trimmed.wholeMatch(of: />\s?(.*)/) {
                if !paragraph.isEmpty { flush() }
                quote.append(String(match.1))
            } else {
                if !quote.isEmpty { flush() }
                paragraph.append(trimmed)
            }
        }
        if let code { kinds.append(.code(code.joined(separator: "\n"))) }
        flush()

        return kinds.enumerated().map { MarkdownBlock(id: $0.offset, kind: $0.element) }
    }
}

#Preview("Markdown") {
    ScrollView {
        MarkdownNoteView(markdown: """
        # Metal Notes
        Key ideas from **Working with Metal**, see `MTLDevice`.

        ## Timestamps
        - 5:41 Command buffers
        - 1:05:41 Wrap-up
        - [x] Watch intro
        - [ ] Try the sample
          - Nested item

        > Prefer argument buffers.

        1. First
        2. Second

        ---

        ```swift
        let device = MTLCreateSystemDefaultDevice()
        ```
        """)
        .padding()
    }
}
