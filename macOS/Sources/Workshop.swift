import Foundation

enum WorkStage: Int, CaseIterable, Codable, Identifiable {
    case staffing = 1, bottleneck, plant, delivery
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .staffing: "Staff the Stations"
        case .bottleneck: "Find the Bottleneck"
        case .plant: "Plan the Plant"
        case .delivery: "Plan the Delivery Route"
        }
    }
    var summary: String {
        switch self {
        case .staffing: "Assign the crew to meet machine goals."
        case .bottleneck: "Move workers to raise finished output."
        case .plant: "Place machines to shorten cart routes."
        case .delivery: "Order the stops and return to the depot."
        }
    }
}

struct ShiftCard: Codable {
    let id, title, layout, greeting, closing: String
    let mode, step: Int
    var pace: String { step <= 2 ? "Warm-up" : step <= 4 ? "Production" : "Rush" }
}

struct FlowPuzzle: Codable {
    let card: ShiftCard
    let stations: [Station]
    let crew: [String]
    let ratings: [[Int]]
    let allowed: [[Int]]
    let capacities: [Int]
    let initial: [Int]
    let goal: Int

    func powers(_ positions: [Int]) -> [Int] {
        var totals = Array(repeating: 0, count: stations.count)
        for (worker, station) in positions.enumerated() { totals[station] += ratings[worker][station] }
        return totals
    }
    func issues(_ positions: [Int]) -> [String] {
        var result: [String] = []
        for i in crew.indices where !allowed[i].contains(positions[i]) {
            result.append("A worker is at an unavailable station.")
            break
        }
        if stations.indices.contains(where: { s in positions.filter { $0 == s }.count > capacities[s] }) {
            result.append("A station has too many workers.")
        }
        if powers(positions).min() ?? 0 < goal { result.append("Finished output is below target.") }
        return result
    }

    func solutions(upTo limit: Int) -> [[Int]] {
        var result: [[Int]] = []
        var remaining = capacities
        var current = Array(repeating: 0, count: crew.count)
        func visit(_ index: Int) {
            guard result.count < limit else { return }
            if index == crew.count {
                if powers(current).allSatisfy({ $0 >= goal }) { result.append(current) }
                return
            }
            for s in allowed[index] where remaining[s] > 0 {
                remaining[s] -= 1
                current[index] = s
                visit(index + 1)
                remaining[s] += 1
            }
        }
        visit(0)
        return result
    }
}

struct CartTransfer: Codable, Identifiable {
    let from, to, trips: Int
    var id: String { "\(from)-\(to)" }
}

struct PlantPuzzle: Codable {
    let card: ShiftCard
    let machines: [Station]
    let bays: [Int]
    let initial: [Int]
    let allowed: [[Int]]
    let transfers: [CartTransfer]
    let goal: Int
    let southMachine, nearShipping, shippingLimit: Int
    let fixed: [Int]
    let receiving, shipping: Int

    func name(_ machine: Int) -> String {
        switch machine {
        case -1: "Receive"
        case -2: "Ship"
        case 0: "Cut"
        case 1: "Assemble"
        case 2: "Inspect"
        case 3: "Pack"
        default: machines[machine].title
        }
    }
    func column(_ machine: Int, in plan: [Int]) -> Int {
        switch machine {
        case -1: receiving
        case -2: shipping
        default: plan[machine] % 6 + 1
        }
    }
    func distance(_ from: Int, _ to: Int, in plan: [Int]) -> Int {
        abs(column(from, in: plan) - column(to, in: plan)) + (from < 0 ? 0 : 1) + (to < 0 ? 0 : 1)
    }
    func cost(_ plan: [Int]) -> Int {
        transfers.reduce(0) { $0 + $1.trips * distance($1.from, $1.to, in: plan) }
    }
    func constraints(_ plan: [Int], language: GameLanguage = .english) -> [(text: String, met: Bool)] {
        var rules: [(String, Bool)] = []
        if southMachine >= 0 { rules.append((language.text("%@ uses a south bay.", name(southMachine)), plan[southMachine] >= 6)) }
        if nearShipping >= 0 {
            rules.append((language.text("%@ within %@ tiles of Ship.", name(nearShipping), String(shippingLimit)),
                          distance(nearShipping, -2, in: plan) <= shippingLimit))
        }
        for m in fixed { rules.append((language.text("%@ stays at its fixed bay.", name(m)), plan[m] == initial[m])) }
        return rules
    }
    func issues(_ plan: [Int], language: GameLanguage = .english) -> [String] {
        var result = constraints(plan, language: language).filter { !$0.met }.map(\.text)
        if Set(plan).count != plan.count || !Set(plan).isSubset(of: Set(bays)) {
            result.append(language.text("Place each machine in a different open bay."))
        }
        if cost(plan) > goal { result.append(language.text("Cart travel is above target.")) }
        return result
    }
    func solutions(upTo limit: Int) -> [[Int]] {
        var result: [[Int]] = []
        var used = Set<Int>()
        var current = initial
        func visit(_ index: Int) {
            guard result.count < limit else { return }
            if index == current.count {
                if cost(current) <= goal { result.append(current) }
                return
            }
            for bay in allowed[index] where used.insert(bay).inserted {
                current[index] = bay
                visit(index + 1)
                used.remove(bay)
            }
        }
        visit(0)
        return result
    }
}

