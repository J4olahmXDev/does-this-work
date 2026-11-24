import AppKit
import AVFoundation
import Foundation
import SwiftUI

enum GameIdentity {
    static let name = "Does This Work?"
    static let version = "0.3"
    static let title = name + " v" + version
    static let qaBundleID = "com.doesthiswork.game.qa"
}

enum Cue: String, CaseIterable {
    case click = "01-Menu-Click"
    case back = "02-Menu-Back"
    case popup = "03-Popup-Open"
    case pause = "04-Pause"
    case resume = "05-Resume"
    case pickup = "06-Piece-Pickup"
    case place = "07-Piece-Place"
    case swap = "08-Piece-Swap"
    case tray = "09-Return-to-Tray"
    case blocked = "10-Slot-Blocked"
    case check = "11-Check-Plan"
    case revise = "12-Plan-Needs-Work"
    case passed = "13-Puzzle-Passed"
    case nextStaffing = "14-Next-Puzzle-Staffing"
    case nextBottleneck = "15-Next-Puzzle-Bottleneck"
    case nextPlant = "16-Next-Puzzle-Plant"
    case nextDelivery = "17-Next-Puzzle-Delivery"
    case stageCleared = "18-Stage-Cleared"
    case stageUnlocked = "19-Stage-Unlocked"
    case gameComplete = "20-Game-Complete"
    case staffingPlacement = "21-Staffing-Station-Place"
    case bottleneckFlow = "22-Bottleneck-Flow-Updated"
    case plantTile = "23-Plant-Tile-Place"
    case plantRemove = "24-Plant-Tile-Remove"
    case deliveryStop = "25-Delivery-Stop-Added"
    case deliveryReorder = "26-Delivery-Stop-Reordered"
    case deliveryReturn = "27-Delivery-Depot-Return"

    enum Lane: Hashable { case navigation, pick, place, warning, result, transition }

    var lane: Lane {
        switch self {
        case .pickup: .pick
        case .place, .swap, .tray, .staffingPlacement, .bottleneckFlow,
             .plantTile, .plantRemove, .deliveryStop, .deliveryReorder, .deliveryReturn: .place
        case .blocked, .revise: .warning
        case .passed, .stageCleared, .gameComplete: .result
        case .nextStaffing, .nextBottleneck, .nextPlant, .nextDelivery, .stageUnlocked: .transition
        default: .navigation
        }
    }
}

struct LaunchOptions {
    let profile: URL?
    let qaLog: URL?
    let mute: Bool
    let orderedRun: Bool
    let stationCount: Int?
    let smoke: Bool

    init(_ arguments: [String] = CommandLine.arguments) {
        func path(after flag: String) -> URL? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.indices.contains(index + 1) else { return nil }
            return URL(fileURLWithPath: arguments[index + 1])
        }
        let qaBundle = Bundle.main.bundleIdentifier == GameIdentity.qaBundleID
        func bundlePath(_ key: String) -> URL? {
            guard qaBundle, let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
            return URL(fileURLWithPath: value)
        }
        profile = path(after: "--qa-profile") ?? bundlePath("IEQAProfile")
        qaLog = path(after: "--qa-log") ?? bundlePath("IEQALog")
        mute = arguments.contains("--qa-muted") || qaBundle
        orderedRun = arguments.contains("--qa-ordered") || qaBundle
        let flagCount = arguments.firstIndex(of: "--qa-stations").flatMap { index in
            arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) : nil
        }
        let qaCount = qaBundle ? Bundle.main.object(forInfoDictionaryKey: "IEQAStations") as? Int : nil
        let requested = flagCount ?? qaCount
        stationCount = requested.flatMap { PuzzleBank.stationCounts.contains($0) ? $0 : nil }
        let bundleSmoke = qaBundle && Bundle.main.object(forInfoDictionaryKey: "IEQASmoke") as? Bool == true
        smoke = (arguments.contains("--qa-smoke") || bundleSmoke) && profile != nil && qaLog != nil
    }
}

protocol AudioPlayback: AnyObject {
    var numberOfLoops: Int { get set }
    var currentTime: TimeInterval { get set }
    var volume: Float { get set }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    func prepareToPlay() -> Bool
    func play() -> Bool
    func stop()
    func setVolume(_ volume: Float, fadeDuration duration: TimeInterval)
}

