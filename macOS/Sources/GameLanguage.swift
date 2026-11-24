import Foundation

enum GameLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case thai = "th"

    var id: String { rawValue }
    var name: String { self == .thai ? "ภาษาไทย" : "English" }
    var locale: Locale { Locale(identifier: self == .thai ? "th_TH" : "en_US") }

    func text(_ key: String, _ arguments: String...) -> String {
        let phrase = lookup(key)
        guard !arguments.isEmpty else { return phrase }
        return String(format: phrase, locale: locale, arguments: arguments.map { lookup($0) as CVarArg })
    }

    private func lookup(_ key: String) -> String {
        self == .thai ? ThaiCopy.interface[key] ?? ThaiCopy.puzzles[key] ?? key : key
    }
}
