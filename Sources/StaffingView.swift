import SwiftUI

private let boardSpace = "staffing-board"

private struct SlotFrames: PreferenceKey {
    static let defaultValue: [Slot: CGRect] = [:]
    static func reduce(value: inout [Slot: CGRect], nextValue: () -> [Slot: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct TrayFrame: PreferenceKey {
    static let defaultValue = CGRect.null
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isNull { value = next }
    }
}

private struct MovingWorker {
    let id: String
    let point: CGPoint
}

private final class BoardInteraction: ObservableObject {
    var frames: [Slot: CGRect] = [:]
    var trayFrame = CGRect.null
    @Published var drag: MovingWorker?
    var suppressesClick = false
}

struct StaffingScreen: View {
    @EnvironmentObject private var game: GameSession
    let run: StageRun

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Staff the Stations").gameFont(32, .bold)
                        .accessibilityAddTraits(.isHeader)
                    Text(run.board.puzzle.title + " · " + run.board.puzzle.layout)
                        .gameFont(15).foregroundStyle(Palette.quiet)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Puzzle \(run.index + 1) of \(run.puzzles.count)").gameFont(15, .bold)
                    Text("\(run.board.puzzle.stations.count) stations")
                        .gameFont(14).foregroundStyle(Palette.quiet)
                }.padding(.trailing, 5)
                GameButton(title: "Pause", symbol: "pause.fill") { game.pause() }
                    .accessibilityIdentifier("game-pause")
                    .keyboardShortcut(.escape, modifiers: [])
            }
            GeometryReader { size in
                HStack(alignment: .top, spacing: 16) {
                    BoardView(board: run.board)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    CrewPanel(board: run.board, compact: size.size.height < 650)
                        .frame(width: max(418, min(650, size.size.width * 0.39)))
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BoardView: View {
    @EnvironmentObject private var game: GameSession
    let board: StaffingBoard
    @StateObject private var interaction = BoardInteraction()
    private var drag: MovingWorker? { interaction.drag }

    var body: some View {
        GeometryReader { size in
            let height = size.size.height
            let wall = min(78, max(42, height * 0.10))
            let traySpace: Double = 113
            let rowHeight = max(139, (height - wall - traySpace - 42) / 2)
            VStack(spacing: 0) {
                FactoryWall().frame(height: wall)
                floorRows(height: rowHeight)
                    .padding(.horizontal, 12)
                    .padding(.top, 9)
                Spacer(minLength: 2)
                tray.padding(.horizontal, 12).padding(.bottom, 7)
                if game.settings.keyboardHints {
                    Text("Esc  Pause  ·  Enter  Check plan")
                        .gameFont(11).foregroundStyle(Palette.quiet)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 13).padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.beige.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Palette.line, lineWidth: 1) }
        .overlay {
            if let drag, let worker = board.roster[drag.id] {
                WorkerArt(style: worker.style)
                    .frame(width: 62, height: 62)
                    .position(drag.point)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .coordinateSpace(name: boardSpace)
        .onPreferenceChange(SlotFrames.self) { interaction.frames = $0 }
        .onPreferenceChange(TrayFrame.self) { interaction.trayFrame = $0 }
    }

    private func floorRows(height: Double) -> some View {
        let stations = board.puzzle.stations
        let firstRow = stations.count == 4 ? 2 : 3
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(stations.prefix(firstRow), id: \.self) { station in
                    stationColumn(station, rowHeight: height)
                }
            }
            HStack(spacing: 8) {
                ForEach(stations.dropFirst(firstRow), id: \.self) { station in
                    stationColumn(station, rowHeight: height)
                }
            }
        }
    }

    private func stationColumn(_ station: Station, rowHeight: Double) -> some View {
        let required = board.puzzle.minimum(at: station)
        let power = board.power(at: station)
        let ready = power >= required
        let slots = board.puzzle.slots(at: station)
        let ratio = min(1.0, Double(power) / Double(required))
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(station.tint).frame(width: 5, height: 14)
                    .accessibilityHidden(true)
                Text(station.title).gameFont(15, .bold)
                Spacer(minLength: 2)
                if ready {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(Palette.deepSage)
                        .accessibilityHidden(true)
                }
                Text("\(power) / \(required)").gameFont(13, .semibold).monospacedDigit()
            }
            .padding(.horizontal, 9)
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(station.title), \(power) of \(required) power" + (ready ? ", ready" : ""))
            GeometryReader { meter in
                Capsule().fill(Palette.line.opacity(0.32))
                    .overlay(alignment: .leading) {
                        if power > 0 {
                            Capsule().fill(ready ? Palette.deepSage : station.tint)
                                .frame(width: meter.size.width * ratio)
                        }
                    }
            }
            .frame(height: 3)
            .padding(.horizontal, 10)
            .accessibilityHidden(true)

            GeometryReader { area in
                let bayWidth = area.size.width
                let slotSize = min(46, max(26, (bayWidth * 0.53 - 7) / 2))
                let artWidth = min(184, bayWidth * 0.45)
                let surfaceHeight = min(174, area.size.height)
                HStack(spacing: 5) {
                    MachineArt(station: station)
                        .frame(width: artWidth, height: surfaceHeight)
                    stationSlots(slots, size: slotSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: surfaceHeight)
                .background(Palette.beige.opacity(0.36), in: RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .background(Palette.paper.opacity(0.84), in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.86), lineWidth: 1) }
    }

    private func stationSlots(_ slots: [Slot], size: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                ForEach(slots.prefix(2)) { slot in slotButton(slot, size: size) }
            }
            if slots.count > 2 {
                HStack(spacing: 4) {
                    ForEach(slots.dropFirst(2)) { slot in slotButton(slot, size: size) }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func slotButton(_ slot: Slot, size: Double) -> some View {
        let occupantID = board.worker(in: slot)
        let occupant = occupantID.flatMap { board.roster[$0] }
        let selected = game.selected == occupantID && occupantID != nil
        let blocked = game.selected.map { !board.canPlace($0, in: slot) } ?? false
        let target = game.selected != nil && !blocked && !selected
        let hovered = drag.map { interaction.frames[slot]?.contains($0.point) == true } ?? false
        let slotView = Button {
            guard interaction.drag == nil, !interaction.suppressesClick else { return }
            game.act(on: slot)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(
                        selected || (target && hovered) ? Palette.sage.opacity(0.69) :
                            target ? Palette.sage.opacity(0.30) : Palette.paper.opacity(0.8))
                    RoundedRectangle(cornerRadius: 8).strokeBorder(
                        selected || target ? Palette.deepSage : Palette.quiet.opacity(0.74),
                        style: StrokeStyle(lineWidth: game.settings.strongerSlots ? 2.6 : target ? 1.8 : 1.25,
                                           dash: occupant == nil && !target && !blocked ? [4, 3] : []))
                    if let occupant, drag?.id != occupant.id {
                        WorkerArt(style: occupant.style).padding(3)
                    }
                    if blocked {
                        Path { path in
                            path.move(to: pt(9, size - 9))
                            path.addLine(to: pt(size - 9, 9))
                        }.stroke(Palette.warn.opacity(occupant == nil ? 0.90 : 0.65), lineWidth: 1.5)
                    }
                    if target && occupant != nil {
                        Image(systemName: "arrow.left.arrow.right")
                            .systemFont(size: 9)
                            .padding(2)
                            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .frame(width: size, height: size)
                Text(slot.id).gameFont(10, .semibold).monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("slot-\(slot.id)")
        .accessibilityLabel("\(slot.id), \(occupant?.name ?? "empty")" +
                            (blocked ? ", unavailable" : target ? ", available" : ""))
        .background(GeometryReader { size in
            Color.clear.preference(key: SlotFrames.self, value: [slot: size.frame(in: .named(boardSpace))])
        })
        if let occupantID {
            slotView.simultaneousGesture(dragGesture(for: occupantID))
        } else {
            slotView
        }
    }

    private var tray: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Crew tray").gameFont(15, .bold)
                Spacer()
                if game.selected != nil {
                    let assigned = game.selected.flatMap { board.slot(for: $0) } != nil
                    Button(assigned ? "Return to tray" : "Clear selection") {
                        if assigned { game.returnToTray() } else { game.cancelSelection() }
                    }.buttonStyle(.plain).gameFont(13, .semibold).foregroundStyle(Palette.deepSage)
                }
            }
            HStack(spacing: 5) {
                ForEach(board.crew) { worker in trayWorker(worker) }
            }
        }
        .padding(9)
        .background(Palette.paper.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
        .background(GeometryReader { size in
            Color.clear.preference(key: TrayFrame.self, value: size.frame(in: .named(boardSpace)))
        })
    }

    private func trayWorker(_ worker: Worker) -> some View {
        let slot = board.slot(for: worker.id)
        let selected = game.selected == worker.id
        return Button {
            guard interaction.drag == nil, !interaction.suppressesClick else { return }
            game.pick(worker.id)
        } label: {
            VStack(spacing: 3) {
                if let slot {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle")
                            .gameFont(17).foregroundStyle(Palette.deepSage)
                        Text(slot.id).gameFont(10, .semibold)
                    }
                    .frame(height: 37)
                } else if drag?.id == worker.id {
                    Color.clear.frame(height: 37)
                } else {
                    WorkerArt(style: worker.style).frame(width: 37, height: 37)
                }
                Text(worker.name).gameFont(12, .semibold).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(selected ? Palette.sage.opacity(0.5) : Palette.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Palette.deepSage : Palette.line,
                                                               lineWidth: selected ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("worker-\(worker.id)")
        .accessibilityLabel(slot.map { "\(worker.name), at \($0.id)" } ?? "\(worker.name), unassigned")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .simultaneousGesture(dragGesture(for: worker.id))
    }

    private func dragGesture(for worker: String) -> some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .named(boardSpace))
            .onChanged { value in
                guard game.gameActive else { return }
                if drag == nil { game.pick(worker, toggle: false) }
                interaction.drag = MovingWorker(id: worker, point: value.location)
            }
            .onEnded { value in
                guard drag?.id == worker else { return }
                interaction.suppressesClick = true
                interaction.drag = nil
                DispatchQueue.main.async { interaction.suppressesClick = false }
                if let target = interaction.frames.first(where: { $0.value.contains(value.location) })?.key {
                    game.move(worker, to: target)
                } else if interaction.trayFrame.contains(value.location) {
                    game.returnToTray(worker)
                } else {
                    game.cancelSelection(fromDrag: true)
                }
            }
    }
}

private extension Image {
    func systemFont(size: Double) -> some View { font(.system(size: size, weight: .semibold)) }
}

private struct CrewPanel: View {
    @EnvironmentObject private var game: GameSession
    let board: StaffingBoard
    let compact: Bool
    private let statWidth: CGFloat = 29
    private let placeWidth: CGFloat = 37

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 11) {
            goals
            Divider().overlay(Palette.line.opacity(0.8))
            HStack(alignment: .firstTextBaseline) {
                Text("Crew skills").gameFont(16, .bold).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 3)
                Text("Power = assigned skills").gameFont(11).foregroundStyle(Palette.quiet)
            }
            Text(board.puzzle.stations.map { $0.initial + " " + $0.title }.joined(separator: " · "))
                .gameFont(10).foregroundStyle(Palette.quiet)
                .fixedSize(horizontal: false, vertical: true)
            roster
            if !board.puzzle.rules.isEmpty {
                rules
            }
            if let feedback = game.feedback {
                Label(feedback.message, systemImage: feedback.problem ? "exclamationmark.circle" : "info.circle")
                    .gameFont(12, .semibold)
                    .foregroundStyle(feedback.problem ? Palette.warn : Palette.deepSage)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("staff-feedback")
            }
            GameButton(title: "Check plan", symbol: "checkmark", style: .filled, expand: true) {
                game.checkPlan()
            }
            .accessibilityIdentifier("check-plan")
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(compact ? 10 : 13)
        .background(Palette.paper.opacity(0.86), in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1) }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shift goals").gameFont(17, .bold).accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                goal("Assign workers", current: board.assignments.count, total: board.crew.count)
                goal("Power stations", current: board.readyStationCount, total: board.puzzle.stations.count)
                if !board.puzzle.rules.isEmpty {
                    goal("Follow rules", current: board.puzzle.rules.filter { board.status(of: $0) == .met }.count,
                         total: board.puzzle.rules.count)
                }
            }
        }
    }