struct Road: Codable {
    let a, b, km, minutes: Int
    let slowFrom, slowMinutes: Int?
}

struct DeliveryStop: Codable {
    let name: String
    let open, close: Int
}

struct DeliveryPuzzle: Codable {
    let card: ShiftCard
    let stops: [DeliveryStop]
    let roads: [Road]
    let departure, limit, service: Int

    struct Leg {
        let amount: Int
        let path: [Int]
    }
    struct Forecast {
        var distance = 0
        var time: Int
        var arrival: [Int: Int] = [:]
        var waiting: [Int: Int] = [:]
        var late: [Int] = []
        var path: [Int] = []
        var homePath: [Int] = []
    }
    var timeBased: Bool { card.mode != 0 }
    func leg(from: Int, to: Int, at departure: Int) -> Leg {
        var best = Array(repeating: Int.max, count: stops.count)
        var parent = Array(repeating: -1, count: stops.count)
        var pending = Set(stops.indices)
        best[from] = 0
        while let current = pending.min(by: { (best[$0], $0) < (best[$1], $1) }), best[current] < Int.max {
            if current == to { break }
            pending.remove(current)
            for road in roads where road.a == current || road.b == current {
                let other = road.a == current ? road.b : road.a
                let slow = road.slowFrom.map { departure + best[current] >= $0 } ?? false
                let length = timeBased ? (slow ? road.slowMinutes ?? road.minutes : road.minutes) : road.km
                if best[current] + length < best[other] {
                    best[other] = best[current] + length
                    parent[other] = current
                }
            }
        }
        var path = [to]
        while let node = path.last, node != from, parent[node] >= 0 { path.append(parent[node]) }
        return Leg(amount: best[to], path: path.reversed())
    }
    func forecast(_ order: [Int]) -> Forecast {
        var result = Forecast(time: departure)
        var from = 0
        for stop in order {
            let leg = leg(from: from, to: stop, at: result.time)
            result.path += leg.path.dropLast()
            if timeBased {
                let arrival = result.time + leg.amount
                let begin = card.mode == 1 ? max(arrival, stops[stop].open) : arrival
                result.arrival[stop] = begin
                if begin > arrival { result.waiting[stop] = begin - arrival }
                result.time = begin + service
                if card.mode == 1 && result.time > stops[stop].close { result.late.append(stop) }
            } else {
                result.distance += leg.amount
            }
            from = stop
        }
        result.path.append(from)
        let home = leg(from: from, to: 0, at: result.time)
        result.homePath = home.path
        if timeBased { result.time += home.amount }
        else { result.distance += home.amount }
        return result
    }
    func issues(_ order: [Int]) -> [String] {
        let result = forecast(order)
        var issues: [String] = []
        if order.count != stops.count - 1 || Set(order) != Set(1..<stops.count) { issues.append("Visit every shop.") }
        if !result.late.isEmpty { issues.append("A delivery finishes after its window closes.") }
        if (timeBased ? result.time : result.distance) > limit { issues.append("The return to the depot is over the limit.") }
        return issues
    }
    func solutions(upTo limit: Int) -> [[Int]] {
        var result: [[Int]] = []
        func visit(_ order: [Int], _ remaining: [Int]) {
            guard result.count < limit else { return }
            if remaining.isEmpty {
                if issues(order).isEmpty { result.append(order) }
                return
            }
            for stop in remaining { visit(order + [stop], remaining.filter { $0 != stop }) }
        }
        visit([], Array(1..<stops.count))
        return result
    }
}

struct WorkshopBank: Codable {
    let flow: [FlowPuzzle]
    let plant: [PlantPuzzle]
    let delivery: [DeliveryPuzzle]

    func draw(_ stage: WorkStage, mode: Int, ordered: Bool = false) -> [WorkshopBoard] {
        let all: [WorkshopBoard]
        switch stage {
        case .staffing: return []
        case .bottleneck: all = flow.map { .flow($0, $0.initial) }
        case .plant: all = plant.map { .plant($0, $0.initial) }
        case .delivery: all = delivery.map { .delivery($0, []) }
        }
        return (1...6).compactMap { step in
            let group = all.filter { $0.card.mode == mode && $0.card.step == step }
            return ordered ? group.first : group.randomElement()
        }
    }