extension AVAudioPlayer: AudioPlayback {}
typealias AudioLoader = (URL) throws -> any AudioPlayback

@MainActor
final class GameAudio {
    private var music: (any AudioPlayback)?
    private var players: [Cue: any AudioPlayback] = [:]
    private var active: [Cue.Lane: any AudioPlayback] = [:]
    private var settings = PlayerSettings()
    private let options: LaunchOptions
    private let volumeRatio: Float = 0.54
    private(set) var loadFailure: String?

    init(resources: URL, options: LaunchOptions, load: AudioLoader) {
        self.options = options
        let folder = resources.appendingPathComponent("Audio", isDirectory: true)
        do {
            let track = folder.appendingPathComponent("Music.wav")
            let musicPlayer = try load(track)
            musicPlayer.numberOfLoops = -1
            _ = musicPlayer.prepareToPlay()
            music = musicPlayer
            for cue in Cue.allCases {
                let file = folder.appendingPathComponent(cue.rawValue).appendingPathExtension("wav")
                let effect = try load(file)
                _ = effect.prepareToPlay()
                players[cue] = effect
            }
            log("Audio loaded: \(players.count) effects; music \(musicPlayer.duration)s")
        } catch {
            loadFailure = "Some game audio could not be loaded."
            log("Audio load failed: \(error)")
        }
    }

    var ready: Bool { music != nil && players.count == Cue.allCases.count }
    var musicPlaying: Bool { music?.isPlaying == true }
    func isPlaying(_ cue: Cue) -> Bool { players[cue]?.isPlaying == true }

    func start(with settings: PlayerSettings) {
        configure(settings)
        if !musicPlaying, let music { log("Music started: \(music.play()); loop count \(music.numberOfLoops)") }
    }

    func configure(_ settings: PlayerSettings) {
        self.settings = settings
        music?.volume = options.mute ? 0 : Float(settings.masterVolume * settings.musicVolume) * volumeRatio
        for player in players.values { player.volume = effectsGain }
    }

    private var effectsGain: Float {
        options.mute ? 0 : Float(settings.masterVolume * settings.effectsVolume) * 0.78
    }

    func play(_ cue: Cue) {
        guard let effect = players[cue] else { return }
        let previous = active[cue.lane]
        if previous === effect && effect.isPlaying && effect.currentTime < 0.035 { return }
        if previous !== effect && cue.lane != .result && cue.lane != .transition {
            previous?.stop()
        }
        if cue.lane == .transition, let result = active[.result], result.isPlaying {
            result.setVolume(effectsGain * 0.30, fadeDuration: 0.075)
        }
        effect.currentTime = 0
        effect.volume = effectsGain
        active[cue.lane] = effect
        let started = effect.play()
        if options.qaLog != nil {
            let lanes = active.filter { $0.value.isPlaying }.count
            log("Cue \(cue.rawValue): \(started); active lanes: \(lanes)")
        }
    }

    func log(_ message: String) {
        guard let url = options.qaLog, let bytes = (message + "\n").data(using: .utf8) else { return }
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: bytes)
        } catch {
            print("QA log: \(error)")
        }
    }
}

enum Screen: Equatable { case home, instructions, stages, game, settings }
enum GameOverlay: Equatable { case briefing, pause, leave, passed, completed }

struct DialogueLine {
    let worker: Worker
    let text: String
}

struct Briefing {
    let cast: [Worker]
    let introduced: String?
    let situation: String
    let lines: [DialogueLine]
}

struct Feedback: Equatable {
    var message: String
    var problem: Bool = false
}

@MainActor
final class GameSession: ObservableObject {
    @Published private(set) var screen: Screen = .home
    @Published private(set) var data: PlayerData
    @Published private(set) var run: StageRun?
    @Published private(set) var selected: String?
    @Published private(set) var overlay: GameOverlay?
    @Published private(set) var briefing: Briefing?
    @Published private(set) var dialogueIndex = 0
    @Published private(set) var feedback: Feedback?
    @Published private(set) var warning: String?
    @Published private(set) var launchFailure: String?

    var didSmokeTest = false
    let audio: GameAudio
    let options: LaunchOptions
    private let store: PlayerStore
    private let bank: PuzzleBank?
    private var returnScreen: Screen = .home
    private var didStart = false
    private var seenWorkers: Set<String> = []
    private var saveReadable = true

