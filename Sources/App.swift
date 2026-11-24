import AppKit
import SwiftUI

final class GameAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = LaunchOptions()
        if Bundle.main.bundleIdentifier == GameIdentity.qaBundleID, !options.smoke {
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct IEPuzzleApp: App {
    @NSApplicationDelegateAdaptor(GameAppDelegate.self) private var appDelegate
    @StateObject private var game = GameSession(resources: Bundle.main.resourceURL!)

    var body: some Scene {
        WindowGroup(GameIdentity.title) {
            RootView()
                .environmentObject(game)
                .frame(minWidth: 1080, minHeight: 665)
        }
        .defaultSize(width: 1280, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var game: GameSession

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            if let failure = game.launchFailure {
                VStack(spacing: 15) {
                    Text("Unable to start the game").gameFont(28, .bold)
                    Text(failure).gameFont(16)
                    GameButton(title: "Quit") { game.quit() }
                }.padding(30)
            } else {
                content
            }
            if let warning = game.warning {
                VStack {
                    Spacer()
                    Label(warning, systemImage: "exclamationmark.circle")
                        .gameFont(13, .semibold).foregroundStyle(Palette.warn)
                        .padding(8)
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                }.padding(.bottom, 6).allowsHitTesting(false)
            }
        }
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .tint(Palette.deepSage)
        .environment(\.gameTextScale, game.settings.largeText ? 1.16 : 1)
        .environment(\.locale, Locale(identifier: "en_US"))
        .background(WindowBinder(settings: game.settings))
        .onAppear { game.startAudio() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            synchronizeFullscreen(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            synchronizeFullscreen(true)
        }
        .task {
            guard game.options.smoke, !game.didSmokeTest else { return }
            game.didSmokeTest = true
            try? await Task.sleep(for: .milliseconds(850))
            game.smokeTest()
            NSApplication.shared.terminate(nil)
        }
    }

    @ViewBuilder private var content: some View {
        switch game.screen {
        case .home: HomeMenu()
        case .instructions: InstructionsMenu()
        case .stages: StageMenu()
        case .settings: SettingsMenu()
        case .game:
            if let run = game.run {
                if game.overlay == .briefing, let intro = game.briefing {
                    ShiftScene(run: run, intro: intro)
                        .id(run.board.puzzle.id)
                } else {
                    StaffingScreen(run: run)
                        .id(run.board.puzzle.id)
                        .disabled(game.overlay != nil)
                        .accessibilityHidden(game.overlay != nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let overlay = game.overlay {
                        Palette.ink.opacity(0.19).ignoresSafeArea()
                        StaffingDialog(overlay: overlay)
                            .id(overlay)
                    }
                }
            }
        }
    }

    private func synchronizeFullscreen(_ value: Bool) {
        guard game.settings.fullscreen != value else { return }
        var settings = game.settings
        settings.fullscreen = value
        game.updateSettings(settings)
    }
}

private struct WindowBinder: NSViewRepresentable {
    let settings: PlayerSettings

    func makeNSView(context: Context) -> WindowAnchor {
        let anchor = WindowAnchor()
        anchor.update(settings)
        return anchor
    }

    func updateNSView(_ nsView: WindowAnchor, context: Context) { nsView.update(settings) }
}

private final class WindowAnchor: NSView {
    private var requested: PlayerSettings?
    private var appliedSize: WindowSize?
    private var appliedFullscreen: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let requested { update(requested) }
    }

    func update(_ settings: PlayerSettings) {
        requested = settings
        DispatchQueue.main.async { [weak self] in self?.applySettings() }
    }

    private func applySettings() {
        guard let window, let requested else { return }
        let actualFullscreen = window.styleMask.contains(.fullScreen)
        if appliedFullscreen != requested.fullscreen {
            appliedFullscreen = requested.fullscreen
            if actualFullscreen != requested.fullscreen {
                window.toggleFullScreen(nil)
                return
            }
        }
        if !actualFullscreen && appliedSize != requested.windowSize {
            appliedSize = requested.windowSize
            let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            let width = min(requested.windowSize.width, visible.map { Double($0.width) } ?? requested.windowSize.width)
            let height = min(requested.windowSize.height, (visible.map { Double($0.height) } ?? requested.windowSize.height) - 28)
            window.setContentSize(NSSize(width: width, height: max(665, height)))
            window.center()
        }
    }
}
