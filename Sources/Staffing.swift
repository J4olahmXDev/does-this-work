import Foundation

enum Station: String, CaseIterable, Codable, Hashable {
    case large, medium, small, sort, seal, label

    var title: String {
        switch self {
        case .large: "Press"
        case .medium: "Assemble"
        case .small: "Wrap"
        default: rawValue.capitalized
        }
    }

    var initial: String {
        switch self {
        case .large: "P"
        case .medium: "A"
        case .small: "W"
        case .sort: "So"
        case .seal: "Se"
        case .label: "La"
        }
    }
}

struct Worker: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let style: String
    let ratings: [Station: Int]

    private enum CodingKeys: String, CodingKey { case id, name, style, ratings }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        id = try fields.decode(String.self, forKey: .id)
        name = try fields.decode(String.self, forKey: .name)
        style = try fields.decode(String.self, forKey: .style)
        let values = try fields.decode([String: Int].self, forKey: .ratings)
        ratings = Dictionary(uniqueKeysWithValues: Station.allCases.compactMap { station in
            values[station.rawValue].map { (station, $0) }
        })
    }

    func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(id, forKey: .id)
        try fields.encode(name, forKey: .name)
        try fields.encode(style, forKey: .style)
        try fields.encode(Dictionary(uniqueKeysWithValues: ratings.map { ($0.key.rawValue, $0.value) }), forKey: .ratings)
    }

    func power(at station: Station) -> Int { ratings[station, default: 0] }
}

struct Slot: Hashable, Identifiable {
    let station: Station
    let number: Int

    var id: String { "\(station.initial)\(number)" }
}

struct Rule: Codable, Hashable {
    enum Kind: String, Codable, Hashable { case only, banned, together, apart }

    let kind: Kind
    let workers: [String]
    let station: Station?

    func allows(_ worker: String, at target: Station) -> Bool {
        guard workers.contains(worker) else { return true }
        switch kind {
        case .only: return station == target
        case .banned: return station != target
        case .together, .apart: return true
        }
    }

    func satisfied(by stations: [String: Station]) -> Bool {
        switch kind {
        case .only, .banned:
            guard let worker = workers.first, let target = stations[worker] else { return true }
            return allows(worker, at: target)
        case .together, .apart:
            guard workers.count == 2, let first = stations[workers[0]], let second = stations[workers[1]] else {
                return true
            }
            return kind == .together ? first == second : first != second
        }
    }
}

struct Puzzle: Codable, Identifiable {
    let id: String
    let title: String
    let layout: String
    let briefing: String
    let greeting: String
    let closing: String
    let crew: [String]
    let stations: [Station]
    let minimums: [Int]
    let capacity: [Int]
    let rules: [Rule]
    let initial: [String: String]

    func minimum(at station: Station) -> Int {
        stations.firstIndex(of: station).map { minimums[$0] } ?? 0
    }

    func slots(at station: Station) -> [Slot] {
        guard let index = stations.firstIndex(of: station) else { return [] }
        let total = capacity[index]
        return (1...total).map { Slot(station: station, number: $0) }
    }

    var slots: [Slot] { stations.flatMap { slots(at: $0) } }

    func allowedStations(for worker: String) -> [Station] {
        stations.filter { target in rules.allSatisfy { $0.allows(worker, at: target) } }
    }
}

struct PuzzleBank: Codable {
    let workers: [Worker]
    let puzzles: [Puzzle]

    static let stationCounts = [4, 5, 6]

    var roster: [String: Worker] { Dictionary(uniqueKeysWithValues: workers.map { ($0.id, $0) }) }

    func draw<R: RandomNumberGenerator>(using random: inout R, stationCount: Int? = nil) -> [Puzzle] {
        let count = stationCount ?? Self.stationCounts.randomElement(using: &random)!
        return Array(puzzles.filter { $0.stations.count == count }.shuffled(using: &random).prefix(StageRun.length))
    }

    static func load(from url: URL) throws -> PuzzleBank {
        let bank = try JSONDecoder().decode(PuzzleBank.self, from: Data(contentsOf: url))
        try bank.validate()
        return bank
    }

