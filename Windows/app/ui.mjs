import {
  stationNames, slotCodes, thaiCodes, stages, pace, clock, slotID, slotList, slotLabel, allowedStation,
  selectRun, makeBoard, ruleState, explainRule, staffGoals, placeStaff, flowPowers, moveFlow,
  plantName, plantColumn, plantDistance, plantCost, plantRules, movePlant, forecast, reorderStop, issues, conversation,
} from './model.mjs';
import { translator } from './i18n.mjs';
import { GameSound } from './sound.mjs';

const base = document.querySelector('#game');
const announce = document.querySelector('#announcement');
const read = path => fetch(new URL('./assets/' + path, import.meta.url)).then(response => {
  if (!response.ok) throw new Error(path);
  return response.json();
});
const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, char =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const defaults = { lang: 'en', master: .8, music: .6, effects: .8, voices: .55, fullscreen: false,
  size: 0, large: false, reduce: false, outlines: false, hints: true };

let staffing, workshop, catalog, roster;
let profile = { completed: 0, settings: { ...defaults } };
try {
  const saved = JSON.parse(localStorage.getItem('dtw-v06-profile') ?? 'null');
  if (saved) {
    profile.completed = Number.isInteger(saved.completed) ? Math.min(4, Math.max(0, saved.completed)) : 0;
    for (const [key, value] of Object.entries(defaults)) {
      const candidate = saved.settings?.[key];
      if (typeof candidate !== typeof value) continue;
      if (key === 'lang' && !['en', 'th'].includes(candidate)) continue;
      if (typeof value === 'number' && (!Number.isFinite(candidate) ||
        (key === 'size' ? ![0, 1, 2].includes(candidate) : candidate < 0 || candidate > 1))) continue;
      profile.settings[key] = candidate;
    }
  }
} catch { /* A fresh profile can be played even if saved settings are unreadable. */ }

const sound = new GameSound(profile.settings);
let t = key => key;
const state = { screen: 'home', tab: 'Audio', back: 'home', overlay: null, stage: 0, index: 0,
  run: [], board: null, selected: null, transfer: 1, seen: new Set(), voice: null, timer: null, feedback: '' };
const e = escapeHTML;
const label = (key, ...values) => e(t(key, ...values));
const artURL = file => './assets/art/' + file + '.png';
const workerArt = (id, className = '') => {
  const worker = roster[id];
  return `<img class="worker ${className}" src="${artURL('worker-' + worker.style.replace(':', '-'))}" alt="" draggable="false">`;
};
const machineArt = station => `<img class="machine" src="${artURL('machine-' + station)}" alt="" draggable="false">`;
const stageArt = stage => `<img class="stage-art" src="${artURL('stage-' + stage)}" alt="">`;
const name = id => t(roster[id]?.name ?? id);
const code = (station, i) => (profile.settings.lang === 'th' ? thaiCodes : slotCodes)[station] + (i + 1);
const slotDisplay = id => slotLabel(state.board.puzzle, id, profile.settings.lang);
const staffOrder = ['nextStaff', 'nextFlow', 'nextPlant', 'nextRoute'];
const save = () => {
  try { localStorage.setItem('dtw-v06-profile', JSON.stringify(profile)); }
  catch { announce.textContent = t('Progress or settings could not be saved.'); }
};
const card = () => state.stage === 1 ? state.board.puzzle : state.board.puzzle.card;
const documentTitle = 'Does This Work?';

function button(action, title, options = {}) {
  const { value, primary, disabled, small, pressed, key, icon } = options;
  return `<button type="button" class="button${primary ? ' primary' : ''}${small ? ' small' : ''}"
    data-action="${e(action)}"${value == null ? '' : ` data-value="${e(value)}"`}
    ${key == null ? '' : `data-key="${e(key)}"`}
    ${pressed == null ? '' : `aria-pressed="${String(pressed)}"`} ${disabled ? 'disabled' : ''}>${icon ? icon + ' ' : ''}${label(title)}</button>`;
}
function sectionHeading(title, subtitle = '') {
  return `<header class="section-title"><h1>${label(title)}</h1>${subtitle ? `<p>${label(subtitle)}</p>` : ''}</header>`;
}

function home() {
  return `<section class="home"><div class="home-copy"><h1>Does This<br>Work?</h1>
  <nav class="home-actions" aria-label="${label('Play')}">
    ${button('stages', 'Play', { primary: true, icon: '▶' })}
    ${button('instructions', 'How to play')}${button('settings', 'Settings')}${button('quit', 'Quit')}
  </nav></div>
  <div class="diorama" aria-hidden="true">
    <div class="wall"></div>
    <svg class="trail" viewBox="0 0 600 320" preserveAspectRatio="none">
      <path d="M160 86 C188 25 510 42 446 132S120 252 248 280 S440 296 487 242" fill="none" stroke="#ab967b" stroke-dasharray="8 10" stroke-width="2.5"/>
    </svg>
    <div class="diorama-worker left">${workerArt('ari')}</div>
    <div class="diorama-worker right">${workerArt('cam')}</div>
    <div class="diorama-machine">${machineArt('large')}</div>
    <div class="diorama-stage line">${stageArt(2)}</div>
    <div class="diorama-stage map">${stageArt(4)}</div>
  </div></section>`;
}

