# Does This Work? v0.4

Does This Work? is an offline English-language macOS game about industrial
engineering decisions. Staff the Stations is the playable first stage.

Play six puzzles from a single four-, five-, or six-station layout picked
at the start of the run. Assign everyone to an allowed slot, meet each
station's power goal, and satisfy the shift rules. The six puzzles progress
from Warm-up through Production to Rush. Some Rush stations have both a
minimum and a maximum. Each layout still has 30 puzzles. Only Stage 1 is playable.

Hover over a worker in the crew tray or on the floor to see their name,
ratings, allowed stations, and any rules that apply. The crew skills panel
keeps the whole active crew's ratings and assignments in view. Select or
drag a worker to highlight usable slots.

## Build and test

You need macOS and Xcode selected as the active developer directory. The
application targets macOS 14 or later, builds for the host architecture, and
uses the local Xcode SDK. The downloadable v0.4 build was packaged for Apple
Silicon. This project has no external package dependencies.

```sh
./Scripts/test.sh
./Scripts/test_session.sh
./Scripts/build.sh
```

Open `outputs/Does This Work? v0.4.app` to play. The app keeps settings and
completed-stage progress locally. Reopening the app starts a new run while
preserving completed-stage progress.

To regenerate the checked-in puzzle bank after editing the authored scenarios,
use Python 3.10 or later and run `python3 Scripts/author_puzzles.py`. Sources, audio, art, and compiled
puzzle definitions are included in the source distribution.

## Version history

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
