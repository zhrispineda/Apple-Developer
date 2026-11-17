//
//  Image+Symbol.swift
//  Developer
//

import SwiftUI

extension Image {
    init(symbol name: String) {
        #if canImport(UIKit)
        let hasAsset = UIImage(named: name) != nil
        #elseif canImport(AppKit)
        let hasAsset = NSImage(named: name) != nil
        #else
        let hasAsset = false
        #endif

        if hasAsset {
            self.init(name)
        } else {
            self.init(systemName: name)
        }
    }
}

/// Shows an SF Symbol, a custom symbol, or a vector image asset at the size of a symbol in the current font.
struct SymbolIcon: View {
    let name: String
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 20

    var body: some View {
        if Self.isImageAsset(name) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            Image(symbol: name)
        }
    }

    /// Bitmap/PDF image sets load as images but not as symbols.
    private static func isImageAsset(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name).map { !$0.isSymbolImage } ?? false
        #elseif canImport(AppKit)
        NSImage(named: name) != nil && NSImage(symbolName: name, bundle: .main, variableValue: 0) == nil
        #else
        false
        #endif
    }
}
