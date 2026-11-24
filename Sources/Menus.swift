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

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: .rounded))
    }
}

extension View {
    func gameFont(_ size: Double, _ weight: Font.Weight = .medium) -> some View {
        modifier(GameFont(size: size, weight: weight))
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
                Text(title)
            }
            .gameFont(16, .semibold)
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
            Text(title).gameFont(33, .bold).accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).gameFont(16).foregroundStyle(Palette.quiet)
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
                Text("Does This\nWork?")
                    .gameFont(63, .heavy)
                    .lineSpacing(-3)
                    .accessibilityAddTraits(.isHeader)
                Text("v" + GameIdentity.version).gameFont(17, .semibold)
                    .foregroundStyle(Palette.quiet).padding(.bottom, 8)
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
    private let stages: [(StageArtwork, String)] = [
        (.staffing, "Staff the Stations"),
        (.bottleneck, "Find the Bottleneck"),
        (.plant, "Plan the Plant"),
        (.delivery, "Plan the Delivery Route"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            SectionHeading(title: "Choose a stage")
            Spacer(minLength: 6)
            HStack(spacing: 14) {
                ForEach(stages, id: \.0.rawValue) { stage, name in
                    let enabled = stage == .staffing
                    VStack(spacing: 12) {
                        StageIllustration(stage: stage)
                            .frame(height: 110)
                            .opacity(enabled ? 1 : 0.58)
                        Text(name).gameFont(19, .bold)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 56)
                        if enabled {
                            if game.data.completedStageOne {
                                Label("Completed", systemImage: "checkmark.circle")
                                    .gameFont(13, .semibold).foregroundStyle(Palette.deepSage)
                            } else {
                                Text("90 puzzles · 6 per run").gameFont(13).foregroundStyle(Palette.quiet)
                            }
                            GameButton(title: game.data.completedStageOne ? "Play again" : "Play",
                                       style: .filled, expand: true) { game.startRun() }
                                .accessibilityIdentifier("stage-one-play")
                                .keyboardShortcut(.return, modifiers: [])
                        } else {
                            Label("Locked", systemImage: "lock")
                                .gameFont(14, .semibold).foregroundStyle(Palette.quiet)
                                .frame(minHeight: 64)
                                .help("This stage is locked in this version.")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 272)
                    .background(enabled ? Palette.paper : Palette.beige.opacity(0.54),
                                in: RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1) }
                }
            }
            Spacer(minLength: 12)
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
                helpStep("Choose a worker", detail: "Click or drag a worker. Read their skills and allowed stations beside the board.") {
                    WorkerArt(style: "goggles").padding(13)
                }
                helpStep("Choose a slot", detail: "Outlined slots accept the worker. A slash marks a slot you can't use.") {
                    HStack(spacing: 10) {
                        HintSlot(blocked: false, strong: true)
                        HintSlot(blocked: true, strong: true)
                    }
                }
                helpStep("Check your plan", detail: "Everyone needs a place. Meet each minimum and check any extra rules.") {
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
            Text(title).gameFont(22, .bold)
            Text(detail).gameFont(16).foregroundStyle(Palette.quiet)
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
    case audio = "Audio", display = "Display", accessibility = "Accessibility"
    var id: Self { self }
}

private final class SettingsSelection: ObservableObject {
    @Published var current = SettingsTab.audio
}

struct SettingsMenu: View {
    @EnvironmentObject private var game: GameSession
    @StateObject private var tabs = SettingsSelection()
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
                        Text(item.rawValue).gameFont(19, .bold)
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
            case .display:
                row("Window mode") {
                    Picker("Window mode", selection: binding(\.fullscreen)) {
                        Text("Windowed").tag(false)
                        Text("Fullscreen").tag(true)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                row("Window size") {
                    Picker("Window size", selection: binding(\.windowSize)) {
                        ForEach(WindowSize.allCases, id: \.self) { size in Text(size.rawValue).tag(size) }
                    }.labelsHidden().disabled(game.settings.fullscreen)
                }
                row("Text size") {
                    Picker("Text size", selection: binding(\.largeText)) {
                        Text("Standard").tag(false)
                        Text("Large").tag(true)
                    }.pickerStyle(.segmented).labelsHidden()
                }
            case .accessibility:
                toggleRow("Reduce motion", \.reduceMotion)
                toggleRow("Stronger slot outlines", \.strongerSlots)
                toggleRow("Show keyboard hints", \.keyboardHints)
                HStack(spacing: 20) {
                    Text("Slot preview").gameFont(15, .bold)
                    HintSlot(blocked: false, strong: game.settings.strongerSlots)
                    Text("Open").gameFont(13)
                    HintSlot(blocked: true, strong: game.settings.strongerSlots)
                    Text("Blocked").gameFont(13)
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
                Text(title).gameFont(17, .semibold)
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
                }) { Text(title) }
                .labelsHidden()
                Text(game.settings[keyPath: key].formatted(.percent.precision(.fractionLength(0))))
                    .gameFont(15, .semibold).monospacedDigit().frame(width: 50, alignment: .trailing)
            }
        }
    }

    private func toggleRow(_ title: String, _ key: WritableKeyPath<PlayerSettings, Bool>) -> some View {
        row(title) {
            Toggle(title, isOn: binding(key)).toggleStyle(.switch).labelsHidden()
        }
    }
}
