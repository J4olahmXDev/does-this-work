import SwiftUI

struct ConfirmStrip: View {
    let title: String
    let detail: String
    let ready: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).gameFont(15, .bold)
                Text(detail).gameFont(12, .semibold).foregroundStyle(ready ? Palette.deepSage : Palette.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 1)
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ready ? Palette.deepSage : Palette.quiet)
                    .frame(width: 56, height: 56)
                    .background(ready ? Palette.sage : Color(white: 0.85), in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(ready ? Palette.deepSage : Palette.line) }
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!ready)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("check-plan")
            .accessibilityLabel(title)
            .accessibilityHint(detail)
            .help(detail)
        }
        .padding(.leading, 12).padding([.trailing, .top, .bottom], 5)
        .background(Palette.beige.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}

private let workshopSpace = "workshop-board"

private enum WorkshopTarget: Hashable {
    case flow(station: Int, slot: Int, occupant: Int?)
    case plant(Int)
    case route(Int)
}

private enum WorkshopPiece {
    case worker(Int), machine(Int), stop(Int)
}

private struct WorkshopTargets: PreferenceKey {
    static let defaultValue: [WorkshopTarget: CGRect] = [:]
    static func reduce(value: inout [WorkshopTarget: CGRect], nextValue: () -> [WorkshopTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private extension View {
    func workshopTarget(_ target: WorkshopTarget) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: WorkshopTargets.self, value: [target: geometry.frame(in: .named(workshopSpace))])
        })
    }
}

struct WorkshopScreen: View {
    @EnvironmentObject private var game: GameSession
    let run: WorkshopRun
    @StateObject private var editing = WorkshopSelection()

