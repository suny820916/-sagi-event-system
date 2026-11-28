// Preparation for fixture/persistence integration. No live endpoint or package is used.
import assert from 'node:assert/strict';

function fixtureBinding(savedFixtures, current, remote) {
  const samePair = savedFixtures.filter(fixture => fixture.legacyKey === remote.legacyKey);
  if (current.legacyKey !== remote.legacyKey) return 'DIFFERENT_FIXTURE';
  if (remote.fixtureId) {
    return current.fixtureId === remote.fixtureId ? 'FOLLOW' : 'DIFFERENT_FIXTURE';
  }
  if (samePair.length > 1) return 'EXPLICIT_SELECTION_REQUIRED';
  return samePair.length === 1 && samePair[0].fixtureId === current.fixtureId
    ? 'FOLLOW_LEGACY'
    : 'EXPLICIT_SELECTION_REQUIRED';
}

const legacyKey = 'cup|rovers|city';
const first = { fixtureId: 'round-1', legacyKey };
const rematch = { fixtureId: 'round-2', legacyKey };
const different = { fixtureId: 'round-3', legacyKey: 'cup|rovers|town' };
const schedule = [first, rematch, different];
const bridge = JSON.parse(JSON.stringify({ ...first, revision: 104, homeScore: 4, eventId: 'goal-12' }));

assert.equal(fixtureBinding(schedule, first, bridge), 'FOLLOW', 'same saved match follows after restart');
assert.equal(fixtureBinding(schedule, rematch, bridge), 'DIFFERENT_FIXTURE', 'rematch must keep its own score');
assert.equal(fixtureBinding(schedule, different, bridge), 'DIFFERENT_FIXTURE');
assert.equal(fixtureBinding(schedule, rematch, { ...bridge, fixtureId: undefined }), 'EXPLICIT_SELECTION_REQUIRED');
assert.equal(fixtureBinding(schedule, first, { legacyKey }), 'EXPLICIT_SELECTION_REQUIRED');
assert.equal(fixtureBinding([first], first, { legacyKey }), 'FOLLOW_LEGACY');
assert.equal(fixtureBinding([], first, { legacyKey }), 'EXPLICIT_SELECTION_REQUIRED');
assert.equal(fixtureBinding([first], first, { ...bridge, fixtureId: 'unknown' }), 'DIFFERENT_FIXTURE');
console.log('PASS fixture identity preparation: restart, same-team rematch, and ambiguous legacy snapshots');
