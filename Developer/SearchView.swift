//
//  SearchView.swift
//  Developer
//

import SwiftUI

struct SearchView: View {
    var embedsInNavigationStack = true

    @Environment(SessionStore.self) private var store
    @State private var searchText = ""
    @AppStorage("recentSearches") private var recentSearchesStorage = ""

    private static let maxRecentSearches = 10

    private var recentSearches: [String] {
        recentSearchesStorage.split(separator: "\n").map(String.init)
    }

    private var results: [WWDCSession] {
        store.search(searchText)
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack {
                content
                    .navigationDestination(for: Route.self) { route in
                        RouteView(route: route)
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if searchText.isEmpty {
                recentSearchesView
            } else {
                resultsView
            }
        }
        .navigationTitle("Search")
        #if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        #else
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        #endif
        .onSubmit(of: .search) { addRecentSearch(searchText) }
    }

    // MARK: Subviews

    @ViewBuilder
    private var recentSearchesView: some View {
        if recentSearches.isEmpty {
            VStack(spacing: 4) {
                Text("No Recent Searches")
                    .font(.headline)
                Text("Recent searches will be added as you search for videos, articles, and more.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Recently Searched")
                            .font(.title3.bold())
                        Spacer()
                        Button("Clear") { recentSearchesStorage = "" }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                    .padding(.bottom, 4)

                    ForEach(Array(recentSearches.enumerated()), id: \.element) { index, query in
                        if index > 0 {
                            Divider()
                        }
                        Button {
                            searchText = query
                            addRecentSearch(query)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
    }

    private var resultsView: some View {
        List(results) { session in
            NavigationLink(value: Route.session(session)) {
                ContentItemRow(session: session)
            }
            .sessionContextMenu(for: session)
        }
        .listStyle(.plain)
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    // MARK: Recent searches

    private func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = [trimmed] + recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recentSearchesStorage = updated.prefix(Self.maxRecentSearches).joined(separator: "\n")
    }
}

#Preview {
    SearchView()
        .environment(SessionStore())
        .environment(WatchProgressStore())
        .environment(DownloadEngine())
        .environment(SynchronizedListManager())
}
