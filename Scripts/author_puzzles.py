"""Generate the three independent Stage 1 banks from authored shift scenarios."""
import json
from pathlib import Path

from balance_puzzles import balance
from scenarios import BRIEFS, CLOSINGS, OPENINGS, ROSTER, SCENARIOS, STATIONS, apart, banned, only

ROOT = Path(__file__).resolve().parent.parent
EXTENSIONS = ("sort", "seal", "label")
ALL_STATIONS = STATIONS + EXTENSIONS
SLOT_PREFIX = dict(zip(ALL_STATIONS, ("P", "A", "W", "So", "Se", "La")))
EXTRA_SKILLS = (
    (2, 1, 3), (4, 2, 1), (3, 2, 4), (3, 4, 2), (2, 3, 4), (2, 3, 3),
    (4, 3, 1), (2, 4, 3), (3, 4, 2), (2, 2, 4), (4, 3, 2), (3, 3, 4),
)
CREW_GROUPS = (
    (
        ("mika", "Mika", "beanie:blue", (2, 3, 1, 5, 2, 3)),
        ("quin", "Quin", "visor:violet", (3, 2, 3, 4, 3, 2)),
        ("tess", "Tess", "star:blue", (1, 3, 4, 5, 2, 2)),
    ),
    (
        ("noa", "Noa", "earmuffs:pink", (3, 2, 2, 3, 5, 2)),
        ("wren", "Wren", "headband:sage", (2, 4, 2, 2, 4, 3)),
        ("pax", "Pax", "scarf:blue", (2, 2, 3, 3, 5, 2)),
    ),
    (
        ("rene", "Rene", "glasses:sage", (1, 3, 3, 2, 3, 5)),
        ("uma", "Uma", "badge:pink", (3, 2, 2, 3, 2, 4)),
        ("sol", "Sol", "cap:ochre", (2, 3, 4, 2, 2, 5)),
    ),
)
LAYOUTS = {
    4: ("Sorting cell", "The sorter is on this shift, too. Leave enough power there."),
    5: ("Sealing line", "We’re running the sealer as well. Its target is on the board."),
    6: ("Dispatch floor", "Nothing leaves without a label. Check all six targets before we start."),
}
SHORT_OPENINGS = (
    "I sorted one bin and somehow ended up with two more. Typical.",
    "The sorter is ready. The bins, however, have formed their own queue.",
    "Somebody put the empty bin in with the full ones. We should get organised.",
)
MEDIUM_OPENINGS = (
    "Why does the sealer always get the warmest spot in the room?",
    "I swear these boxes grow wider on the way to the sealer.",
    "I brought the seal strips. Please tell me that’s the right tray this time.",
)
WIDE_OPENINGS = (
    "The labels are finally in order. I’m afraid to look away.",
    "Somebody labelled the label dispenser. I’d like to know who did that.",
    "Three parcels are waiting for labels. They look more patient than I feel.",
)
OPENING_VARIANTS = {4: SHORT_OPENINGS, 5: MEDIUM_OPENINGS, 6: WIDE_OPENINGS}

workers = {key: (name, style, skills + extras) for (key, (name, style, skills)), extras
           in zip(ROSTER.items(), EXTRA_SKILLS)}
for group in CREW_GROUPS:
    for key, name, style, skills in group:
        workers[key] = (name, style, skills)

puzzles = []
for station_count, (layout, ending) in LAYOUTS.items():
    stations = ALL_STATIONS[:station_count]
    for index, (title, grouping, slack, limits, core_rules, initial) in enumerate(SCENARIOS):
        groups = [members.split() for members in grouping]
        extensions = [CREW_GROUPS[d][(index + d * 2 + station_count - 4) % 3][0]
                      for d in range(station_count - 3)]
        groups.extend([worker] for worker in extensions)
        assignments = {worker: station for station, members in zip(stations, groups) for worker in members}
        crew = [worker for worker in workers if worker in assignments]
        minimums = [sum(workers[worker][2][i] for worker in members) -
                    (slack[i] if i < 3 else int((index + i + station_count) % 4 == 0) +
                     int(index < 6 and i == station_count - 1))
                    for i, members in enumerate(groups)]
        capacities = [*limits, *(1 + int((index + i) % 3 != 0) for i in range(len(extensions)))]

        # Vary crew restrictions while keeping each scenario's authored plan valid.
        rules = list(core_rules)
        new = extensions[(index + station_count) % len(extensions)]
        if len(rules) < 4:
            style = (index + station_count) % 7
            if style == 0:
                rules.append(only(new, assignments[new]))
            elif style in (1, 3):
                rules.append(apart(new, groups[0][0]))
            elif style in (2, 5):
                rules.append(banned(new, STATIONS[(index + station_count) % 3]))

        slots = {worker: SLOT_PREFIX[STATIONS["LMS".index(slot[0])]] + slot[1:]
                 for worker, slot in initial.items()}
        if index % 4 == 2:
            slots[new] = SLOT_PREFIX[assignments[new]] + "1"

        context = BRIEFS[index]
        for old, updated in (("Large", "Press"), ("Medium", "Assemble"), ("Small", "Wrap")):
            context = context.replace(old, updated)
        greeting = OPENINGS[index]
        closing = CLOSINGS[index]
        for old, updated in (("Large", "Press"), ("Medium", "Assemble"), ("Small", "Wrap")):
            greeting = greeting.replace(old, updated)
            closing = closing.replace(old, updated)
        if index % 5 == station_count - 4:
            greeting = OPENING_VARIANTS[station_count][index % 3]
            closing = ending
        puzzle = dict(id=f"staff-{station_count}-{index+1:02}", title=title, layout=layout,
                            briefing=context, greeting=greeting, closing=closing, crew=crew, stations=stations,
                            minimums=minimums, capacity=capacities, rules=rules, initial=slots)
        balance(puzzle, workers, step=index // 5 + 1)
        puzzles.append(puzzle)

roster = [dict(id=key, name=name, style=style, ratings=dict(zip(ALL_STATIONS, skills)))
          for key, (name, style, skills) in workers.items()]
(ROOT / "Resources" / "Puzzles.json").write_text(
    json.dumps({"workers": roster, "puzzles": puzzles}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
