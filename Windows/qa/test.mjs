import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  conversation, flowPowers, forecast, issues, makeBoard, placeStaff, plantCost, selectRun, slotList,
} from '../app/model.mjs';
import { translator } from '../app/i18n.mjs';

const read = relative => readFile(new URL(relative, import.meta.url), 'utf8').then(JSON.parse);
const [staffing, workshop, catalog, references] = await Promise.all([
  read('../app/assets/Puzzles.json'), read('../app/assets/Workshop.json'),
  read('../app/assets/Thai.json'), read('./reference.json'),
]);
const t = translator(catalog, 'en');
const thai = translator(catalog, 'th');
const roster = Object.fromEntries(staffing.workers.map(worker => [worker.id, worker]));
const pools = [staffing.puzzles, workshop.flow, workshop.plant, workshop.delivery];
assert.equal(references.length, 360);
assert.equal(new Set(references.map(r => r.id)).size, 360);
pools.forEach((pool, index) => {
  const stage = index + 1;
  assert.equal(pool.length, 90);
  for (const puzzle of pool) {
    const row = references.find(ref => ref.id === (stage === 1 ? puzzle.id : puzzle.card.id));
    assert.equal(row?.stage, stage);
    const board = makeBoard(stage, puzzle);
    assert.ok(issues(board, roster, t).length > 0, row.id + ' has an unsolved opening');
    if (stage === 1) {
      assert.equal(Object.keys(row.plan).length, puzzle.crew.length);
      assert.equal(new Set(Object.values(row.plan)).size, puzzle.crew.length);
      assert.ok(Object.values(row.plan).every(id => slotList(puzzle).some(slot => slot.id === id)));
      board.plan = {};
      for (const [id, slot] of Object.entries(row.plan)) {
        assert.ifError(placeStaff(board, roster, id, slot, t, 'en').error);
      }
    } else board.plan = row.plan;
    assert.deepEqual(issues(board, roster, t), [], row.id);
    assert.deepEqual(issues(board, roster, thai), [], row.id + ' in Thai');
    if (stage === 2) assert.deepEqual(flowPowers(puzzle, row.plan), row.power, row.id);
    if (stage === 3) assert.equal(plantCost(puzzle, row.plan), row.cost, row.id);
    if (stage === 4) {
      const trip = forecast(puzzle, row.plan);
      assert.equal(trip.distance, row.distance, row.id);
      assert.equal(trip.time, row.time, row.id);
    }
    const dialogue = conversation(board, roster, thai, new Set());
    assert.ok(dialogue.lines.every(line => /[ก-๙]/u.test(line)), row.id + ' Thai story: ' + dialogue.lines.join(' | '));
    assert.ok(dialogue.cast.every(worker => Object.hasOwn(roster, worker)), row.id + ' cast');
  }
  for (let mode = 0; mode < 3; mode++) {
    const deck = selectRun(stage, staffing, workshop, () => .5, mode);
    assert.deepEqual(deck.map(p => stage === 1 ? p.shiftStep : p.card.step), [1, 2, 3, 4, 5, 6]);
    assert.ok(deck.every(p => stage === 1 ? p.stations.length === mode + 4 : p.card.mode === mode));
  }
  console.log('Stage ' + stage + ': 90 reference solutions, Thai stories, and all run modes passed.');
});
