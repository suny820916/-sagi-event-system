import assert from 'node:assert/strict';
import { planPresentation } from './presentation-plan.mjs';
const plan = type => planPresentation({type,cueId:'fixture_001',programInput:'camera-guid'});
const intro = plan('INTRO');
assert.deepEqual(intro.steps.map(s=>s.graphic || s.action), ['competition','matchup','home-lineup','away-lineup','RETURN_PROGRAM']);
assert.equal(intro.steps.reduce((sum,s)=>sum+(s.durationMs||0),0),24000);
for (const [type,graphic] of Object.entries({GOAL:'goal-player',YELLOW:'yellow-card',RED:'red-card',SUB:'substitution'})) {
  const p=plan(type);
  assert.equal(p.steps[0].graphic,graphic);
  assert.deepEqual(p.steps.at(-1),{action:'RETURN_PROGRAM',input:'camera-guid'});
}
assert.throws(()=>plan('constructor'),/UNSUPPORTED/);
assert.throws(()=>planPresentation({type:'GOAL',cueId:'fixture_001'}),/PROGRAM_INPUT_REQUIRED/);
assert.throws(()=>planPresentation({type:'INTRO',cueId:'bad',programInput:'cam'}),/INVALID_CUE_ID/);
assert.throws(()=>{intro.steps[0].durationMs=1;},TypeError);
console.log('presentation-plan-selftest PASS');