    init(resources: URL, options: LaunchOptions = LaunchOptions(),
         loadAudio: AudioLoader = { try AVAudioPlayer(contentsOf: $0) }) {
        self.options = options
        audio = GameAudio(resources: resources, options: options, load: loadAudio)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = PlayerStore(directory: options.profile ?? support.appendingPathComponent(GameIdentity.name, isDirectory: true))
        let oldStore = PlayerStore(directory: support.appendingPathComponent("IE Puzzle Game", isDirectory: true))
        do {
            if options.profile == nil,
               !FileManager.default.fileExists(atPath: store.file.path),
               FileManager.default.fileExists(atPath: oldStore.file.path) {
                data = (try? oldStore.load()) ?? PlayerData()
            } else {
                data = try store.load()
            }
        } catch {
            data = PlayerData()
            saveReadable = false
            warning = "Saved settings could not be read. This session won't overwrite them."
        }
        do {
            bank = try PuzzleBank.load(from: resources.appendingPathComponent("Puzzles.json"))
        } catch {
            bank = nil
            launchFailure = "The puzzle bank could not be opened. \(error.localizedDescription)"
        }
        if warning == nil { warning = audio.loadFailure }
    }

    var settings: PlayerSettings { data.settings }
    var gameActive: Bool { screen == .game && overlay == nil && run != nil }
    var profileFile: URL { store.file }

    func startAudio() {
        guard !didStart else { return }
        didStart = true
        audio.start(with: settings)
    }

    func navigate(to next: Screen, cue: Cue = .click) {
        screen = next
        audio.play(cue)
    }

    func showSettings() {
        returnScreen = screen
        navigate(to: .settings)
    }

    func closeSettings() { navigate(to: returnScreen, cue: .back) }

    func updateSettings(_ settings: PlayerSettings) {
        guard settings != data.settings else { return }
        data.settings = settings
        audio.configure(settings)
        save()
    }

    func changeVolumePreview() { audio.play(.click) }

    func resetSettings() {
        updateSettings(PlayerSettings())
        audio.play(.popup)
    }