    func validate() throws {
        let groups: [[ShiftCard]] = [flow.map(\.card), plant.map(\.card), delivery.map(\.card)]
        let content = groups.allSatisfy { cards in
            cards.count == 90 && Set(cards.map(\.id)).count == 90 &&
                (0..<3).allSatisfy { mode in
                    (1...6).allSatisfy { step in cards.filter { $0.mode == mode && $0.step == step }.count == 5 }
                }
        }
        if !content { throw BankError.invalid("Expected 90 workshop puzzles per stage.") }
        for p in flow {
            let positions = p.stations.indices
            guard p.stations.count == p.card.mode + 4, Set(p.stations).count == p.stations.count,
                  Set(p.crew).count == p.crew.count, p.ratings.count == p.crew.count,
                  p.allowed.count == p.crew.count, p.initial.count == p.crew.count,
                  p.capacities.count == p.stations.count, p.capacities.allSatisfy({ (1...3).contains($0) }),
                  p.ratings.allSatisfy({ $0.count == p.stations.count && $0.allSatisfy { $0 > 0 } }),
                  p.allowed.allSatisfy({ !$0.isEmpty && $0.allSatisfy(positions.contains) }),
                  p.initial.allSatisfy(positions.contains), p.goal > 0 else {
                throw BankError.invalid(p.card.id + ": invalid line positions or skills.")
            }
        }
        for p in plant {
            let validBays = Set(p.bays)
            let machineIndices = p.machines.indices
            guard p.machines.count == 4, p.initial.count == p.machines.count,
                  p.allowed.count == p.machines.count, Set(p.initial).count == p.initial.count,
                  validBays.isSubset(of: Set(0..<12)), Set(p.initial).isSubset(of: validBays),
                  p.allowed.allSatisfy({ !$0.isEmpty && Set($0).isSubset(of: validBays) }),
                  p.fixed.allSatisfy(machineIndices.contains),
                  p.southMachine == -1 || machineIndices.contains(p.southMachine),
                  p.nearShipping == -1 || machineIndices.contains(p.nearShipping),
                  (0...7).contains(p.receiving), (0...7).contains(p.shipping), p.receiving != p.shipping,
                  p.goal > 0, !p.transfers.isEmpty, p.transfers.allSatisfy({
                      $0.trips > 0 && (-2..<p.machines.count).contains($0.from) &&
                      (-2..<p.machines.count).contains($0.to) && $0.from != $0.to
                  }) else { throw BankError.invalid(p.card.id + ": invalid layout or transfer.") }
        }
        for p in delivery {
            guard (5...6).contains(p.stops.count), p.service >= 0, p.limit > 0,
                  p.stops.allSatisfy({ $0.open <= $0.close }),
                  p.roads.allSatisfy({ r in
                      p.stops.indices.contains(r.a) && p.stops.indices.contains(r.b) && r.a != r.b &&
                      r.km > 0 && r.minutes > 0 &&
                      (r.slowFrom == nil) == (r.slowMinutes == nil) && (r.slowMinutes ?? r.minutes) >= r.minutes
                  }) else { throw BankError.invalid(p.card.id + ": invalid windows or roads.") }
            for stop in p.stops.indices where p.leg(from: 0, to: stop, at: p.departure).amount == Int.max {
                throw BankError.invalid(p.card.id + ": all shops must be reachable.")
            }
        }
    }
}

enum WorkshopBoard {
    case flow(FlowPuzzle, [Int])
    case plant(PlantPuzzle, [Int])
    case delivery(DeliveryPuzzle, [Int])

    var card: ShiftCard {
        switch self {
        case .flow(let p, _): p.card
        case .plant(let p, _): p.card
        case .delivery(let p, _): p.card
        }
    }
    var issues: [String] { issues(in: .english) }

    func issues(in language: GameLanguage) -> [String] {
        switch self {
        case .flow(let p, let plan): p.issues(plan).map { language.text($0) }
        case .plant(let p, let plan): p.issues(plan, language: language)
        case .delivery(let p, let plan): p.issues(plan).map { language.text($0) }
        }
    }

    func spotlight(in language: GameLanguage) -> String {
        switch self {
        case .flow(let p, _): return language.text("We need %@ finished items a minute. Keep an eye on the slowest station.", String(p.goal))
        case .plant(let p, _):
            if p.southMachine >= 0 {
                return language.text("Keep %@ on the south side. Try shortening the trips that happen most often.", p.name(p.southMachine))
            }
            return language.text("Keep the aisle open. We have a budget of %@ tile-trips per batch.", String(p.goal))
        case .delivery(let p, _):
            return switch p.card.mode {
            case 0: language.text("The full trip, including the drive back, has to fit within %@ kilometres.", String(p.limit))
            case 1: language.text("Check each shop's window. We can wait if we're early, but unloading has to finish before closing.")
            default: language.text("Some roads slow down later. The time we enter a road is the one that counts.")
            }
        }
    }
}

struct WorkshopRun {
    let puzzles: [WorkshopBoard]
    private(set) var index = 0
    var board: WorkshopBoard
    init(_ puzzles: [WorkshopBoard]) {
        precondition(puzzles.count == 6)
        self.puzzles = puzzles
        board = puzzles[0]
    }
    var isFinal: Bool { index == puzzles.count - 1 }
    mutating func next() {
        guard !isFinal else { return }
        index += 1
        board = puzzles[index]
    }
}

func clockText(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
}
