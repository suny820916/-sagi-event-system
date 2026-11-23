import { createInitialMatchState, applyCommand, hydrateMatchState, consistencyView } from "./match-core.mjs";

let state=createInitialMatchState({fixtureId:"T",home:"H",away:"A"});
const run=(type,commandId,extra={})=>{let r=applyCommand(state,{type,commandId,...extra});state=r.state;return r};
const ok=(x)=>{if(!x)throw Error("assertion")};
const reject=(f)=>{let failed=false;try{f()}catch{failed=true}ok(failed)};
run("START_PENALTIES","start");run("PENALTY_ATTEMPT","a",{side:"HOME",outcome:"SCORED"});run("PENALTY_ATTEMPT","b",{side:"AWAY",outcome:"MISSED"});
const divergent=hydrateMatchState(state); divergent.penalties.history.reverse(); ok(consistencyView(divergent)!==consistencyView(state));
const wrongOutcome=hydrateMatchState(state); wrongOutcome.penalties.history[0].outcome="MISSED"; ok(consistencyView(wrongOutcome)!==consistencyView(state));
let [first,last]=state.penalties.history;reject(()=>run("UNDO_PENALTY_ATTEMPT","wrong",{attemptId:first.attemptId}));
run("UNDO_PENALTY_ATTEMPT","u1",{attemptId:last.attemptId});ok(state.penalties.away===0&&state.penalties.history.length===1);
state=hydrateMatchState(JSON.parse(JSON.stringify(state)));ok(run("UNDO_PENALTY_ATTEMPT","u1",{attemptId:last.attemptId}).duplicate);
run("UNDO_PENALTY_ATTEMPT","u2",{attemptId:first.attemptId});ok(state.penalties.home===0&&state.homeScore===0&&state.eventLog.length===4&&state.penalties.history.length===0);
reject(()=>run("UNDO_PENALTY_ATTEMPT","again",{attemptId:first.attemptId}));run("FINISH_PENALTIES","finish");reject(()=>run("UNDO_PENALTY_ATTEMPT","late",{attemptId:first.attemptId}));const finishedRevision=state.revision;
for(const type of ["GOAL","YELLOW","RED","SUB","HALF_TIME","FULL_TIME"]){
  reject(()=>run(type,"late_"+type,{side:"HOME"}));
  ok(state.revision===finishedRevision);
}
// Final-state mutation boundary: administrative commands must not reopen or alter a finished match.
for (const [type, extra] of [
  ["SCORE_ADJUST", {side:"HOME",delta:1}],
  ["SET_PERIOD", {period:"2H"}],
  ["SET_CLOCK", {running:true,elapsedSeconds:60}],
  ["SET_CLOCK_RUNNING", {running:true}],
  ["START_PENALTIES", {}],
  ["PENALTY_ATTEMPT", {side:"HOME",outcome:"SCORED"}],
  ["FINISH_PENALTIES", {}],
]) {
  const before=consistencyView(state);
  reject(()=>run(type,"final_guard_"+type,extra));
  ok(consistencyView(state)===before);
}
// A delayed retry of an already accepted command stays a duplicate, even at FT.
ok(run("FINISH_PENALTIES","finish").duplicate);
// Presentation controls remain possible after FT.
run("SET_SCOREBOARD","post_match_board",{visible:true});
ok(state.period==="FT"&&state.scoreboardVisible);
ok(run("MVP","post_match_mvp",{player:{id:"7",name:"球员",number:"7"}}).state.period==="FT");
console.log("penalty undo PASS");