    var body: some View {
        VStack(spacing: 12) {
            header
            GeometryReader { size in
                HStack(alignment: .top, spacing: 14) {
                    Group {
                        switch run.board {
                        case .flow(let puzzle, let plan): flowFloor(puzzle, plan)
                        case .plant(let puzzle, let plan): plantFloor(puzzle, plan)
                        case .delivery(let puzzle, let order): routeFloor(puzzle, order)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.beige.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line) }
                    sidebar.frame(width: max(334, min(450, size.size.width * 0.33)))
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .overlay {
            if let point = editing.dragPoint, let piece = editing.dragPiece {
                dragPreview(piece).position(point).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .coordinateSpace(name: workshopSpace)
        .onPreferenceChange(WorkshopTargets.self) { editing.targets = $0 }
    }

    private func drag(_ piece: WorkshopPiece) -> some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .named(workshopSpace))
            .onChanged { value in
                guard game.gameActive else { return }
                if !editing.dragging {
                    editing.dragging = true
                    editing.selected = nil
                    editing.dragPiece = piece
                    game.audio.play(.pickup)
                }
                editing.dragPoint = value.location
            }
            .onEnded { gesture in
                guard editing.dragging else { return }
                editing.suppressClick = true
                editing.dragging = false
                editing.dragPoint = nil
                editing.dragPiece = nil
                DispatchQueue.main.async { editing.suppressClick = false }
                guard let target = editing.targets.first(where: { $0.value.contains(gesture.location) })?.key else { return }
                switch (piece, target) {
                case (.worker(let worker), .flow(let station, _, let other)): game.moveFlow(worker: worker, to: station, swapping: other)
                case (.machine(let machine), .plant(let bay)): game.moveMachine(machine, to: bay)
                case (.stop(let stop), .route(let index)): game.reorderStop(stop, to: index)
                default: break
                }
            }
    }

    @ViewBuilder private func dragPreview(_ piece: WorkshopPiece) -> some View {
        switch (piece, run.board) {
        case (.worker(let i), .flow(let p, _)):
            WorkerArt(style: game.worker(p.crew[i])?.style ?? "cap").frame(width: 62, height: 62)
        case (.machine(let i), .plant(let p, _)):
            MachineArt(station: p.machines[i]).frame(width: 86, height: 62)
        case (.stop(let i), .delivery(let p, _)):
            Text(p.stops[i].name).gameFont(14, .bold)
                .padding(10).background(Palette.sage, in: RoundedRectangle(cornerRadius: 7))
        default: EmptyView()
        }
    }

    private var header: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.stage.title).gameFont(29, .bold).accessibilityAddTraits(.isHeader)
                Text(run.board.card.title + " · " + run.board.card.layout)
                    .gameFont(14, .semibold).foregroundStyle(Palette.quiet)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Puzzle \(run.index + 1) of 6").gameFont(14, .bold)
                Text(run.board.card.pace).gameFont(12, .semibold).foregroundStyle(Palette.deepSage)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Palette.sage.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
            }
            GameButton(title: "Pause", symbol: "pause.fill") { game.pause() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.line.opacity(0.78)) }
    }

    private var sidebar: some View {
        let ready = run.board.issues.isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .vertical) {
                sidebarContent(compact: false).fixedSize(horizontal: false, vertical: true)
                sidebarContent(compact: true).fixedSize(horizontal: false, vertical: true)
                ScrollView { sidebarContent(compact: true) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if let feedback = game.feedback {
                Text(feedback.message).gameFont(12, .semibold)
                    .foregroundStyle(feedback.problem ? Palette.warn : Palette.deepSage)
            }
            ConfirmStrip(title: confirmTitle, detail: ready ? "All conditions met" :
                            run.board.issues.first ?? "Meet all conditions", ready: ready) { game.checkPlan() }
        }
        .padding(12)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line) }
    }

    private func sidebarContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch run.board {
            case .flow(let puzzle, let plan): flowDetails(puzzle, plan)
            case .plant(let puzzle, let plan): plantDetails(puzzle, plan)
            case .delivery(let puzzle, let order): routeDetails(puzzle, order, compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmTitle: String {
        switch game.stage {
        case .plant: "Confirm layout"
        case .delivery: "Confirm route"
        default: "Confirm plan"
        }
    }

    private func metric(_ title: String, value: String, unit: String, goal: String, ready: Bool,
                        compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            Text(title).gameFont(compact ? 17 : 20, .bold).accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).gameFont(compact ? 28 : 35, .bold).monospacedDigit()
                Text(unit).gameFont(13, .semibold)
            }.foregroundStyle(ready ? Palette.deepSage : Palette.warn)
            Text(goal).gameFont(13, .bold).padding(.horizontal, 7).padding(.vertical, 4)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 7 : 10)
        .background((ready ? Palette.sage : Palette.ochre).opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private func flowFloor(_ puzzle: FlowPuzzle, _ plan: [Int]) -> some View {
        let powers = puzzle.powers(plan)
        let slow = powers.min() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Select or drag a worker to an open slot. Drop on a worker to swap.")
                .gameFont(14, .semibold).foregroundStyle(Palette.quiet)
            ViewThatFits(in: .vertical) {
                flowStations(puzzle, plan, powers: powers, slow: slow, compact: false)
                flowStations(puzzle, plan, powers: powers, slow: slow, compact: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ForEach(puzzle.stations.indices, id: \.self) { i in
                    HStack(spacing: 3) {
                        ForEach(0..<(powers[i] == slow && slow < puzzle.goal ? 3 : 1), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(powers[i] == slow && slow < puzzle.goal ? Palette.ochre : Palette.beige)
                                .frame(width: 15, height: 17)
                        }
                    }.frame(maxWidth: .infinity)
                }
            }.padding(8).background(Palette.blue.opacity(0.40), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(slow < puzzle.goal ? "Work is waiting at the highlighted stations." : "Line is ready to meet the output goal.")
                .gameFont(13, .semibold).foregroundStyle(slow < puzzle.goal ? Palette.warn : Palette.deepSage)
        }.padding(13)
    }

    private func flowStations(_ puzzle: FlowPuzzle, _ plan: [Int], powers: [Int], slow: Int, compact: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: compact ? 3 : puzzle.stations.count)
        return LazyVGrid(columns: columns, spacing: 7) {
            ForEach(puzzle.stations.indices, id: \.self) { s in
                let workers = plan.indices.filter { plan[$0] == s }
                VStack(alignment: .leading, spacing: 5) {
                    Text(puzzle.stations[s].title).gameFont(14, .bold).lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(powers[s])/min").gameFont(16, .bold)
                        .foregroundStyle(powers[s] == slow && slow < puzzle.goal ? Palette.warn : Palette.deepSage)
                    MachineArt(station: puzzle.stations[s]).frame(height: compact ? 35 : 76)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 3)], spacing: 4) {
                        ForEach(0..<puzzle.capacities[s], id: \.self) { slot in
                            flowSlot(puzzle, station: s, index: slot, worker: workers.indices.contains(slot) ? workers[slot] : nil)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(powers[s] == slow && slow < puzzle.goal ? Palette.ochre.opacity(0.24) : Palette.paper,
                            in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.line) }
            }
        }
    }

    @ViewBuilder private func flowSlot(_ puzzle: FlowPuzzle, station: Int, index: Int, worker: Int?) -> some View {
        let model = worker.flatMap { game.worker(puzzle.crew[$0]) }
        let code = puzzle.stations[station].initial + String(index + 1)
        let active = worker != nil && editing.selected == worker
        let target = editing.selected.map { puzzle.allowed[$0].contains(station) } ?? false
        let button = Button {
            guard !editing.suppressClick, !editing.dragging else { return }
            if let selection = editing.selected, selection != worker {
                game.moveFlow(worker: selection, to: station, swapping: worker)
                editing.selected = nil
            } else if let worker {
                editing.selected = active ? nil : worker
                if !active { game.audio.play(.pickup) }
            }
        } label: {
            VStack(spacing: 0) {
                if let model {
                    WorkerArt(style: model.style).frame(width: 38, height: 38)
                } else {
                    Color.clear.frame(height: 38)
                }
                Text(code).gameFont(10, .bold)
            }
            .frame(maxWidth: .infinity, minHeight: 53)
            .background(active || target ? Palette.sage.opacity(active ? 0.62 : 0.32) : Palette.beige.opacity(0.38),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6).strokeBorder(active || target ? Palette.deepSage : Palette.line,
                                                               style: StrokeStyle(lineWidth: 1, dash: worker == nil ? [4,3] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.map { "\($0.name) · +\(puzzle.ratings[worker!][station]) items/min here" } ?? "Open slot")
        .accessibilityLabel(code + ", " + (model?.name ?? "open"))
        .workshopTarget(.flow(station: station, slot: index, occupant: worker))
        if let worker {
            button.simultaneousGesture(drag(.worker(worker)))
        } else {
            button
        }
    }

    private func flowDetails(_ puzzle: FlowPuzzle, _ plan: [Int]) -> some View {
        let power = puzzle.powers(plan).min() ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            metric("Line forecast", value: String(power), unit: "items/min",
                   goal: "Goal \(puzzle.goal)+ items/min", ready: power >= puzzle.goal)
            Text("Crew output by station").gameFont(16, .bold)
            Text("A dash means that worker cannot use the station.").gameFont(11).foregroundStyle(Palette.quiet)
            HStack(spacing: 3) {
                Text("Worker").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(puzzle.stations, id: \.self) { Text($0.initial).frame(width: 24) }
                Text("At").frame(width: 30)
            }.gameFont(11, .bold)
            ForEach(puzzle.crew.indices, id: \.self) { i in
                let worker = game.worker(puzzle.crew[i])
                Button {
                    editing.selected = editing.selected == i ? nil : i
                    if editing.selected != nil { game.audio.play(.pickup) }
                } label: {
                    HStack(spacing: 3) {
                        HStack(spacing: 2) {
                            WorkerArt(style: worker?.style ?? "cap").frame(width: 23, height: 23)
                            Text(worker?.name ?? puzzle.crew[i]).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(puzzle.stations.indices, id: \.self) { s in
                            Text(puzzle.allowed[i].contains(s) ? String(puzzle.ratings[i][s]) : "—").frame(width: 24)
                        }
                        Text(puzzle.stations[plan[i]].initial).frame(width: 30)
                    }.gameFont(12).background(editing.selected == i ? Palette.sage.opacity(0.35) : .clear)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }

    private func plantFloor(_ puzzle: PlantPuzzle, _ plan: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Place machines in open bays and keep the cart aisle clear.")
                .gameFont(14, .semibold).foregroundStyle(Palette.quiet)
            GeometryReader { geometry in
                let cell = geometry.size.width / 8
                let height = geometry.size.height
                let north = height * 0.24
                let aisle = height * 0.50
                let south = height * 0.76
                let bayHeight = min(101, height * 0.21)
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Palette.blue.opacity(0.40))
                        .frame(height: 48).position(x: geometry.size.width / 2, y: aisle)
                    if puzzle.transfers.indices.contains(editing.transfer) {
                        let edge = puzzle.transfers[editing.transfer]
                        let from = puzzle.column(edge.from, in: plan)
                        let to = puzzle.column(edge.to, in: plan)
                        let x1 = cell * (Double(from) + 0.5)
                        let x2 = cell * (Double(to) + 0.5)
                        let y1 = edge.from < 0 ? aisle : plan[edge.from] < 6 ? north + bayHeight / 2 : south - bayHeight / 2
                        let y2 = edge.to < 0 ? aisle : plan[edge.to] < 6 ? north + bayHeight / 2 : south - bayHeight / 2
                        Path { path in
                            path.move(to: pt(x1, y1))
                            path.addLines([pt(x1, aisle), pt(x2, aisle), pt(x2, y2)])
                        }.stroke(Palette.warn.opacity(0.66), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .allowsHitTesting(false)
                    }
                    ForEach(0..<12) { bay in
                        plantBay(puzzle, plan, bay: bay)
                            .frame(width: max(35, cell - 5), height: bayHeight)
                            .position(x: (Double(bay % 6) + 1.5) * cell, y: bay < 6 ? north : south)
                    }
                    dock("Receive").frame(width: max(51, cell - 4)).position(x: (Double(puzzle.receiving) + 0.5) * cell, y: aisle)
                    dock("Ship").frame(width: max(51, cell - 4)).position(x: (Double(puzzle.shipping) + 0.5) * cell, y: aisle)
                    Text("North bays").gameFont(11, .bold).foregroundStyle(Palette.quiet)
                        .position(x: cell * 0.50, y: north)
                    Text("South bays").gameFont(11, .bold).foregroundStyle(Palette.quiet)
                        .position(x: cell * 0.50, y: south)
                }
            }
            Text("Select a transfer to highlight the cart route.").gameFont(12).foregroundStyle(Palette.quiet)
        }.padding(12)
    }

    private func dock(_ name: String) -> some View {
        Text(name).gameFont(12, .bold).lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 43)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.line) }
    }

    @ViewBuilder private func plantBay(_ puzzle: PlantPuzzle, _ plan: [Int], bay: Int) -> some View {
        let occupant = plan.firstIndex(of: bay)
        let usable = puzzle.bays.contains(bay)
        let fixed = occupant.map(puzzle.fixed.contains) ?? false
        let code = (bay < 6 ? "N" : "S") + String(bay % 6 + 1)
        let button = Button {
            guard !editing.suppressClick, !editing.dragging else { return }
            if let moving = editing.selected, moving != occupant {
                game.moveMachine(moving, to: bay)
                editing.selected = nil
            } else if let occupant, !fixed {
                editing.selected = editing.selected == occupant ? nil : occupant
                if editing.selected != nil { game.audio.play(.pickup) }
            }
        } label: {
            VStack(spacing: 3) {
                if let occupant {
                    MachineArt(station: puzzle.machines[occupant])
                        .frame(maxHeight: 52)
                    Text(puzzle.name(occupant)).gameFont(11, .bold).lineLimit(1).minimumScaleFactor(0.75)
                }
                Text(fixed ? "Fixed" : usable ? code : "Closed").gameFont(10, .semibold)
                    .foregroundStyle(Palette.quiet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(occupant != nil && occupant == editing.selected ? Palette.sage :
                            occupant != nil ? Palette.paper : usable ? Palette.cream : Palette.beige.opacity(0.48),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line,
                    style: StrokeStyle(lineWidth: 1.25, dash: occupant == nil && usable ? [5,4] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .accessibilityLabel(code + ", " + (occupant.map(puzzle.name) ?? (usable ? "open" : "closed")))
        .workshopTarget(.plant(bay))
        if let occupant, !fixed { button.simultaneousGesture(drag(.machine(occupant))) }
        else { button }
    }

    private func plantDetails(_ puzzle: PlantPuzzle, _ plan: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metric("Cart travel", value: String(puzzle.cost(plan)), unit: "tile-trips per batch",
                   goal: "Goal \(puzzle.goal) or less", ready: puzzle.cost(plan) <= puzzle.goal)
            HStack {
                Text("Transfer")
                Spacer()
                Text("Trips × tiles").frame(width: 80)
                Text("Cost").frame(width: 35)
            }.gameFont(12, .bold)
            ForEach(Array(puzzle.transfers.enumerated()), id: \.offset) { i, transfer in
                let distance = puzzle.distance(transfer.from, transfer.to, in: plan)
                Button {
                    editing.transfer = i
                    game.audio.play(.click)
                } label: {
                    HStack {
                        Text(puzzle.name(transfer.from) + " → " + puzzle.name(transfer.to)).lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(transfer.trips) × \(distance)").frame(width: 74)
                        Text(String(transfer.trips * distance)).frame(width: 30, alignment: .trailing)
                    }.gameFont(12).padding(.horizontal, 5).frame(minHeight: 29)
                        .background(editing.transfer == i ? Palette.ochre.opacity(0.30) : .clear, in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Divider()
            Text("Layout rules").gameFont(14, .bold)
            ruleRow("Keep every machine in an open bay.", true)
            ForEach(Array(puzzle.constraints(plan).enumerated()), id: \.offset) { _, rule in ruleRow(rule.text, rule.met) }
        }
    }

    private func ruleRow(_ title: String, _ met: Bool) -> some View {
        Label(title, systemImage: met ? "checkmark.circle" : "circle.dashed")
            .gameFont(12, .semibold).foregroundStyle(met ? Palette.deepSage : Palette.warn)
    }

    private func routeFloor(_ puzzle: DeliveryPuzzle, _ order: [Int]) -> some View {
        let trip = puzzle.forecast(order)
        return VStack(alignment: .leading, spacing: 9) {
            Text("Select shops in visit order. The dashed line returns to the depot.")
                .gameFont(14, .semibold).foregroundStyle(Palette.quiet)
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let nodes = puzzle.stops.indices.map { i -> CGPoint in
                    let theta = Double(i) * .pi * 2 / Double(puzzle.stops.count) + .pi * 0.68
                    return pt(width / 2 + cos(theta) * (width * 0.37), height / 2 + sin(theta) * (height * 0.34))
                }
                ZStack {
                    Canvas { context, _ in
                        let art = Art(context: context)
                        for road in puzzle.roads {
                            art.line([nodes[road.a], nodes[road.b]], color: Palette.line, width: 14)
                            art.line([nodes[road.a], nodes[road.b]], color: Palette.paper, width: 2)
                        }
                        art.line(trip.path.map { nodes[$0] }, color: Palette.blue, width: 5)
                        if !trip.homePath.isEmpty {
                            let path = Path { path in
                                path.move(to: nodes[trip.homePath[0]])
                                for node in trip.homePath.dropFirst() { path.addLine(to: nodes[node]) }
                            }
                            context.stroke(path, with: .color(Palette.deepSage), style: StrokeStyle(lineWidth: 4, dash: [6,5]))
                        }
                    }.allowsHitTesting(false)
                    ForEach(Array(puzzle.roads.enumerated()), id: \.offset) { _, road in
                        let center = pt((nodes[road.a].x + nodes[road.b].x) / 2, (nodes[road.a].y + nodes[road.b].y) / 2)
                        Text(roadText(road, timed: puzzle.timeBased)).gameFont(10, .bold)
                            .multilineTextAlignment(.center)
                            .padding(4).background(Palette.paper, in: RoundedRectangle(cornerRadius: 4))
                            .position(center)
                            .allowsHitTesting(false)
                    }
                    Canvas { context, _ in
                        let art = Art(context: context)
                        let tints = [Palette.clay, Palette.sage, Palette.blue, Palette.violet, Palette.ochre]
                        for i in puzzle.stops.indices where i != 0 {
                            let node = nodes[i]
                            let tint = tints[(i-1) % tints.count]
                            art.block(node.x - 31, node.y - 48, 62, 27, radius: 4, fill: tint.opacity(0.54),
                                      line: Palette.line, width: 1)
                            art.poly([pt(node.x - 36, node.y - 44), pt(node.x - 27, node.y - 54),
                                      pt(node.x + 27, node.y - 54), pt(node.x + 36, node.y - 44)],
                                     fill: tint, line: Palette.line, width: 1)
                        }
                    }.allowsHitTesting(false)
                    ForEach(puzzle.stops.indices, id: \.self) { i in
                        let index = order.firstIndex(of: i)
                        Button {
                            game.toggleStop(i)
                        } label: {
                            Text(index.map { "\($0 + 1) · " + puzzle.stops[i].name } ?? puzzle.stops[i].name)
                                .gameFont(13, .bold).lineLimit(2)
                                .frame(width: 105, height: 54)
                                .background(index != nil || i == 0 ? Palette.sage : Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line) }
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(i == 0)
                            .position(nodes[i])
                    }
                }
            }
        }.padding(13)
    }

    private func roadText(_ road: Road, timed: Bool) -> String {
        guard timed else { return "\(road.km) km" }
        guard let from = road.slowFrom, let slow = road.slowMinutes else { return "\(road.minutes) min" }
        return "\(road.minutes) → \(slow) min\nfrom \(clockText(from))"
    }

    private func routeDetails(_ puzzle: DeliveryPuzzle, _ order: [Int], compact: Bool) -> some View {
        let trip = puzzle.forecast(order)
        let goal = puzzle.timeBased ? "Back by \(clockText(puzzle.limit))" : "Goal \(puzzle.limit) km or less"
        return VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            metric("Return forecast", value: puzzle.timeBased ? clockText(trip.time) : String(trip.distance),
                   unit: puzzle.timeBased ? "at depot" : "km including return", goal: goal,
                   ready: puzzle.issues(order).isEmpty, compact: compact)
            if puzzle.timeBased {
                Text("Depart \(clockText(puzzle.departure)) · \(puzzle.service) min unloading per shop")
                    .gameFont(11, .semibold)
            }
            Text("Visit order · \(order.count)/\(puzzle.stops.count - 1)").gameFont(16, .bold)
            Text("Shops are serviced in the order listed here.").gameFont(11).foregroundStyle(Palette.quiet)
            if order.isEmpty { Text("Select the first shop on the map.").gameFont(12).foregroundStyle(Palette.quiet) }
            ForEach(Array(order.enumerated()), id: \.element) { index, stop in
                HStack(spacing: 5) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(index + 1)  \(puzzle.stops[stop].name)").gameFont(13, .semibold).lineLimit(1)
                        if puzzle.card.mode == 1 {
                            Text(clockText(puzzle.stops[stop].open) + "–" + clockText(puzzle.stops[stop].close))
                                .gameFont(10).foregroundStyle(Palette.quiet)
                        }
                    }
                    Spacer(minLength: 0)
                    if let start = trip.arrival[stop] {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(clockText(start)).gameFont(11, .semibold)
                            if let wait = trip.waiting[stop] { Text("Wait \(wait)m").gameFont(9, .semibold) }
                        }
                        .foregroundStyle(trip.late.contains(stop) ? Palette.warn : Palette.quiet)
                        .help("Service starts at " + clockText(start))
                    }
                    routeButton("chevron.up", label: "Move earlier", enabled: index > 0) {
                        game.reorderStop(stop, to: index - 1)
                    }
                    routeButton("chevron.down", label: "Move later", enabled: index + 1 < order.count) {
                        game.reorderStop(stop, to: index + 1)
                    }
                    routeButton("xmark", label: "Remove stop", enabled: true) { game.toggleStop(stop) }
                }
                .padding(.horizontal, 7).frame(minHeight: compact ? 40 : 45)
                .background(Palette.beige.opacity(0.40), in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .workshopTarget(.route(index))
                .simultaneousGesture(drag(.stop(stop)))
            }
            if puzzle.card.mode == 1 {
                Text("Service must finish by the shop’s closing time.").gameFont(11, .semibold)
                let remaining = puzzle.stops.indices.dropFirst().filter { !order.contains($0) }
                if !remaining.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible())], alignment: .leading, spacing: 3) {
                        ForEach(remaining, id: \.self) { s in
                            let stop = puzzle.stops[s]
                            Text("\(stop.name)  \(clockText(stop.open))–\(clockText(stop.close))")
                                .gameFont(compact ? 10 : 11).lineLimit(2).foregroundStyle(Palette.quiet)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else if puzzle.card.mode == 2 {
                Text("Changing roads use the time you enter.").gameFont(12, .semibold)
            }
        }
    }

    private func routeButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                .frame(width: 31, height: 35).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled).help(label).accessibilityLabel(label)
    }
}

private final class WorkshopSelection: ObservableObject {
    @Published var selected: Int?
    @Published var transfer = 1
    @Published var dragPoint: CGPoint?
    var dragPiece: WorkshopPiece?
    var targets: [WorkshopTarget: CGRect] = [:]
    var dragging = false
    var suppressClick = false
}
