//
//  LibraryView.swift
//  Developer
//

import SwiftUI

struct LibraryView: View {
    /// False in the sidebar layout, where the detail column already provides the stack.
    var embedsInNavigationStack = true

    @Environment(SessionStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(NotesStore.self) private var notesStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var isCreatingPlaylist = false
    @State private var renamingPlaylist: Playlist?

    private static let recentHistoryLimit = 5
    private static let recentHistoryCardLimit = 12
    private static let noteCardLimit = 6

    /// The Mac and wide iPad get a card layout; iPhone keeps a compact list.
    private var usesCardLayout: Bool {
        #if os(macOS)
        true
        #elseif os(iOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack {
                content
                    .navigationDestination(for: Route.self) { RouteView(route: $0) }
            }
        } else {
            content
        }
    }

    private var content: some View {
        let sections = LibrarySections(
            history: store.sessions(orderedByIDs: progressStore.historySessionIDs),
            bookmarked: store.sessions(withIDs: bookmarkStore.bookmarkedIDs),
            noted: store.sessions(orderedByIDs: notesStore.sessionIDsWithNotes)
        )

        return Group {
            if usesCardLayout {
                cardLayout(sections)
            } else {
                listLayout(sections)
            }
        }
        .navigationTitle("Library")
        .playlistTitleAlert("New Playlist", isPresented: $isCreatingPlaylist, confirmLabel: "Create") {
            playlistStore.create(title: $0)
        }
        .playlistTitleAlert(
            "Rename Playlist",
            isPresented: Binding { renamingPlaylist != nil } set: { if !$0 { renamingPlaylist = nil } },
            initialTitle: renamingPlaylist?.title ?? "",
            confirmLabel: "Rename"
        ) { title in
            if let renamingPlaylist { playlistStore.rename(renamingPlaylist.id, to: title) }
        }
    }

    @ViewBuilder
    private func playlistActions(for playlist: Playlist) -> some View {
        Button("Rename", systemImage: "pencil") { renamingPlaylist = playlist }
        Button("Delete Playlist", systemImage: "trash", role: .destructive) {
            playlistStore.delete(playlist.id)
        }
    }

    // MARK: Card layout (Mac, iPad)

    private func cardLayout(_ sections: LibrarySections) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    NavigationLink(value: Route.library(.history)) {
                        LibrarySummaryTile(title: "History", systemImage: "clock.arrow.circlepath", count: sections.history.count)
                    }
                    NavigationLink(value: Route.library(.bookmarks)) {
                        LibrarySummaryTile(title: "Bookmarks", systemImage: "bookmark", count: sections.bookmarked.count)
                    }
                    NavigationLink(value: Route.library(.notes)) {
                        LibrarySummaryTile(title: "Notes", systemImage: "note.text", count: sections.noted.count)
                    }
                }

                playlistsCardSection

                if !sections.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        cardSectionHeader("Recently Watched", seeAll: .library(.history))
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(sections.history.prefix(Self.recentHistoryCardLimit)) { session in
                                    NavigationLink(value: Route.session(session)) {
                                        FilteredContentGridCell(entry: .video(session), width: 220)
                                    }
                                    .sessionContextMenu(for: session)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                    }
                }

                if !sections.noted.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        cardSectionHeader("Notes", seeAll: sections.noted.count > Self.noteCardLimit ? .library(.notes) : nil)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16)], spacing: 16) {
                            ForEach(sections.noted.prefix(Self.noteCardLimit)) { session in
                                NavigationLink(value: Route.session(session)) {
                                    NoteCard(session: session, note: notesStore.note(for: session.id))
                                }
                                .sessionContextMenu(for: session)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var playlistsCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                cardSectionTitle("Playlists")
                Spacer()
                Button("New Playlist", systemImage: "plus") { isCreatingPlaylist = true }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16, alignment: .top)], alignment: .leading, spacing: 20) {
                ForEach(playlistStore.playlists) { playlist in
                    NavigationLink(value: Route.library(.playlist(playlist.id))) {
                        PlaylistCard(
                            playlist: playlist,
                            sessions: Array(store.sessions(orderedByIDs: playlist.sessionIDs).prefix(4))
                        )
                    }
                    .contextMenu { playlistActions(for: playlist) }
                }

                if playlistStore.playlists.isEmpty {
                    Button { isCreatingPlaylist = true } label: {
                        NewPlaylistCard()
                    }
                }
            }
        }
    }

    private func cardSectionHeader(_ title: LocalizedStringKey, seeAll destination: Route?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            cardSectionTitle(title)
            Spacer()
            if let destination {
                NavigationLink("See All", value: destination)
                    .foregroundStyle(.tint)
            }
        }
    }

    private func cardSectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title2.bold())
    }

    // MARK: List layout (iPhone)

    private func listLayout(_ sections: LibrarySections) -> some View {
        List {
            Section {
                NavigationLink(value: Route.library(.history)) {
                    row("History", systemImage: "clock.arrow.circlepath", count: sections.history.count)
                }
                NavigationLink(value: Route.library(.bookmarks)) {
                    row("Bookmarks", systemImage: "bookmark", count: sections.bookmarked.count)
                }
                NavigationLink(value: Route.library(.notes)) {
                    row("Notes", systemImage: "note.text", count: sections.noted.count)
                }
            }

            Section("Playlists") {
                ForEach(playlistStore.playlists) { playlist in
                    NavigationLink(value: Route.library(.playlist(playlist.id))) {
                        row(playlist.title, systemImage: "list.and.film", count: playlist.sessionIDs.count)
                    }
                    .contextMenu { playlistActions(for: playlist) }
                }
                .onDelete { offsets in
                    offsets.map { playlistStore.playlists[$0].id }.forEach(playlistStore.delete)
                }

                Button("New Playlist", systemImage: "plus") {
                    isCreatingPlaylist = true
                }
            }

            // A session can appear in both sections below, so each section
            // scopes its row identity; otherwise the list mixes up the rows.
            if !sections.noted.isEmpty {
                Section("Notes") {
                    ForEach(sections.noted, id: \.notesRowID) { session in
                        NavigationLink(value: Route.session(session)) {
                            NoteRow(session: session, note: notesStore.text(for: session.id))
                        }
                        .sessionContextMenu(for: session)
                    }
                    .onDelete { offsets in
                        offsets.map { sections.noted[$0].id }.forEach(notesStore.deleteNote(for:))
                    }
                }
            }

            if !sections.history.isEmpty {
                Section("Recently Watched") {
                    ForEach(sections.history.prefix(Self.recentHistoryLimit), id: \.historyRowID) { session in
                        NavigationLink(value: Route.session(session)) {
                            ContentItemRow(session: session)
                        }
                        .sessionContextMenu(for: session)
                    }
                }
            }
        }
    }

    private func row(_ title: String, systemImage: String, count: Int) -> some View {
        LabeledContent {
            Text(count, format: .number)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct LibrarySections {
    let history: [WWDCSession]
    let bookmarked: [WWDCSession]
    let noted: [WWDCSession]
}

private extension WWDCSession {
    var notesRowID: String { "notes-\(id)" }
    var historyRowID: String { "history-\(id)" }
}

// MARK: - Cards

/// A tile with a symbol, a title and a count.
private struct LibrarySummaryTile: View {
    let title: LocalizedStringKey
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(count, format: .number)
                .font(.title2.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

/// Shows up to four of a playlist's thumbnails as artwork, with its title and video count.
private struct PlaylistCard: View {
    let playlist: Playlist
    let sessions: [WWDCSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { artwork }
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("^[\(playlist.sessionIDs.count) video](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var artwork: some View {
        if sessions.count >= 4 {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    FillImage(url: sessions[0].thumbnailURL)
                    FillImage(url: sessions[1].thumbnailURL)
                }
                GridRow {
                    FillImage(url: sessions[2].thumbnailURL)
                    FillImage(url: sessions[3].thumbnailURL)
                }
            }
        } else if let first = sessions.first {
            FillImage(url: first.thumbnailURL)
        } else {
            Rectangle()
                .fill(Color.accentColor.gradient)
                .overlay {
                    Image(systemName: "list.and.film")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.9))
                }
        }
    }
}

private struct NewPlaylistCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("New Playlist")
                    .font(.headline)
                // Keeps the title aligned with the playlist cards beside it.
                Text(verbatim: " ")
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }
}

