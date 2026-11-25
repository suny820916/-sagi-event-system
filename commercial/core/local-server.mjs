import http from "node:http";
import { mkdir, rmdir } from "node:fs/promises";
import path from "node:path";
import { randomBytes, timingSafeEqual } from "node:crypto";
import { applyCommand, createInitialMatchState, hydrateMatchState } from "./match-core.mjs";
import { createMatchClock } from "./match-clock.mjs";
import { FileMatchStore } from "./file-store.mjs";
import { serveBroadcastOutput } from "../director/broadcast-output.mjs";
import { readVMixStatus } from "./vmix-status.mjs";

const safeEqual=(a,b)=>{const x=Buffer.from(String(a??"")),y=Buffer.from(String(b??""));return x.length===y.length&&timingSafeEqual(x,y)};
function send(res,status,data){const body=JSON.stringify(data);res.writeHead(status,{"content-type":"application/json; charset=utf-8","cache-control":"no-store","x-content-type-options":"nosniff"});res.end(body)}
async function readJson(req){let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>65536)throw new Error("PAYLOAD_TOO_LARGE");chunks.push(chunk)}const data=JSON.parse(Buffer.concat(chunks).toString("utf8"));if(!data||typeof data!=="object"||Array.isArray(data))throw new Error("INVALID_BODY");return data}

/** Local-first authoritative match API. Bind loopback unless LAN is explicitly configured. */
export async function createLocalServer({dataDir,meta,host="127.0.0.1",port=0,token=randomBytes(32).toString("hex"),vmixAdapter=null,broadcastRoute,clockNow,checkpointIntervalMs=15000,store=dataDir?new FileMatchStore(dataDir):null}={}){
  if(!store)throw new Error("STORE_REQUIRED");
  if(typeof token!=="string"||token.length<32)throw new Error("WEAK_TOKEN");
  if(!Number.isSafeInteger(checkpointIntervalMs)||checkpointIntervalMs<0)throw new Error("INVALID_CHECKPOINT_INTERVAL");
  await store.init();
  const ownership = path.join(store.rootDir, "match-engine.lock");
  try { await mkdir(ownership); } catch (error) {
    if (error.code === "EEXIST") throw new Error("ENGINE_ALREADY_RUNNING_OR_RECOVERY_REQUIRED");
    throw error;
  }
  try {
  let state;
  try{state=await store.load()}catch(error){if(error.code!=="ENOENT")throw error;state=createInitialMatchState(meta)}
  state=hydrateMatchState(state);
  const clock=createMatchClock(state.clock, clockNow ? {now:clockNow} : {});
  const liveState=()=>{const {recoveryPending,...currentClock}=clock.read();return {...state,clock:currentClock,clockRecoveryPending:recoveryPending}};
  let queue=Promise.resolve();
  let checkpointWarning=null;
  let checkpointPending=false;
  const checkpoint=()=>{
    if(checkpointPending)return queue;
    checkpointPending=true;
    const work=queue.then(async()=>{
      const current=liveState();
      if(store.journalError || !current.clock.running || current.clock.elapsedSeconds<=state.clock.elapsedSeconds)return;
      delete current.clockRecoveryPending;
      await store.checkpointClock(current);
      state=current;
      checkpointWarning=null;
    });
    queue=work.catch(()=>{checkpointWarning="CLOCK_CHECKPOINT_FAILED"}).finally(()=>{checkpointPending=false});
    return queue;
  };
  const server=http.createServer(async(req,res)=>{
    if (serveBroadcastOutput(req,res,broadcastRoute,liveState)) return;
    const pathname=new URL(req.url??"/","http://localhost").pathname;
    if(pathname==="/health"&&req.method==="GET")return send(res,store.journalError?503:200,{ok:!store.journalError,service:"sagi-local-engine",revision:state.revision,recoveryRequired:!!store.journalError});
    if(!safeEqual(req.headers.authorization,`Bearer ${token}`))return send(res,401,{error:"UNAUTHORIZED"});
    if(pathname==="/api/v1/diagnostics"&&req.method==="GET")return send(res,200,{revision:state.revision,recoveryRequired:!!store.journalError,journalWarning:store.journalError?"JOURNAL_RESTART_REQUIRED":null,clockCheckpointWarning:checkpointWarning,snapshotWarning:store.snapshotError?"SNAPSHOT_FAILED":null});
    if(pathname==="/api/v1/state"&&req.method==="GET")return send(res,200,{state:liveState()});
    if(pathname==="/api/v1/vmix/status"&&req.method==="GET"){
      if(!vmixAdapter)return send(res,503,{ok:false,code:"VMIX_NOT_CONFIGURED"});
      try{
        const result=await readVMixStatus(vmixAdapter);
        return send(res,result.ok?200:503,result);
      }catch{return send(res,503,{ok:false,code:"VMIX_UNAVAILABLE"})}
    }
    if(pathname==="/api/v1/commands"&&req.method==="POST"){
      let command;
      try{command=await readJson(req)}catch(error){return send(res,400,{error:error.message})}
      const work=queue.then(async()=>{
        if(store.journalError)return{status:503,body:{error:"JOURNAL_RESTART_REQUIRED"}};
        if(command.fixtureId!==undefined&&command.fixtureId!==state.fixtureId)return{status:409,body:{error:"FIXTURE_MISMATCH",revision:state.revision}};
        if(command.expectedRevision!==undefined&&command.expectedRevision!==state.revision&&!state.processedCommandIds.includes(String(command.commandId)))return{status:409,body:{error:"REVISION_CONFLICT",revision:state.revision}};
        const before=liveState();
        const result=applyCommand(before,command);
        if(!result.duplicate){
          const type=String(command.type).trim().toUpperCase();
          const explicitClock=type==="SET_CLOCK" || type==="SET_CLOCK_RUNNING" || result.state.clock.running!==before.clock.running || ["SET_PERIOD","HALF_TIME","FULL_TIME","START_PENALTIES","PENALTY_ATTEMPT","FINISH_PENALTIES"].includes(type);
          delete result.state.clockRecoveryPending;
          if(before.clockRecoveryPending && !explicitClock)result.state.clock.running=true;
          await store.commit(result.state,result.event);
          state=result.state;
          if(explicitClock)clock.set(state.clock);
        }
        return{status:200,body:{duplicate:result.duplicate,event:result.event,state:liveState()}}
      });
      queue=work.catch(()=>{});
      try{const result=await work;return send(res,result.status,result.body)}catch(error){if(error.message==="COMMAND_ID_CONFLICT")return send(res,409,{error:"COMMAND_ID_CONFLICT"});const bad=error.message==="MATCH_ALREADY_FINISHED"||/^(INVALID_|UNSUPPORTED_COMMAND)/.test(error.message);return send(res,bad?400:503,{error:bad?error.message:"STORE_UNAVAILABLE"})}
    }
    return send(res,404,{error:"NOT_FOUND"})
  });
  await new Promise((resolve,reject)=>{server.once("error",reject);server.listen(port,host,resolve)});
  const timer=checkpointIntervalMs ? setInterval(checkpoint,checkpointIntervalMs) : null;
  timer?.unref();
  let closing;
  return {server,token,address:server.address(),close:()=>closing ??= (async()=>{
    if(timer)clearInterval(timer);
    await new Promise((resolve,reject)=>server.close(err=>err?reject(err):resolve()));
    await queue;
    await checkpoint();
    await rmdir(ownership);
  })()};
  } catch (error) {
    await rmdir(ownership).catch(()=>{});
    throw error;
  }
}
