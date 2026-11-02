//
//  RelatedResourcesView.swift
//  Developer
//

import SwiftUI

struct RelatedResourcesView: View {
    let resources: [SessionResource]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resources")
                .font(.title2.bold())

            VStack(spacing: 0) {
                ForEach(resources) { resource in
                    Link(destination: resource.url) {
                        Label {
                            Text(resource.title)
                                .multilineTextAlignment(.leading)
                        } icon: {
                            Image(systemName: resource.kind == .download ? "arrow.down.document" : "document")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)

                    if resource.id != resources.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.1), in: .rect(cornerRadius: 24))
        }
    }
}