    func validate() throws {
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw BankError.invalid(reason) }
        }
        let ids = workers.map(\.id)
        try require(Set(ids).count == workers.count, "Duplicate worker identity")
        let knownWorkers = Set(ids)
        for worker in workers {
            try require(!worker.name.isEmpty && worker.ratings.count == Station.allCases.count &&
                worker.ratings.values.allSatisfy { (1...5).contains($0) }, "Invalid worker: \(worker.id)")
        }
        try require(puzzles.count == 90 && Set(puzzles.map(\.id)).count == 90, "Expected 90 unique puzzles")
        for count in Self.stationCounts {
            try require(puzzles.filter { $0.stations.count == count }.count == 30,
                        "Expected 30 boards with \(count) stations")
        }
        for puzzle in puzzles {
            let count = puzzle.stations.count
            let crew = Set(puzzle.crew)
            try require(Self.stationCounts.contains(count) && Set(puzzle.stations).count == count,
                        "\(puzzle.id): invalid stations")
            try require(crew.count == puzzle.crew.count && ((count + 2)...(count + 4)).contains(crew.count) &&
                crew.isSubset(of: knownWorkers), "\(puzzle.id): invalid crew")
            try require(puzzle.minimums.count == count && puzzle.minimums.allSatisfy { $0 > 0 },
                        "\(puzzle.id): invalid minimums")
            try require(puzzle.capacity.count == count && puzzle.capacity.allSatisfy { (1...4).contains($0) } &&
                puzzle.capacity.reduce(0, +) >= crew.count, "\(puzzle.id): invalid station slots")
            let slotIDs = Set(puzzle.slots.map(\.id))
            try require(Set(puzzle.initial.values).count == puzzle.initial.count &&
                Set(puzzle.initial.values).isSubset(of: slotIDs) && Set(puzzle.initial.keys).isSubset(of: crew),
                "\(puzzle.id): invalid starting assignments")
            for rule in puzzle.rules {
                let expectsStation = rule.kind == .only || rule.kind == .banned
                try require(rule.workers.count == (expectsStation ? 1 : 2) &&
                    Set(rule.workers).count == rule.workers.count && Set(rule.workers).isSubset(of: crew) &&
                    (rule.station != nil) == expectsStation &&
                    rule.station.map { puzzle.stations.contains($0) } != false, "\(puzzle.id): invalid rule")
            }
            for (worker, id) in puzzle.initial {
                let slot = puzzle.slots.first { $0.id == id }!
                try require(puzzle.allowedStations(for: worker).contains(slot.station),
                            "\(puzzle.id): ineligible starting placement")
            }
        }
    }
}

enum BankError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): reason }
    }
}

enum MoveResult: Equatable {
    case placed, swapped, unchanged, blocked(String)
}

struct StaffingBoard {
    let puzzle: Puzzle
    let roster: [String: Worker]
    private(set) var assignments: [String: String]

    init(puzzle: Puzzle, roster: [String: Worker]) {
        self.puzzle = puzzle
        self.roster = roster
        assignments = puzzle.initial
    }

    var crew: [Worker] { puzzle.crew.compactMap { roster[$0] } }

    func worker(in slot: Slot) -> String? {
        assignments.first { $0.value == slot.id }?.key
    }

    func slot(for worker: String) -> Slot? {
        puzzle.slots.first { $0.id == assignments[worker] }
    }

    func power(at station: Station) -> Int {
        puzzle.slots(at: station).compactMap { worker(in: $0) }
            .reduce(0) { $0 + (roster[$1]?.power(at: station) ?? 0) }
    }

    func canPlace(_ worker: String, in target: Slot) -> Bool {
        rejection(for: worker, in: target) == nil
    }

    private func rejection(for worker: String, in target: Slot) -> String? {
        guard puzzle.crew.contains(worker), puzzle.slots.contains(target) else {
            return "Choose a slot on this board."
        }
        let name = roster[worker]?.name ?? "This worker"
        guard puzzle.allowedStations(for: worker).contains(target.station) else {
            return "\(name) cannot work at \(target.station.title)."
        }
        if let occupant = self.worker(in: target), occupant != worker {
            guard let from = slot(for: worker) else {
                return "\(target.id) is occupied. Choose an empty slot."
            }
            guard puzzle.allowedStations(for: occupant).contains(from.station) else {
                return "\(roster[occupant]?.name ?? "That worker") cannot swap into \(from.id)."
            }
        }
        return nil
    }

    @discardableResult
    mutating func place(_ worker: String, in target: Slot) -> MoveResult {
        if let message = rejection(for: worker, in: target) { return .blocked(message) }
        if assignments[worker] == target.id { return .unchanged }
        let occupant = self.worker(in: target)
        if let occupant, let previous = assignments[worker] {
            assignments[occupant] = previous
            assignments[worker] = target.id
            return .swapped
        }
        assignments[worker] = target.id
        return .placed
    }

    @discardableResult
    mutating func remove(_ worker: String) -> Bool {
        assignments.removeValue(forKey: worker) != nil
    }

    func text(for rule: Rule) -> String {
        let names = rule.workers.compactMap { roster[$0]?.name }
        guard let first = names.first else { return "Worker assignment rule" }
        switch rule.kind {
        case .only:
            return "\(first) can only work at \(rule.station?.title ?? "")."
        case .banned:
            return "\(first) cannot work at \(rule.station?.title ?? "")."
        case .together:
            return "\(first) and \(names[1]) must work together."
        case .apart:
            return "\(first) and \(names[1]) must work at different stations."
        }
    }

    func issues() -> [String] {
        var result: [String] = []
        let unassigned = crew.filter { assignments[$0.id] == nil }.map(\.name)
        if !unassigned.isEmpty {
            result.append(unassigned.count == 1
                ? "\(unassigned[0]) still needs a station."
                : "Assign \(unassigned.joined(separator: ", ")).")
        }
        for station in puzzle.stations {
            let needed = puzzle.minimum(at: station) - power(at: station)
            if needed > 0 {
                result.append("\(station.title) needs \(needed) more power.")
            }
        }
        let stations = assignments.reduce(into: [String: Station]()) { result, entry in
            result[entry.key] = slot(for: entry.key)?.station
        }
        for rule in puzzle.rules where !rule.satisfied(by: stations) {
            result.append(text(for: rule))
        }
        return result
    }