/// A session thumbnail beside a preview of its note.
private struct NoteCard: View {
    let session: WWDCSession
    let note: SessionNote?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ContentItemThumbnail(session: session, width: 128)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.eventName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(session.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let note {
                    Text(MarkdownBlock.plainText(note.text))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Text("Edited \(note.updatedAt, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
        .contentShape(.rect(cornerRadius: 14))
    }
}

/// A thumbnail that fills whatever space it's given.
private struct FillImage: View {
    let url: URL?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let url {
                    AsyncImage(request: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipped()
    }
}

/// A session row with a preview of its note underneath.
private struct NoteRow: View {
    let session: WWDCSession
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ContentItemRow(session: session)
            Label {
                Text(MarkdownBlock.plainText(note))
                    .lineLimit(2)
            } icon: {
                Image(systemName: "note.text")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Destinations

/// Every video that has been played, finished or not, most recently watched first.
struct HistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(WatchProgressStore.self) private var progressStore

    var body: some View {
        let sessions = store.sessions(orderedByIDs: progressStore.historySessionIDs)
        FilteredContentView(
            title: "History",
            sessions: sessions,
            removeAction: .init(title: "Remove from History") { entry in
                progressStore.removeFromHistory(sessionID: entry.id)
            }
        )
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Videos you watch will appear here.")
                )
            }
        }
    }
}

struct BookmarkedVideosView: View {
    @Environment(SessionStore.self) private var store
    @Environment(SynchronizedListManager.self) private var bookmarkStore

    var body: some View {
        let sessions = store.sessions(withIDs: bookmarkStore.bookmarkedIDs)
        FilteredContentView(title: "Bookmarks", sessions: sessions)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Touch and hold a video, then choose Add to Bookmarks.")
                    )
                }
            }
    }
}

/// Videos with notes, most recently edited first.
struct NotedVideosView: View {
    @Environment(SessionStore.self) private var store
    @Environment(NotesStore.self) private var notesStore

    var body: some View {
        let sessions = store.sessions(orderedByIDs: notesStore.sessionIDsWithNotes)
        FilteredContentView(title: "Notes", sessions: sessions)
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Open a video and choose Notes to start writing.")
                    )
                }
            }
    }
}

#Preview {
    @Previewable @State var store = SessionStore()

    LibraryView()
        .environment(store)
        .environment(WatchProgressStore())
        .environment(SynchronizedListManager())
        .environment(PlaylistStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(NotesStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(DownloadEngine())
        .environment(ContentStore())
        .environment(NewsStore())
        .task { await store.load() }
}
