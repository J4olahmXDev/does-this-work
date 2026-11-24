import AppKit
import SwiftUI

private struct TextScaleKey: EnvironmentKey { static let defaultValue = 1.0 }

extension EnvironmentValues {
    var gameTextScale: Double {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
}

private struct GameFont: ViewModifier {
    @Environment(\.gameTextScale) var scale
    let size: Double
    let weight: Font.Weight
    let display: Bool

    func body(content: Content) -> some View {
        content.font(GameTypography.font(size: size * scale, weight: weight, display: display || size >= 20))
    }
}

extension View {
    func gameFont(_ size: Double, _ weight: Font.Weight = .medium, display: Bool = false) -> some View {
        modifier(GameFont(size: size, weight: weight, display: display))
    }
}

enum ActionStyle { case filled, outlined, quiet }

struct GameButton: View {
    let title: String
    var symbol: String? = nil
    var style: ActionStyle = .outlined
    var expand = false
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                GameText(title)
            }
            .gameFont(16, .semibold, display: true)
            .padding(.horizontal, 17)
            .frame(maxWidth: expand ? .infinity : nil, minHeight: 41)
            .background(style == .filled ? Palette.sage : style == .outlined ? Palette.paper : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if style != .quiet {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ink.opacity(0.76), lineWidth: 1.35)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(enabled ? 1 : 0.48)
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GameText(title).gameFont(33, .bold).accessibilityAddTraits(.isHeader)
            if let subtitle {
                GameText(subtitle).gameFont(16).foregroundStyle(Palette.quiet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomeMenu: View {
    @EnvironmentObject private var game: GameSession

    var body: some View {
        HStack(spacing: 45) {
            VStack(alignment: .leading, spacing: 13) {
                GameText("Does This\nWork?")
                    .gameFont(63, .heavy)
                    .lineSpacing(-3)
                    .accessibilityAddTraits(.isHeader)
                GameButton(title: "Play", symbol: "play.fill", style: .filled, expand: true) {
                    game.navigate(to: .stages)
                }
                .accessibilityIdentifier("home-play")
                .keyboardShortcut(.return, modifiers: [])
                GameButton(title: "How to play", expand: true) { game.navigate(to: .instructions) }
                GameButton(title: "Settings", expand: true) { game.showSettings() }
                    .accessibilityIdentifier("home-settings")
                GameButton(title: "Quit", style: .quiet, expand: true) { game.quit() }
            }
            .frame(width: 315)
            MenuDiorama()
                .frame(maxWidth: .infinity, maxHeight: 450)
        }
        .padding(.horizontal, 62)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MenuDiorama: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 36)
                    .fill(Palette.beige.opacity(0.68))
                    .overlay { RoundedRectangle(cornerRadius: 36).strokeBorder(Palette.line, lineWidth: 1.5) }
                    .padding(14)
                FactoryWall()
                    .frame(width: max(0, w - 28), height: min(56, h * 0.13))
                    .position(x: w / 2, y: 14 + min(28, h * 0.065))
                    .clipShape(RoundedRectangle(cornerRadius: 36).inset(by: 14))
                Path { path in
                    path.move(to: pt(w * 0.39, h * 0.25))
                    path.addQuadCurve(to: pt(w * 0.73, h * 0.24), control: pt(w * 0.50, h * 0.11))
                    path.addQuadCurve(to: pt(w * 0.57, h * 0.49), control: pt(w * 0.88, h * 0.45))
                    path.addQuadCurve(to: pt(w * 0.33, h * 0.64), control: pt(w * 0.27, h * 0.51))
                    path.addQuadCurve(to: pt(w * 0.73, h * 0.75), control: pt(w * 0.32, h * 0.83))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 7]))
                WorkerArt(style: "cap").frame(width: w * 0.15).position(x: w * 0.19, y: h * 0.29)
                MachineArt(station: .large).frame(width: w * 0.22, height: h * 0.24)
                    .position(x: w * 0.32, y: h * 0.29)
                StageIllustration(stage: .bottleneck).frame(width: w * 0.28, height: h * 0.25)
                    .position(x: w * 0.69, y: h * 0.34)
                WorkerArt(style: "pocket").frame(width: w * 0.15).position(x: w * 0.84, y: h * 0.28)
                StageIllustration(stage: .plant).frame(width: w * 0.31, height: h * 0.30)
                    .position(x: w * 0.34, y: h * 0.69)
                StageIllustration(stage: .delivery).frame(width: w * 0.30, height: h * 0.31)
                    .position(x: w * 0.74, y: h * 0.76)
                Image(systemName: "wrench.adjustable")
                    .gameFont(20).foregroundStyle(Palette.line)
                    .rotationEffect(.degrees(-18))
                    .position(x: w * 0.87, y: h * 0.16)
            }
        }
        .accessibilityHidden(true)
    }
}

