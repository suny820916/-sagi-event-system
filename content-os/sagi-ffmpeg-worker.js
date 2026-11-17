/* SAGI FFmpeg Worker V4.0.2
 * Same-origin module worker for iPhone/Safari.
 * Avoids ffmpeg.wasm bundled worker resolving blob URLs as webpack module ids.
 */
const CORE_URL="https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd/ffmpeg-core.js";
const T={
  LOAD:"LOAD",EXEC:"EXEC",FFPROBE:"FFPROBE",WRITE_FILE:"WRITE_FILE",READ_FILE:"READ_FILE",
  DELETE_FILE:"DELETE_FILE",RENAME:"RENAME",CREATE_DIR:"CREATE_DIR",LIST_DIR:"LIST_DIR",
  DELETE_DIR:"DELETE_DIR",ERROR:"ERROR",PROGRESS:"PROGRESS",LOG:"LOG",MOUNT:"MOUNT",UNMOUNT:"UNMOUNT"
};
let ffmpeg;

async function loadCore({coreURL:_coreURL,wasmURL:_wasmURL,workerURL:_workerURL}={}){
  const first=!ffmpeg;
  if(!_coreURL)_coreURL=CORE_URL;
  try{
    importScripts(_coreURL);
  }catch(e){
    if(!_coreURL||_coreURL===CORE_URL)_coreURL=CORE_URL.replace("/umd/","/esm/");
    const mod=await import(_coreURL);
    self.createFFmpegCore=mod&&mod.default;
    if(!self.createFFmpegCore)throw new Error("failed to import ffmpeg-core.js");
  }
  const coreURL=_coreURL;
  const wasmURL=_wasmURL||_coreURL.replace(/\.js$/,".wasm");
  const workerURL=_workerURL||_coreURL.replace(/\.js$/,".worker.js");
  ffmpeg=await self.createFFmpegCore({
    mainScriptUrlOrBlob:coreURL+"#"+btoa(JSON.stringify({wasmURL,workerURL}))
  });
  ffmpeg.setLogger(data=>self.postMessage({type:T.LOG,data}));
  ffmpeg.setProgress(data=>self.postMessage({type:T.PROGRESS,data}));
  return first;
}
function exec(data){ffmpeg.setTimeout(data.timeout??-1);ffmpeg.exec(...(data.args||[]));const ret=ffmpeg.ret;ffmpeg.reset();return ret}
function ffprobe(data){ffmpeg.setTimeout(data.timeout??-1);ffmpeg.ffprobe(...(data.args||[]));const ret=ffmpeg.ret;ffmpeg.reset();return ret}
function writeFile({path,data}){ffmpeg.FS.writeFile(path,data);return true}
function readFile({path,encoding}){return ffmpeg.FS.readFile(path,{encoding})}
function deleteFile({path}){ffmpeg.FS.unlink(path);return true}
function rename({oldPath,newPath}){ffmpeg.FS.rename(oldPath,newPath);return true}
function createDir({path}){ffmpeg.FS.mkdir(path);return true}
function listDir({path}){return ffmpeg.FS.readdir(path).map(name=>{const stat=ffmpeg.FS.stat(path+"/"+name);return{name,isDir:ffmpeg.FS.isDir(stat.mode)}})}
function deleteDir({path}){ffmpeg.FS.rmdir(path);return true}
function mount({fsType,options,mountPoint}){const fs=ffmpeg.FS.filesystems[fsType];if(!fs)return false;ffmpeg.FS.mount(fs,options,mountPoint);return true}
function unmount({mountPoint}){ffmpeg.FS.unmount(mountPoint);return true}

self.onmessage=async({data:{id,type,data}})=>{
  const trans=[];
  let out;
  try{
    if(type!==T.LOAD&&!ffmpeg)throw new Error("ffmpeg is not loaded");
    switch(type){
      case T.LOAD:out=await loadCore(data);break;
      case T.EXEC:out=exec(data);break;
      case T.FFPROBE:out=ffprobe(data);break;
      case T.WRITE_FILE:out=writeFile(data);break;
      case T.READ_FILE:out=readFile(data);break;
      case T.DELETE_FILE:out=deleteFile(data);break;
      case T.RENAME:out=rename(data);break;
      case T.CREATE_DIR:out=createDir(data);break;
      case T.LIST_DIR:out=listDir(data);break;
      case T.DELETE_DIR:out=deleteDir(data);break;
      case T.MOUNT:out=mount(data);break;
      case T.UNMOUNT:out=unmount(data);break;
      default:throw new Error("unknown message type: "+type);
    }
  }catch(e){
    self.postMessage({id,type:T.ERROR,data:String(e&&e.message?e.message:e)});
    return;
  }
  if(out instanceof Uint8Array)trans.push(out.buffer);
  self.postMessage({id,type,data:out},trans);
};