    func quit() {
        if screen == .game, overlay != .completed {
            askToLeave()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    func startRun() {
        guard let bank else { return }
        var random = SystemRandomNumberGenerator()
        let draw: [Puzzle]
        if options.orderedRun {
            let count = options.stationCount ?? PuzzleBank.stationCounts[0]
            draw = Array(bank.puzzles.filter { $0.stations.count == count }.prefix(StageRun.length))
        } else {
            draw = bank.draw(using: &random)
        }
        run = StageRun(puzzles: draw, roster: bank.roster)
        selected = nil
        feedback = nil
        seenWorkers = []
        screen = .game
        prepareBriefing()
        audio.play(.click)
        audio.log("Run: \(draw.prefix(StageRun.length).map(\.id).joined(separator: ", "))")
    }

    func pick(_ worker: String, toggle: Bool = true) {
        guard gameActive, let board = run?.board, board.puzzle.crew.contains(worker) else { return }
        if selected == worker {
            if toggle { cancelSelection() }
            return
        }
        selected = worker
        feedback = nil
        audio.play(.pickup)
    }

    func cancelSelection(fromDrag: Bool = false) {
        guard selected != nil else { return }
        selected = nil
        feedback = nil
        if fromDrag { audio.play(.tray) }
    }

    func act(on slot: Slot) {
        guard gameActive, let board = run?.board else { return }
        if let selected {
            move(selected, to: slot)
        } else if let worker = board.worker(in: slot) {
            pick(worker)
        } else {
            feedback = Feedback(message: "Choose a worker first.")
        }
    }

    func move(_ worker: String, to slot: Slot) {
        guard gameActive, var current = run else { return }
        switch current.board.place(worker, in: slot) {
        case .placed:
            run = current
            selected = nil
            feedback = nil
            audio.play(.staffingPlacement)
            audio.log("Occupied " + slot.id + " with " + worker)
        case .swapped:
            run = current
            selected = nil
            feedback = nil
            audio.play(.swap)
        case .unchanged:
            cancelSelection()
        case .blocked(let message):
            feedback = Feedback(message: message, problem: true)
            audio.play(.blocked)
        }
    }

    func returnToTray(_ worker: String? = nil) {
        guard gameActive, let worker = worker ?? selected, var current = run else { return }
        if current.board.remove(worker) { run = current }
        selected = nil
        feedback = nil
        audio.play(.tray)
    }

    func checkPlan() {
        guard gameActive, var current = run else { return }
        let issues = current.check()
        run = current
        if let first = issues.first {
            feedback = Feedback(message: first, problem: true)
            audio.play(.revise)
            return
        }
        selected = nil
        feedback = nil
        if current.isFinalPuzzle {
            data.completedStageOne = true
            save()
            overlay = .completed
            audio.play(.stageCleared)
        } else {
            overlay = .passed
            audio.play(.passed)
        }
    }

    func continueRun() {
        guard overlay == .passed, var current = run, current.next() else { return }
        run = current
        prepareBriefing()
        audio.play(.nextStaffing)
        audio.log("Opened next puzzle: \(current.board.puzzle.id)")
    }

    private func prepareBriefing() {
        guard let board = run?.board else { return }
        let newWorkers = board.crew.filter { !seenWorkers.contains($0.id) }
        let ruleWorkers = board.puzzle.rules.flatMap(\.workers)
        let newIDs = Set(newWorkers.map(\.id))
        let priorityNew = ruleWorkers.first { newIDs.contains($0) }.flatMap { board.roster[$0] }
        let priorityCrew = ruleWorkers.first.flatMap { board.roster[$0] }
        let speaker = priorityNew ?? newWorkers.first ?? priorityCrew ?? board.crew[0]
        let ownRule = board.puzzle.rules.first { $0.workers.contains(speaker.id) }
        let line: String
        if let ownRule {
            switch ownRule.kind {
            case .only:
                line = "I can only work at " + ownRule.station!.title + " today."
            case .banned:
                line = "I can't use " + ownRule.station!.title + " today."
            case .together, .apart:
                let partnerID = ownRule.workers.first { $0 != speaker.id }!
                let name = board.roster[partnerID]!.name
                line = ownRule.kind == .together
                    ? name + " and I need to work at the same station."
                    : name + " and I need to work at different stations."
            }
        } else {
            let station = board.puzzle.stations.max { speaker.power(at: $0) < speaker.power(at: $1) }!
            line = "I bring " + String(speaker.power(at: station)) + " power to " + station.title + "."
        }
        let coworker = ownRule?.workers.first(where: { $0 != speaker.id }).flatMap { board.roster[$0] }
            ?? board.crew.first(where: { $0.id != speaker.id })!
        let introduced = newWorkers.contains(speaker) && run?.index != 0 ? speaker.id : nil
        seenWorkers.formUnion(board.puzzle.crew)
        briefing = Briefing(cast: [coworker, speaker], introduced: introduced,
                            situation: board.puzzle.briefing, lines: [
            DialogueLine(worker: coworker, text: board.puzzle.greeting),
            DialogueLine(worker: speaker, text: line),
            DialogueLine(worker: coworker, text: board.puzzle.closing),
        ])
        dialogueIndex = 0
        overlay = .briefing
        audio.log("Dialogue ready: " + board.puzzle.id)
    }

    func advanceDialogue() {
        guard overlay == .briefing, let briefing else { return }
        if dialogueIndex + 1 < briefing.lines.count {
            dialogueIndex += 1
            audio.play(.click)
        } else {
            beginPuzzle()
        }
    }

    func beginPuzzle(skip: Bool = false) {
        guard overlay == .briefing else { return }
        overlay = nil
        briefing = nil
        audio.play(skip ? .back : .click)
    }

    func escape() {
        if selected != nil { cancelSelection() } else { pause() }
    }

    func pause() {
        guard gameActive else { return }
        overlay = .pause
        audio.play(.pause)
    }

    func resume() {
        guard overlay == .pause else { return }
        overlay = nil
        audio.play(.resume)
    }

    func askToLeave() {
        guard run != nil else { return }
        overlay = .leave
        audio.play(.popup)
    }

    func keepPlaying() {
        overlay = .pause
        audio.play(.back)
    }

    func leaveStage() {
        run = nil
        briefing = nil
        selected = nil
        overlay = nil
        feedback = nil
        navigate(to: .stages, cue: .back)
    }

    private func save() {
        guard saveReadable else { return }
        do {
            try store.save(data)
            audio.log("Player saved; stage one complete: \(data.completedStageOne)")
        } catch {
            warning = "Progress or settings could not be saved. \(error.localizedDescription)"
            audio.log("Save failed: \(error)")
        }
    }
}