function stagesScreen() {
  const cards = stages.map(stage => {
    const enabled = stage.id <= profile.completed + 1, completed = stage.id <= profile.completed;
    return `<article class="stage-card ${enabled ? '' : 'muted'}">
      ${stageArt(stage.id)}<div><h2>${label(stage.title)}</h2><p>${label(stage.summary)}</p>
      <p class="mini">${label('90 puzzles · 6 per run')}</p>
      ${enabled ? button('start', completed ? 'Replay' : 'Play', { value: stage.id, primary: true, key: 'start-' + stage.id }) :
        `<p class="lock">▣ ${label('Complete the previous stage')}</p>`}</div></article>`;
  }).join('');
  return `<section class="menu">${sectionHeading('Choose a stage', 'Play six puzzles to unlock the next stage.')}
  <div class="stage-grid">${cards}</div><footer>${button('home', 'Back')}</footer></section>`;
}

function instructions() {
  return `<section class="menu">${sectionHeading('How to play','Staff each station and reach its power target.')}
    <div class="stage-grid instruction-grid">${stages.map(stage => `<article class="stage-card">${stageArt(stage.id)}
      <div><h2>${label(stage.title)}</h2><p>${label(stage.summary)}</p></div></article>`).join('')}</div>
    <p>${label('Click or drag a worker. Hover over a model for their name, skills, and shift rules.')}</p>
    <p>${label('Everyone needs a place. Reach each power goal and stay within any power range.')}</p>
    <footer>${button('home', 'Back')}${button('stages', 'Play', { primary: true })}</footer></section>`;
}

function settingsScreen() {
  const tabs = ['Audio', 'Display', 'Accessibility', 'Language'];
  const row = (title, control) => `<div class="setting-row"><span>${label(title)}</span><div>${control}</div></div>`;
  const range = (key, title) => row(title, `<input type="range" id="${key}" data-setting="${key}" aria-label="${label(title)}"
    min=0 max=100 value="${Math.round(profile.settings[key] * 100)}"><output id="out-${key}">${Math.round(profile.settings[key] * 100)}%</output>`);
  const toggle = (key, title) => row(title, `<input type="checkbox" data-setting="${key}" aria-label="${label(title)}"${profile.settings[key] ? ' checked' : ''}>`);
  let content;
  switch (state.tab) {
    case 'Audio':
      content = range('master', 'Master volume') + range('music', 'Music') + range('effects', 'Sound effects') +
        range('voices', 'Dialogue voices'); break;
    case 'Display':
      content = row('Window mode', button('fullscreen', 'Windowed', { value: 'false', primary: !profile.settings.fullscreen }) +
        button('fullscreen', 'Fullscreen', { value: 'true', primary: profile.settings.fullscreen })) +
        row('Window size', `<select data-setting="size" aria-label="${label('Window size')}"${profile.settings.fullscreen ? ' disabled' : ''}>
          ${['1280 × 720', '1440 × 900', '1600 × 900'].map((size, i) =>
            `<option value="${i}"${i === profile.settings.size ? ' selected' : ''}>${size}</option>`).join('')}</select>`) +
        row('Text size', button('large', 'Standard', { value: 'false', primary: !profile.settings.large }) +
          button('large', 'Large', { value: 'true', primary: profile.settings.large })); break;
    case 'Accessibility':
      content = toggle('reduce', 'Reduce motion') + toggle('outlines', 'Stronger slot outlines') +
        toggle('hints', 'Show keyboard hints'); break;
    default:
      content = row('Game language', button('language', 'English', { value: 'en', primary: profile.settings.lang === 'en', key: 'language-en' }) +
        button('language', 'ภาษาไทย', { value: 'th', primary: profile.settings.lang === 'th', key: 'language-th' })) +
        `<p class="settings-help">${label('Choose the language for menus, puzzles, and dialogue.')}</p>`;
  }
  return `<section class="menu settings"><header class="section-title"><h1>${workerArt('bo')} ${label('Settings')}</h1></header>
    <nav class="tabs" aria-label="${label('Settings')}">${tabs.map(tab => button('tab', tab, {
      value: tab, pressed: state.tab === tab, key: 'tab-' + tab,
    })).join('')}</nav><div class="settings-content">${content}</div>
    <footer>${button('settingsBack', 'Back')}${button('reset', 'Reset defaults')}</footer></section>`;
}

function boardHeader() {
  const puzzle = card();
  return `<header class="game-header">
    <div><h1>${label(stages[state.stage - 1].title)}</h1><p>${label(puzzle.title)} · ${label(puzzle.layout)}</p></div>
    <div class="round"><strong>${label('Puzzle %@ of %@', state.index + 1, 6)}</strong>
    <span class="pace">${label(pace(puzzle.shiftStep ?? puzzle.step))}</span></div>
    ${button('pause', 'Pause', { icon: 'Ⅱ', key: 'pause' })}
  </header>`;
}

function confirm(results) {
  const ready = results.length === 0;
  const title = state.stage === 3 ? 'Confirm layout' : state.stage === 4 ? 'Confirm route' : 'Confirm plan';
  const detail = ready ? t('All conditions met') : results[0];
  return `<div class="confirm-strip"><div><strong>${label(title)}</strong><p class="${ready ? 'ok' : ''}">${e(detail)}</p></div>
    <button class="confirm ${ready ? 'ready' : 'locked'}" type="button" data-action="confirm" data-key="confirm"
      aria-label="${label(title)}" title="${e(detail)}" ${ready ? '' : 'disabled'}>
      <svg aria-hidden="true" viewBox="0 0 48 48"><path d="M10 24l9 10 19-22" /></svg>
    </button></div>`;
}

function wideMetric(title, value, unit, goal, ready) {
  return `<section class="wide-metric ${ready ? 'ok' : 'notice'}"><h2>${label(title)}</h2>
    <strong>${e(value)}</strong> <span>${label(unit)}</span><p><b>${e(goal)}</b></p></section>`;
}

function feedback() {
  return state.feedback ? `<div class="feedback" role="status">${e(state.feedback)}</div>` : '';
}

