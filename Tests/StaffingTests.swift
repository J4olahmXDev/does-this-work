import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(message) }
}

func physicalGroupings(_ limits: [Int], workers: Int) -> Int {
    var ways = [Int](repeating: 0, count: workers + 1)
    ways[0] = 1
    for limit in limits {
        var next = [Int](repeating: 0, count: workers + 1)
        for placed in 0...workers where ways[placed] > 0 {
            var combinations = 1
            for added in 0...min(workers - placed, limit) {
                if added > 0 { combinations = combinations * (workers - placed - added + 1) / added }
                next[placed + added] += ways[placed] * combinations
            }
        }
        ways = next
    }
    return ways[workers]
}

func bruteCount(_ board: StaffingBoard) -> (passes: Int, physical: Int) {
    var mapping: [String: Station] = [:]
    var counts = board.puzzle.stations.map { _ in 0 }
    var physical = 0
    var passes = 0
    let crew = board.crew
    func enumerate(_ row: Int) {
        if row == crew.count {
            physical += 1
            guard board.puzzle.rules.allSatisfy({ $0.satisfied(by: mapping) }) else { return }
            if board.puzzle.stations.allSatisfy({ station in
                let power = crew.filter { mapping[$0.id] == station }.reduce(0) { $0 + $1.power(at: station) }
                return power >= board.puzzle.minimum(at: station) &&
                    board.puzzle.maximum(at: station).map { power <= $0 } != false
            }) { passes += 1 }
            return
        }
        for (index, station) in board.puzzle.stations.enumerated() where counts[index] < board.puzzle.capacity[index] {
            mapping[crew[row].id] = station
            counts[index] += 1
            enumerate(row + 1)
            counts[index] -= 1
        }
    }
    enumerate(0)
    return (passes, physical)
}

func solve(_ original: StaffingBoard) throws -> StaffingBoard {
    guard let solution = original.solution() else { throw TestFailure("\(original.puzzle.id) has no plan") }
    var board = original
    for worker in board.crew { board.remove(worker.id) }
    for worker in board.crew {
        try expect(board.place(worker.id, in: solution[worker.id]!) == .placed, "Solution assigns an eligible worker")
    }
    try expect(board.issues().isEmpty, "Verified solution passes \(board.puzzle.id)")
    return board
}

@main
enum StaffingTests {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { throw TestFailure("Provide a bank and a fresh profile directory") }
        let bank = try PuzzleBank.load(from: URL(fileURLWithPath: args[1]))
        let roster = bank.roster
        var metrics: [Int: [Double]] = [:]
        for puzzle in bank.puzzles {
            let board = StaffingBoard(puzzle: puzzle, roster: roster)
            try expect(!puzzle.briefing.isEmpty && !puzzle.greeting.isEmpty && !puzzle.closing.isEmpty, "Briefing text")
            try expect(!board.issues().isEmpty, "Starting board needs work: \(puzzle.id)")
            let passes = board.solutionCount()
            let physical = physicalGroupings(puzzle.capacity, workers: board.crew.count)
            let rate = Double(passes) / Double(physical)
            try expect(passes >= 3, "\(puzzle.id): only \(passes) station groupings pass")
            try expect(rate <= 0.01, "\(puzzle.id): too permissive, \(passes)/\(physical)")
            if puzzle.shiftStep == 6 {
                try expect(puzzle.stations.contains { puzzle.maximum(at: $0) != nil },
                           "Every final shift has a capped station")
            }
            let completed = try solve(board)
            try expect(completed.readyStationCount == puzzle.stations.count, "All station goals turn ready after solving")
            try expect(puzzle.rules.allSatisfy { completed.status(of: $0) == .met }, "Solved board meets every displayed shift rule")
            metrics[puzzle.stations.count, default: []].append(rate)
            print("\(puzzle.id) \(puzzle.title): \(board.crew.count) workers, \(passes)/\(physical) groupings")
        }

        let signatures = try bank.puzzles.map { puzzle -> String in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try puzzle.crew.joined(separator: ",") + "\(puzzle.stations)\(puzzle.capacity)\(puzzle.minimums)"
                + String(decoding: encoder.encode(puzzle.rules), as: UTF8.self) +
                String(decoding: encoder.encode(puzzle.maximums), as: UTF8.self)
        }
        try expect(Set(signatures).count == 90, "Distinct decisions across all 90 puzzles")

