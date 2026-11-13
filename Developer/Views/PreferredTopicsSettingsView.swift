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

    static func binding(for topic: WWDCTopic, in storage: Binding<String>) -> Binding<Bool> {
        Binding {
            decode(storage.wrappedValue).contains(topic.name)
        } set: { isOn in
            var topics = decode(storage.wrappedValue)
            if isOn { topics.insert(topic.name) } else { topics.remove(topic.name) }
            storage.wrappedValue = encode(topics)
        }
    }
}

struct PreferredTopicsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PreferredTopicsList()
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
}

struct PreferredTopicsList: View {
    @Environment(SessionStore.self) private var store
    @AppStorage(PreferredTopics.storageKey) private var preferredTopicsStorage = ""

    var body: some View {
        List(store.topics) { topic in
            Toggle(isOn: PreferredTopics.binding(for: topic, in: $preferredTopicsStorage)) {
                Label(topic.name, systemImage: topic.systemImage)
            }
        }
    }
}

#Preview("PreferredTopics") {
    @Previewable @State var storage = PreferredTopics.encode(["Swift", "SwiftUI & UI Frameworks"])

    List {
        Section {
            ForEach(WWDCTopic.known) { topic in
                Toggle(isOn: PreferredTopics.binding(for: topic, in: $storage)) {
                    Label(topic.name, systemImage: topic.systemImage)
                }
            }
        } footer: {
            Text(PreferredTopics.decode(storage).sorted().formatted(.list(type: .and)))
        }
    }
}

#Preview("PreferredTopicsSettingsView") {
    @Previewable @State var store = SessionStore()

    PreferredTopicsSettingsView()
        .environment(store)
        .task { await store.load() }
}

#Preview("PreferredTopicsList") {
    @Previewable @State var store = SessionStore()

    PreferredTopicsList()
        .environment(store)
        .task { await store.load() }
}
