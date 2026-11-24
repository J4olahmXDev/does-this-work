"""Generate the reproducible Stage 2–4 puzzle banks."""
from itertools import combinations, permutations
from pathlib import Path
import heapq
import json
import random

rng = random.Random(3052026)
stations = ["large", "medium", "small", "sort", "seal", "label"]
people = ["ari", "bo", "cam", "dee", "eli", "fay", "gus", "hana", "ivo", "jo", "kit", "luz"]
orders = ["Morning", "Lunch Rush", "Late Shift", "Saturday", "Rainy Day"]
materials = ["Parcel", "Sample", "Gift Box", "Label", "Book", "Return"]
districts = ["Market", "Canal", "Station", "Garden", "Museum"]
shops = ["Bakery", "Florist", "Books", "Grocer", "Tea Shop", "Tailor", "Deli", "Stationery", "Cafe", "Pharmacy"]


def card(prefix, mode, step, variant, layout, title, greeting, closing):
    return dict(id=f"{prefix}-{mode+1}-{step}-{variant+1}", title=title, layout=layout,
                greeting=greeting, closing=closing, mode=mode, step=step)


def flow_counts(n, ratings, allowed, cap, minimum):
    groups = []
    for s in range(n):
        eligible = [i for i, choices in enumerate(allowed) if s in choices]
        masks = []
        for length in range(1, cap[s] + 1):
            for crew in combinations(eligible, length):
                if sum(ratings[i][s] for i in crew) >= minimum:
                    masks.append(sum(1 << i for i in crew))
        groups.append(masks)
    groups.sort(key=len)
    last = set(groups[-1])

    def count(index, remaining):
        if index == n - 1:
            return int(remaining in last)
        return sum(count(index + 1, remaining ^ mask) for mask in groups[index] if mask & remaining == mask)
    return count(0, (1 << len(ratings))-1)


