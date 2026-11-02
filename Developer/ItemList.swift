//
//  ItemList.swift
//  Developer
//

import SwiftUI

struct ItemList: View {
    let list: DiscoverItemList

    @Environment(ContentStore.self) private var store

    var body: some View {
        let minimum = list.layout == .card ? DiscoverMetrics.cardWidth - 40 : DiscoverMetrics.wideCardWidth - 40
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: DiscoverMetrics.spacing, alignment: .top)],
                      spacing: 24) {
                ForEach(store.items(for: list)) { item in
                    ContentItemNavigationLink(item: item) {
                        switch list.layout {
                        case .card: ItemListCard(item: item)
                        case .wideCard: ItemListWideCard(item: item)
                        }
                    }
                }
            }
            .padding(DiscoverMetrics.margin)
        }
        .navigationTitle(list.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.monitorLive() }
    }
}
