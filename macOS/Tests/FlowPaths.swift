import Foundation

struct LegalFlowMove {
    let worker, station: Int
    let swap: Int?
}

func pathToFlowPlan(_ puzzle: FlowPuzzle, from first: [Int], to target: [Int]) -> [LegalFlowMove]? {
    var pending = [first]
    var parents: [[Int]: ([Int], LegalFlowMove)] = [:]
    var seen: Set<[Int]> = [first]
    func difference(_ plan: [Int]) -> Int { zip(plan, target).filter { $0 != $1 }.count }
    while let plan = pending.popLast() {
        if plan == target {
            var node = plan
            var path: [LegalFlowMove] = []
            while let (prior, move) = parents[node] {
                path.append(move)
                node = prior
            }
            return path.reversed()
        }
        guard seen.count < 150_000 else { return nil }
        var next: [[Int]] = []
        for i in plan.indices where plan[i] != target[i] {
            for station in puzzle.allowed[i] where station != plan[i] {
                let occupants = plan.indices.filter { plan[$0] == station }
                let swaps: [Int?] = occupants.filter { puzzle.allowed[$0].contains(plan[i]) }.map(Optional.some)
                for other in occupants.count < puzzle.capacities[station] ? swaps + [nil] : swaps {
                    var changed = plan
                    changed[i] = station
                    if let other { changed[other] = plan[i] }
                    if seen.insert(changed).inserted {
                        parents[changed] = (plan, LegalFlowMove(worker: i, station: station, swap: other))
                        next.append(changed)
                    }
                }
            }
        }
        pending += next.sorted { difference($0) > difference($1) }
    }
    return nil
}

