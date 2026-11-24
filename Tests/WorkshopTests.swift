import Foundation

enum WorkshopTestError: Error { case failed(String) }

func verify(_ condition: @autoclosure () -> Bool, _ detail: String) throws {
    if !condition() { throw WorkshopTestError.failed(detail) }
}

@main
enum WorkshopTests {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let bank = try JSONDecoder().decode(WorkshopBank.self, from: Data(contentsOf: url))
        try bank.validate()
        for p in bank.flow {
            let solutions = p.solutions(upTo: 140)
            try verify(solutions.count >= 2 && solutions.count <= [140,100,75,48,28,18][p.card.step-1], p.card.id)
            try verify(!p.issues(p.initial).isEmpty, "Starting plan fails " + p.card.id)
            try verify(solutions.prefix(2).allSatisfy {
                p.issues($0).isEmpty && pathToFlowPlan(p, from: p.initial, to: $0) != nil
            }, "Two reachable plans " + p.card.id)
        }
        for p in bank.plant {
            let solutions = p.solutions(upTo: 2)
            try verify(solutions.count == 2 && solutions.allSatisfy { p.issues($0).isEmpty }, p.card.id)
            try verify(!p.issues(p.initial).isEmpty, "Starting layout fails " + p.card.id)
        }
        for p in bank.delivery {
            let solutions = p.solutions(upTo: 70)
            try verify(solutions.count >= 2 && solutions.count <= (p.stops.count == 5 ? 12 : 60), p.card.id)
            try verify(!p.issues([]).isEmpty, "Empty tour fails " + p.card.id)
            for solution in solutions.prefix(2) {
                let result = p.forecast(solution)
                try verify(result.homePath.last == 0 && p.issues(solution).isEmpty, "Return to depot " + p.card.id)
            }
        }
        let layout = bank.plant.first { $0.card.id == "plant-1-3-1" }!
        try verify(layout.cost(layout.initial) == 40 && layout.goal == 31, "Approved plant example")
        try verify(layout.issues([0,2,9,11]).isEmpty && layout.issues([1,2,10,11]).isEmpty, "Two different plant plans")
        try verify(layout.cost([0,6,1,5]) == 28 && !layout.issues([0,6,1,5]).isEmpty, "A cheap layout still fails when Inspect is in the wrong zone")
        let sample = bank.delivery.first { $0.card.id == "delivery-1-1-1" }!
        try verify(sample.forecast([1,2,3,4]).distance == 12 && sample.issues([1,2,3,4]).isEmpty,
                   "Exact distance limit includes the return leg")
        let changing = bank.delivery.first { $0.card.mode == 2 }!
        let road = changing.roads.first { $0.slowFrom != nil }!
        let edgeOnly = DeliveryPuzzle(card: changing.card, stops: Array(changing.stops.prefix(2)),
                                      roads: [Road(a: 0, b: 1, km: road.km, minutes: road.minutes,
                                                   slowFrom: road.slowFrom, slowMinutes: road.slowMinutes)],
                                      departure: changing.departure, limit: changing.limit, service: 0)
        try verify(edgeOnly.leg(from: 0, to: 1, at: road.slowFrom! - 1).amount == road.minutes &&
                   edgeOnly.leg(from: 0, to: 1, at: road.slowFrom!).amount == road.slowMinutes!,
                   "Congestion changes at the exact entry time")
        for stage in WorkStage.allCases.dropFirst() {
            for mode in 0..<3 {
                for _ in 0..<4 {
                    let run = bank.draw(stage, mode: mode)
                    try verify(run.map(\.card.step) == Array(1...6), "Difficulty progression")
                    try verify(run.allSatisfy { $0.card.mode == mode }, "Single mode per run")
                }
            }
        }
        print("PASS: 270 workshop puzzles, reachable flow plans, cart constraints, timed deliveries and progression.")
    }
}
