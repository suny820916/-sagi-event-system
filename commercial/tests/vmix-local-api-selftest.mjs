import assert from "node:assert/strict";
import {mkdtemp,rm} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {createLocalServer} from "../core/local-server.mjs";

const token="b".repeat(64);
const dir=await mkdtemp(path.join(os.tmpdir(),"sagi-vmix-api-"));
let app;
let online=true;
const adapter={
  async health(){
    if(!online)return {ok:false,code:"VMIX_DISCONNECTED"};
    return {ok:true,body:'<vmix><inputs><input key="cam-1" number="1" type="Capture">主机位</input><input key="cam-2" number="2" type="Capture">副机位</input></inputs><active>1</active><preview>2</preview></vmix>'};
  }
};
try{
  app=await createLocalServer({dataDir:dir,meta:{fixtureId:"vmix-readonly",home:"主队",away:"客队"},token,vmixAdapter:adapter});
  const base=`http://127.0.0.1:${app.address.port}`;
  const get=(auth)=>fetch(base+"/api/v1/vmix/status",{headers:auth?{authorization:`Bearer ${auth}`}:{}});
  assert.equal((await get()).status,401,"vMix status requires authentication");
  const good=await get(token);
  assert.equal(good.status,200);
  const body=await good.json();
  assert.equal(body.status.active,1);
  assert.equal(body.status.preview,2);
  assert.deepEqual(body.status.inputs.map(i=>i.title),["主机位","副机位"]);
  online=false;
  const down=await get(token);
  assert.equal(down.status,503);
  assert.equal((await down.json()).code,"VMIX_DISCONNECTED");
  const state=await fetch(base+"/api/v1/state",{headers:{authorization:`Bearer ${token}`}});
  assert.equal(state.status,200,"vMix failure must not block local match state");
  console.log("SAGI VMIX LOCAL API SELFTEST PASS");
}finally{if(app)await app.close();await rm(dir,{recursive:true,force:true})}
