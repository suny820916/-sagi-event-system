import {parseVMixStatus} from '../core/vmix-status.mjs';
import {createPresentationOutput} from './presentation-output.mjs';
import {setTimeout as delay} from 'node:timers/promises';

// Explicit keys only; never infer a graphic from its editable title or number.
export function bindVMixPresentation({adapter,graphics,programKeys,...timing}={}) {
  if(typeof adapter?.health!=='function'||typeof adapter?.cue!=='function') throw Error('VMIX_ADAPTER_REQUIRED');
  if (!Array.isArray(programKeys)) throw Error('INVALID_PROGRAM_KEYS');
  // Snapshot configuration once; caller mutations cannot alter validated mappings.
  graphics=Object.freeze({...graphics});
  programKeys=Object.freeze([...programKeys]);
  const keys=[...Object.values(graphics),...programKeys];
  async function snapshot(signal) {
    signal?.throwIfAborted();
    const result=await adapter.health({signal});
    signal?.throwIfAborted();
    if(!result.ok) throw Error('VMIX_STATUS_UNAVAILABLE');
    const status=parseVMixStatus(result.body);
    const numbers=status.inputs.map(i=>i.number);
    const inputKeys=status.inputs.map(i=>i.key);
    if(new Set(inputKeys).size!==inputKeys.length) throw Error('AMBIGUOUS_INPUT_KEYS');
    if(new Set(numbers).size!==numbers.length) throw Error('AMBIGUOUS_INPUT_NUMBERS');
    if(!keys.every(key=>status.inputs.some(i=>i.key===key))) throw Error('VMIX_MAPPING_MISSING');
    const active=status.inputs.find(i=>i.number===status.active);
    if(!active) throw Error('VMIX_ACTIVE_UNKNOWN');
    return active.key;
  }
  return createPresentationOutput({...timing,graphics,programKeys,
    sleep:timing.sleep??((ms,{signal}={})=>delay(ms,undefined,{signal})),
    readActiveKey:({signal}={})=>snapshot(signal),
    cut:async(key,{signal,expectedActive}={})=>{
      const active = await snapshot(signal);
      if(expectedActive !== undefined && active !== expectedActive) return false;
      signal?.throwIfAborted();
      const result=await adapter.cue({functionName:'Cut',input:key},{signal});
      signal?.throwIfAborted();
      return result.ok===true;
    }
  });
}