struct StageMenu: View {
    @EnvironmentObject private var game: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(title: "Choose a stage", subtitle: "Play six puzzles to unlock the next stage.")
            Spacer(minLength: 0)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 13), GridItem(.flexible())], spacing: 13) {
                ForEach(WorkStage.allCases) { stage in
                    let enabled = game.unlocked(stage)
                    let artwork = StageArtwork(rawValue: stage.rawValue) ?? .staffing
                    HStack(spacing: 14) {
                        StageIllustration(stage: artwork).frame(width: 120, height: 101)
                            .opacity(enabled ? 1 : 0.58)
                        VStack(alignment: .leading, spacing: 6) {
                            GameText(stage.title).gameFont(21, .bold)
                            GameText(stage.summary).gameFont(13).foregroundStyle(Palette.quiet)
                            GameText("90 puzzles · 6 per run").gameFont(12, .semibold)
                            if enabled {
                                GameButton(title: game.completed(stage) ? "Replay" : "Play", style: .filled) {
                                    game.startRun(stage)
                                }.accessibilityIdentifier(stage == .staffing ? "stage-one-play" : "stage-\(stage.rawValue)-play")
                            } else {
                                GameLabel("Complete the previous stage", systemImage: "lock")
                                    .gameFont(12, .semibold).frame(minHeight: 41)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                    .background(enabled ? Palette.paper : Palette.beige.opacity(0.54), in: RoundedRectangle(cornerRadius: 13))
                    .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.line) }
                }
            }
            Spacer(minLength: 0)
            GameButton(title: "Back", symbol: "chevron.left") { game.navigate(to: .home, cue: .back) }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(38)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InstructionsMenu: View {
    @EnvironmentObject private var game: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "How to play", subtitle: "Staff each station and reach its power target.")
            Spacer(minLength: 4)
            HStack(alignment: .top, spacing: 26) {
                helpStep("Choose a worker", detail: "Click or drag a worker. Hover over a model for their name, skills, and shift rules.") {
                    WorkerArt(style: "goggles").padding(13)
                }
                helpStep("Choose a slot", detail: "Outlined slots accept the worker. A slash marks a slot you can't use.") {
                    HStack(spacing: 10) {
                        HintSlot(blocked: false, strong: true)
                        HintSlot(blocked: true, strong: true)
                    }
                }
                helpStep("Check your plan", detail: "Everyone needs a place. Reach each power goal and stay within any power range.") {
                    MachineArt(station: .large)
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: 12) {
                GameButton(title: "Back", symbol: "chevron.left") { game.navigate(to: .home, cue: .back) }
                    .keyboardShortcut(.escape, modifiers: [])
                GameButton(title: "Play", style: .filled) { game.navigate(to: .stages) }
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(42)
    }

    private func helpStep<Picture: View>(_ title: String, detail: String,
                                         @ViewBuilder picture: () -> Picture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            picture().frame(height: 126).frame(maxWidth: .infinity)
                .background(Palette.beige.opacity(0.64), in: RoundedRectangle(cornerRadius: 14))
            GameText(title).gameFont(22, .bold)
            GameText(detail).gameFont(16).foregroundStyle(Palette.quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HintSlot: View {
    let blocked: Bool
    let strong: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(blocked ? Palette.clay.opacity(0.22) : Palette.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(blocked ? Palette.quiet : Palette.deepSage,
                                  style: StrokeStyle(lineWidth: strong ? 2.6 : 1.4, dash: blocked ? [] : [5, 4]))
                if blocked { Image(systemName: "slash.forward").gameFont(19).foregroundStyle(Palette.quiet) }
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case audio = "Audio", display = "Display", accessibility = "Accessibility", language = "Language"
    var id: Self { self }
}

private final class SettingsSelection: ObservableObject {
    @Published var current: SettingsTab
    init(current: SettingsTab) { self.current = current }
}

struct SettingsMenu: View {
    @EnvironmentObject private var game: GameSession
    @StateObject private var tabs: SettingsSelection

    init(initialTab: SettingsTab = .audio) {
        _tabs = StateObject(wrappedValue: SettingsSelection(current: initialTab))
    }
    private var tab: SettingsTab { tabs.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 9) {
                WorkerArt(style: "beanie").frame(width: 52)
                SectionHeading(title: "Settings")
            }
            HStack(spacing: 22) {
                ForEach(SettingsTab.allCases) { item in
                    Button {
                        tabs.current = item
                        game.audio.play(.click)
                    } label: {
                        GameText(item.rawValue).gameFont(19, .bold)
                            .padding(.horizontal, 9)
                            .padding(.bottom, 9)
                            .overlay(alignment: .bottom) {
                                if item == tab { Capsule().fill(Palette.deepSage).frame(height: 3) }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == tab ? .isSelected : [])
                }
            }
            Divider().overlay(Palette.line)
            switch tab {
            case .audio:
                volumeRow("Master volume", \.masterVolume)
                volumeRow("Music", \.musicVolume)
                volumeRow("Sound effects", \.effectsVolume)
                volumeRow("Dialogue voices", \.voiceVolume)
            case .display:
                row("Window mode") {
                    Picker("", selection: binding(\.fullscreen)) {
                        GameText("Windowed").tag(false)
                        GameText("Fullscreen").tag(true)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                row("Window size") {
                    Picker("", selection: binding(\.windowSize)) {
                        ForEach(WindowSize.allCases, id: \.self) { size in GameText(size.rawValue).tag(size) }
                    }.labelsHidden().disabled(game.settings.fullscreen)
                }
                row("Text size") {
                    Picker("", selection: binding(\.largeText)) {
                        GameText("Standard").tag(false)
                        GameText("Large").tag(true)
                    }.pickerStyle(.segmented).labelsHidden()
                }
            case .language:
                row("Game language") {
                    HStack(spacing: 8) {
                        ForEach(GameLanguage.allCases) { language in
                            let selected = game.settings.language == language
                            GameButton(title: language.name, style: selected ? .filled : .outlined) {
                                if !selected {
                                    var settings = game.settings
                                    settings.language = language
                                    game.updateSettings(settings)
                                    game.audio.play(.click)
                                }
                            }
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("language-" + language.id)
                        }
                    }
                }
                GameText("Choose the language for menus, puzzles, and dialogue.")
                    .gameFont(15).foregroundStyle(Palette.quiet)
            case .accessibility:
                toggleRow("Reduce motion", \.reduceMotion)
                toggleRow("Stronger slot outlines", \.strongerSlots)
                toggleRow("Show keyboard hints", \.keyboardHints)
                HStack(spacing: 20) {
                    GameText("Slot preview").gameFont(15, .bold)
                    HintSlot(blocked: false, strong: game.settings.strongerSlots)
                    GameText("Open").gameFont(13)
                    HintSlot(blocked: true, strong: game.settings.strongerSlots)
                    GameText("Blocked").gameFont(13)
                }
            }
            Spacer(minLength: 3)
            HStack {
                GameButton(title: "Back", symbol: "chevron.left") { game.closeSettings() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                GameButton(title: "Reset defaults") { game.resetSettings() }
            }
        }
        .padding(37)
        .frame(maxWidth: 1000, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding<Value>(_ key: WritableKeyPath<PlayerSettings, Value>) -> Binding<Value> {
        Binding(get: { game.settings[keyPath: key] }, set: { value in
            var settings = game.settings
            settings[keyPath: key] = value
            game.updateSettings(settings)
        })
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GameText(title).gameFont(17, .semibold)
                Spacer()
                control().frame(width: 320, alignment: .trailing)
            }
            .frame(minHeight: 30)
            Divider().overlay(Palette.line.opacity(0.72))
        }
    }

    private func volumeRow(_ title: String, _ key: WritableKeyPath<PlayerSettings, Double>) -> some View {
        row(title) {
            HStack(spacing: 13) {
                Slider(value: binding(key), in: 0...1, step: 0.01, onEditingChanged: { editing in
                    if !editing, key != \.musicVolume { game.changeVolumePreview() }
                }) { GameText(title) }
                .labelsHidden()
                GameText(game.settings[keyPath: key].formatted(.percent.precision(.fractionLength(0))))
                    .gameFont(15, .semibold).monospacedDigit().frame(width: 50, alignment: .trailing)
            }
        }
    }

    private func toggleRow(_ title: String, _ key: WritableKeyPath<PlayerSettings, Bool>) -> some View {
        row(title) {
            Toggle(isOn: binding(key)) { GameText(title) }.toggleStyle(.switch).labelsHidden()
        }
    }
}