function workerTooltip(id, extra, rules = []) {
  return `<span class="worker-tooltip" aria-hidden="true"><strong>${e(name(id))}</strong>
    ${extra.map(line => `<span>${e(line)}</span>`).join('')}${rules.map(rule => `<span class="tip-rule">${e(rule)}</span>`).join('')}</span>`;
}

function staffScreen(results) {
  const board = state.board, p = board.puzzle;
  const goals = staffGoals(board, roster);
  const staffTip = id => workerTooltip(id, [
      p.stations.map(s => t(stationNames[s]) + ' ' + roster[id].ratings[s]).join(' · '),
      t('Allowed: %@', p.stations.filter(s => allowedStation(p, id, s)).map(s => t(stationNames[s])).join(', ')),
    ], p.rules.filter(r => r.workers.includes(id)).map(r => explainRule(r, roster, t)));
  const columns = goals.map((g, i) => {
    const slots = Array.from({ length: p.capacity[i] }, (_, n) => {
      const id = slotID(g.station, n);
      const person = Object.keys(board.plan).find(person => board.plan[person] === id);
      const selected = state.selected;
      const active = person && selected === person;
      const target = selected && allowedStation(p, selected, g.station);
      return `<button type="button" class="slot ${person ? 'occupied' : 'empty'} ${active ? 'active' : ''} ${target ? 'target' : ''}"
        data-action="staffSlot" data-value="${id}" data-drop="staffSlot" ${person ? `draggable="true" data-drag="${e(person)}"` : ''}
        data-key="staff-${id}" aria-label="${e(slotDisplay(id) + ', ' + (person ? name(person) : t('empty')))}">
        ${person ? workerArt(person) + staffTip(person) : ''}<span>${e(slotDisplay(id))}</span></button>`;
    }).join('');
    const goal = g.max == null ? g.min + '+' : g.min + '–' + g.max;
    return `<section class="station"><header><h3>${label(stationNames[g.station])}</h3>${g.ready ? '<b class="ok">✓</b>' : ''}
      <p><strong class="${g.ready ? 'ok' : ''}">${g.power}</strong> ${label('power')}</p><small>${label('Goal %@', goal)}</small></header>
      <div class="meter"><span style="width:${Math.min(100, 100 * g.power / (g.max ?? g.min))}%"></span></div>
      <div class="station-content">${machineArt(g.station)}<div class="slots">${slots}</div></div></section>`;
  }).join('');
  const crew = p.crew.map(id => {
    const slot = board.plan[id];
    return `<button type="button" class="crew-tile ${slot ? 'assigned' : ''} ${state.selected === id ? 'active' : ''}"
      data-action="worker" data-value="${id}" data-key="crew-${id}" draggable="true" data-drag="${id}"
      title="${e(name(id))}" aria-label="${e(slot ? t('%@, at %@', name(id), slotDisplay(slot)) : t('%@, unassigned', name(id)))}">
      ${slot ? `<b>✓</b><span>${e(slotDisplay(slot))}</span>` : workerArt(id)}
      ${staffTip(id)}</button>`;
  }).join('');
  const stats = (section, current, max) => `<div><span>${label(section)}</span><b>${current} / ${max}</b></div>`;
  const rules = p.rules.map(rule => {
    const status = ruleState(board, rule);
    return `<li class="${status === 'Met' ? 'ok' : status === 'Waiting' ? '' : 'warning'}">${e(explainRule(rule, roster, t))}
      <small>${label(status)}</small></li>`;
  }).join('');
  const table = p.crew.map(id => {
    const allowed = p.stations.filter(s => allowedStation(p, id, s));
    const permit = allowed.length === p.stations.length ? t('All') :
      allowed.map(s => (profile.settings.lang === 'th' ? thaiCodes : slotCodes)[s]).join(', ');
    return `<tr><th><button class="table-worker" type="button" data-action="worker" data-value="${id}" data-key="row-${id}"
      aria-label="${e(name(id))}" title="${e(name(id))}">${workerArt(id)}</button></th>
      ${p.stations.map(s => `<td>${roster[id].ratings[s]}</td>`).join('')}
      <td>${e(permit)}</td><td>${board.plan[id] ? e(slotDisplay(board.plan[id])) : '—'}</td></tr>`;
  }).join('');
  return `<div class="board-split">
    <section class="board staff-floor"><div class="board-bar">
      ${label(p.maximums ? 'Assign every worker. Keep stations with a range within both limits.' :
        'Assign every worker and meet each station’s power goal.')}
    </div><div class="station-grid ${p.stations.length === 4 ? 'two' : ''}">${columns}</div>
    <div class="crew-tray" data-drop="staffTray">
      <header><h3>${label('Crew tray')}</h3>${state.selected ? button('returnStaff',
        board.plan[state.selected] ? 'Return to tray' : 'Clear selection', { small: true }) : ''}</header>
      <div class="crew-row">${crew}</div>
    </div>
    ${profile.settings.hints ? `<small class="key-hint">${label(results.length ? 'Esc  Pause' : 'Esc  Pause  ·  Enter  Confirm plan')}</small>` : ''}
    </section>
    <aside class="sidebar staff-side"><div class="details"><h2>${label('Shift goals')}</h2>
      <div class="stat-cards">${stats('Assign workers', Object.keys(board.plan).length, p.crew.length)}
      ${stats('Power stations', goals.filter(g => g.ready).length, goals.length)}
      ${p.rules.length ? stats('Follow rules', p.rules.filter(r => ruleState(board, r) === 'Met').length, p.rules.length) : ''}</div>
      <h3>${label('Crew skills')}</h3>
      <p class="legend">${p.stations.map(s => e((profile.settings.lang === 'th' ? thaiCodes : slotCodes)[s] + ' ' + t(stationNames[s]))).join(' · ')}</p>
      <table class="crew-table"><thead><tr><th>${label('Worker')}</th>${p.stations.map(s =>
        `<th title="${label(stationNames[s])}">${e((profile.settings.lang === 'th' ? thaiCodes : slotCodes)[s])}</th>`).join('')}
        <th>${label('Allowed')}</th><th>${label('At')}</th></tr></thead><tbody>${table}</tbody></table>
      ${rules ? `<h3>${label('Shift rules')}</h3><ul class="rules">${rules}</ul>` : ''}</div>${feedback()}${confirm(results)}</aside></div>`;
}

