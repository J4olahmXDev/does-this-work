export const stationNames = { large: 'Press', medium: 'Assemble', small: 'Wrap', sort: 'Sort', seal: 'Seal', label: 'Label' };
export const slotCodes = { large: 'P', medium: 'A', small: 'W', sort: 'So', seal: 'Se', label: 'La' };
export const thaiCodes = { large: 'ก', medium: 'ป', small: 'ห', sort: 'ค', seal: 'ซ', label: 'ฉ' };
export const stages = [
  { id: 1, title: 'Staff the Stations', summary: 'Assign the crew to meet machine goals.' },
  { id: 2, title: 'Find the Bottleneck', summary: 'Move workers to raise finished output.' },
  { id: 3, title: 'Plan the Plant', summary: 'Place machines to shorten cart routes.' },
  { id: 4, title: 'Plan the Delivery Route', summary: 'Order the stops and return to the depot.' },
];
export const pace = step => step <= 2 ? 'Warm-up' : step <= 4 ? 'Production' : 'Rush';
export const clock = minutes => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
export const slotID = (station, position) => slotCodes[station] + (position + 1);
export const slotList = card => card.stations.flatMap((station, index) =>
  Array.from({ length: card.capacity[index] }, (_, number) => ({ id: slotID(station, number), station, number })));
export const allowedStation = (card, id, station) => card.rules.every(rule =>
  !rule.workers.includes(id) || (rule.kind === 'only' ? rule.station === station :
    rule.kind === 'banned' ? rule.station !== station : true));
export const slotStation = (card, id) => slotList(card).find(slot => slot.id === id)?.station;
export const crewName = (roster, id) => roster[id]?.name ?? id;
export const slotLabel = (card, id, lang) => {
  const slot = slotList(card).find(item => item.id === id);
  return slot ? (lang === 'th' ? thaiCodes : slotCodes)[slot.station] + (slot.number + 1) : id;
};

export function selectRun(stage, staffing, workshop, random = Math.random, fixedMode) {
  const mode = fixedMode ?? Math.floor(random() * 3);
  const items = stage === 1 ? staffing.puzzles : workshop[['flow', 'plant', 'delivery'][stage - 2]];
  const pool = items.filter(puzzle => stage === 1 ? puzzle.stations.length === 4 + mode : puzzle.card.mode === mode);
  return Array.from({ length: 6 }, (_, i) => {
    const choices = pool.filter(p => (stage === 1 ? p.shiftStep : p.card.step) === i + 1);
    if (!choices.length) throw new Error('Puzzle bank is incomplete.');
    return choices[Math.floor(random() * choices.length)];
  });
}

export function makeBoard(stage, puzzle) {
  return { stage, puzzle, plan: stage === 1 ? { ...puzzle.initial } : stage === 4 ? [] : [...puzzle.initial] };
}

export function ruleState(board, rule) {
  const positions = rule.workers.map(id => slotStation(board.puzzle, board.plan[id]));
  if (positions.some(value => value === undefined)) return 'Waiting';
  const [first, second] = positions;
  const met = rule.kind === 'only' ? first === rule.station : rule.kind === 'banned' ? first !== rule.station :
    rule.kind === 'together' ? first === second : first !== second;
  return met ? 'Met' : 'Needs change';
}

export function explainRule(rule, roster, t) {
  const [first, second] = rule.workers.map(id => crewName(roster, id));
  switch (rule.kind) {
    case 'only': return t('%@ can only work at %@.', first, stationNames[rule.station]);
    case 'banned': return t('%@ cannot work at %@.', first, stationNames[rule.station]);
    case 'together': return t('%@ and %@ must work together.', first, second);
    case 'apart': return t('%@ and %@ must work at different stations.', first, second);
    default: return t('Worker assignment rule');
  }
}

export function staffPower(board, roster, station) {
  return Object.entries(board.plan).reduce((total, [id, slot]) =>
    total + (slotStation(board.puzzle, slot) === station ? roster[id].ratings[station] : 0), 0);
}

export function staffGoals(board, roster) {
  return board.puzzle.stations.map((station, index) => {
    const power = staffPower(board, roster, station);
    const min = board.puzzle.minimums[index], max = board.puzzle.maximums?.[index];
    return { station, power, min, max, ready: power >= min && (max == null || power <= max) };
  });
}

export function placeStaff(board, roster, id, target, t, lang) {
  const card = board.puzzle, current = board.plan[id], station = slotStation(card, target);
  if (!card.crew.includes(id) || !station) return { error: t('Choose a slot on this board.') };
  if (current === target) return {};
  if (!allowedStation(card, id, station)) {
    return { error: t('%@ cannot work at %@.', crewName(roster, id), stationNames[station]) };
  }
  const other = Object.keys(board.plan).find(key => board.plan[key] === target);
  if (other && !current) {
    return { error: t('%@ is occupied. Choose an empty slot.', slotLabel(card, target, lang)) };
  }
  if (other && !allowedStation(card, other, slotStation(card, current))) {
    return { error: t('%@ cannot swap into %@.', crewName(roster, other), slotLabel(card, current, lang)) };
  }
  if (other) board.plan[other] = current;
  board.plan[id] = target;
  return { cue: other ? 'swap' : 'staffplace' };
}

