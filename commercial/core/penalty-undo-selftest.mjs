import { createInitialMatchState, applyCommand, hydrateMatchState } from "./match-core.mjs";

let state=createInitialMatchState({fixtureId:"T",home:"H",away:"A"});
const run=(type,commandId,extra={})=>{let r=applyCommand(state,{type,commandId,...extra});state=r.state;return r};
const ok=(x)=>{if(!x)throw Error("assertion")};
const reject=(f)=>{let failed=false;try{f()}catch{failed=true}ok(failed)};
run("START_PENALTIES","start");run("PENALTY_ATTEMPT","a",{side:"HOME",outcome:"SCORED"});run("PENALTY_ATTEMPT","b",{side:"AWAY",outcome:"MISSED"});
let [first,last]=state.penalties.history;reject(()=>run("UNDO_PENALTY_ATTEMPT","wrong",{attemptId:first.attemptId}));
run("UNDO_PENALTY_ATTEMPT","u1",{attemptId:last.attemptId});ok(state.penalties.away===0&&state.penalties.history.length===1);
state=hydrateMatchState(JSON.parse(JSON.stringify(state)));ok(run("UNDO_PENALTY_ATTEMPT","u1",{attemptId:last.attemptId}).duplicate);
run("UNDO_PENALTY_ATTEMPT","u2",{attemptId:first.attemptId});ok(state.penalties.home===0&&state.homeScore===0&&state.eventLog.length===4&&state.penalties.history.length===0);
reject(()=>run("UNDO_PENALTY_ATTEMPT","again",{attemptId:first.attemptId}));run("FINISH_PENALTIES","finish");reject(()=>run("UNDO_PENALTY_ATTEMPT","late",{attemptId:first.attemptId}));console.log("penalty undo PASS");
