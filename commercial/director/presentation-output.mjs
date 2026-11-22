// Full-screen input presentation adapter. Inject existing bounded vMix transport.
// A successful HTTP command is insufficient; require active-input readback.
export function createPresentationOutput({ cut, readActiveKey, graphics, programKeys, timeoutMs=2000, pollMs=100, now=()=>performance.now(), sleep } = {}) {
  if (typeof cut !== 'function' || typeof readActiveKey !== 'function' || typeof sleep !== 'function') throw Error('TRANSPORT_REQUIRED');
  if (!Number.isFinite(timeoutMs) || timeoutMs>30000 || timeoutMs<=0 || !Number.isFinite(pollMs) || pollMs<=0 || pollMs>timeoutMs) throw Error('INVALID_TIMEOUT');
  const valid = key => typeof key==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(key);
  const names=['competition','matchup','home-lineup','away-lineup','goal-player','yellow-card','red-card','substitution'];
  const map=new Map(names.map(name=>[name,graphics?.[name]]));
  const programs=new Set(programKeys);
  if (![...map.values(),...programs].every(valid) || !programs.size || [...map.values()].some(k=>programs.has(k)) || new Set(map.values()).size!==map.size) throw Error('INVALID_INPUT_MAPPING');
  async function switchTo(key,{signal,expectedActive}={}) {
    signal?.throwIfAborted();
    const deadline=now()+timeoutMs;
    const deadlineSignal=AbortSignal.timeout(Math.max(1, Math.ceil(timeoutMs)));
    signal=signal ? AbortSignal.any([signal,deadlineSignal]) : deadlineSignal;
    // Transport must honor the signal and its own bounded request timeout.
    const previous = map.get(expectedActive) ?? expectedActive;
    if (previous !== undefined) {
      if (!programs.has(previous) && ![...map.values()].includes(previous)) throw Error('PREVIOUS_INPUT_NOT_ALLOWED');
      if (await readActiveKey({signal}) !== previous) return false;
    }
    signal?.throwIfAborted();
    if(now()>=deadline) return false;
    if (await cut(key,{signal,expectedActive:previous})!==true) return false;
    for(let i=0;i<=Math.ceil(timeoutMs/pollMs);i++) {
      signal?.throwIfAborted();
      if(now()>=deadline) return false;
      const active=await readActiveKey({signal});
      signal?.throwIfAborted();
      if(now()>=deadline) return false;
      if(active===key) return true;
      await sleep(pollMs,{signal});
    }
    return false;
  }
  return Object.freeze({
    showGraphic(name,options) { if(!map.has(name)) throw Error('UNKNOWN_GRAPHIC'); return switchTo(map.get(name),options); },
    returnProgram(key,options) { if(!programs.has(key)) throw Error('PROGRAM_NOT_ALLOWED'); return switchTo(key,options); }
  });
}
