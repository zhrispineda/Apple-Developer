//
//  MarkdownText.swift
//  Developer
//

import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var style: TextStyle? = nil

    var body: some View {
        Text(Self.attributedString(from: markdown))
            .font(font)
            .foregroundStyle(color)
    }

    static func attributedString(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }

    private var font: Font {
        let weight = style?.weight.flatMap(Self.weight(named:))
        if let pointSize = style?.pointSize {
            return .system(size: pointSize, weight: weight ?? .regular)
        }
        let base = Font.system(style?.textStyle.flatMap(Self.textStyle(named:)) ?? .body)
        return weight.map { base.weight($0) } ?? base
    }

    private var color: Color {
        switch style?.color {
        case "secondary": .secondary
        case "blue": .blue
        case let hex?: Color(hexString: hex) ?? .primary
        case nil: .primary
        }
    }

    nonisolated static func textStyle(named name: String) -> Font.TextStyle? {
        switch name {
        case "largeTitle": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: nil
        }
    }

    nonisolated static func weight(named name: String) -> Font.Weight? {
        switch name {
        case "ultraLight": .ultraLight
        case "thin": .thin
        case "light": .light
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        case "black": .black
        default: nil
        }
    }
}

extension Color {
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? hexString.dropFirst() : Substring(hexString)
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(light: value, dark: value)
    }

    init?(lightHex: String?, darkHex: String?) {
        let parse = { (hex: String?) -> UInt32? in
            guard let hex else { return nil }
            let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
            return digits.count == 6 ? UInt32(digits, radix: 16) : nil
        }
        guard let light = parse(lightHex) else { return nil }
        self.init(light: light, dark: parse(darkHex) ?? light)
    }
}
