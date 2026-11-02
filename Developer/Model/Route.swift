//
//  Route.swift
//  Developer
//

import SwiftUI

enum Route: Hashable {
    case session(WWDCSession)
    case article(ContentItem)
    case news(NewsItem)
    case live(ContentItem)
    case discoverList(DiscoverItemList)
}

struct OpenRouteAction {
    let handler: (Route) -> Void

    func callAsFunction(_ route: Route) {
        handler(route)
    }
}

extension EnvironmentValues {
    @Entry var openRoute: OpenRouteAction? = nil
}

struct RouteView: View {
    let route: Route

    @Environment(ContentStore.self) private var contentStore

    var body: some View {
        switch route {
        case .session(let session):
            ContentItemVideoDetail(session: session)
        case .article(let item):
            ContentItemPlainDetail(item: item)
        case .news(let item):
            // The content feed's copy has the full page (with links to videos and
            // resources); the RSS version is the fallback before the feed loads.
            if case .article(let article)? = contentStore.route(for: item.url) {
                ContentItemPlainDetail(item: article)
            } else {
                NewsArticleView(item: item)
            }
        case .live(let item):
            LiveSessionView(item: item)
        case .discoverList(let list):
            ItemList(list: list)
        }
    }
}