        let tutorial = StaffingBoard(puzzle: bank.puzzles[0], roster: roster)
        let independent = bruteCount(tutorial)
        try expect(independent.passes == tutorial.solutionCount() &&
                   independent.physical == physicalGroupings(tutorial.puzzle.capacity, workers: tutorial.crew.count),
                   "Pruning and occupancy counts match an independent exhaustive search")
        let rush = bank.puzzles.first { $0.stations.count == 4 && $0.shiftStep == 6 }!
        let rushedBoard = StaffingBoard(puzzle: rush, roster: roster)
        try expect(bruteCount(rushedBoard).passes == rushedBoard.solutionCount(),
                   "The exhaustive search agrees with the capped solver")
        let stationIndex = rush.maximums!.firstIndex { $0 != nil }!
        let station = rush.stations[stationIndex]
        var forcedOverload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rush)) as! [String: Any]
        var minimums = rush.minimums
        minimums[stationIndex] = rush.maximum(at: station)! + 1
        forcedOverload["maximums"] = nil
        forcedOverload["minimums"] = minimums
        let overloadPuzzle = try JSONDecoder().decode(Puzzle.self, from: JSONSerialization.data(withJSONObject: forcedOverload))
        let overload = try solve(StaffingBoard(puzzle: overloadPuzzle, roster: roster))
        var capped = rushedBoard
        for worker in capped.crew { capped.remove(worker.id) }
        for worker in capped.crew { _ = capped.place(worker.id, in: overload.slot(for: worker.id)!) }
        try expect(!capped.isReady(station) && capped.issues().contains { $0.contains("over its limit") },
                   "Overloaded station is marked unready and gives specific feedback")

        var restricted = StaffingBoard(puzzle: bank.puzzles[1], roster: roster)
        let press = Slot(station: .large, number: 1)
        let assembly = Slot(station: .medium, number: 1)
        let restriction = restricted.puzzle.rules.first { $0.kind == .only && $0.workers.contains("dee") }!
        try expect(restricted.status(of: restriction) == .waiting, "Rule waits for the worker")
        let old = restricted.assignments
        try expect(restricted.place("dee", in: press) == .blocked("Dee cannot work at Press."), "Eligibility is enforced")
        try expect(restricted.assignments == old, "Rejected position leaves the plan untouched")
        _ = restricted.place("dee", in: assembly)
        try expect(restricted.status(of: restriction) == .met, "Allowed placement satisfies the displayed rule")
        _ = restricted.place("ari", in: press)
        try expect(!restricted.canPlace("ari", in: assembly), "Swap must be compatible for both workers")
        restricted.remove("dee")
        try expect(restricted.issues().contains { $0.contains("Dee") }, "Missing worker feedback")

        var paired = StaffingBoard(puzzle: bank.puzzles[4], roster: roster)
        let pair = paired.puzzle.rules.first { $0.kind == .together }!
        try expect(paired.status(of: pair) == .waiting, "An incomplete pair is waiting")
        _ = paired.place("cam", in: press)
        _ = paired.place("dee", in: assembly)
        try expect(paired.status(of: pair) == .needsChange, "A split pair needs change")
        _ = paired.place("dee", in: Slot(station: .large, number: 2))
        try expect(paired.status(of: pair) == .met, "Moving the pair updates its goal")

        var random = SystemRandomNumberGenerator()
        for count in PuzzleBank.stationCounts {
            let initial = bank.draw(using: &random, stationCount: count)
            var run = StageRun(puzzles: initial, roster: roster)
            try expect(!run.next(), "Requires passing")
            for index in initial.indices {
                try expect(run.board.puzzle.id == initial[index].id && run.board.puzzle.stations.count == count,
                           "Locks the run to its original station count")
                run.board = try solve(run.board)
                let result = run.check()
                try expect(result.isEmpty, "Run puzzle passes")
                let advanced = run.next()
                try expect(advanced == (index + 1 < initial.count), "Stops after six")
            }
            let rates = metrics[count]!
            print("\(count) stations: \(rates.count) boards; pass-rate range \(rates.min()!)–\(rates.max()!)")
        }
        var seen: Set<Int> = []
        for _ in 0..<120 {
            let draw = bank.draw(using: &random)
            try expect(draw.count == 6 && Set(draw.map(\.id)).count == 6, "No repeated puzzle in a run")
            try expect(Set(draw.map { $0.stations.count }).count == 1, "Never mixes the three layouts")
            try expect(draw.compactMap(\.shiftStep) == Array(1...6), "Draws one puzzle per successive shift step")
            seen.insert(draw[0].stations.count)
        }
        try expect(seen == Set(PuzzleBank.stationCounts), "Every layout is drawn")
        let store = PlayerStore(directory: URL(fileURLWithPath: args[2]))
        var data = try store.load()
        try expect(!data.completedStageOne, "Fresh save")
        data.completedStageOne = true
        data.settings.musicVolume = 0.4
        try store.save(data)
        let readBack = try store.load()
        try expect(readBack == data, "Settings and progress persist")
        print("PASS: 90 solvable boards, player rules, random runs, alternate plans and persistence.")
    }
}
