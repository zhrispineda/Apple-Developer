//
//  CodeSnippet.swift
//  Developer
//

import SwiftUI

struct CodeSnippet: View {
    let sample: CodeSample

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(SyntaxTheme.attributedCode(for: sample.tokens))
                .font(.system(.callout, design: .monospaced))
                .fixedSize(horizontal: true, vertical: false)
                .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1), in: .rect(cornerRadius: 20))
        .contextMenu {
            Button("Copy Code", systemImage: "doc.on.doc") {
                copyToPasteboard(sample.code)
            }
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

enum SyntaxTheme {
    static func attributedCode(for tokens: [CodeSample.Token]) -> AttributedString {
        tokens.reduce(into: AttributedString()) { result, token in
            var run = AttributedString(token.text)
            run.foregroundColor = color(for: token.kind)
            result += run
        }
    }

    // Created once rather than per token, since each is a dynamic platform color.
    private static let keyword = Color(light: 0x9B2393, dark: 0xFF7AB2)
    private static let type = Color(light: 0x0B4F79, dark: 0x5DD8FF)
    private static let function = Color(light: 0x326D74, dark: 0x67B7A4)
    private static let comment = Color(light: 0x5D6C79, dark: 0x7F8C98)
    private static let string = Color(light: 0xC41A16, dark: 0xFC6A5D)
    private static let number = Color(light: 0x1C00CF, dark: 0xD0BF69)
    private static let tag = Color(light: 0x3900A0, dark: 0xA167E6)

    static func color(for kind: String?) -> Color {
        switch kind {
        case "keyword", "attr", "meta", "built_in": keyword
        case "class", "type": type
        case "function", "title": function
        case "comment", "doctag": comment
        case "string", "regexp", "subst": string
        case "number", "literal": number
        case "tag", "name", "selector-tag": tag
        default: Color.primary
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

#Preview("Code") {
    @Previewable @State var samples: [CodeSample] = []

    CodeSnippetsPane(samples: samples, onSeek: { _ in })
        .task {
            let url = URL(string: "https://developer.apple.com/videos/play/tech-talks/111468/")!
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            samples = WWDCVideoService.parseCodeSamples(from: String(decoding: data, as: UTF8.self))
        }
}
