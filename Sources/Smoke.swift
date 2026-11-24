import Foundation

extension GameSession {
    /// Runs only with an explicit isolated QA profile and logfile. The production UI uses the same session methods.
    @discardableResult
    func smokeTest() -> Bool {
        var failures: [String] = []
        func expect(_ result: Bool, _ detail: String) {
            if !result { failures.append(detail) }
        }

        expect(launchFailure == nil && audio.ready && audio.musicPlaying, "Launch and bundled audio")
        expect(!data.completedStageOne, "QA profile must be fresh")
        navigate(to: .stages)
        startRun()
        expect(run?.puzzles.allSatisfy({ $0.stations.count == options.stationCount }) == true, "Run uses one station count")
        expect(overlay == .briefing && briefing?.cast.count == 2 && briefing?.lines.count == 3, "Two-worker shift scene")
        let firstSpeaker = briefing?.lines[0].worker.id
        advanceDialogue()
        expect(dialogueIndex == 1 && briefing?.lines[1].worker.id != firstSpeaker, "Conversation changes speaker")
        advanceDialogue()
        expect(dialogueIndex == 2 && overlay == .briefing, "Conversation reply")
        advanceDialogue()
        expect(gameActive, "Dialogue opens the board after the last line")
        checkPlan()
        expect(feedback?.problem == true && run?.index == 0, "Invalid plan stays on the same puzzle")
        if let board = run?.board, let worker = board.crew.first {
            pick(worker.id)
            let before = run?.board.assignments
            pause()
            showSettings()
            var changed = settings
            changed.musicVolume = 0.42
            changed.effectsVolume = 0.63
            changed.largeText = true
            changed.reduceMotion = true
            updateSettings(changed)
            closeSettings()
            resume()
            expect(selected == worker.id && run?.board.assignments == before, "Pause preserves the draft")
        }

        for index in 0..<StageRun.length {
            guard let board = run?.board, let solution = board.solution() else {
                failures.append("Puzzle \(index + 1) has no solution")
                break
            }
            if index == 1, let dee = board.crew.first(where: { $0.id == "dee" }),
               let blocked = board.puzzle.slots(at: .large).first {
                pick(dee.id)
                let previous = run?.board.assignments
                move(dee.id, to: blocked)
                expect(feedback?.problem == true && run?.board.assignments == previous, "Blocked placement is rejected")
            }
            for worker in board.crew where board.slot(for: worker.id) != nil {
                returnToTray(worker.id)
            }
            for (offset, worker) in board.crew.enumerated() {
                pick(worker.id)
                move(worker.id, to: solution[worker.id]!)
                if index == 0 && offset == 0 {
                    expect(audio.isPlaying(.pickup) && audio.isPlaying(.staffingPlacement),
                           "A quick placement does not cut off the pickup cue")
                }
            }
            checkPlan()
            if index < StageRun.length - 1 {
                expect(overlay == .passed, "Puzzle pass and continuation at \(index + 1)")
                continueRun()
                expect(run?.index == index + 1 && overlay == .briefing, "Next puzzle has a new briefing")
                beginPuzzle()
            }
        }
        expect(overlay == .completed && data.completedStageOne, "Stage 1 complete at puzzle six")
        do {
            let saved = try JSONDecoder().decode(PlayerData.self, from: Data(contentsOf: profileFile))
            expect(saved.completedStageOne && saved.settings.musicVolume == 0.42, "Save written before leaving the stage")
        } catch {
            failures.append("Read-back from disk: \(error)")
        }
        leaveStage()
        startRun()
        beginPuzzle()
        askToLeave()
        leaveStage()
        expect(run == nil && data.completedStageOne, "Leaving a replay preserves completed stage")
        audio.log(failures.isEmpty ? "SMOKE PASS" : "SMOKE FAIL: \(failures.joined(separator: "; "))")
        return failures.isEmpty
    }
}
