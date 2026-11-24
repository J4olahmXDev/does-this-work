"""Tune power targets against feasible crew groupings while authoring Stage 1."""
from itertools import combinations

MINIMUM_PLANS = 3


def feasible_power(puzzle, workers, minimums=None):
    """Yield one tuple of station power totals for each feasible crew grouping."""
    crew = puzzle["crew"]
    required = puzzle["minimums"] if minimums is None else minimums
    bits = {worker: 1 << index for index, worker in enumerate(crew)}
    all_workers = (1 << len(crew)) - 1
    candidates = []
    for index, (station, limit) in enumerate(zip(puzzle["stations"], puzzle["capacity"])):
        required_workers = forbidden_workers = 0
        paired = []
        for rule in puzzle["rules"]:
            participants = [bits[worker] for worker in rule["workers"]]
            match rule["kind"]:
                case "only":
                    if rule["station"] == station:
                        required_workers |= participants[0]
                    else:
                        forbidden_workers |= participants[0]
                case "banned" if rule["station"] == station:
                    forbidden_workers |= participants[0]
                case "together" | "apart":
                    paired.append((sum(participants), rule["kind"]))
        skills = {worker: workers[worker][2][index] for worker in crew}
        station_plans = {}
        eligible = [worker for worker in crew if not bits[worker] & forbidden_workers]
        for count in range(1, limit + 1):
            for members in combinations(eligible, count):
                power = sum(skills[worker] for worker in members)
                if power < required[index]:
                    continue
                mask = sum(bits[worker] for worker in members)
                if mask & required_workers != required_workers:
                    continue
                if any(mask & pair not in (0, pair) if kind == "together" else mask & pair == pair
                       for pair, kind in paired):
                    continue
                station_plans[mask] = power
        candidates.append(station_plans)
    order = sorted(range(len(required)), key=lambda index: len(candidates[index]))
    powers = [0] * len(required)

    def visit(row, remaining):
        index = order[row]
        if row == len(order) - 1:
            if remaining in candidates[index]:
                powers[index] = candidates[index][remaining]
                yield tuple(powers)
            return
        for mask, power in candidates[index].items():
            if mask & remaining == mask:
                powers[index] = power
                yield from visit(row + 1, remaining ^ mask)

    return list(visit(0, all_workers))


def choose_cap(plans, lower, target):
    options = []
    for index, minimum in enumerate(lower):
        totals = sorted({plan[index] for plan in plans})
        for upper in totals[:-1]:
            if upper <= minimum:
                continue
            remaining = [plan for plan in plans if plan[index] <= upper]
            if len(remaining) >= MINIMUM_PLANS:
                options.append((index, upper, remaining))
    if not options:
        return None
    return min(options, key=lambda option: (abs(len(option[2]) - target), option[1] - lower[option[0]]))


def balance(puzzle, workers, step):
    minimums = puzzle["minimums"][:]
    base = feasible_power(puzzle, workers)
    if len(base) < MINIMUM_PLANS:
        raise ValueError(f"{puzzle['id']} needs more feasible crew groupings")

    plans = base
    target = max(MINIMUM_PLANS, round(len(base) * (0.72, 0.63, 0.53, 0.43, 0.34, 0.28)[step - 1]))
    caps = [None] * len(minimums)
    if step >= 5:
        cap = choose_cap(plans, minimums, target)
        # When even the original viable plans all have the same output, open a
        # little room to make a range that requires choosing which workers to move.
        if cap is None:
            for index, original in enumerate(minimums):
                if original <= 2:
                    continue
                trial = minimums[:]
                trial[index] -= 1
                alternatives = feasible_power(puzzle, workers, trial)
                candidate = choose_cap(alternatives, trial, target)
                if candidate and len(candidate[2]) <= len(base):
                    minimums = trial
                    cap = candidate
                    break
        if cap:
            index, caps[index], plans = cap

    for _ in range((2, 3, 4, 5, 5, 6)[step - 1]):
        if len(plans) <= target:
            break
        candidates = []
        for i, minimum in enumerate(minimums):
            if caps[i] is not None and minimum + 1 >= caps[i]:
                continue
            filtered = [plan for plan in plans if plan[i] > minimum]
            if MINIMUM_PLANS <= len(filtered) < len(plans):
                candidates.append((i, filtered))
        if not candidates:
            break
        index, plans = min(candidates, key=lambda candidate: abs(len(candidate[1]) - target))
        minimums[index] += 1

    puzzle["shiftStep"] = step
    puzzle["minimums"] = minimums
    if any(cap is not None for cap in caps):
        puzzle["maximums"] = caps
