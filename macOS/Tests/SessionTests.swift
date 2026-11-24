import AVFoundation
import Foundation

/// Reads the real bundled audio without requiring a live output device.
private final class RecordingPlayback: AudioPlayback {
    let duration: TimeInterval
    var numberOfLoops = 0
    var currentTime: TimeInterval = 0
    var volume: Float = 1
    private(set) var isPlaying = false

    init(file: URL) throws {
        let audio = try AVAudioFile(forReading: file)
        duration = Double(audio.length) / audio.fileFormat.sampleRate
        guard duration > 0 else { throw CocoaError(.fileReadCorruptFile) }
    }

    func prepareToPlay() -> Bool { true }
    func play() -> Bool {
        isPlaying = true
        return true
    }
    func stop() { isPlaying = false }
    func setVolume(_ volume: Float, fadeDuration duration: TimeInterval) {
        self.volume = volume
    }
}

@main
struct SessionTests {
    @MainActor
    static func main() async throws {
        let arguments = CommandLine.arguments
        precondition(arguments.count == 3)
        let resources = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
        var failures = 0
        for count in PuzzleBank.stationCounts {
            let settings = LaunchOptions(["test", "--qa-muted", "--qa-ordered", "--qa-stations", String(count),
                "--qa-profile", root.appendingPathComponent("profile-\(count)").path,
                "--qa-log", root.appendingPathComponent("events-\(count).log").path])
            let game = GameSession(resources: resources, options: settings, loadAudio: RecordingPlayback.init)
            game.startAudio()
            if game.smokeTest() {
                print("PASS: \(count)-station session, save, dialogue and audio cue routing.")
            } else {
                failures += 1
                let log = root.appendingPathComponent("events-\(count).log")
                print("FAILED \(count) stations: \(try String(contentsOf: log).split(separator: "\n").last ?? "")")
            }
        }
        try progression(resources: resources, root: root)
        try localization(resources: resources, root: root)
        let timerProfile = root.appendingPathComponent("timer-profile")
        let timerGame = GameSession(resources: resources,
                                    options: LaunchOptions(["test", "--qa-profile", timerProfile.path, "--qa-muted"]),
                                    loadAudio: RecordingPlayback.init)
        timerGame.startRun()
        await timerGame.playDialogueBeat()
        precondition(timerGame.dialogueIndex == 1)
        timerGame.toggleDialoguePause()
        await timerGame.playDialogueBeat()
        precondition(timerGame.dialogueIndex == 1)
        timerGame.beginPuzzle(skip: true)
        precondition(timerGame.gameActive)
        print("PASS: Automatic dialogue advances, pauses and skips.")
        if failures > 0 { exit(1) }
    }
    @MainActor
    private static func localization(resources: URL, root: URL) throws {
        let thai = GameLanguage.thai
        func hasThai(_ value: String) -> Bool {
            value.unicodeScalars.contains { (0x0E00...0x0E7F).contains(Int($0.value)) }
        }
        let staffing = try PuzzleBank.load(from: resources.appendingPathComponent("Puzzles.json"))
        let workshop = try JSONDecoder().decode(WorkshopBank.self, from: Data(contentsOf: resources.appendingPathComponent("Workshop.json")))
        for puzzle in staffing.puzzles {
            precondition([puzzle.title, puzzle.layout, puzzle.briefing, puzzle.greeting, puzzle.closing]
                .allSatisfy { hasThai(thai.text($0)) }, "Missing Thai text for " + puzzle.id)
            let board = StaffingBoard(puzzle: puzzle, roster: staffing.roster)
            precondition(board.issues(language: thai).allSatisfy(hasThai))
            precondition(puzzle.rules.allSatisfy { hasThai(board.text(for: $0, language: thai)) })
        }
        precondition(staffing.workers.allSatisfy { hasThai(thai.text($0.name)) })
        precondition(workshop.delivery.flatMap(\.stops).allSatisfy { hasThai(thai.text($0.name)) })
        for stage in WorkStage.allCases.dropFirst() {
            for mode in 0..<3 {
                for board in workshop.draw(stage, mode: mode) {
                    precondition(hasThai(board.spotlight(in: thai)))
                }
            }
        }
        let cards = workshop.flow.map(\.card) + workshop.plant.map(\.card) + workshop.delivery.map(\.card)
        for card in cards {
            precondition([card.title, card.layout, card.greeting, card.closing, card.pace]
                .allSatisfy { hasThai(thai.text($0)) }, "Missing Thai text for " + card.id)
        }
        precondition(thai.text("Puzzle %@ of %@", "2", "6") == "โจทย์ 2 จาก 6")
        precondition(thai.text("I bring %@ power to %@.", "4", "Press") == "ถ้าอยู่สถานีกดขึ้นรูป ฉันช่วยเพิ่มกำลังได้ 4")
        precondition(GameLanguage.english.text("Puzzle %@ of %@", "2", "6") == "Puzzle 2 of 6")

        let profile = root.appendingPathComponent("thai-profile")
        let options = LaunchOptions(["test", "--qa-profile", profile.path, "--qa-muted", "--qa-ordered"])
        let game = GameSession(resources: resources, options: options, loadAudio: RecordingPlayback.init)
        precondition(game.settings.language == .english)
        game.startRun()
        game.beginPuzzle(skip: true)
        game.pause()
        game.showSettings()
        let draft = game.run?.board.assignments
        var settings = game.settings
        settings.language = .thai
        game.updateSettings(settings)
        game.closeSettings()
        game.resume()
        precondition(game.run?.board.assignments == draft && game.gameActive)
        let restored = GameSession(resources: resources, options: options, loadAudio: RecordingPlayback.init)
        precondition(restored.settings.language == .thai)
        print("PASS: Thai copy for all 360 puzzles, translated rules, language switching and persistence.")
    }

