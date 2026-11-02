//
//  URL+Locations.swift
//  Developer
//

import Foundation

extension URL {
    var newsArticleKey: String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "id" }?.value
    }
}

extension WWDCEvent {
    var pageURL: URL {
        WWDCVideoService.baseURL.appending(path: "videos/\(id)/")
    }
}

extension WWDCTopic {
    var pageURL: URL {
        let slug = name.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
        return WWDCVideoService.baseURL.appending(path: "videos/\(slug)/")
    }
}