    func solution() -> [String: Slot]? { search(limit: 1).first }

    func solutionCount() -> Int { search().count }

    private func search(limit: Int = Int.max) -> (count: Int, first: [String: Slot]?) {
        let stations = puzzle.stations
        let workers = crew.sorted {
            puzzle.allowedStations(for: $0.id).count < puzzle.allowedStations(for: $1.id).count
        }
        let eligible = workers.map { worker in
            stations.indices.filter { puzzle.allowedStations(for: worker.id).contains(stations[$0]) }
        }
        let power = workers.map { worker in stations.map { worker.power(at: $0) } }
        var maxRemaining: [[[Int]]] = []
        for row in 0...workers.count {
            maxRemaining.append(stations.indices.map { station in
                let possible = (row..<workers.count)
                    .filter { eligible[$0].contains(station) }
                    .map { power[$0][station] }.sorted(by: >)
                return (0...puzzle.capacity[station]).map { possible.prefix($0).reduce(0, +) }
            })
        }
        let pairRules = puzzle.rules.filter { $0.workers.count == 2 }
        let workerIndex = Dictionary(uniqueKeysWithValues: workers.enumerated().map { ($0.element.id, $0.offset) })
        let pairs = workers.map { worker in
            pairRules.filter { $0.workers.contains(worker.id) }.map { rule in
                (workerIndex[rule.workers.first { $0 != worker.id }!]!, rule.kind == .together)
            }
        }
        var positions = Array(repeating: -1, count: workers.count)
        var open = puzzle.capacity
        var totals = Array(repeating: 0, count: stations.count)
        let thresholds = puzzle.minimums
        var found = 0
        var first: [String: Slot]?

        func visit(_ row: Int) {
            if found == limit { return }
            for station in stations.indices where totals[station] + maxRemaining[row][station][open[station]] < thresholds[station] {
                return
            }
            if row == workers.count {
                found += 1
                if first == nil {
                    var occupied = Array(repeating: 0, count: stations.count)
                    first = [:]
                    for i in workers.indices {
                        let index = positions[i]
                        occupied[index] += 1
                        first?[workers[i].id] = Slot(station: stations[index], number: occupied[index])
                    }
                }
                return
            }
            for station in eligible[row] where open[station] > 0 {
                let fits = pairs[row].allSatisfy { partner, same in
                    positions[partner] < 0 || (positions[partner] == station) == same
                }
                guard fits else { continue }
                positions[row] = station
                open[station] -= 1
                totals[station] += power[row][station]
                visit(row + 1)
                totals[station] -= power[row][station]
                open[station] += 1
                positions[row] = -1
            }
        }
        visit(0)
        return (found, first)
    }
}

struct StageRun {
    static let length = 6

    let puzzles: [Puzzle]
    private(set) var index = 0
    private(set) var hasPassed = false
    var board: StaffingBoard

    init(puzzles: [Puzzle], roster: [String: Worker]) {
        precondition(puzzles.count == Self.length && Set(puzzles.map(\.id)).count == Self.length &&
                     Set(puzzles.map { $0.stations.count }).count == 1)
        self.puzzles = puzzles
        board = StaffingBoard(puzzle: puzzles[0], roster: roster)
    }

    var isFinalPuzzle: Bool { index + 1 == puzzles.count }

    mutating func check() -> [String] {
        let issues = board.issues()
        hasPassed = issues.isEmpty
        return issues
    }

    @discardableResult
    mutating func next() -> Bool {
        guard hasPassed, !isFinalPuzzle else { return false }
        index += 1
        hasPassed = false
        board = StaffingBoard(puzzle: puzzles[index], roster: board.roster)
        return true
    }
}

enum WindowSize: String, CaseIterable, Codable {
    case compact = "1280 × 720"
    case regular = "1440 × 900"
    case wide = "1600 × 900"

    var width: Double {
        switch self {
        case .compact: 1280
        case .regular: 1440
        case .wide: 1600
        }
    }

    var height: Double { self == .compact ? 720 : 900 }
}

struct PlayerSettings: Codable, Equatable {
    var masterVolume = 0.8
    var musicVolume = 0.6
    var effectsVolume = 0.8
    var fullscreen = false
    var windowSize: WindowSize = .compact
    var largeText = false
    var reduceMotion = false
    var strongerSlots = false
    var keyboardHints = true
}

struct PlayerData: Codable, Equatable {
    var completedStageOne = false
    var settings = PlayerSettings()
}

struct PlayerStore {
    let directory: URL

    var file: URL { directory.appendingPathComponent("Player.json") }

    func load() throws -> PlayerData {
        guard FileManager.default.fileExists(atPath: file.path) else { return PlayerData() }
        return try JSONDecoder().decode(PlayerData.self, from: Data(contentsOf: file))
    }

    func save(_ data: PlayerData) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: file, options: .atomic)
    }
}