function flowScreen(results) {
  const { puzzle: p, plan } = state.board;
  const powers = flowPowers(p, plan), minimum = Math.min(...powers);
  const stations = p.stations.map((station, s) => {
    const workers = plan.flatMap((at, i) => at === s ? [i] : []);
    const slots = Array.from({ length: p.capacities[s] }, (_, i) => {
      const worker = workers[i], item = worker == null ? undefined : p.crew[worker];
      const value = `${s}:${worker ?? ''}`;
      return `<button type="button" class="slot ${item ? 'occupied' : 'empty'} ${worker != null && state.selected === worker ? 'active' : ''}"
        data-action="flowSlot" data-value="${value}" data-drop="flowSlot" data-key="flow-${s}-${i}"
        ${item ? `draggable="true" data-drag="${worker}"` : ''} aria-label="${e(code(station, i) + ', ' + (item ? name(item) : t('empty')))}">
        ${item ? workerArt(item) + workerTooltip(item, [t('%@ · +%@ items/min here', name(item), p.ratings[worker][s])]) : ''}
        <span>${e(code(station, i))}</span></button>`;
    }).join('');
    return `<section class="station flow-tile ${powers[s] === minimum && minimum < p.goal ? 'notice' : ''}">
      <header><h3>${label(stationNames[station])}</h3><p><strong>${label('%@/min', powers[s])}</strong></p></header>
      ${machineArt(station)}<div class="slots">${slots}</div></section>`;
  }).join('');
  const table = p.crew.map((id, worker) => `<tr><th><button type="button" class="table-worker named"
      data-action="flowWorker" data-value="${worker}" data-key="flow-row-${worker}">${workerArt(id)} ${e(name(id))}</button></th>
    ${p.stations.map((_, s) => `<td>${p.allowed[worker].includes(s) ? p.ratings[worker][s] : '—'}</td>`).join('')}
    <td>${e((profile.settings.lang === 'th' ? thaiCodes : slotCodes)[p.stations[plan[worker]]])}</td></tr>`).join('');
  return `<div class="board-split"><section class="board flow-floor"><p class="board-bar">
    ${label('Select or drag a worker to an open slot. Drop on a worker to swap.')}</p>
    <div class="flow-grid">${stations}</div><div class="conveyor" aria-hidden="true">${powers.map(power =>
      `<span${power === minimum && minimum < p.goal ? ' class="waiting"' : ''}></span>`).join('')}</div>
    <p class="${minimum < p.goal ? 'warning' : 'ok'}">${label(minimum < p.goal ? 'Work is waiting at the highlighted stations.' :
      'Line is ready to meet the output goal.')}</p></section>
    <aside class="sidebar"><div class="details">${wideMetric('Line forecast', minimum, 'items/min', t('Goal %@+ items/min', p.goal), minimum >= p.goal)}
    <h3>${label('Crew output by station')}</h3><p class="legend">${label('A dash means that worker cannot use the station.')}</p>
    <table class="crew-table"><thead><tr><th>${label('Worker')}</th>${p.stations.map(s =>
      `<th title="${label(stationNames[s])}">${e((profile.settings.lang === 'th' ? thaiCodes : slotCodes)[s])}</th>`).join('')}
      <th>${label('At')}</th></tr></thead><tbody>${table}</tbody></table></div>${feedback()}${confirm(results)}</aside></div>`;
}

