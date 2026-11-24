import SwiftUI

struct ShiftScene: View {
    @EnvironmentObject private var game: GameSession
    let run: StageRun
    let intro: Briefing

    private var line: DialogueLine { intro.lines[game.dialogueIndex] }
    private var isLastLine: Bool { game.dialogueIndex + 1 == intro.lines.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before the shift · " + run.board.puzzle.layout).gameFont(15, .semibold)
                        .foregroundStyle(Palette.quiet)
                    Text(run.board.puzzle.title).gameFont(32, .bold).accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Text("Puzzle \(run.index + 1) of \(run.puzzles.count)").gameFont(15, .semibold)
            }

            workshopScene
                .frame(minHeight: 230, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(line.worker.name).gameFont(20, .bold).foregroundStyle(Palette.deepSage)
                    if intro.introduced == line.worker.id {
                        Text("New on this shift").gameFont(13).foregroundStyle(Palette.quiet)
                    }
                    Spacer()
                    Text("\(game.dialogueIndex + 1) / \(intro.lines.count)")
                        .gameFont(13, .semibold).monospacedDigit().foregroundStyle(Palette.quiet)
                        .accessibilityLabel("Line \(game.dialogueIndex + 1) of \(intro.lines.count)")
                }
                Text("“\(line.text)”").gameFont(21, .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 53, alignment: .topLeading)
                    .accessibilityIdentifier("dialogue-line")

                if game.dialogueIndex == 1 {
                    HStack(spacing: 5) {
                        ForEach(run.board.puzzle.stations, id: \.self) { station in
                            Text("\(station.title) \(line.worker.power(at: station))")
                                .gameFont(12, .semibold)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Palette.beige, in: Capsule())
                        }
                    }
                    .frame(height: 28)
                } else {
                    Text(intro.situation).gameFont(13).foregroundStyle(Palette.quiet)
                        .frame(minHeight: 28, alignment: .topLeading)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 19)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.line, lineWidth: 1) }

            HStack(spacing: 12) {
                if game.settings.keyboardHints {
                    Text("Enter  " + (isLastLine ? "Start puzzle" : "Next") + "   ·   Esc  Skip intro")
                        .gameFont(12).foregroundStyle(Palette.quiet)
                }
                Spacer()
                GameButton(title: "Skip intro", style: .quiet) { game.beginPuzzle(skip: true) }
                    .keyboardShortcut(.escape, modifiers: [])
                GameButton(title: isLastLine ? "Start puzzle" : "Next", style: .filled) {
                    game.advanceDialogue()
                }
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier(isLastLine ? "start-puzzle" : "next-line")
            }
        }
        .padding(29)
        .frame(maxWidth: 1150, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    private var workshopScene: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Palette.beige.opacity(0.59))
                FactoryWall()
                    .frame(height: min(53, height * 0.15))
                    .position(x: width * 0.5, y: min(26.5, height * 0.075))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line, lineWidth: 1)
                Path { path in
                    path.move(to: pt(width * 0.10, height * 0.78))
                    path.addLine(to: pt(width * 0.90, height * 0.78))
                }.stroke(Palette.line, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Capsule().fill(Palette.beige.opacity(0.75))
                    .frame(width: width * 0.69, height: 8)
                    .position(x: width * 0.5, y: height * 0.804)
                MachineArt(station: .large)
                    .frame(width: width * 0.16, height: height * 0.47)
                    .opacity(0.69)
                    .position(x: width * 0.15, y: height * 0.54)
                MachineArt(station: run.board.puzzle.stations.last ?? .small)
                    .frame(width: width * 0.15, height: height * 0.41)
                    .opacity(0.72)
                    .position(x: width * 0.84, y: height * 0.61)
                Image(systemName: "wrench.adjustable")
                    .gameFont(23).foregroundStyle(Palette.quiet.opacity(0.48))
                    .rotationEffect(.degrees(-17))
                    .position(x: width * 0.82, y: height * 0.19)
                ForEach(Array(intro.cast.enumerated()), id: \.element.id) { index, worker in
                    let speaking = worker.id == line.worker.id
                    let size = min(height * 0.57, 174)
                    VStack(spacing: 5) {
                        ZStack {
                            Circle().fill(Palette.paper.opacity(speaking ? 0.90 : 0))
                                .frame(width: size, height: size)
                            WorkerArt(style: worker.style).frame(width: size, height: size)
                                .scaleEffect(speaking ? 1.07 : 0.84)
                                .opacity(speaking ? 1 : 0.70)
                        }
                        Text(worker.name).gameFont(16, speaking ? .bold : .semibold)
                            .foregroundStyle(speaking ? Palette.deepSage : Palette.quiet)
                    }
                    .animation(game.settings.reduceMotion ? nil : .easeInOut(duration: 0.29), value: speaking)
                    .position(x: width * (index == 0 ? 0.36 : 0.64), y: height * 0.49)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
