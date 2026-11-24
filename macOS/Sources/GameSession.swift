import AppKit
import AVFoundation
import Foundation
import SwiftUI

enum GameIdentity {
    static let name = "Does This Work?"
    static let version = "0.6"
    static let profileDirectory = name + " v" + version
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
    private var themes: [WorkStage: any AudioPlayback] = [:]
    private var layers: [WorkStage: any AudioPlayback] = [:]
    private var voices: [String: any AudioPlayback] = [:]
    private var voice: (any AudioPlayback)?
    private var activeStage: WorkStage?
    private var briefingMix = false
    private(set) var stageMixReady = false
    private var layerTask: Task<Void, Never>?
    private var layerAudible = false
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
            for stage in WorkStage.allCases {
                for (suffix, layer) in [("", false), ("-Layer", true)] {
                    let player = try load(folder.appendingPathComponent("Stage-\(stage.rawValue)\(suffix).wav"))
                    player.numberOfLoops = -1
                    _ = player.prepareToPlay()
                    if layer { layers[stage] = player } else { themes[stage] = player }
                }
            }
            for name in ["cap", "beanie", "pocket", "goggles", "earmuffs", "bow",
                         "visor", "scarf", "glasses", "badge", "star", "headband"] {
                let player = try load(folder.appendingPathComponent("Voice-\(name).wav"))
                _ = player.prepareToPlay()
                voices[name] = player
            }
            stageMixReady = true
        } catch {
            loadFailure = "Some game audio could not be loaded."
            log("Audio load failed: \(error)")
        }
    }

    var ready: Bool { music != nil && players.count == Cue.allCases.count }
    private var currentMusic: (any AudioPlayback)? {
        if let activeStage { return themes[activeStage] }
        return music
    }
    var musicPlaying: Bool { currentMusic?.isPlaying == true }
    func isPlaying(_ cue: Cue) -> Bool { players[cue]?.isPlaying == true }

    func start(with settings: PlayerSettings) {
        configure(settings)
        if !musicPlaying, let track = currentMusic {
            log("Music started: \(track.play()); loop count \(track.numberOfLoops)")
        }
    }

    func configure(_ settings: PlayerSettings) {
        self.settings = settings
        currentMusic?.volume = musicGain * (briefingMix ? 0.62 : 1)
        if let activeStage { layers[activeStage]?.volume = layerAudible ? musicGain : 0 }
        voice?.volume = voiceGain
        for player in players.values { player.volume = effectsGain }
    }

    private var musicGain: Float {
        options.mute ? 0 : Float(settings.masterVolume * settings.musicVolume) * volumeRatio
    }

    private var voiceGain: Float {
        options.mute ? 0 : Float(settings.masterVolume * settings.voiceVolume)
    }

    func soundscape(stage: WorkStage?, menu: Bool, briefing: Bool) {
        let oldTrack = currentMusic
        if activeStage != stage || (!menu && stage == nil) {
            layerTask?.cancel()
            layerAudible = false
            if let activeStage { layers[activeStage]?.stop() }
            oldTrack?.stop()
            activeStage = stage
        }
        briefingMix = briefing
        configure(settings)
        guard menu || stage != nil, let track = currentMusic else { return }
        if !track.isPlaying {
            track.currentTime = 0
            if let stage, let layer = layers[stage] {
                layer.currentTime = 0
                layer.volume = 0
                if let base = track as? AVAudioPlayer, let companion = layer as? AVAudioPlayer {
                    let start = base.deviceCurrentTime + 0.035
                    _ = base.play(atTime: start)
                    _ = companion.play(atTime: start)
                } else {
                    _ = track.play()
                    _ = layer.play()
                }
            } else {
                _ = track.play()
            }
        }
        layerTask?.cancel()
        guard let stage, let layer = layers[stage] else { return }
        if briefing {
            layerAudible = false
            layer.setVolume(0, fadeDuration: 0.2)
            return
        }
        let tempo = [112.0,116,108,118][stage.rawValue-1]
        let bar = 240 / tempo
        let wait = bar - track.currentTime.truncatingRemainder(dividingBy: bar)
        layerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, self.activeStage == stage, !self.briefingMix else { return }
            self.layerAudible = true
            layer.setVolume(self.musicGain, fadeDuration: 0.18)
        }
    }

    func speak(_ worker: Worker) {
        stopVoice()
        guard let key = worker.style.split(separator: ":").first, let player = voices[String(key)] else { return }
        voice = player
        player.currentTime = 0
        player.volume = voiceGain
        _ = player.play()
    }

    func stopVoice() {
        voice?.stop()
        voice = nil
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
    @Published private(set) var workshop: WorkshopRun?
    @Published private(set) var stage: WorkStage = .staffing
    @Published private(set) var dialoguePaused = false
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
    private let workshopBank: WorkshopBank?
    private var returnScreen: Screen = .home
    private var didStart = false
    private var seenWorkers: Set<String> = []
    private var saveReadable = true

    init(resources: URL, options: LaunchOptions = LaunchOptions(),
         loadAudio: AudioLoader = { try AVAudioPlayer(contentsOf: $0) }) {
        self.options = options
        audio = GameAudio(resources: resources, options: options, load: loadAudio)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = PlayerStore(directory: options.profile ?? support.appendingPathComponent(GameIdentity.profileDirectory, isDirectory: true))
        let olderStores = [GameIdentity.name + " v0.5", GameIdentity.name, "IE Puzzle Game"].map {
            PlayerStore(directory: support.appendingPathComponent($0, isDirectory: true))
        }
        do {
            if options.profile == nil,
               !FileManager.default.fileExists(atPath: store.file.path),
               let oldStore = olderStores.first(where: { FileManager.default.fileExists(atPath: $0.file.path) }) {
                data = try oldStore.load()
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
            launchFailure = "The puzzle bank could not be opened."
            print("Puzzle bank: \(error.localizedDescription)")
        }
        do {
            let url = resources.appendingPathComponent("Workshop.json")
            let loaded = try JSONDecoder().decode(WorkshopBank.self, from: Data(contentsOf: url))
            try loaded.validate()
            workshopBank = loaded
        } catch {
            workshopBank = nil
            launchFailure = "The workshop puzzles could not be opened."
            audio.log("Workshop puzzles: \(error.localizedDescription)")
        }
        if warning == nil { warning = audio.loadFailure }
    }

    var settings: PlayerSettings { data.settings }
    var gameActive: Bool { screen == .game && overlay == nil && (run != nil || workshop != nil) }
    var puzzleIndex: Int { run?.index ?? workshop?.index ?? 0 }
    var puzzleID: String { run?.board.puzzle.id ?? workshop?.board.card.id ?? "" }
    var puzzleTitle: String { run?.board.puzzle.title ?? workshop?.board.card.title ?? "" }
    var puzzleLayout: String { run?.board.puzzle.layout ?? workshop?.board.card.layout ?? "" }
    var nextStage: WorkStage? { WorkStage(rawValue: stage.rawValue + 1) }
    func worker(_ id: String) -> Worker? { bank?.workers.first { $0.id == id } }
    func unlocked(_ stage: WorkStage) -> Bool { stage.rawValue <= data.completedStageCount + 1 }
    func completed(_ stage: WorkStage) -> Bool { stage.rawValue <= data.completedStageCount }

    private func refreshSound() {
        audio.soundscape(stage: screen == .game ? stage : nil,
                         menu: screen == .home || screen == .settings, briefing: overlay == .briefing)
    }
    var profileFile: URL { store.file }

    func startAudio() {
        guard !didStart else { return }
        didStart = true
        audio.start(with: settings)
    }

    func navigate(to next: Screen, cue: Cue = .click) {
        screen = next
        refreshSound()
        audio.play(cue)
    }

    func showSettings() {
        returnScreen = screen
        navigate(to: .settings)
    }

    func closeSettings() { navigate(to: returnScreen, cue: .back) }

    func updateSettings(_ settings: PlayerSettings) {
        guard settings != data.settings else { return }
        if data.settings.language != settings.language { feedback = nil }
        data.settings = settings
        audio.configure(settings)
        save()
    }

    func changeVolumePreview() { audio.play(.click) }

    func resetSettings() {
        var defaults = PlayerSettings()
        if settings.language != .english { defaults.language = settings.language }
        updateSettings(defaults)
        audio.play(.popup)
    }

    func quit() {
        if screen == .game, overlay != .completed {
            askToLeave()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    func startRun(_ stage: WorkStage = .staffing, mode: Int? = nil) {
        guard let bank, unlocked(stage) else { return }
        self.stage = stage
        workshop = nil
        run = nil
        if stage != .staffing {
            let chosen = mode ?? (options.orderedRun ? 0 : Int.random(in: 0..<3))
            guard let draw = workshopBank?.draw(stage, mode: chosen, ordered: options.orderedRun),
                  draw.count == StageRun.length else { return }
            workshop = WorkshopRun(draw)
            selected = nil
            feedback = nil
            screen = .game
            prepareBriefing()
            audio.play(.click)
            return
        }
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
        switch current.board.place(worker, in: slot, language: settings.language) {
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

    func moveFlow(worker: Int, to station: Int, swapping other: Int?) {
        guard gameActive, case .flow(let puzzle, var plan)? = workshop?.board,
              plan.indices.contains(worker), puzzle.stations.indices.contains(station), plan[worker] != station else { return }
        guard puzzle.allowed[worker].contains(station) else { return reject("This worker cannot use that station.") }
        if let other {
            guard plan.indices.contains(other), plan[other] == station, puzzle.allowed[other].contains(plan[worker]) else {
                return reject("These workers cannot swap stations.")
            }
            plan[other] = plan[worker]
        } else if plan.filter({ $0 == station }).count >= puzzle.capacities[station] {
            return reject("This station is full. Select a worker to swap.")
        }
        plan[worker] = station
        workshop?.board = .flow(puzzle, plan)
        feedback = nil
        audio.play(.bottleneckFlow)
    }

    func moveMachine(_ machine: Int, to bay: Int) {
        guard gameActive, case .plant(let puzzle, var plan)? = workshop?.board,
              plan.indices.contains(machine), puzzle.bays.contains(bay), plan[machine] != bay else { return }
        let occupant = plan.firstIndex(of: bay)
        guard !puzzle.fixed.contains(machine), occupant.map({ !puzzle.fixed.contains($0) }) != false else {
            return reject("That machine is fixed in place.")
        }
        if let occupant { plan[occupant] = plan[machine] }
        plan[machine] = bay
        workshop?.board = .plant(puzzle, plan)
        feedback = nil
        audio.play(.plantTile)
    }

    func toggleStop(_ stop: Int) {
        guard gameActive, case .delivery(let puzzle, var order)? = workshop?.board,
              stop != 0, puzzle.stops.indices.contains(stop) else { return }
        if let index = order.firstIndex(of: stop) {
            order.remove(at: index)
            audio.play(.back)
        } else {
            order.append(stop)
            audio.play(.deliveryStop)
        }
        workshop?.board = .delivery(puzzle, order)
        feedback = nil
    }

    func reorderStop(_ stop: Int, to index: Int) {
        guard gameActive, case .delivery(let puzzle, var order)? = workshop?.board,
              order.indices.contains(index), let from = order.firstIndex(of: stop), from != index else { return }
        order.remove(at: from)
        order.insert(stop, at: index)
        workshop?.board = .delivery(puzzle, order)
        feedback = nil
        audio.play(.deliveryReorder)
    }

    private func reject(_ message: String) {
        feedback = Feedback(message: message, problem: true)
        audio.play(.blocked)
    }

    func checkPlan() {
        guard gameActive else { return }
        let issues: [String]
        let final: Bool
        if var current = run {
            issues = current.check(language: settings.language)
            final = current.isFinalPuzzle
            run = current
        } else if let workshop {
            issues = workshop.board.issues(in: settings.language)
            final = workshop.isFinal
        } else { return }
        if let first = issues.first {
            feedback = Feedback(message: first, problem: true)
            audio.play(.revise)
            return
        }
        selected = nil
        feedback = nil
        if final {
            let prior = data.completedStageCount
            data.completedThrough = max(prior, stage.rawValue)
            if stage == .staffing { data.completedStageOne = true }
            save()
            overlay = .completed
            audio.play(stage == .delivery ? .gameComplete : .stageCleared)
            if prior < stage.rawValue && stage != .delivery { audio.play(.stageUnlocked) }
        } else {
            overlay = .passed
            audio.play(.passed)
        }
    }

    func continueRun() {
        guard overlay == .passed else { return }
        if var current = run {
            guard current.next() else { return }
            run = current
        } else {
            workshop?.next()
        }
        prepareBriefing()
        let cue: Cue = switch stage {
        case .staffing: .nextStaffing
        case .bottleneck: .nextBottleneck
        case .plant: .nextPlant
        case .delivery: .nextDelivery
        }
        audio.play(cue)
        audio.log("Opened next puzzle: " + puzzleID)
    }

    private func prepareBriefing() {
        dialogueIndex = 0
        dialoguePaused = false
        overlay = .briefing
        refreshSound()
        guard let board = run?.board else {
            guard let board = workshop?.board, let roster = bank?.roster else { return }
            let names: [String] = switch stage {
            case .staffing: ["ari", "hana"]
            case .bottleneck: ["dee", "bo"]
            case .plant: ["eli", "fay"]
            case .delivery: ["gus", "cam"]
            }
            let cast = names.compactMap { roster[$0] }
            guard cast.count == 2 else { return }
            briefing = Briefing(cast: cast, introduced: nil, situation: board.card.layout, lines: [
                DialogueLine(worker: cast[0], text: board.card.greeting),
                DialogueLine(worker: cast[1], text: board.spotlight(in: settings.language)),
                DialogueLine(worker: cast[0], text: board.card.closing)
            ])
            return
        }
        let newWorkers = board.crew.filter { !seenWorkers.contains($0.id) }
        let ruleWorkers = board.puzzle.rules.flatMap(\.workers)
        let newIDs = Set(newWorkers.map(\.id))
        let priorityNew = ruleWorkers.first { newIDs.contains($0) }.flatMap { board.roster[$0] }
        let priorityCrew = ruleWorkers.first.flatMap { board.roster[$0] }
        let speaker = priorityNew ?? newWorkers.first ?? priorityCrew ?? board.crew[0]
        let language = settings.language
        let ownRule = board.puzzle.rules.first { $0.workers.contains(speaker.id) }
        let line: String
        if let ownRule {
            switch ownRule.kind {
            case .only:
                line = language.text("I can only work at %@ today.", ownRule.station!.title)
            case .banned:
                line = language.text("I can't use %@ today.", ownRule.station!.title)
            case .together, .apart:
                let partnerID = ownRule.workers.first { $0 != speaker.id }!
                let name = board.roster[partnerID]!.name
                line = ownRule.kind == .together
                    ? language.text("%@ and I need to work at the same station.", name)
                    : language.text("%@ and I need to work at different stations.", name)
            }
        } else {
            let station = board.puzzle.stations.max { speaker.power(at: $0) < speaker.power(at: $1) }!
            line = language.text("I bring %@ power to %@.", String(speaker.power(at: station)), station.title)
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
        audio.log("Dialogue ready: " + board.puzzle.id)
    }

    func advanceDialogue() {
        guard overlay == .briefing, let briefing else { return }
        if dialogueIndex + 1 < briefing.lines.count {
            dialogueIndex += 1
        } else {
            beginPuzzle()
        }
    }

    func toggleDialoguePause() {
        guard overlay == .briefing else { return }
        dialoguePaused.toggle()
        if dialoguePaused { audio.stopVoice() }
        audio.play(dialoguePaused ? .pause : .resume)
    }

    func playDialogueBeat() async {
        guard !dialoguePaused, overlay == .briefing, let line = briefing?.lines[dialogueIndex] else { return }
        let id = puzzleID
        let index = dialogueIndex
        audio.speak(line.worker)
        let caption = settings.language.text(line.text)
        let readingTime = settings.language == .thai ? Double(caption.count) / 16 + 0.7 :
            Double(caption.split(separator: " ").count) / 3.2 + 0.6
        let seconds = max(3.4, readingTime)
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled, !dialoguePaused, overlay == .briefing, puzzleID == id, dialogueIndex == index else { return }
        advanceDialogue()
    }

    func beginPuzzle(skip: Bool = false) {
        guard overlay == .briefing else { return }
        audio.stopVoice()
        overlay = nil
        briefing = nil
        refreshSound()
        if skip { audio.play(.back) }
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
        guard run != nil || workshop != nil else { return }
        audio.stopVoice()
        overlay = .leave
        audio.play(.popup)
    }

    func keepPlaying() {
        overlay = .pause
        audio.play(.back)
    }

    func leaveStage() {
        run = nil
        workshop = nil
        audio.stopVoice()
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
            warning = "Progress or settings could not be saved."
            audio.log("Save failed: \(error)")
        }
    }
}
