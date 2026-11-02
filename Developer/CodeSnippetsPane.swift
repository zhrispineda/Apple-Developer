//
//  CodeSnippetsPane.swift
//  Developer
//

import SwiftUI

struct CodeSnippetsPane: View {
    let samples: [CodeSample]
    let onSeek: (Double) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(samples) { sample in
                    Button {
                        onSeek(sample.start)
                    } label: {
                        Text("\(Text(formattedTimestamp(sample.start)).foregroundStyle(.tint)) - \(sample.title)")
                            .foregroundStyle(Color.primary)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    CodeSnippet(sample: sample)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
