/**
 * Read-only vMix XML status snapshot. No third-party runtime dependencies.
 * XML is treated as untrusted input; parsing is deliberately narrow and bounded.
 * Acknowledged API commands are NOT proof of on-air state.
 */
function decodeXml(value) {
  return String(value).replace(/&(#x[0-9a-f]+|#[0-9]+|amp|lt|gt|quot|apos);/gi, (match, code) => {
    const named={amp:"&",lt:"<",gt:">",quot:'"',apos:"'"};
    if (named[code]) return named[code];
    if (code[0]!=="#") return match;
    const n=code[1]?.toLowerCase()==="x"?parseInt(code.slice(2),16):parseInt(code.slice(1),10);
    return Number.isInteger(n)&&n>0&&n<=0x10ffff&&!(n>=0xd800&&n<=0xdfff)?String.fromCodePoint(n):"";
  });
}
function attributes(tag) {
  const result={};
  for (const match of tag.matchAll(/([a-zA-Z][\w-]*)\s*=\s*(["'])(.*?)\2/g)) result[match[1]]=decodeXml(match[3]);
  return result;
}
function textOf(xml,tag) {
  const m=xml.match(new RegExp("<"+tag+"(?:\\s[^>]*)?>([^<]*)</"+tag+">","i"));
  return m?decodeXml(m[1].trim()):null;
}
export function parseVMixStatus(xml) {
  if(typeof xml!=="string"||xml.length>2_000_000||!/<vmix(?:\s|>)/i.test(xml)) throw new Error("INVALID_VMIX_STATUS");
  const inputs=[];
  const seen=new Set();
  const block=xml.match(/<inputs(?:\s[^>]*)?>([\s\S]*?)<\/inputs>/i)?.[1]??"";
  for(const m of block.matchAll(/<input\b([^>]*?)(?:\/>|>([\s\S]*?)<\/input>)/gi)){
    const attrs=attributes(m[1]);
    const key=String(attrs.key??"").trim(),number=Number(attrs.number);
    if(!key||!Number.isInteger(number)||number<1||seen.has(key)) continue;
    seen.add(key);
    inputs.push({key,number,title:decodeXml((m[2]??"").replace(/<[^>]*>/g,"").trim()).slice(0,256),type:String(attrs.type??""),state:String(attrs.state??"")});
    if(inputs.length>=500) break;
  }
  const active=Number(textOf(xml,"active"));
  const preview=Number(textOf(xml,"preview"));
  return {active:Number.isInteger(active)&&active>0?active:null,preview:Number.isInteger(preview)&&preview>0?preview:null,inputs};
}
export async function readVMixStatus(adapter) {
  const result=await adapter.health();
  if(!result.ok)return result;
  try{return {ok:true,code:"VMIX_STATUS_READ",status:parseVMixStatus(result.body)}}
  catch{return {ok:false,code:"VMIX_INVALID_XML"}}
}
