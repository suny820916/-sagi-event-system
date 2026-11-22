import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createLocalDirector} from './local-director.mjs';
const root=await mkdtemp(join(tmpdir(),'sagi-local-director-'));
try {
 const graphics=Object.fromEntries(['competition','matchup','home-lineup','away-lineup','goal-player','yellow-card','red-card','substitution'].map((n,i)=>[n,'G'+i]));
 const keys=['CAM1',...Object.values(graphics)];
 let active=1,cuts=0,fail=false,entered,resume;
 const started=new Promise(r=>{entered=r;});
 const hold=new Promise(r=>{resume=r;});
 const adapter={
  health:async()=>({ok:true,body:'<vmix><inputs>'+keys.map((k,i)=>'<input key="'+k+'" number="'+(i+1)+'">'+k+'</input>').join('')+'</inputs><active>'+active+'</active></vmix>'}),
  cue:async({input})=>{cuts++;if(fail)return {ok:false};if(cuts===1){entered();await hold;}active=keys.indexOf(input)+1;return {ok:true};}
 };
 const make=()=>createLocalDirector({dataRoot:root,adapter,graphics,programKeys:['CAM1'],timing:{timeoutMs:10000}});
 const req=cueId=>({cueId,type:'GOAL',programInput:'CAM1'});
 await assert.rejects(createLocalDirector({dataRoot:'relative'}),/ABSOLUTE_DATA_ROOT_REQUIRED/);
 const a=await make(),b=await make();
 assert.deepEqual(await a.diagnostics(),{active:null,blocked:false,ownership:'absent',manualReviewRequired:false});
 const running=a.play(req('local-001'));
 await started;
 assert.equal((await a.diagnostics()).ownership,'present');
 assert.equal((await b.diagnostics()).manualReviewRequired,true);
 try {assert.equal((await b.play(req('local-002'))).status,'busy');} finally {resume();}
 assert.equal((await running).status,'completed');
 assert.equal((await (await make()).play(req('local-001'))).status,'duplicate');
 assert.equal(cuts,2);
 assert.equal((await a.diagnostics()).ownership,'absent');
 fail=true;
 assert.equal((await b.play(req('local-002'))).status,'uncertain');
 assert.equal((await (await make()).play(req('local-003'))).status,'busy');
 assert.equal(cuts,3);
 const fresh=await make();
 assert.deepEqual(await fresh.diagnostics(),{active:null,blocked:false,ownership:'present',manualReviewRequired:true});
 assert.equal((await b.diagnostics()).blocked,true);
} finally {await rm(root,{recursive:true,force:true});}
console.log('Local director durable composition PASS');
