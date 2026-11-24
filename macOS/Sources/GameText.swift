import SwiftUI

private struct GameLanguageKey: EnvironmentKey {
    static let defaultValue: GameLanguage = .english
}

extension EnvironmentValues {
    var gameLanguage: GameLanguage {
        get { self[GameLanguageKey.self] }
        set { self[GameLanguageKey.self] = newValue }
    }
}

struct GameText: View {
    @Environment(\.gameLanguage) private var language
    let key: String

    init(_ key: String) { self.key = key }

    var body: some View { Text(verbatim: language.text(key)) }
}

struct GameLabel: View {
    @Environment(\.gameLanguage) private var language
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(verbatim: language.text(title))
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
