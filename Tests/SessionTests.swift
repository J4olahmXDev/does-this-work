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
    static func main() throws {
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
        if failures > 0 { exit(1) }
    }
}
