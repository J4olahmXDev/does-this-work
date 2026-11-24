import AppKit
import CoreText
import SwiftUI

enum GameTypography {
    private static let title = "Mali-SemiBold"
    private static let body = "Sarabun-Medium"
    private static let emphasis = "Sarabun-Bold"

    static func register(in resources: URL) {
        let folder = resources.appendingPathComponent("Fonts", isDirectory: true)
        for name in [title, body, emphasis] {
            let url = folder.appendingPathComponent(name).appendingPathExtension("ttf")
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(size: Double, weight: Font.Weight, display: Bool) -> Font {
        let strong = weight == .semibold || weight == .bold || weight == .heavy
        let name = display ? title : strong ? emphasis : body
        if NSFont(name: name, size: size) != nil {
            return .custom(name, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}