export function flowPowers(puzzle, plan) {
  const result = puzzle.stations.map(() => 0);
  plan.forEach((station, worker) => { result[station] += puzzle.ratings[worker][station]; });
  return result;
}
export function moveFlow(board, worker, station, other, t) {
  const { puzzle: p, plan } = board;
  if (!Number.isInteger(worker) || !p.crew[worker] || !p.stations[station] || plan[worker] === station) return {};
  if (!p.allowed[worker].includes(station)) return { error: t('This worker cannot use that station.') };
  if (other != null) {
    if (plan[other] !== station || !p.allowed[other].includes(plan[worker])) {
      return { error: t('These workers cannot swap stations.') };
    }
    plan[other] = plan[worker];
  } else if (plan.filter(value => value === station).length >= p.capacities[station]) {
    return { error: t('This station is full. Select a worker to swap.') };
  }
  plan[worker] = station;
  return { cue: 'flow' };
}

export const plantName = index => ({ '-1': 'Receive', '-2': 'Ship', 0: 'Cut', 1: 'Assemble', 2: 'Inspect', 3: 'Pack' })[index];
export const plantColumn = (p, plan, machine) => machine === -1 ? p.receiving :
  machine === -2 ? p.shipping : plan[machine] % 6 + 1;
export function plantDistance(p, plan, from, to) {
  return Math.abs(plantColumn(p, plan, from) - plantColumn(p, plan, to)) + (from < 0 ? 0 : 1) + (to < 0 ? 0 : 1);
}
export const plantCost = (p, plan) => p.transfers.reduce((sum, edge) => sum + edge.trips * plantDistance(p, plan, edge.from, edge.to), 0);
export function plantRules(p, plan, t) {
  const result = [];
  if (p.southMachine >= 0) result.push([t('%@ uses a south bay.', plantName(p.southMachine)), plan[p.southMachine] >= 6]);
  if (p.nearShipping >= 0) result.push([
    t('%@ within %@ tiles of Ship.', plantName(p.nearShipping), p.shippingLimit),
    plantDistance(p, plan, p.nearShipping, -2) <= p.shippingLimit,
  ]);
  for (const m of p.fixed) result.push([t('%@ stays at its fixed bay.', plantName(m)), plan[m] === p.initial[m]]);
  return result;
}
export function movePlant(board, machine, bay, t) {
  const { puzzle: p, plan } = board;
  if (!Number.isInteger(machine) || !p.machines[machine] || !p.bays.includes(bay) || plan[machine] === bay) return {};
  const other = plan.indexOf(bay);
  if (p.fixed.includes(machine) || p.fixed.includes(other)) return { error: t('That machine is fixed in place.') };
  if (other >= 0) plan[other] = plan[machine];
  plan[machine] = bay;
  return { cue: 'plant' };
}

export function routeLeg(p, from, to, departure) {
  const best = p.stops.map(() => Infinity);
  const parent = p.stops.map(() => -1);
  const pending = new Set(p.stops.keys());
  best[from] = 0;
  while (pending.size) {
    const current = [...pending].sort((a, b) => best[a] === best[b] ? a - b : best[a] - best[b])[0];
    if (current === to || !Number.isFinite(best[current])) break;
    pending.delete(current);
    for (const road of p.roads) {
      if (road.a !== current && road.b !== current) continue;
      const other = road.a === current ? road.b : road.a;
      const length = p.card.mode === 0 ? road.km :
        (road.slowFrom != null && departure + best[current] >= road.slowFrom ? road.slowMinutes : road.minutes);
      if (best[current] + length < best[other]) {
        best[other] = best[current] + length;
        parent[other] = current;
      }
    }
  }
  const path = [to];
  for (let at = to; at !== from && parent[at] >= 0; at = parent[at]) path.push(parent[at]);
  return { amount: best[to], path: path.reverse() };
}

export function forecast(p, order) {
  const result = { distance: 0, time: p.departure, arrival: {}, waiting: {}, late: [], path: [], homePath: [] };
  let from = 0;
  for (const stop of order) {
    const leg = routeLeg(p, from, stop, result.time);
    result.path.push(...leg.path.slice(0, -1));
    if (p.card.mode === 0) {
      result.distance += leg.amount;
    } else {
      const arrival = result.time + leg.amount, begin = p.card.mode === 1 ? Math.max(arrival, p.stops[stop].open) : arrival;
      result.arrival[stop] = begin;
      if (begin > arrival) result.waiting[stop] = begin - arrival;
      result.time = begin + p.service;
      if (p.card.mode === 1 && result.time > p.stops[stop].close) result.late.push(stop);
    }
    from = stop;
  }
  result.path.push(from);
  const home = routeLeg(p, from, 0, result.time);
  result.homePath = home.path;
  if (p.card.mode === 0) result.distance += home.amount;
  else result.time += home.amount;
  return result;
}
export function reorderStop(board, stop, target) {
  const from = board.plan.indexOf(stop);
  if (from < 0 || target < 0 || target >= board.plan.length || from === target) return false;
  board.plan.splice(from, 1);
  board.plan.splice(target, 0, stop);
  return true;
}

