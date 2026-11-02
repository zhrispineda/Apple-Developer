//
//  ContentPageView+RowView.swift
//  Developer
//

import SwiftUI

extension ContentPageView {
    struct RowView: View {
        let list: DiscoverItemList

        @Environment(ContentStore.self) private var store

        var body: some View {
            let items = store.items(for: list)
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    header(showsSeeAll: list.showsSeeAll || items.count > DiscoverMetrics.rowLimit)
                        .padding(.horizontal, DiscoverMetrics.margin)

                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: DiscoverMetrics.spacing) {
                            ForEach(items.prefix(DiscoverMetrics.rowLimit)) { item in
                                ContentItemNavigationLink(item: item) {
                                    switch list.layout {
                                    case .card:
                                        ItemListCard(item: item)
                                            .frame(width: DiscoverMetrics.cardWidth)
                                    case .wideCard:
                                        ItemListWideCard(item: item)
                                            .frame(width: DiscoverMetrics.wideCardWidth)
                                    }
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, DiscoverMetrics.margin, for: .scrollContent)
                }
            }
        }

        @ViewBuilder
        private func header(showsSeeAll: Bool) -> some View {
            let title = Text(list.title).font(.title2.bold())
            if showsSeeAll {
                NavigationLink(value: Route.discoverList(list)) {
                    HStack(spacing: 6) {
                        title
                        Image(systemName: "chevron.forward")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
            } else {
                title
            }
        }
    }
}
