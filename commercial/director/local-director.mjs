import { mkdir, realpath, lstat } from 'node:fs/promises';
import { resolve, join, isAbsolute } from 'node:path';
import { DirectorOwnership } from './director-ownership.mjs';
import { FileCueClaims } from './file-cue-claims.mjs';
import { PresentationExecutor } from './presentation-executor.mjs';
import { bindVMixPresentation } from './vmix-presentation-binding.mjs';

// One protected local data root per vMix endpoint, supplied by trusted desktop shell.
// Never choose a new root to bypass a recovery latch.
export async function createLocalDirector({dataRoot, adapter, graphics, programKeys, timing={}}={}) {
  if(typeof dataRoot!=='string'||!isAbsolute(dataRoot)) throw Error('ABSOLUTE_DATA_ROOT_REQUIRED');
  const output=bindVMixPresentation({...timing,adapter,graphics,programKeys});
  await mkdir(resolve(dataRoot),{recursive:true,mode:0o700});
  const root=await realpath(resolve(dataRoot));
  const lockPath=join(root,'director-output.lock');
  const executor=new PresentationExecutor({
    ...output,
    ownership:new DirectorOwnership(lockPath),
    cueClaims:new FileCueClaims(join(root,'director-cues'))
  });
  // No public recovery/reset method: reconcile vMix and stop all owners first.
  return Object.freeze({
    play:request=>executor.play(request),
    cancel:()=>executor.cancel(),
    get status(){return executor.status;},
    async diagnostics(){
      let ownership='present';
      try { await lstat(lockPath); }
      catch(error){ ownership=error.code==='ENOENT'?'absent':'unknown'; }
      const {active,blocked}=executor.status;
      return {active,blocked,ownership,manualReviewRequired:blocked||ownership==='unknown'||(!active&&ownership==='present')};
    }
  });
}
