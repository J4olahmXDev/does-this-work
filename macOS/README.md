# Does This Work? v0.6

Does This Work? is an offline Thai- and English-language macOS puzzle game about industrial engineering. Each stage draws six distinct puzzles from one 30-puzzle layout or rule mode, paced from Warm-up to Rush. Clear the run to unlock the next stage. Completed stages remain available for replay.

## Stages

| Stage | Objective | Puzzle bank |
| --- | --- | --- |
| Staff the Stations | Assign every worker to an eligible position, meet station power targets, and satisfy crew rules. | 90 puzzles across 4-, 5-, and 6-station floors |
| Find the Bottleneck | Move or swap workers on a staffed production line. Finished output is the slowest station’s capacity. | 90 puzzles across 4-, 5-, and 6-station lines |
| Plan the Plant | Move machines between bays and shorten cart travel, weighted by the number of trips. Follow placement and fixed-equipment rules. | 90 puzzles across single-product, shared-equipment, and fixed-equipment layouts |
| Plan the Delivery Route | Order shop stops, check the return to the depot, and meet the distance or time limit. | 90 puzzles across distance, shop-window, and changing-traffic modes |

The game forecasts the impact of each move. The square checkmark becomes available when all conditions are met. The stage introduction advances automatically, with an option to pause or skip it. Planning has no real-time deadline.

## Build and test

Use macOS and select Xcode as the active developer directory. The app targets macOS 14 or later and builds for the host architecture. The distributed app is built for Apple Silicon. There are no external package dependencies.

```sh
./Scripts/test.sh
./Scripts/test_workshop.sh
./Scripts/test_session.sh
./Scripts/build.sh
```

Open `outputs/Does This Work?.app`. This build reads older settings and Stage 1 completion on first launch if a v0.6 save is absent. It writes progress to its own profile. A run in progress is cleared on exit, while completed-stage progress is saved.

Puzzle definitions and audio are bundled. To regenerate them from source, run the following with Python 3.10 or later.

```sh
python3 Scripts/author_puzzles.py
python3 Scripts/author_workshop.py
python3 Scripts/make_stage_audio.py
```

## Version history

### Does This Work? beta-v0.6

- Set the macOS app filename and window title to Does This Work? and kept the v0.6 save location.

- Added Thai and English selection under **Settings → Language**. The language changes immediately, including menus, character names, slot labels, board rules, all 360 puzzle titles, and story captions. Nonverbal voices use the same recordings in both languages.
- Enlarged the square confirmation button to 78 × 78 points with a bold checkmark. It turns green and becomes available when every condition is met.
- Added Mali for headings and buttons, and Sarabun for the rules and numeric tables. Both fonts are bundled for offline use.
- Added compact board layouts for translated labels. Reads the v0.5 profile on first launch and saves v0.6 progress in a separate profile.

### Does This Work? v0.5

- Added three playable stages, with 270 new boards and 360 puzzles in total.
- Added progressive unlocks, replay, and compatibility with v0.4 completion and settings.
- Updated the boards with larger click and drop areas and a square confirmation control with gray and green states.
- Added timed dialogue with captions, nonverbal character voices, Pause, and Skip. Every stage has a theme and a playing layer. Settings include a separate Dialogue voices volume.
- Retained Easy Bright for the home and settings screens and the 27 original sound effects.

### Does This Work? v0.4

- Worker speech bubbles sit above the hovered model or tray marker.
- Workers assigned to the floor leave a muted checkmark and slot code in the tray.
- Stations show their current power and a larger, separately labeled goal.
- Each six-puzzle run progresses through Warm-up, Production, and Rush.
  Targets have been retuned, and every run ends with a station that must stay
  within a power range. Compared with v0.3, 72 puzzles accept fewer crew
  groupings. Every puzzle still has at least three distinct plans.
- Only Stage 1 is playable. The existing music and 27 sound effects carry forward.

### Does This Work? v0.3 — Build 4 · Geometric Crew

- **Changed:** Brought the eight approved geometric characters into the game
  as vector models, with matching models and color variants for the rest of
  the Stage 1 roster. The same art appears in the menus, on the board, and
  during conversations.
- **Added:** Hover over a model to see its name, skills, current slot, allowed
  stations, and shift rules in a speech bubble. The crew tray doubles as an
  overview of the full crew, including the workers already on the floor.
- **Changed:** Before each puzzle, two workers stand on the floor and trade
  lines. The speech bubble and speaker emphasis move with the conversation.
  The second line surfaces a real rule or a relevant skill from that puzzle.
- **Changed:** Redrew all six machines with steel panels, controls, and
  recognizable tools. An aisle and quiet utility wall frame the numbered
  slots and stations.
- **Stage 1:** 90 puzzles, 30 per layout, with six puzzles per run. The music
  and 27 effects use the previously approved recordings.

### Does This Work? v0.3 — Build 3

- **Changed:** Redrew all six workshop machines as flat, native vector artwork
  with shared bases and recognizable tools. Each station groups its equipment,
  worker slots, and power meter in one visual bay.
- **Added:** Live shift-goal counts for assigned workers, ready stations, and
  satisfied rules. The rule list explains whether an assignment is waiting,
  met, or needs changing, and Check plan sits next to that feedback.
- **Changed:** Matched the factory wall and ground treatment on the title and
  pre-shift conversation scenes. The board adapts to four, five, or six stations.
- **Validation:** The puzzle model and original soundtrack carry forward.
  Tests cover the new goal states as well as the previous bank and audio routing.

### Does This Work? v0.2

- **Added:** 90 puzzles in three layout banks. Crew sizes scale from 6–8 workers
  at four stations, to 7–9 at five, to 8–10 at six.
- **Added:** Sort, Seal, and Label stations plus new workers, station-relative
  rules, and dialogue that uses the current crew and work floor.
- **Changed:** The station board uses two adaptive rows and a quiet workshop
  wall. All active station ratings stay visible beside the board.
- **Fixed:** Selection and placement effects play on separate lanes. Passing
  and continuing each use their own cue without abruptly cutting off the other.
- **Changed:** The release carries the name Does This Work? and its version
  number. The original v0.1.0 demo is archived separately under its original name.

### IE Puzzle Game — Demo v0.1.0

The first macOS demo had 30 puzzles with three stations, six puzzles per run,
worker dialogue, and the Easy Bright soundtrack.

## Licenses

[MIT](LICENSE) for code. [CC BY 4.0](ASSETS-LICENSE.md) for project artwork,
audio, dialogue, and puzzle designs.