def flow(mode, step, variant):
    n = 4 + mode
    for _ in range(600):
        count = n + 2 + int(step >= 5)
        crew = rng.sample(people, count)
        ratings = [[rng.randint(1, 5) for _ in range(n)] for _ in crew]
        allowed = [sorted(rng.sample(range(n), n-rng.randint(1, 2))) if i < step-1 else list(range(n))
                   for i in range(count)]
        cap = [2] * n
        if step >= 3:
            cap[rng.randrange(n)] = 3
        initial = [i % n for i in range(count)]
        rng.shuffle(initial)
        if any(s not in allowed[i] for i, s in enumerate(initial)):
            continue
        low = min(sum(ratings[i][s] for i in range(count) if initial[i] == s) for s in range(n))
        physical = flow_counts(n, ratings, allowed, cap, 0)
        choices = [(g, flow_counts(n, ratings, allowed, cap, g)) for g in range(max(3, low+1), 6)]
        feasible = [(g, c) for g, c in choices if 2 <= c <= min(physical//3, [140,100,75,48,28,18][step-1])]
        if not feasible:
            continue
        g, answers = feasible[-1]
        material = materials[step-1].lower()
        shift = orders[variant]
        c = card("flow", mode, step, variant, f"{n}-station line", f"{shift} {material.title()} Queue",
                 f"A batch of {material}s is stacking up. The scanner says the last station is ready, but it's waiting.",
                 "Let's move a worker and watch what actually comes off the line.")
        return dict(card=c, stations=stations[:n], crew=crew, ratings=ratings, allowed=allowed,
                    capacities=cap, initial=initial, goal=g)
    raise ValueError(("flow",mode,step,variant))


def plant(mode, step, variant):
    machines = ["large", "medium", "sort", "small"]
    for _ in range(120):
        receiving, shipping = rng.choice([(0,7),(7,0),(0,6),(1,7)])
        bays = sorted(rng.sample(range(12), 8 + rng.randrange(3)))
        initial = rng.sample(bays, 4)
        inspect = 2 if step >= 2 else -1
        near = 3 if step >= 3 else -1
        shipping_limit = rng.choice([2,3,4])
        fixed = [rng.randrange(4)] if mode == 2 else []
        allowed = []
        for i in range(4):
            valid = [b for b in bays if (i != inspect or b >= 6) and
                     (i != near or abs((b%6+1)-shipping)+1 <= shipping_limit)]
            if i in fixed:
                valid = [b for b in valid if b == initial[i]]
            allowed.append(valid)
        edges = [(-1,0,1),(0,1,rng.randrange(2,5)),(1,2,rng.randrange(1,4)),
                 (2,3,rng.randrange(1,4)),(3,-2,1)]
        if mode == 1:
            edges += [(-1,2,rng.randrange(1,4)),(2,0,rng.randrange(1,4)),(0,3,rng.randrange(1,4))]
        def cost(plan):
            cols = [b%6+1 for b in plan]
            def point(i):
                return receiving if i == -1 else shipping if i == -2 else cols[i]
            return sum(t*(abs(point(a)-point(b))+(a>=0)+(b>=0)) for a,b,t in edges)
        totals = sorted(cost(p) for p in permutations(bays,4) if all(b in allowed[i] for i,b in enumerate(p)))
        if len(totals) < 6:
            continue
        percentile = [0.16,0.14,0.10,0.08,0.05,0.03][step-1]
        goal = totals[max(1, int(len(totals)*percentile))]
        if cost(initial) <= goal and all(b in allowed[i] for i,b in enumerate(initial)):
            continue
        if sum(x<=goal for x in totals) > len(totals)//2:
            continue
        context = ["Compact Line","Shared Equipment","Fixed Equipment"][mode]
        c = card("plant", mode, step, variant, context,
                 f"{orders[variant]} {materials[step-1]} Layout",
                 ["We've been pushing the same cart across the floor all day.",
                  "Two orders need the same machines. The carts keep meeting in the aisle.",
                  "The crew marked a machine that has to stay put. Can we shorten the trips around it?"][mode],
                 "Start with the transfers we make most often. Keep every machine connected to the aisle.")
        return dict(card=c,machines=machines,bays=bays,initial=initial,allowed=allowed,
                    transfers=[dict(from_=a,to=b,trips=t) for a,b,t in edges], goal=goal,
                    southMachine=inspect,nearShipping=near,shippingLimit=shipping_limit,
                    fixed=fixed,receiving=receiving,shipping=shipping)
    raise ValueError(("plant",mode,step,variant))


def delivery(mode, step, variant):
    n = 4 if step <= 3 else 5
    for _ in range(500):
        names = ["Depot"] + rng.sample(shops, n)
        departure = 470 + variant*7
        pairs = [(i,(i+1)%(n+1)) for i in range(n+1)]
        if step >= 3:
            pairs += [(0,2),(2,n)]
        roads = [dict(a=a,b=b,km=rng.randint(1,6),minutes=rng.randint(4,16),
                      slowFrom=None,slowMinutes=None) for a,b in pairs]
        if mode == 2:
            for road in rng.sample(roads, 1 if step <= 2 else 2):
                road["slowFrom"] = departure+rng.randint(9,31)
                road["slowMinutes"] = road["minutes"]+rng.randint(6,15)
        def leg(a, b, depart):
            queue = [(0,a)]
            visited = set()
            while queue:
                elapsed,u = heapq.heappop(queue)
                if u == b:
                    return elapsed
                if u in visited:
                    continue
                visited.add(u)
                for r in roads:
                    if u not in (r["a"],r["b"]):
                        continue
                    v = r["b"] if u == r["a"] else r["a"]
                    slow = r["slowFrom"] is not None and depart+elapsed >= r["slowFrom"]
                    length = r["km"] if mode == 0 else r["slowMinutes"] if slow else r["minutes"]
                    heapq.heappush(queue, (elapsed+length,v))
        service = 3 if mode else 0
        windows = [(0, 1439) for _ in names]
        if mode == 1:
            tour = rng.sample(range(1,n+1),n)
            elapsed, prev = departure, 0
            for s in tour:
                elapsed += leg(prev,s,elapsed)
                wide = 25 if step <= 2 else 19 if step <= 4 else 14
                windows[s] = (max(departure,elapsed-rng.randint(3,wide)),elapsed+service+rng.randint(8,wide + 6))
                elapsed += service
                prev = s
        def tour_score(order):
            prev = 0
            elapsed = 0 if mode == 0 else departure
            for s in order:
                elapsed += leg(prev,s,elapsed)
                if mode == 1:
                    elapsed = max(elapsed,windows[s][0])
                    if elapsed+service > windows[s][1]:
                        return None
                elapsed += service
                prev = s
            return elapsed + leg(prev,0,elapsed)
        scores = [tour_score(o) for o in permutations(range(1,n+1))]
        valid = sorted(x for x in scores if x is not None)
        if len(valid) < 2:
            continue
        goal = valid[min(len(valid)-1, [5,4,4,3,2,1][step-1])]
        if sum(x<=goal for x in valid) > len(scores)//2:
            continue
        context = ["Distance Limit","Shop Windows","Changing Traffic"][mode]
        c = card("delivery",mode,step,variant,context, f"{districts[variant]} {orders[(step-1)%5]} Route",
                 ["The boxes are ready and the van is at the depot.",
                  "Some shops only take deliveries at certain times. The order of our stops matters today.",
                  "Traffic changes later this morning. Let's check which road we reach before it slows down."][mode],
                 "Put all the shops in order and make sure we can get back to the depot.")
        return dict(card=c,stops=[dict(name=name,open=a,close=b) for name,(a,b) in zip(names,windows)],
                    roads=roads,departure=departure,limit=goal,service=service)
    raise ValueError(("delivery",mode,step,variant))


def apply_preview_sample(puzzle):
    identity = puzzle["card"]["id"]
    c = puzzle["card"]
    if identity == "flow-2-2-1":
        c.update(title="A Queue at Wrap",
                 greeting="I counted the boxes waiting for Wrap. Then I stopped counting.",
                 closing="Let's move someone from a faster station and check the line again.")
        crew = ["ari", "jo", "kit", "hana", "cam", "dee", "bo", "fay", "gus", "eli", "luz"]
        plan = [0,0,0,1,1,2,3,3,4,4,4]
        powers = [4,3,2,5,2,5,5,3,4,4,2]
        ratings = [[1]*5 for _ in crew]
        for person, (station, power) in enumerate(zip(plan, powers)):
            ratings[person][station] = power
        ratings[crew.index("kit")][2] = 2
        puzzle.update(crew=crew, initial=plan, ratings=ratings,
                      allowed=[[station] if i in (0,1,4) else list(range(5))
                               for i, station in enumerate(plan)],
                      capacities=[3,2,2,2,3], goal=6)
    elif identity == "plant-1-3-1":
        c.update(title="The Packing Room Shuffle",
                 greeting="We moved the order desk, and now my cart gets more exercise than I do.",
                 closing="Cut sends three loads to Assemble. Those two should be closer, too.")
        bays = list(range(12))
        puzzle.update(bays=bays, initial=[0,4,8,11], goal=31, receiving=0, shipping=7,
                      allowed=[bays,bays,list(range(6,12)),[4,5,10,11]],
                      transfers=[dict(from_=a,to=b,trips=n) for a,b,n in
                                 [(-1,0,1),(0,1,3),(1,2,2),(2,3,2),(3,-2,1)]],
                      southMachine=2,nearShipping=3,shippingLimit=3,fixed=[])
    elif identity == "delivery-1-1-1":
        c.update(title="Four Stops Before Lunch",
                 greeting="Four shops, one truck. The bakery has already asked where we are.")
        puzzle.update(stops=[dict(name=name,open=0,close=1439) for name in
                             ["Depot","Bakery","Florist","Books","Grocer"]],
                      roads=[dict(a=a,b=b,km=d,minutes=d*4,slowFrom=None,slowMinutes=None)
                             for a,b,d in [(0,1,2),(1,2,3),(2,3,2),(3,4,2),(4,0,3),(0,2,5),(2,4,4)]],
                      limit=12)


def main():
    banks = {}
    for author in (flow, plant, delivery):
        bank = []
        for mode in range(3):
            for step in range(1,7):
                for variant in range(5):
                    puzzle = author(mode,step,variant)
                    apply_preview_sample(puzzle)
                    for edge in puzzle.get("transfers",[]):
                        edge["from"] = edge.pop("from_")
                    bank.append(puzzle)
        banks[author.__name__] = bank
    path = Path(__file__).resolve().parent.parent/"Resources"/"Workshop.json"
    path.write_text(json.dumps(banks,indent=2)+"\n")

if __name__ == "__main__":
    main()
