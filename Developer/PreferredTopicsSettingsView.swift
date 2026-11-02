//
//  PreferredTopicsSettingsView.swift
//  Developer
//

import SwiftUI

struct PreferredTopics {
    static let storageKey = "preferredTopics"

    static func decode(_ storage: String) -> Set<String> {
        Set(storage.split(separator: "\n").map(String.init))
    }

    static func encode(_ topics: Set<String>) -> String {
        topics.sorted().joined(separator: "\n")
    }
}

struct PreferredTopicsSettingsView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferredTopics.storageKey) private var preferredTopicsStorage = ""

    var body: some View {
        NavigationStack {
            List(store.topics) { topic in
                Toggle(isOn: binding(for: topic)) {
                    Label(topic.name, systemImage: topic.systemImage)
                }
            }
            .navigationTitle("Preferred Topics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 440)
        #endif
    }

    private func binding(for topic: WWDCTopic) -> Binding<Bool> {
        Binding {
            PreferredTopics.decode(preferredTopicsStorage).contains(topic.name)
        } set: { isOn in
            var topics = PreferredTopics.decode(preferredTopicsStorage)
            if isOn { topics.insert(topic.name) } else { topics.remove(topic.name) }
            preferredTopicsStorage = PreferredTopics.encode(topics)
        }
    }
}
