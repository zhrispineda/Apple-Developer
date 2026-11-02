//
//  FilteredContentView.swift
//  Developer
//

import SwiftUI

enum AppContentFilter: String, CaseIterable {
    case all, unwatched, bookmarked, downloaded, preferredTopics
}

struct FilteredContentView: View {
    let title: String
    let groups: [ContentItemGroup]
    var shareURL: URL? = nil

    init(title: String, groups: [ContentItemGroup], shareURL: URL? = nil) {
        self.title = title
        self.groups = groups
        self.shareURL = shareURL
    }

    init(title: String, sessions: [WWDCSession], shareURL: URL? = nil) {
        self.init(title: title, groups: [ContentItemGroup(sessions: sessions)], shareURL: shareURL)
    }

    @Environment(WatchProgressStore.self) private var progressStore
    @Environment(SynchronizedListManager.self) private var bookmarkStore
    @Environment(DownloadEngine.self) private var downloadStore

    @AppStorage("sessionListLayout") private var layout = FilteredContentLayout.list
    @AppStorage("sessionListFilter") private var filter = AppContentFilter.all
    @AppStorage(PreferredTopics.storageKey) private var preferredTopicsStorage = ""
    @State private var isManagingPreferredTopics = false
    @State private var searchText = ""
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var usesSidebarStyle: Bool {
        #if os(macOS)
        true
        #elseif os(iOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    private var filteredGroups: [ContentItemGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let preferred = PreferredTopics.decode(preferredTopicsStorage)
        return groups.compactMap { group in
            let entries = group.entries.filter { entry in
                matchesFilter(entry, preferredTopics: preferred)
                    && (query.isEmpty
                        || entry.title.localizedStandardContains(query)
                        || entry.topics.contains { $0.localizedStandardContains(query) })
            }
            return entries.isEmpty ? nil : ContentItemGroup(id: group.id, title: group.title, entries: entries)
        }
    }

    private func matchesFilter(_ entry: ContentEntry, preferredTopics: Set<String>) -> Bool {
        switch filter {
        case .all:
            true
        case .unwatched:
            entry.session != nil && !(progressStore.progress(for: entry.id)?.isWatched ?? false)
        case .bookmarked:
            bookmarkStore.isBookmarked(entry.id)
        case .downloaded:
            downloadStore.state(for: entry.id) != .notDownloaded
        case .preferredTopics:
            !preferredTopics.isDisjoint(with: entry.topics)
        }
    }

    var body: some View {
        let visibleGroups = filteredGroups
        let hasEntries = groups.contains { !$0.entries.isEmpty }
        Group {
            switch layout {
            case .list:
                list(visibleGroups)
            case .grid:
                grid(visibleGroups)
            }
        }
        .overlay {
            if visibleGroups.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if visibleGroups.isEmpty && hasEntries {
                ContentUnavailableView {
                    Label("No Matching Videos", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No videos match the current filter.")
                } actions: {
                    Button("Show All Items") { filter = .all }
                }
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(usesSidebarStyle ? .large : .inline)
        #endif
        .toolbar { toolbarContent }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Find in \(title)")
        .onChange(of: title) { searchText = "" }
        .sheet(isPresented: $isManagingPreferredTopics) {
            PreferredTopicsSettingsView()
        }
    }

    // MARK: Layouts

    private func list(_ groups: [ContentItemGroup]) -> some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        link(for: entry) {
                            if usesSidebarStyle {
                                ContentItemWideRow(entry: entry)
                            } else {
                                ContentItemRow(entry: entry)
                            }
                        }
                    }
                } header: {
                    if let title = group.title {
                        sectionHeader(title)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        #else
        .listStyle(.plain)
        #endif
    }

    private func grid(_ groups: [ContentItemGroup]) -> some View {
        #if os(macOS)
        let cellWidth: CGFloat = 220
        #else
        let cellWidth: CGFloat = 160
        #endif
        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: 20, alignment: .top)], alignment: .leading, spacing: 24) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            link(for: entry) {
                                FilteredContentGridCell(entry: entry, width: cellWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        if let title = group.title {
                            sectionHeader(title)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title.bold())
            .foregroundStyle(Color.primary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func link(for entry: ContentEntry, @ViewBuilder label: () -> some View) -> some View {
        if let session = entry.session {
            NavigationLink(value: Route.session(session), label: label)
                .sessionContextMenu(for: session)
        } else {
            NavigationLink(value: entry.route, label: label)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            filterMenu
        }

        ToolbarSpacer(.fixed)

        #if os(iOS)
        if usesSidebarStyle {
            ToolbarItem {
                moreMenu
            }
        } else {
            layoutPickerItem
            shareItems
        }
        #else
        layoutPickerItem
        shareItems
        #endif
    }

    @ToolbarContentBuilder
    private var layoutPickerItem: some ToolbarContent {
        ToolbarItem {
            layoutPicker
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
        }
    }

    @ToolbarContentBuilder
    private var shareItems: some ToolbarContent {
        if let shareURL {
            ToolbarSpacer(.fixed)

            ToolbarItem {
                shareLink(for: shareURL)
            }
        }
    }

    private var layoutPicker: some View {
        Picker("View", selection: $layout) {
            Label("List", systemImage: "list.bullet").tag(FilteredContentLayout.list)
            Label("Grid", systemImage: "square.grid.2x2").tag(FilteredContentLayout.grid)
        }
    }

    private func shareLink(for url: URL) -> some View {
        ShareLink(item: url, preview: SharePreview("\(title) - Videos - Apple Developer")) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private var moreMenu: some View {
        Menu {
            layoutPicker
                .pickerStyle(.inline)

            if let shareURL {
                Divider()
                shareLink(for: shareURL)
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $filter) {
                Text("All Items").tag(AppContentFilter.all)
                Divider()
                Text("Only Unwatched").tag(AppContentFilter.unwatched)
                Text("Only Bookmarked").tag(AppContentFilter.bookmarked)
                Text("Only Downloaded").tag(AppContentFilter.downloaded)
                Text("Only Preferred Topics").tag(AppContentFilter.preferredTopics)
            }
            .pickerStyle(.inline)

            Divider()

            Button("Manage Preferred Topics") {
                isManagingPreferredTopics = true
            }
        } label: {
            Label("Filter", systemImage: filter == .all
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

struct TopicContentView: View {
    let topic: WWDCTopic

    @Environment(ContentStore.self) private var contentStore
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        FilteredContentView(
            title: topic.name,
            groups: contentStore.groups(topic: topic.name)
                ?? [ContentItemGroup(sessions: sessionStore.sessions(topic: topic.name))],
            shareURL: topic.pageURL
        )
        .task { await contentStore.load() }
    }
}

#Preview("Event sessions") {
    @Previewable @State var store = SessionStore()
    @Previewable @State var progress: WatchProgressStore = {
        let progress = WatchProgressStore(defaults: UserDefaults(suiteName: "preview-watch-progress")!)
        progress.update(sessionID: "wwdc2023-101", position: 2400, duration: 7560)
        progress.update(sessionID: "wwdc2023-111", position: 7560, duration: 7560)
        return progress
    }()

    NavigationStack {
        FilteredContentView(title: "WWDC23", sessions: store.sessions(in: .wwdc(2023)))
    }
    .environment(store)
    .environment(progress)
    .environment(DownloadEngine())
    .environment(SynchronizedListManager())
    .task { await store.load() }
}

enum FilteredContentLayout: String {
    case list, grid
}