function plantScreen(results) {
  const { puzzle: p, plan } = state.board;
  const tile = bay => {
    const machine = plan.indexOf(bay), open = p.bays.includes(bay), fixed = p.fixed.includes(machine);
    const name = machine < 0 ? '' : plantName(machine);
    const row = profile.settings.lang === 'th' ? (bay < 6 ? 'น' : 'ต') : (bay < 6 ? 'N' : 'S');
    return `<button type="button" class="bay ${machine < 0 ? 'empty' : 'occupied'} ${machine >= 0 && state.selected === machine ? 'active' : ''}"
      data-action="bay" data-value="${bay}" data-drop="bay" data-key="bay-${bay}"
      ${open ? '' : 'disabled'} ${machine >= 0 && !fixed ? `draggable="true" data-drag="${machine}"` : ''}
      aria-label="${e(row + (bay % 6 + 1) + ', ' + t(name || (open ? 'open' : 'closed')))}">
      ${machine >= 0 ? machineArt(p.machines[machine]) + `<strong>${label(name)}</strong>` : ''}
      <span>${fixed ? label('Fixed') : open ? row + (bay % 6 + 1) : label('Closed')}</span></button>`;
  };
  const edge = p.transfers[state.transfer] ?? p.transfers[0];
  const pathPoint = m => [plantColumn(p, plan, m) * 100 + 50, m < 0 ? 152 : plan[m] < 6 ? 85 : 221];
  const from = pathPoint(edge.from), to = pathPoint(edge.to);
  const path = `M${from.join(' ')} V152 H${to[0]} V${to[1]}`;
  const cost = plantCost(p, plan);
  const transfers = p.transfers.map((edge, i) => {
    const distance = plantDistance(p, plan, edge.from, edge.to);
    return `<button type="button" class="transfer ${i === state.transfer ? 'current' : ''}" data-action="transfer" data-value="${i}"
      data-key="transfer-${i}"><span>${label(plantName(edge.from))} → ${label(plantName(edge.to))}</span><span>${edge.trips} × ${distance}</span>
      <strong>${edge.trips * distance}</strong></button>`;
  }).join('');
  return `<div class="board-split"><section class="board plant-floor"><p class="board-bar">${label('Place machines in open bays and keep the cart aisle clear.')}</p>
    <div class="plant-diagram">
      <div class="aisle"></div>
      <svg viewBox="0 0 800 304" preserveAspectRatio="none" aria-hidden="true"><path d="${path}" fill="none" stroke="#9b6b42" stroke-width="5" stroke-linecap="round"/></svg>
      <div class="plant-row north"><small>${label('North bays')}</small>${Array.from({ length: 6 }, (_, i) => tile(i)).join('')}</div>
      <div class="docks"><div style="grid-column:${p.receiving + 1}">${label('Receive')}</div><div style="grid-column:${p.shipping + 1}">${label('Ship')}</div></div>
      <div class="plant-row south"><small>${label('South bays')}</small>${Array.from({ length: 6 }, (_, i) => tile(i + 6)).join('')}</div>
    </div><p>${label('Select a transfer to highlight the cart route.')}</p></section>
    <aside class="sidebar"><div class="details">${wideMetric('Cart travel', cost, 'tile-trips per batch', t('Goal %@ or less', p.goal), cost <= p.goal)}
      <div class="transfer-head"><span>${label('Transfer')}</span><span>${label('Trips × tiles')}</span><span>${label('Cost')}</span></div>
      ${transfers}<h3>${label('Layout rules')}</h3>
      <ul class="rules"><li class="ok">✓ ${label('Keep every machine in an open bay.')}</li>
        ${plantRules(p, plan, t).map(([rule, met]) => `<li class="${met ? 'ok' : 'warning'}">${met ? '✓' : '○'} ${e(rule)}</li>`).join('')}</ul>
    </div>${feedback()}${confirm(results)}</aside></div>`;
}

function routeScreen(results) {
  const { puzzle: p, plan } = state.board;
  const trip = forecast(p, plan), timed = p.card.mode !== 0;
  const points = p.stops.map((_, i) => {
    const angle = i / p.stops.length * 2 * Math.PI + .68 * Math.PI;
    return [400 + Math.cos(angle) * 285, 226 + Math.sin(angle) * 146];
  });
  const line = nodes => nodes.map(i => points[i].join(',')).join(' ');
  const profileLine = road => !timed ? t('%@ km', road.km) : road.slowFrom == null ? t('%@ min', road.minutes) :
    t('%@ → %@ min\nfrom %@', road.minutes, road.slowMinutes, clock(road.slowFrom));
  const roads = p.roads.map(r => `<line x1="${points[r.a][0]}" y1="${points[r.a][1]}" x2="${points[r.b][0]}" y2="${points[r.b][1]}"/>`).join('');
  const chips = p.roads.map(road => {
    const a = points[road.a], b = points[road.b];
    return `<span class="road-tag" style="left:${(a[0] + b[0]) / 16}%;top:${(a[1] + b[1]) / 9.04}%">${e(profileLine(road))}</span>`;
  }).join('');
  const shops = p.stops.map((stop, i) => {
    const position = plan.indexOf(i), [x, y] = points[i];
    return `<button type="button" class="shop shop-${i} ${i === 0 || position >= 0 ? 'done' : ''}" style="left:${x / 8}%;top:${y / 4.52}%"
      data-action="stop" data-value="${i}" data-key="stop-${i}" ${i === 0 ? 'disabled' : ''}>
      ${position < 0 ? '' : position + 1 + ' · '}${label(stop.name)}</button>`;
  }).join('');
  const stops = plan.map((i, j) => {
    const stop = p.stops[i];
    const times = p.card.mode === 1 ? `<small>${clock(stop.open)}–${clock(stop.close)}</small>` : '';
    const service = timed ? `<div class="service ${trip.late.includes(i) ? 'warning' : ''}">${clock(trip.arrival[i])}
      ${trip.waiting[i] ? `<small>${label('Wait %@m', trip.waiting[i])}</small>` : ''}</div>` : '';
    const action = (title, glyph, action, value, disabled) => `<button type="button" class="icon-button"
      data-action="${action}" data-value="${value}" aria-label="${label(title)}" title="${label(title)}" ${disabled ? 'disabled' : ''}>${glyph}</button>`;
    return `<div class="visit-row" draggable="true" data-drag="${i}" data-drop="reorder" data-value="${j}">
      <div class="visit-name"><b>${j + 1} · ${label(stop.name)}</b>${times}</div>${service}${action('Move earlier', '⌃', 'reorder', `${i}:${j - 1}`, j === 0)}
      ${action('Move later', '⌄', 'reorder', `${i}:${j + 1}`, j === plan.length - 1)}
      ${action('Remove stop', '×', 'stop', i, false)}</div>`;
  }).join('');
  return `<div class="board-split"><section class="board route-floor">
    <p class="board-bar">${label('Select shops in visit order. The dashed line returns to the depot.')}</p>
    <div class="route-map"><svg viewBox="0 0 800 452" preserveAspectRatio="none" aria-hidden="true">
      <g class="road-base">${roads}</g><g class="road-center">${roads}</g>
      <polyline class="route-out" points="${line(trip.path)}" /><polyline class="route-home" points="${line(trip.homePath)}" />
    </svg>${chips}${shops}</div></section>
    <aside class="sidebar"><div class="details">
      ${wideMetric('Return forecast', timed ? clock(trip.time) : trip.distance, timed ? 'at depot' : 'km including return',
        timed ? t('Back by %@', clock(p.limit)) : t('Goal %@ km or less', p.limit), !results.length)}
      ${timed ? `<p class="legend">${label('Depart %@ · %@ min unloading per shop', clock(p.departure), p.service)}</p>` : ''}
      <h3>${label('Visit order · %@/%@', plan.length, p.stops.length - 1)}</h3>
      <p class="legend">${label(plan.length ? 'Shops are serviced in the order listed here.' : 'Select the first shop on the map.')}</p>
      <div class="visit-list">${stops}</div>
      ${p.card.mode === 1 ? `<p class="legend">${label('Service must finish by the shop’s closing time.')}</p>
        <div class="window-list">${p.stops.slice(1).map((stop, i) => plan.includes(i + 1) ? '' :
          `<span>${label(stop.name)} ${clock(stop.open)}–${clock(stop.close)}</span>`).join('')}</div>` : ''}
      ${p.card.mode === 2 ? `<p class="legend">${label('Changing roads use the time you enter.')}</p>` : ''}
    </div>${feedback()}${confirm(results)}</aside></div>`;
}