    @MainActor
    private static func progression(resources: URL, root: URL) throws {
        let url = root.appendingPathComponent("release-profile")
        let store = PlayerStore(directory: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let legacy = #"{"completedStageOne":true,"settings":{"masterVolume":0.8,"musicVolume":0.6,"effectsVolume":0.8,"fullscreen":false,"windowSize":"1280 × 720","largeText":false,"reduceMotion":false,"strongerSlots":false,"keyboardHints":true}}"#
        try Data(legacy.utf8).write(to: store.file)
        let options = LaunchOptions(["test", "--qa-muted", "--qa-ordered", "--qa-profile", url.path])
        let game = GameSession(resources: resources, options: options, loadAudio: RecordingPlayback.init)
        game.startAudio()
        precondition(game.launchFailure == nil && game.audio.ready && game.audio.stageMixReady)
        precondition(game.completed(.staffing) && game.unlocked(.bottleneck) && !game.unlocked(.plant))
        game.startRun(.delivery)
        precondition(game.workshop == nil)
        for stage in WorkStage.allCases.dropFirst() {
            game.startRun(stage, mode: stage.rawValue - 2)
            precondition(game.briefing?.lines.count == 3)
            game.toggleDialoguePause()
            precondition(game.dialoguePaused)
            game.toggleDialoguePause()
            for index in 0..<6 {
                game.beginPuzzle(skip: true)
                precondition(game.gameActive && game.audio.musicPlaying)
                switch game.workshop!.board {
                case .flow(let p, let plan):
                    let solved = p.solutions(upTo: 1)[0]
                    let instructions = pathToFlowPlan(p, from: plan, to: solved)!
                    for move in instructions {
                        game.moveFlow(worker: move.worker, to: move.station, swapping: move.swap)
                    }
                case .plant(let p, let plan):
                    let solved = p.solutions(upTo: 1)[0]
                    var current = plan
                    for i in plan.indices where !p.fixed.contains(i) && current[i] != solved[i] {
                        game.moveMachine(i, to: solved[i])
                        if case .plant(_, let changed) = game.workshop!.board { current = changed }
                    }
                case .delivery(let p, _):
                    let tour = p.solutions(upTo: 1)[0]
                    for stop in tour.reversed() { game.toggleStop(stop) }
                    for (index, stop) in tour.enumerated() { game.reorderStop(stop, to: index) }
                }
                precondition(game.workshop?.board.issues.isEmpty == true, "UI actions must reach a passing plan")
                game.checkPlan()
                precondition(game.overlay == (index == 5 ? .completed : .passed))
                if index < 5 {
                    game.continueRun()
                    precondition(game.overlay == .briefing && game.puzzleIndex == index + 1)
                }
            }
            precondition(game.data.completedStageCount == stage.rawValue)
        }
        let reopened = GameSession(resources: resources, options: options, loadAudio: RecordingPlayback.init)
        precondition(reopened.data.completedStageCount == 4)
        print("PASS: Legacy save, all unlocks, 18 workshop puzzles via play actions, sound assets and final save.")
    }
}
