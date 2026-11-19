import http from "node:http";
import { randomBytes, timingSafeEqual } from "node:crypto";
import { applyCommand, createInitialMatchState, hydrateMatchState } from "./match-core.mjs";
import { FileMatchStore } from "./file-store.mjs";

const safeEqual=(a,b)=>{const x=Buffer.from(String(a??"")),y=Buffer.from(String(b??""));return x.length===y.length&&timingSafeEqual(x,y)};
function send(res,status,data){const body=JSON.stringify(data);res.writeHead(status,{"content-type":"application/json; charset=utf-8","cache-control":"no-store","x-content-type-options":"nosniff"});res.end(body)}
async function readJson(req){let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>65536)throw new Error("PAYLOAD_TOO_LARGE");chunks.push(chunk)}const data=JSON.parse(Buffer.concat(chunks).toString("utf8"));if(!data||typeof data!=="object"||Array.isArray(data))throw new Error("INVALID_BODY");return data}

/** Local-first authoritative match API. Bind loopback unless LAN is explicitly configured. */
export async function createLocalServer({dataDir,meta,host="127.0.0.1",port=0,token=randomBytes(32).toString("hex"),store=dataDir?new FileMatchStore(dataDir):null}={}){
  if(!store)throw new Error("STORE_REQUIRED");
  if(typeof token!=="string"||token.length<32)throw new Error("WEAK_TOKEN");
  await store.init();
  let state;
  try{state=await store.load()}catch(error){if(error.code!=="ENOENT")throw error;state=createInitialMatchState(meta)}
  state=hydrateMatchState(state);
  let queue=Promise.resolve();
  const server=http.createServer(async(req,res)=>{
    const pathname=new URL(req.url??"/","http://localhost").pathname;
    if(pathname==="/health"&&req.method==="GET")return send(res,200,{ok:true,service:"sagi-local-engine",revision:state.revision});
    if(!safeEqual(req.headers.authorization,`Bearer ${token}`))return send(res,401,{error:"UNAUTHORIZED"});
    if(pathname==="/api/v1/state"&&req.method==="GET")return send(res,200,{state});
    if(pathname==="/api/v1/commands"&&req.method==="POST"){
      let command;
      try{command=await readJson(req)}catch(error){return send(res,400,{error:error.message})}
      const work=queue.then(async()=>{
        if(command.expectedRevision!==undefined&&command.expectedRevision!==state.revision&&!state.processedCommandIds.includes(String(command.commandId)))return{status:409,body:{error:"REVISION_CONFLICT",revision:state.revision}};
        const result=applyCommand(state,command);
        if(!result.duplicate){await store.commit(result.state,result.event);state=result.state}
        return{status:200,body:{duplicate:result.duplicate,event:result.event,state}}
      });
      queue=work.catch(()=>{});
      try{const result=await work;return send(res,result.status,result.body)}catch(error){const bad=/^(INVALID_|UNSUPPORTED_COMMAND)/.test(error.message);return send(res,bad?400:503,{error:bad?error.message:"STORE_UNAVAILABLE"})}
    }
    return send(res,404,{error:"NOT_FOUND"})
  });
  await new Promise((resolve,reject)=>{server.once("error",reject);server.listen(port,host,resolve)});
  return{server,token,address:server.address(),close:()=>new Promise((resolve,reject)=>server.close(err=>err?reject(err):resolve()))}
}
