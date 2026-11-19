//
//  PlaylistView.swift
//  Developer
//

import SwiftUI

/// Lists the videos in a playlist, with reordering, removal, renaming and deletion.
struct PlaylistView: View {
    let playlistID: UUID

    @Environment(SessionStore.self) private var store
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false

    var body: some View {
        if let playlist = playlistStore.playlist(withID: playlistID) {
            content(for: playlist)
        } else {
            ContentUnavailableView("Playlist Not Found", systemImage: "list.and.film")
        }
    }

    private func content(for playlist: Playlist) -> some View {
        let sessions = store.sessions(orderedByIDs: playlist.sessionIDs)
        return List {
            ForEach(sessions) { session in
                NavigationLink(value: Route.session(session)) {
                    ContentItemRow(session: session)
                }
                .sessionContextMenu(for: session)
            }
            .onDelete { offsets in
                playlistStore.remove(Set(offsets.map { sessions[$0].id }), from: playlistID)
            }
            .onMove { source, destination in
                var ids = sessions.map(\.id)
                ids.move(fromOffsets: source, toOffset: destination)
                // Keep any IDs that couldn't be resolved yet (e.g. sessions still loading).
                let visible = Set(ids)
                playlistStore.setSessionIDs(ids + playlist.sessionIDs.filter { !visible.contains($0) }, in: playlistID)
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.plain)
        #endif
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Videos",
                    systemImage: "list.and.film",
                    description: Text("Touch and hold a video, then choose Add to Playlist.")
                )
            }
        }
        .navigationTitle(playlist.title)
        .toolbar {
            #if os(iOS)
            if !sessions.isEmpty {
                ToolbarItem {
                    EditButton()
                }
            }
            #endif
            ToolbarItem {
                Menu("More", systemImage: "ellipsis") {
                    Button("Rename", systemImage: "pencil") { isRenaming = true }
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .playlistTitleAlert("Rename Playlist", isPresented: $isRenaming, initialTitle: playlist.title, confirmLabel: "Rename") {
            playlistStore.rename(playlistID, to: $0)
        }
        .confirmationDialog("Delete \"\(playlist.title)\"?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Playlist", role: .destructive) {
                playlistStore.delete(playlistID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Add to Playlist

struct NewPlaylistAction {
    let handler: (String?) -> Void

    func callAsFunction(adding sessionID: String? = nil) {
        handler(sessionID)
    }
}

extension EnvironmentValues {
    @Entry var newPlaylist: NewPlaylistAction? = nil
}

struct AddToPlaylistMenu: View {
    let sessionID: String

    @Environment(PlaylistStore.self) private var playlistStore: PlaylistStore?
    @Environment(\.newPlaylist) private var newPlaylist

    var body: some View {
        if let playlistStore {
            Menu("Add to Playlist", systemImage: "text.badge.plus") {
                if let newPlaylist {
                    Button("New Playlist…", systemImage: "plus") {
                        newPlaylist(adding: sessionID)
                    }
                }

                Section {
                    ForEach(playlistStore.playlists) { playlist in
                        Toggle(isOn: Binding {
                            playlist.sessionIDs.contains(sessionID)
                        } set: { _ in
                            playlistStore.toggle(sessionID, in: playlist.id)
                        }) {
                            Label(playlist.title, systemImage: "list.and.film")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Title Alert

extension View {
    func playlistTitleAlert(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        initialTitle: String = "",
        confirmLabel: LocalizedStringKey,
        onConfirm: @escaping (String) -> Void
    ) -> some View {
        modifier(PlaylistTitleAlert(
            title: title, isPresented: isPresented, initialTitle: initialTitle,
            confirmLabel: confirmLabel, onConfirm: onConfirm
        ))
    }
}

private struct PlaylistTitleAlert: ViewModifier {
    let title: LocalizedStringKey
    @Binding var isPresented: Bool
    let initialTitle: String
    let confirmLabel: LocalizedStringKey
    let onConfirm: (String) -> Void

    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField("Title", text: $text)
                Button(confirmLabel) { onConfirm(text) }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: isPresented) {
                if isPresented { text = initialTitle }
            }
    }
}

#Preview {
    @Previewable @State var store = SessionStore()
    @Previewable @State var playlistStore = PlaylistStore(defaults: UserDefaults(suiteName: "preview")!)

    NavigationStack {
        if let playlist = playlistStore.playlists.first {
            PlaylistView(playlistID: playlist.id)
        }
    }
    .environment(store)
    .environment(playlistStore)
    .environment(WatchProgressStore())
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    .task {
        await store.load()
        if playlistStore.playlists.isEmpty {
            playlistStore.create(title: "Favorites", sessionIDs: Array(store.sessions.prefix(5).map(\.id)))
        }
    }
}
