import assert from "node:assert/strict";
import {VMixAdapter} from "../core/vmix-adapter.mjs";
const calls=[];
const adapter=new VMixAdapter({fetchImpl:async(url)=>{calls.push(String(url));return {ok:true,status:200,text:async()=>"<vmix/>"}}});
assert.equal((await adapter.health()).ok,true);
assert.equal((await adapter.cue({functionName:"Cut",input:"Camera 1"})).ok,true);
assert.match(calls.at(-1),/Function=Cut/);
assert.match(calls.at(-1),/Input=Camera\+1/);
assert.equal((await adapter.cue({functionName:"Fade",input:"Camera 2",duration:250})).ok,true);
assert.match(calls.at(-1),/Duration=250/);
const count=calls.length;
for(const cue of [{functionName:"ScriptStart"},{functionName:"Cut",input:""},{functionName:"Fade",input:"1",duration:-1}]) {
  await assert.rejects(()=>adapter.cue(cue));
}
assert.equal(calls.length,count,"Invalid requests must never reach vMix");
let attempts=0;
const offline=new VMixAdapter({fetchImpl:async()=>{attempts++;throw new Error("offline")}});
assert.equal((await offline.cue({functionName:"Cut",input:"1"})).code,"VMIX_DISCONNECTED");
assert.equal(attempts,1,"Unsafe vMix commands must not be automatically retried");
const httpError=new VMixAdapter({fetchImpl:async()=>({ok:false,status:503})});
assert.equal((await httpError.cue({functionName:"Cut",input:"1"})).code,"VMIX_HTTP_ERROR");
console.log("SAGI VMIX ADAPTER SELFTEST PASS");
