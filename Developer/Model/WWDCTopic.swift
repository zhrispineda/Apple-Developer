//
//  WWDCTopic.swift
//  Developer
//

import Foundation

struct WWDCTopic: Identifiable, Hashable {
    let name: String
    let systemImage: String

    var id: String { name }

    static let known: [WWDCTopic] = [
        WWDCTopic(name: "AI & Machine Learning", systemImage: "sparkles"),
        WWDCTopic(name: "Accessibility & Inclusion", systemImage: "person.2"),
        WWDCTopic(name: "App Services", systemImage: "gearshape"),
        WWDCTopic(name: "App Store, Distribution & Marketing", systemImage: "storefront"),
        WWDCTopic(name: "Audio & Video", systemImage: "tv.and.hifispeaker.fill"),
        WWDCTopic(name: "Business & Education", systemImage: "briefcase"),
        WWDCTopic(name: "Design", systemImage: "paintbrush.pointed"),
        WWDCTopic(name: "Developer Tools", systemImage: "hammer"),
        WWDCTopic(name: "Essentials", systemImage: "cube"),
        WWDCTopic(name: "Graphics & Games", systemImage: "gamecontroller"),
        WWDCTopic(name: "Health & Fitness", systemImage: "heart"),
        WWDCTopic(name: "Maps & Location", systemImage: "map"),
        WWDCTopic(name: "Photos & Camera", systemImage: "camera"),
        WWDCTopic(name: "Privacy & Security", systemImage: "lock"),
        WWDCTopic(name: "Safari & Web", systemImage: "safari"),
        WWDCTopic(name: "Spatial Computing", systemImage: "visionpro"),
        WWDCTopic(name: "Swift", systemImage: "swift"),
        WWDCTopic(name: "SwiftUI & UI Frameworks", systemImage: "rectangle.3.group"),
        WWDCTopic(name: "System Services", systemImage: "gearshape.2"),
    ]
}
