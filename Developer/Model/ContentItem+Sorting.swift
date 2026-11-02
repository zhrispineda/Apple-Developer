//
//  ContentItem+Sorting.swift
//  Developer
//

import Foundation

extension ContentItem {
    var isBrowsable: Bool {
        switch type {
        case "Video", "Session": videoURL != nil
        case "Article": articleID != nil
        default: false
        }
    }

    var titleSortKey: Substring {
        title.drop { !$0.isLetter && !$0.isNumber }
    }
}

extension Sequence<ContentItem> {
    func groupedByPublicationYear(calendar: Calendar = .current) -> [ContentItemGroup] {
        let byYear = Dictionary(grouping: self) { item in
            item.publishedAt.map { calendar.component(.year, from: $0) } ?? 0
        }
        return byYear.keys.sorted(by: >).map { year in
            let items = byYear[year, default: []].sorted {
                $0.titleSortKey.localizedStandardCompare($1.titleSortKey) == .orderedAscending
            }
            return ContentItemGroup(
                id: String(year),
                title: year > 0 ? String(year) : nil,
                entries: items.map { $0.isArticle ? .article($0) : .video($0.session) }
            )
        }
    }
}