function storyScreen() {
  const speech = state.voice, speaking = speech.line === 1 ? 1 : 0, person = speech.cast[speaking];
  return `<section class="story">
    <header class="section-title"><div><p>${label('Before the shift · %@', card().layout)}</p><h1>${label(card().title)}</h1></div>
      <span>${label('Puzzle %@ of %@', state.index + 1, 6)}</span></header>
    <div class="story-set"><div class="wall"></div><div class="story-prop left">${state.stage === 4 ? stageArt(4) : machineArt('large')}</div>
      <div class="story-prop right">${stageArt(state.stage)}</div>
      ${speech.cast.map((actor, i) => `<div class="actor ${speaking === i ? 'speaking' : ''} pos-${i}">
        ${i === speaking ? `<div class="speech"><strong>${e(name(person))}</strong><p>“${e(speech.lines[speech.line])}”</p></div>` : ''}
        ${workerArt(actor)}</div>`).join('')}
    </div>
    <p class="story-info">${e(speech.info)} <span>${speech.line + 1} / ${speech.lines.length}</span></p>
    <footer><small>${label(speech.paused ? 'Scene paused' : 'Scene plays automatically')}</small>
      ${button('scenePause', speech.paused ? 'Resume scene' : 'Pause scene', { key: 'scenePause' })}
      ${button('skip', 'Skip scene', { primary: true, key: 'skip' })}</footer>
  </section>`;
}

function modal() {
  const next = stages[state.stage];
  let title, message, controls;
  switch (state.overlay) {
    case 'pause':
      title = t('Paused'); message = t('Your plan is ready when you are.');
      controls = button('resume', 'Resume', { primary: true }) + button('settings', 'Settings') + button('askLeave', 'Leave stage'); break;
    case 'leave':
      title = t('Leave this run?'); message = t('Your unfinished run and current plan will be cleared.');
      controls = button('pause', 'Keep playing', { primary: true }) + button('leave', 'Leave stage'); break;
    case 'passed':
      title = t('Puzzle complete');
      message = t('All conditions are met.');
      if (state.run[state.index + 1]) {
        const nextPuzzle = state.run[state.index + 1];
        const nextPace = pace(nextPuzzle.shiftStep ?? nextPuzzle.card?.step);
        if (nextPace !== pace(card().shiftStep ?? card().step)) message = t('Next up: %@.', nextPace);
      }
      controls = button('continue', 'Continue', { primary: true }); break;
    default:
      title = t(state.stage === 4 ? 'Game complete' : 'Stage complete');
      message = next ? t('Unlocked %@.', next.title) : t('You finished all four stages.');
      controls = (next ? button('start', 'Next stage', { value: next.id, primary: true }) : '') +
        button('start', 'Replay', { value: state.stage }) + button('leave', 'Choose a stage');
  }
  return `<div class="veil"><section class="dialog" role="dialog" aria-modal="true" aria-label="${e(title)}">
    <div class="dialog-mark">${state.overlay === 'pause' || state.overlay === 'leave' ? 'Ⅱ' : '✓'}</div>
    <h2>${e(title)}</h2><p>${e(message)}</p><footer>${controls}</footer></section></div>`;
}

function render() {
  t = translator(catalog, profile.settings.lang);
  document.documentElement.lang = profile.settings.lang;
  document.documentElement.classList.toggle('big-type', profile.settings.large);
  document.documentElement.classList.toggle('reduce-motion', profile.settings.reduce);
  document.documentElement.classList.toggle('strong-outlines', profile.settings.outlines);
  const active = document.activeElement?.dataset.key;
  const scrollTop = base.querySelector('.details')?.scrollTop ?? 0;
  if (state.screen === 'home') base.innerHTML = home();
  else if (state.screen === 'stages') base.innerHTML = stagesScreen();
  else if (state.screen === 'instructions') base.innerHTML = instructions();
  else if (state.screen === 'settings') base.innerHTML = settingsScreen();
  else if (state.overlay === 'story') base.innerHTML = storyScreen();
  else {
    const results = issues(state.board, roster, t);
    const board = [staffScreen, flowScreen, plantScreen, routeScreen][state.stage - 1](results);
    base.innerHTML = `<section class="game-shell"${state.overlay ? ' inert' : ''}>${boardHeader()}${board}</section>` +
      (state.overlay ? modal() : '');
    const panel = base.querySelector('.details');
    if (panel) panel.scrollTop = scrollTop;
  }
  if (active) [...base.querySelectorAll('[data-key]')].find(node => node.dataset.key === active)?.focus({ preventScroll: true });
  if (state.overlay && state.overlay !== 'story' && state.screen === 'game' && !base.contains(document.activeElement)) {
    base.querySelector('.dialog button')?.focus({ preventScroll: true });
  }
}