    private func goal(_ title: String, current: Int, total: Int) -> some View {
        let met = current == total
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).gameFont(11, .semibold).lineLimit(1)
            HStack(spacing: 4) {
                if met {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        .foregroundStyle(Palette.deepSage)
                        .accessibilityHidden(true)
                }
                Text("\(current) / \(total)").gameFont(15, .bold).monospacedDigit()
                    .foregroundStyle(met ? Palette.deepSage : Palette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7).padding(.vertical, compact ? 4 : 6)
        .background(met ? Palette.sage.opacity(0.30) : Palette.beige.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(current) of \(total)" + (met ? ", complete" : ""))
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text("Shift rules").gameFont(13, .bold).accessibilityAddTraits(.isHeader)
            ForEach(Array(board.puzzle.rules.enumerated()), id: \.offset) { _, rule in
                let state = board.status(of: rule)
                let status = state == .met ? "Met" : state == .waiting ? "Waiting" : "Needs change"
                let icon = state == .met ? "checkmark.circle" : state == .waiting ? "circle.dashed" : "exclamationmark.circle"
                let tone = state == .met ? Palette.deepSage : state == .waiting ? Palette.quiet : Palette.warn
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: icon).font(.system(size: 11)).foregroundStyle(tone)
                        .accessibilityHidden(true)
                    Text(board.text(for: rule)).gameFont(11).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 2)
                    Text(status).gameFont(10, .semibold).foregroundStyle(tone)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var roster: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("Worker").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(board.puzzle.stations, id: \.self) { station in
                    Text(station.initial).frame(width: statWidth).accessibilityLabel(station.title)
                }
                Text("Allowed").frame(width: 66, alignment: .leading)
                Text("At").frame(width: placeWidth)
            }
            .gameFont(11, .bold)
            .padding(.horizontal, 5)
            .padding(.vertical, compact ? 3 : 5)
            Divider().overlay(Palette.line)
            ForEach(board.crew) { worker in
                workerRow(worker)
                Divider().overlay(Palette.line.opacity(0.6))
            }
        }
    }

    private func workerRow(_ worker: Worker) -> some View {
        let stations = board.puzzle.stations
        let allowed = board.puzzle.allowedStations(for: worker.id)
        let at = board.slot(for: worker.id)?.id
        let excluded = stations.filter { !allowed.contains($0) }
        let allowedText: String
        if excluded.isEmpty {
            allowedText = "All"
        } else if excluded.count < allowed.count {
            allowedText = "No " + excluded.map { $0.initial }.joined(separator: ", ")
        } else {
            allowedText = allowed.map { $0.initial }.joined(separator: ", ")
        }
        let ratings = stations.map { $0.title + " " + String(worker.power(at: $0)) }.joined(separator: ", ")
        let description = [worker.name, ratings, "allowed " + allowed.map { $0.title }.joined(separator: ", "),
                           at.map { "at " + $0 } ?? "unassigned"].joined(separator: "; ")
        let selected = game.selected == worker.id
        return Button {
            game.pick(worker.id)
        } label: {
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    WorkerArt(style: worker.style).frame(width: compact ? 16 : 19, height: compact ? 16 : 19)
                    Text(worker.name).gameFont(12, .semibold).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                ForEach(stations, id: \.self) { station in
                    Text(String(worker.power(at: station))).frame(width: statWidth).monospacedDigit()
                }
                Text(allowedText).frame(width: 66, alignment: .leading)
                Text(at ?? "—").frame(width: placeWidth)
            }
            .gameFont(13)
            .padding(.horizontal, 5)
            .frame(minHeight: compact ? 20 : 25)
            .background(selected ? Palette.sage.opacity(0.38) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(description)
    }
}

