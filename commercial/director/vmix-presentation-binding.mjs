import {parseVMixStatus} from '../core/vmix-status.mjs';
import {createPresentationOutput} from './presentation-output.mjs';
import {setTimeout as delay} from 'node:timers/promises';

// Explicit keys only; never infer a graphic from its editable title or number.
export function bindVMixPresentation({adapter,graphics,programKeys,...timing}={}) {
  if(typeof adapter?.health!=='function'||typeof adapter?.cue!=='function') throw Error('VMIX_ADAPTER_REQUIRED');
  const keys=[...Object.values(graphics??{}),...programKeys];
  async function snapshot(signal) {
    signal?.throwIfAborted();
    const result=await adapter.health({signal});
    signal?.throwIfAborted();
    if(!result.ok) throw Error('VMIX_STATUS_UNAVAILABLE');
    const status=parseVMixStatus(result.body);
    const numbers=status.inputs.map(i=>i.number);
    if(new Set(numbers).size!==numbers.length) throw Error('AMBIGUOUS_INPUT_NUMBERS');
    if(!keys.every(key=>status.inputs.some(i=>i.key===key))) throw Error('VMIX_MAPPING_MISSING');
    const active=status.inputs.find(i=>i.number===status.active);
    if(!active) throw Error('VMIX_ACTIVE_UNKNOWN');
    return active.key;
  }
  return createPresentationOutput({...timing,graphics,programKeys,
    sleep:timing.sleep??((ms,{signal}={})=>delay(ms,undefined,{signal})),
    readActiveKey:({signal}={})=>snapshot(signal),
    cut:async(key,{signal}={})=>{
      await snapshot(signal);
      signal?.throwIfAborted();
      const result=await adapter.cue({functionName:'Cut',input:key},{signal});
      signal?.throwIfAborted();
      return result.ok===true;
    }
  });
}