function syncAudio() {
  const scene = state.screen === 'home' || state.screen === 'settings' ? 'menu' :
    state.screen === 'game' ? String(state.stage) : '';
  sound.setScene(scene, state.overlay === 'story');
}

function go(screen) {
  state.screen = screen;
  syncAudio();
  render();
}
function createStory() {
  state.selected = null;
  state.transfer = 1;
  state.feedback = '';
  state.board = makeBoard(state.stage, state.run[state.index]);
  state.voice = { ...conversation(state.board, roster, t, state.seen), line: 0, paused: false };
  state.overlay = 'story';
  go('game');
  beginLine();
}

function beginLine() {
  clearTimeout(state.timer);
  if (state.overlay !== 'story' || state.voice.paused) return;
  const story = state.voice, line = story.lines[story.line], actor = roster[story.cast[story.line === 1 ? 1 : 0]];
  sound.voice(actor.style);
  const seconds = profile.settings.lang === 'th' ? Array.from(line).length / 16 + 0.7 : line.split(/\s+/).length / 3.2 + 0.6;
  state.timer = setTimeout(() => {
    if (state.overlay !== 'story' || state.voice !== story || story.paused) return;
    if (++story.line >= story.lines.length) finishStory();
    else { render(); beginLine(); }
  }, 1000 * Math.max(3.4, seconds));
}
function finishStory() {
  clearTimeout(state.timer);
  sound.stopVoice();
  state.overlay = null;
  syncAudio();
  render();
}
function selectPiece(id) {
  state.feedback = '';
  state.selected = state.selected === id ? null : id;
  if (state.selected != null) sound.play('pickup');
  render();
}
function moveResult(result) {
  state.feedback = result.error ?? '';
  state.selected = null;
  if (result.error) sound.play('blocked');
  else if (result.cue) sound.play(result.cue);
  render();
}

function handle(action, value) {
  sound.activate();
  if (['home', 'stages', 'instructions', 'settings', 'settingsBack', 'tab', 'language', 'fullscreen', 'large', 'reset'].includes(action)) {
    if (action === 'settings') { state.back = state.screen; state.tab = 'Audio'; go('settings'); }
    else if (action === 'settingsBack') go(state.back);
    else if (action === 'tab') { state.tab = value; render(); }
    else if (action === 'language') {
      profile.settings.lang = value;
      state.feedback = '';
      save();
      render();
    } else if (action === 'fullscreen') {
      profile.settings.fullscreen = value === 'true';
      window.desktopGame?.fullscreen(profile.settings.fullscreen);
      save();
      render();
    } else if (action === 'large') { profile.settings.large = value === 'true'; save(); render(); }
    else if (action === 'reset') {
      profile.settings = { ...defaults, lang: profile.settings.lang };
      sound.update(profile.settings);
      window.desktopGame?.fullscreen(false);
      save();
      render();
    } else go(action);
    sound.play(action === 'settingsBack' || action === 'home' ? 'back' : 'click');
    return;
  }
  if (action === 'quit') { window.desktopGame?.quit(); return; }
  if (action === 'start') {
    const stage = Number(value);
    if (!stages[stage - 1] || stage > profile.completed + 1) return;
    state.run = selectRun(stage, staffing, workshop);
    state.stage = stage;
    state.index = 0;
    state.seen.clear();
    sound.play('click');
    createStory();
    return;
  }
  if (state.overlay === 'story') {
    if (action === 'skip') { sound.play('back'); finishStory(); }
    if (action === 'scenePause') {
      state.voice.paused = !state.voice.paused;
      if (state.voice.paused) { clearTimeout(state.timer); sound.stopVoice(); }
      else beginLine();
      sound.play(state.voice.paused ? 'pause' : 'resume');
      render();
    }
    return;
  }
  if (action === 'pause' || action === 'resume' || action === 'askLeave' || action === 'leave') {
    if (action === 'leave') { state.run = []; state.board = null; state.overlay = null; go('stages'); }
    else {
      state.overlay = action === 'pause' ? 'pause' : action === 'askLeave' ? 'leave' : null;
      sound.play(action === 'pause' ? 'pause' : action === 'resume' ? 'resume' : 'popup');
      render();
    }
    return;
  }
  if (state.overlay === 'passed' && action === 'continue') {
    state.index++;
    sound.play(staffOrder[state.stage - 1]);
    createStory();
    return;
  }
  if (state.overlay || state.screen !== 'game') return;
  const board = state.board;
  switch (action) {
    case 'confirm': {
      if (issues(board, roster, t).length) return;
      state.selected = null;
      state.feedback = '';
      const final = state.index + 1 === state.run.length;
      state.overlay = final ? 'completed' : 'passed';
      if (final) {
        const newUnlock = profile.completed < state.stage && state.stage < stages.length;
        profile.completed = Math.max(profile.completed, state.stage);
        save();
        sound.play(state.stage === stages.length ? 'game' : 'cleared');
        if (newUnlock) sound.play('unlocked');
      } else sound.play('passed');
      render();
      return;
    }
    case 'worker': selectPiece(value); return;
    case 'staffSlot': {
      if (state.selected != null) { moveResult(placeStaff(board, roster, state.selected, value, t, profile.settings.lang)); return; }
      const id = Object.keys(board.plan).find(id => board.plan[id] === value);
      if (id) { selectPiece(id); return; }
      break;
    }
    case 'returnStaff':
      if (state.selected != null) {
        delete board.plan[state.selected];
        state.selected = null;
        state.feedback = '';
        sound.play('tray');
      }
      break;
    case 'flowWorker': selectPiece(Number(value)); return;
    case 'flowSlot': {
      const [station, occupied] = value.split(':');
      const worker = occupied === '' ? undefined : Number(occupied);
      if (state.selected != null && state.selected !== worker) {
        moveResult(moveFlow(board, state.selected, Number(station), worker, t)); return;
      }
      if (worker != null) { selectPiece(worker); return; }
      break;
    }
    case 'bay': {
      const bay = Number(value), machine = board.plan.indexOf(bay);
      if (state.selected != null && machine !== state.selected) { moveResult(movePlant(board, state.selected, bay, t)); return; }
      if (machine >= 0 && !board.puzzle.fixed.includes(machine)) { selectPiece(machine); return; }
      break;
    }
    case 'transfer': state.transfer = Number(value); sound.play('click'); break;
    case 'stop': {
      const stop = Number(value);
      if (stop === 0 || !board.puzzle.stops[stop]) return;
      const pos = board.plan.indexOf(stop);
      if (pos >= 0) { board.plan.splice(pos, 1); sound.play('back'); }
      else { board.plan.push(stop); sound.play('stop'); }
      break;
    }
    case 'reorder': {
      const [stop, target] = value.split(':').map(Number);
      if (reorderStop(board, stop, target)) sound.play('reorder');
      break;
    }
    default: return;
  }
  render();
}

