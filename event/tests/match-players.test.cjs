const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');

function fixture(){
  const vmContext=vm.createContext({crypto:require('node:crypto').webcrypto});
  for(const file of ['players.js','match-players.js']){
    vm.runInContext(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),vmContext);
  }
  const run=code=>vm.runInContext(code,vmContext);
  run(`
    const match={id:'m1',home:0,away:1,hs:null,as:null,status:'pending'};
    const state=EventPlayers.normalize({teams:['甲队','乙队'],events:{},matches:[match]},{});
    const [seven,ten,eighteen]=[7,10,18].map(number=>EventPlayers.savePlayer(state,'team-1',{number,name:'队员'+number}));
    MatchPlayers.saveLineup(state,match,'home',[seven,ten],[eighteen],null,ten,'');
    const record=(type,player_id,related_player_id)=>MatchPlayers.record(state,match,'home',{type,player_id,related_player_id,minute:31});
  `);
  return run;
}

test('锁定名单有修改日志且拒绝破坏已有换人记录',()=>{
  const run=fixture();
  run(`record('sub',seven,eighteen)`);
  assert.throws(()=>run(`record('goal',seven)`),/不可选/);
  assert.throws(()=>run(`MatchPlayers.saveLineup(state,match,'home',[ten,eighteen],[seven],null,ten,'调整名单')`),/失效/);
  assert.throws(()=>run(`MatchPlayers.saveLineup(state,match,'home',[seven,ten],[eighteen],null,ten,'')`),/原因/);
  run(`MatchPlayers.saveLineup(state,match,'home',[seven,ten],[eighteen],seven,ten,'更正门将')`);
  assert.equal(run(`state.events.m1[1].reason`),'更正门将');
  assert.equal(run(`state.events.m1[1].after.goalkeeper===seven`),true);
});

test('点球决胜保持原比分，乌龙球计入对方且保留球员原号码',()=>{
  const run=fixture();
  run(`record('goal',ten,seven);record('shootout',ten);record('own_goal',ten);`);
  assert.equal(run(`[match.hs,match.as].join(':')`),'1:1');
  assert.equal(run(`state.events.m1[0].related_player_id===seven`),true);
  run(`EventPlayers.savePlayer(state,'team-1',{number:30,name:'队员10'},ten);EventPlayers.archivePlayer(state,'team-1',ten);`);
  assert.equal(run(`state.events.m1[0].player_id===ten`),true);
  assert.equal(run(`state.events.m1[0].player.number`),'10');
});
