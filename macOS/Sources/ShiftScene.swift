import SwiftUI

struct ShiftScene: View {
    @Environment(\.gameLanguage) private var language
    @EnvironmentObject private var game: GameSession
    let intro: Briefing

    private var line: DialogueLine { intro.lines[game.dialogueIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    GameText(language.text("Before the shift · %@", game.puzzleLayout)).gameFont(15, .semibold)
                        .foregroundStyle(Palette.quiet)
                    GameText(game.puzzleTitle).gameFont(32, .bold).accessibilityAddTraits(.isHeader)
                }
                Spacer()
                GameText(language.text("Puzzle %@ of %@", String(game.puzzleIndex + 1), "6")).gameFont(15, .semibold)
            }

            workshopScene
                .frame(minHeight: 230, maxHeight: .infinity)

            HStack(alignment: .center, spacing: 10) {
                if game.dialogueIndex == 1, let run = game.run {
                    ForEach(run.board.puzzle.stations, id: \.self) { station in
                        GameText("\(language.text(station.title)) \(line.worker.power(at: station))")
                            .gameFont(12, .semibold)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.beige, in: Capsule())
                    }
                } else {
                    GameText(intro.situation).gameFont(13).foregroundStyle(Palette.quiet)
                }
                Spacer()
                GameText("\(game.dialogueIndex + 1) / \(intro.lines.count)")
                    .gameFont(13, .semibold).monospacedDigit().foregroundStyle(Palette.quiet)
                    .accessibilityLabel(language.text("Line %@ of %@", String(game.dialogueIndex + 1), String(intro.lines.count)))
            }
            .padding(.horizontal, 9)
            .frame(minHeight: 30)

            HStack(spacing: 12) {
                GameText(game.dialoguePaused ? "Scene paused" : "Scene plays automatically")
                    .gameFont(13, .semibold).foregroundStyle(Palette.quiet)
                Spacer()
                GameButton(title: game.dialoguePaused ? "Resume scene" : "Pause scene", style: .quiet) {
                    game.toggleDialoguePause()
                }
                GameButton(title: "Skip scene", style: .filled) { game.beginPuzzle(skip: true) }
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityIdentifier("skip-scene")
            }
        }
        .padding(29)
        .frame(maxWidth: 1150, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .task(id: "\(game.dialogueIndex)-\(game.dialoguePaused)") { await game.playDialogueBeat() }
    }

    private var workshopScene: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let wallHeight = min(98, height * 0.22)
            let speakerOnLeft = intro.cast.first?.id == line.worker.id
            let speakerX = width * (speakerOnLeft ? 0.35 : 0.65)
            let modelSize = min(height * 0.41, 178)
            let modelY = height * 0.82 - modelSize / 2
            ZStack {
                Palette.beige.opacity(0.54)
                VStack(spacing: 0) {
                    FactoryWall().frame(height: wallHeight)
                    Spacer(minLength: 0)
                }
                Path { path in
                    path.move(to: pt(width * 0.06, height * 0.86))
                    path.addLine(to: pt(width * 0.94, height * 0.86))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 1.3, dash: [8, 7]))
                sceneProps(width: width, height: height)

                ForEach(Array(intro.cast.enumerated()), id: \.element.id) { index, worker in
                    let speaking = worker.id == line.worker.id
                    WorkerArt(style: worker.style)
                        .frame(width: modelSize, height: modelSize)
                        .scaleEffect(speaking ? 1.13 : 0.95, anchor: .bottom)
                        .opacity(speaking ? 1 : 0.76)
                        .animation(game.settings.reduceMotion ? nil : .easeInOut(duration: 0.25), value: speaking)
                        .position(x: width * (index == 0 ? 0.35 : 0.65), y: modelY)
                }

                Color.clear.overlay(alignment: .topLeading) {
                    let bubbleWidth = min(374, width * 0.45)
                    dialogueBubble
                        .frame(width: bubbleWidth)
                        .alignmentGuide(.top) { $0.height }
                        .offset(x: speakerX - bubbleWidth / 2,
                                y: modelY - modelSize * 0.52)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.line, lineWidth: 1) }
        }
    }

    @ViewBuilder private func sceneProps(width: Double, height: Double) -> some View {
        switch game.stage {
        case .staffing, .bottleneck:
            MachineArt(station: game.stage == .staffing ? .large : .small)
                .frame(width: width * 0.19, height: height * 0.36)
                .opacity(0.74).position(x: width * 0.13, y: height * 0.54)
            if game.stage == .staffing {
                MachineArt(station: game.run?.board.puzzle.stations.last ?? .small)
                    .frame(width: width * 0.19, height: height * 0.36)
                    .opacity(0.74).position(x: width * 0.87, y: height * 0.54)
            } else {
                StageIllustration(stage: .bottleneck).frame(width: width * 0.22, height: height * 0.4)
                    .position(x: width * 0.87, y: height * 0.56)
            }
        case .plant:
            StageIllustration(stage: .plant).frame(width: width * 0.22, height: height * 0.38)
                .position(x: width * 0.87, y: height * 0.57)
            MachineArt(station: .medium).frame(width: width * 0.18, height: height * 0.36)
                .position(x: width * 0.13, y: height * 0.55)
        case .delivery:
            StageIllustration(stage: .delivery).frame(width: width * 0.30, height: height * 0.47)
                .position(x: width * 0.85, y: height * 0.55)
        }
    }

    private var dialogueBubble: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    GameText(line.worker.name).gameFont(16, .bold).foregroundStyle(Palette.deepSage)
                    if intro.introduced == line.worker.id {
                        GameText("New on this shift").gameFont(11).foregroundStyle(Palette.quiet)
                    }
                }
                GameText("“\(language.text(line.text))”").gameFont(17, .semibold)
                    .accessibilityIdentifier("dialogue-line")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .padding(.horizontal, 13)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line, lineWidth: 1) }
            SpeechTail()
        }
    }
}

struct SpeechTail: View {
    var body: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: pt(9, 8))
            path.addLine(to: pt(18, 0))
        }
        .fill(Palette.paper)
        .overlay {
            Path { path in
                path.move(to: .zero)
                path.addLine(to: pt(9, 8))
                path.addLine(to: pt(18, 0))
            }.stroke(Palette.line, lineWidth: 1)
        }
        .frame(width: 18, height: 8)
        .accessibilityHidden(true)
    }
}