let dragged;
base.addEventListener('click', event => {
  const control = event.target.closest('[data-action]');
  if (control && !control.disabled) handle(control.dataset.action, control.dataset.value);
});
base.addEventListener('input', event => {
  const control = event.target, key = control.dataset.setting;
  if (!key || control.type !== 'range') return;
  sound.activate();
  profile.settings[key] = Number(control.value) / 100;
  document.querySelector('#out-' + key).textContent = control.value + '%';
  sound.update(profile.settings);
  save();
});
base.addEventListener('change', event => {
  const control = event.target, key = control.dataset.setting;
  if (!key) return;
  if (key === 'size') {
    profile.settings.size = Number(control.value);
    window.desktopGame?.size(profile.settings.size);
  } else if (control.type === 'checkbox') profile.settings[key] = control.checked;
  else { if (key !== 'music') sound.play('click'); return; }
  save();
  render();
});
base.addEventListener('dragstart', event => {
  const target = event.target.closest('[data-drag]');
  if (!target || state.overlay) return;
  sound.activate();
  dragged = target.dataset.drag;
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', dragged);
  sound.play('pickup');
});
base.addEventListener('dragover', event => {
  if (dragged == null) return;
  const target = event.target.closest('[data-drop]');
  if (target && !target.disabled) {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    target.classList.add('drag-over');
  }
});
base.addEventListener('dragleave', event => event.target.closest('[data-drop]')?.classList.remove('drag-over'));
base.addEventListener('dragend', () => {
  dragged = undefined;
  for (const target of base.querySelectorAll('.drag-over')) target.classList.remove('drag-over');
});
base.addEventListener('drop', event => {
  const target = event.target.closest('[data-drop]');
  if (!target || dragged == null || target.disabled || state.overlay) return;
  event.preventDefault();
  const { drop, value } = target.dataset, id = dragged;
  dragged = undefined;
  target.classList.remove('drag-over');
  if (drop === 'staffSlot') moveResult(placeStaff(state.board, roster, id, value, t, profile.settings.lang));
  else if (drop === 'staffTray') { state.selected = id; handle('returnStaff'); }
  else if (drop === 'bay') moveResult(movePlant(state.board, Number(id), Number(value), t));
  else if (drop === 'flowSlot') {
    const [station, occupied] = value.split(':');
    moveResult(moveFlow(state.board, Number(id), Number(station), occupied === '' ? undefined : Number(occupied), t));
  } else if (drop === 'reorder') handle('reorder', id + ':' + value);
});
document.addEventListener('keydown', event => {
  if (!staffing || event.repeat) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    if (state.screen === 'settings') handle('settingsBack');
    else if (state.screen === 'game') {
      if (state.overlay === 'story') handle('skip');
      else if (state.overlay === 'pause') handle('resume');
      else if (state.overlay === 'leave') handle('pause');
      else if (!state.overlay) handle('pause');
    } else if (state.screen !== 'home') handle('home');
  } else if (event.key === 'Enter' && event.target === document.body && state.screen === 'game') {
    event.preventDefault();
    handle(state.overlay === 'passed' ? 'continue' : 'confirm');
  }
});
window.desktopGame?.onFullscreen(enabled => {
  profile.settings.fullscreen = enabled;
  save();
  if (state.screen === 'settings') render();
});

try {
  [staffing, workshop, catalog] = await Promise.all([read('Puzzles.json'), read('Workshop.json'), read('Thai.json')]);
  roster = Object.fromEntries(staffing.workers.map(worker => [worker.id, worker]));
  document.title = documentTitle;
  if (profile.settings.fullscreen) window.desktopGame?.fullscreen(true);
  else window.desktopGame?.size(profile.settings.size);
  go('home');
} catch (error) {
  t = translator(catalog ?? { 'Unable to start the game': 'เปิดเกมไม่ได้' }, profile.settings.lang);
  base.innerHTML = `<section class="menu">${sectionHeading('Unable to start the game')}</section>`;
  console.error(error);
}
