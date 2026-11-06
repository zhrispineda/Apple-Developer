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
