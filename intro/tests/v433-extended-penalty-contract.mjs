import fs from 'node:fs';
function run(source){
 const names=['mdPenaltyState','mdPenaltyStats','mdPenaltyNextSide','mdPenaltyCurrentRound','mdPenaltySuddenDeath','mdPenaltyEvaluateWinner','mdPenaltyDots','mdPenaltyStatus','mdPenaltySnapshot','mdIdentityNorm','mdConsistencyComparable'];
 const extract=n=>{const start=source.indexOf('function '+n+'(');if(start<0)throw Error('Missing '+n);const next=source.indexOf('\nfunction ',start+1);let end=next<0?source.length:next;const windowIndex=source.indexOf('\nwindow.',start+1);if(windowIndex>=0&&windowIndex<end)end=windowIndex;return source.slice(start,end)};
 const api=new Function('let matchdayState={};const q=()=>({value:"TEAM"});'+names.map(extract).join('\n')+'\nreturn {set:s=>matchdayState=s,get:()=>matchdayState,mdPenaltySnapshot,mdPenaltyEvaluateWinner,mdPenaltyDots,mdConsistencyComparable};')();
 const tests=[];const record=(name,pass,actual)=>tests.push({name,pass,actual});
 const history=Array.from({length:26},(_,i)=>({side:i%2?'AWAY':'HOME',result:i===25?'MISS':'GOAL',at:String(i)}));
 api.set({homeScore:2,awayScore:2,penaltyShootout:{sourceVersion:'V4.33',started:true,visible:true,rounds:5,firstSide:'HOME',history}});
 api.mdPenaltyEvaluateWinner();const snap=api.mdPenaltySnapshot();
 record('26-kick snapshot lossless',snap.history.length===26,snap.history.length);
 api.set({homeScore:2,awayScore:2,penaltyShootout:JSON.parse(JSON.stringify(snap))});
 record('winner survives snapshot restore',api.mdPenaltyEvaluateWinner()==='HOME',api.get().penaltyShootout.winner);
 api.set({penaltyShootout:{sourceVersion:'V4.33',started:true,rounds:5,history}});
 record('latest away miss appears in director dots',api.mdPenaltyDots('AWAY').includes('penDot miss'),api.mdPenaltyDots('AWAY'));
 const a={penaltyShootout:{started:true,rounds:5,firstSide:'HOME',history:[{side:'HOME',result:'GOAL'},{side:'AWAY',result:'MISS'}]}};
 const b={penaltyShootout:{started:true,rounds:5,firstSide:'HOME',history:[{side:'HOME',result:'MISS'},{side:'AWAY',result:'GOAL'}]}};
 record('same-revision kick sequence mismatch detectable',api.mdConsistencyComparable(a)!==api.mdConsistencyComparable(b),'comparison');
 record('first kicker and round config mismatch detectable',api.mdConsistencyComparable(a)!==api.mdConsistencyComparable({...a,penaltyShootout:{...a.penaltyShootout,rounds:3,firstSide:'AWAY'}}),'comparison');
 return tests;
}
const results=run(fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8'));
console.log(JSON.stringify(results,null,2));
if(results.some(x=>!x.pass))process.exitCode=1;
