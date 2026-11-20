/**
 * vMix HTTP API adapter. No cloud dependency.
 * Intentionally does NOT retry potentially non-idempotent vMix actions.
 * Adapter acknowledgements are not proof that vMix visually completed a cue.
 */
const ALLOWED = new Set(["Cut", "Fade", "OverlayInput1In", "OverlayInput1Out", "OverlayInput2In", "OverlayInput2Out", "StartRecording", "StopRecording"]);
const INPUT_REQUIRED = new Set(["Cut", "Fade", "OverlayInput1In", "OverlayInput2In"]);
function assertInput(value) {
  const input = String(value ?? "").trim();
  if (!input || input.length > 128 || /[\u0000-\u001f]/.test(input)) throw new Error("INVALID_VMIX_INPUT");
  return input;
}
export class VMixAdapter {
  constructor({host="127.0.0.1",port=8088,fetchImpl=fetch,timeoutMs=1500}={}) {
    if (!["127.0.0.1","localhost","::1"].includes(host) && !/^(?:\d{1,3}\.){3}\d{1,3}$/.test(host)) throw new Error("INVALID_VMIX_HOST");
    if (!Number.isInteger(port)||port<1||port>65535) throw new Error("INVALID_VMIX_PORT");
    if (!Number.isInteger(timeoutMs)||timeoutMs<100||timeoutMs>30000) throw new Error("INVALID_TIMEOUT");
    this.base = `http://${host.includes(":")?"["+host+"]":host}:${port}/api/`;
    this.fetchImpl=fetchImpl;
    this.timeoutMs=timeoutMs;
  }
  async request(params) {
    const url=new URL(this.base);
    for(const [k,v] of Object.entries(params)) url.searchParams.set(k,String(v));
    try {
      const response=await this.fetchImpl(url,{signal:AbortSignal.timeout(this.timeoutMs),cache:"no-store"});
      if(!response.ok) return {ok:false,code:"VMIX_HTTP_ERROR",status:response.status};
      return {ok:true,code:"VMIX_ACCEPTED",body:await response.text()};
    } catch(error) {
      return {ok:false,code:error?.name==="TimeoutError"?"VMIX_TIMEOUT":"VMIX_DISCONNECTED"};
    }
  }
  async health() {return this.request({});}
  async cue({functionName,input,duration}={}) {
    if(!ALLOWED.has(functionName)) throw new Error("INVALID_VMIX_FUNCTION");
    const params={Function:functionName};
    if(INPUT_REQUIRED.has(functionName)) params.Input=assertInput(input);
    if(functionName==="Fade") {
      if(!Number.isInteger(duration)||duration<0||duration>10000) throw new Error("INVALID_FADE_DURATION");
      params.Duration=duration;
    }
    const result=await this.request(params);
    return {...result,functionName};
  }
}