export function issues(board, roster, t) {
  const { stage, puzzle: p, plan } = board;
  const result = [];
  if (stage === 1) {
    const missing = p.crew.filter(id => !plan[id]).map(id => crewName(roster, id));
    if (missing.length === 1) result.push(t('%@ still needs a station.', missing[0]));
    else if (missing.length) result.push(t('Assign %@.', missing.map(name => t(name)).join(', ')));
    for (const goal of staffGoals(board, roster)) {
      const name = stationNames[goal.station];
      if (goal.power < goal.min) result.push(t('%@ needs %@ more power.', name, goal.min - goal.power));
      else if (goal.max != null && goal.power > goal.max) {
        result.push(t('%@ is over its limit by %@ power.', name, goal.power - goal.max));
      }
    }
    for (const rule of p.rules) if (ruleState(board, rule) === 'Needs change') result.push(explainRule(rule, roster, t));
  } else if (stage === 2) {
    if (plan.some((station, worker) => !p.allowed[worker].includes(station))) result.push(t('A worker is at an unavailable station.'));
    if (p.capacities.some((cap, s) => plan.filter(value => value === s).length > cap)) result.push(t('A station has too many workers.'));
    if (Math.min(...flowPowers(p, plan)) < p.goal) result.push(t('Finished output is below target.'));
  } else if (stage === 3) {
    result.push(...plantRules(p, plan, t).filter(([, met]) => !met).map(([label]) => label));
    if (new Set(plan).size !== plan.length || plan.some(bay => !p.bays.includes(bay))) {
      result.push(t('Place each machine in a different open bay.'));
    }
    if (plantCost(p, plan) > p.goal) result.push(t('Cart travel is above target.'));
  } else {
    const trip = forecast(p, plan);
    if (plan.length !== p.stops.length - 1 || new Set(plan).size !== plan.length) result.push(t('Visit every shop.'));
    if (trip.late.length) result.push(t('A delivery finishes after its window closes.'));
    if ((p.card.mode === 0 ? trip.distance : trip.time) > p.limit) result.push(t('The return to the depot is over the limit.'));
  }
  return result;
}

export function conversation(board, roster, t, seen) {
  const { stage, puzzle: p } = board;
  if (stage === 1) {
    const fresh = p.crew.filter(id => !seen.has(id));
    const peopleWithRules = p.rules.flatMap(rule => rule.workers);
    const speaker = peopleWithRules.find(id => fresh.includes(id)) ?? fresh[0] ?? peopleWithRules[0] ?? p.crew[0];
    const rule = p.rules.find(item => item.workers.includes(speaker));
    const partner = rule?.workers.find(id => id !== speaker);
    const coworker = partner ?? p.crew.find(id => id !== speaker);
    let key;
    if (rule?.kind === 'only') key = t('I can only work at %@ today.', stationNames[rule.station]);
    else if (rule?.kind === 'banned') key = t("I can't use %@ today.", stationNames[rule.station]);
    else if (rule) key = t(rule.kind === 'together' ? '%@ and I need to work at the same station.' :
      '%@ and I need to work at different stations.', crewName(roster, partner));
    else {
      const station = [...p.stations].sort((a, b) => roster[speaker].ratings[b] - roster[speaker].ratings[a])[0];
      key = t('I bring %@ power to %@.', roster[speaker].ratings[station], stationNames[station]);
    }
    for (const id of p.crew) seen.add(id);
    return { info: t(p.briefing), cast: [coworker, speaker], lines: [t(p.greeting), key, t(p.closing)] };
  }
  const cast = { 2: ['dee', 'bo'], 3: ['eli', 'fay'], 4: ['gus', 'cam'] }[stage];
  const key = stage === 2 ? t('We need %@ finished items a minute. Keep an eye on the slowest station.', p.goal) :
    stage === 3 ? (p.southMachine >= 0 ? t('Keep %@ on the south side. Try shortening the trips that happen most often.', plantName(p.southMachine)) :
      t('Keep the aisle open. We have a budget of %@ tile-trips per batch.', p.goal)) :
    p.card.mode === 0 ? t('The full trip, including the drive back, has to fit within %@ kilometres.', p.limit) :
    t(p.card.mode === 1 ? "Check each shop's window. We can wait if we're early, but unloading has to finish before closing." :
      'Some roads slow down later. The time we enter a road is the one that counts.');
  return { info: t(p.card.layout), cast, lines: [t(p.card.greeting), key, t(p.card.closing)] };
}
