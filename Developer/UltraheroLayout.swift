//
//  UltraheroLayout.swift
//  Developer
//

import SwiftUI

struct UltraheroLayout: Layout {
    let aspectRatio: Double
    static let minimumHeight: CGFloat = 300
    static let maximumHeight: CGFloat = 450
    static let minimumTextWidth: CGFloat = 240

    private func artworkSize(forWidth width: CGFloat) -> CGSize {
        let ratio = max(aspectRatio, 0.1)
        var artworkWidth = max(0, min(width * 0.7, width - Self.minimumTextWidth))
        let height = min(Self.maximumHeight, max(Self.minimumHeight, artworkWidth / ratio))
        artworkWidth = min(artworkWidth, height * ratio)
        return CGSize(width: artworkWidth, height: height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.map { $0.isFinite ? $0 : 900 } ?? 900
        return CGSize(width: width, height: artworkSize(forWidth: width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let artwork = artworkSize(forWidth: bounds.width)
        let textWidth = max(0, bounds.width - artwork.width)
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: textWidth, height: bounds.height))
        subviews[1].place(
            at: CGPoint(x: bounds.minX + textWidth, y: bounds.minY),
            proposal: ProposedViewSize(artwork)
        )
    }
}
