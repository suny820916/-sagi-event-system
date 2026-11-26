const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const context = vm.createContext({crypto: require('node:crypto').webcrypto});
const source = fs.readFileSync(path.join(__dirname,'../players.js'),'utf8');
vm.runInContext(source,context);
const execute = code => vm.runInContext(code,context);

test('旧赛事迁移保留球队并创建独立身份；修改号码、退出名单不改变 player_id',()=>{
  const values=execute(`
    var data=EventPlayers.normalize({teams:['主队','客队']},{});
    var id=EventPlayers.savePlayer(data,'team-1',{name:'阿迪力',number:'08'});
    EventPlayers.savePlayer(data,'team-1',{name:'阿迪力',number:'18'},id);
    EventPlayers.archivePlayer(data,'team-1',id);
    [data.schemaVersion,data.teamIds[0],data.players[0].player_id===id,data.registrations[0].number,EventPlayers.teamRoster(data,'team-1').length].join('|')
  `);
  assert.equal(values,'2|team-1|true|18|0');
});

test('导入预览检查现有名单与同一批次，保留 CSV 原始行号',()=>{
  const values=execute(`
    var data=EventPlayers.normalize({teams:['主队','客队']},{});
    EventPlayers.savePlayer(data,'team-1',{name:'现有球员',number:'1'});
    var parsed=EventPlayers.parseDelimited('球衣号码,姓名,备注\\r\\n1,号码冲突,x\\r\\n2,现有球员,x\\r\\n3,新球员,"多个\\n行"\\r\\n3,批次冲突,x',',');
    var checks=EventPlayers.preview(data,'team-1',parsed);
    JSON.stringify({checks:checks.map(row=>[row.line,row.error||row.data.notes]),players:data.players.length})
  `);
  const {checks,players}=JSON.parse(values);
  assert.equal(players,1);
  assert.match(checks[0][1],/号码重复/);
  assert.match(checks[1][1],/已有此球员/);
  assert.deepEqual(checks.slice(2).map(x=>x[0]),[4,6]);
  assert.equal(checks[2][1],'多个\n行');
  assert.match(checks[3][1],/号码重复/);
});