struct StaffingDialog: View {
    @EnvironmentObject private var game: GameSession
    let overlay: GameOverlay

    var body: some View {
        Group {
            switch overlay {
            case .briefing:
                EmptyView()
            case .pause:
                dialog(title: "Paused", message: "Your plan is ready when you are.", symbol: "pause.circle") {
                    GameButton(title: "Resume", style: .filled) { game.resume() }
                        .keyboardShortcut(.escape, modifiers: [])
                    GameButton(title: "Settings") { game.showSettings() }
                    GameButton(title: "Leave stage") { game.askToLeave() }
                }
            case .leave:
                dialog(title: "Leave this run?", message: "Your unfinished run and current plan will be cleared.",
                       symbol: "door.left.hand.open") {
                    GameButton(title: "Keep playing", style: .filled) { game.keepPlaying() }
                        .keyboardShortcut(.escape, modifiers: [])
                    GameButton(title: "Leave stage") { game.leaveStage() }
                }
            case .passed:
                dialog(title: "Puzzle complete", message: "Everyone has a place and all the stations are ready.",
                       symbol: "checkmark.circle.fill") {
                    GameButton(title: "Continue", style: .filled) { game.continueRun() }
                        .accessibilityIdentifier("next-puzzle")
                        .keyboardShortcut(.return, modifiers: [])
                }
            case .completed:
                dialog(title: "Stage complete", message: "You finished all six puzzles in this run.",
                       symbol: "checkmark.seal.fill") {
                    GameButton(title: "Play again", style: .filled) { game.startRun() }
                    GameButton(title: "Choose a stage") { game.leaveStage() }
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(26)
        .frame(width: 530)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line, lineWidth: 1.4) }
        .shadow(color: Palette.ink.opacity(0.13), radius: 22, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func dialog<Buttons: View>(title: String, message: String, symbol: String,
                                       @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).gameFont(40).foregroundStyle(Palette.deepSage)
                .accessibilityHidden(true)
            Text(title).gameFont(29, .bold).accessibilityAddTraits(.isHeader)
            Text(message).gameFont(15).foregroundStyle(Palette.quiet).multilineTextAlignment(.center)
            HStack(spacing: 8, content: buttons).padding(.top, 8)
        }.frame(maxWidth: .infinity)
    }
}
