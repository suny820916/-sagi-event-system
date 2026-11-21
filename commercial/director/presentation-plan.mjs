// Pure, offline presentation planning. Does not mutate match state or call vMix.
const stages = Object.freeze({
  INTRO: [['competition',4000],['matchup',4000],['home-lineup',8000],['away-lineup',8000]],
  GOAL: [['goal-player',5000]],
  YELLOW: [['yellow-card',4000]],
  RED: [['red-card',4000]],
  SUB: [['substitution',5000]],
});
export function planPresentation({ type, cueId, programInput } = {}) {
  if (!Object.hasOwn(stages,type)) throw new Error('UNSUPPORTED_PRESENTATION');
  if (typeof cueId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(cueId)) throw new Error('INVALID_CUE_ID');
  if (typeof programInput !== 'string' || !programInput.trim() || programInput.length > 128) throw new Error('PROGRAM_INPUT_REQUIRED');
  return Object.freeze({
    cueId, type, programInput,
    steps: Object.freeze([...stages[type].map(([graphic,durationMs]) => Object.freeze({ action:'SHOW_GRAPHIC',graphic,durationMs })), Object.freeze({ action:'RETURN_PROGRAM',input:programInput })]),
  });
}
