'use strict';

const EventPlayers = (() => {
  const positions = ['门将', '后卫', '中场', '前锋', '其他'];
  const feet = ['左脚', '右脚', '双脚'];
  const eligibility = ['待审核', '已核验', '不合格'];
  const headers = ['球衣号码','姓名','位置','是否门将','是否队长','出生年份','惯用脚','资格状态','是否可参赛','备注'];
  const imagePattern = /^data:image\/(?:png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/;
  const text = value => String(value ?? '').trim();
  const copy = value => JSON.parse(JSON.stringify(value));
  const uid = kind => kind+'-'+(globalThis.crypto?.randomUUID?.()||Date.now().toString(36)+'-'+Math.random().toString(36).slice(2));
  const safeId = (id,kind) => typeof id==='string'&&new RegExp('^'+kind+'-[a-z0-9-]+$','i').test(id);
  const list = (value, field) => {
    if (value == null) return [];
    if (!Array.isArray(value)) throw new Error(field+'格式无效');
    return value;
  };
  function ids(raw, length){
    if(raw==null)return Array.from({length},(_,i)=>'team-'+(i+1));
    if(!Array.isArray(raw)||raw.length!==length||new Set(raw).size!==length||raw.some(id=>!safeId(id,'team')))throw new Error('球队身份数据无效');
    return raw.slice();
  }
  function formatPlayer(input){
    const name=text(input.name), number=text(input.number), birth=text(input.birthYear);
    const position=text(input.position)||'其他', foot=text(input.foot);
    const status=text(input.eligibility)||'待审核';
    if(!name||name.length>60)throw new Error('请填写 1–60 字的姓名');
    if(!/^\d{1,3}$/.test(number))throw new Error('球衣号码须为 0–999 的整数');
    if(birth&&(!/^\d{4}$/.test(birth)||Number(birth)<1900||Number(birth)>new Date().getFullYear()))throw new Error('出生年份无效');
    if(!positions.includes(position)||!eligibility.includes(status)||(foot&&!feet.includes(foot)))throw new Error('位置、惯用脚或资格状态无效');
    return {name,number:String(Number(number)),position,birthYear:birth?Number(birth):null,foot,
      notes:text(input.notes).slice(0,300),photo:imagePattern.test(input.photo||'')&&input.photo.length<=180000?input.photo:'',
      goalkeeper:!!input.goalkeeper||position==='门将',captain:!!input.captain,eligible:input.eligible!==false,eligibility:status};
  }
  function normalize(output, raw){
    if(raw.schemaVersion!=null&&raw.schemaVersion!==2)throw new Error('此版本无法读取该赛事备份');
    output.schemaVersion=2;
    output.teamIds=ids(raw.teamIds,output.teams.length);
    if(output.draftTeams)output.draftTeamIds=raw.draftTeamIds!=null?ids(raw.draftTeamIds,output.draftTeams.length):
      output.draftTeams.map((_,i)=>output.teamIds[i]||uid('team'));
    const teamIds=new Set(output.teamIds.concat(output.draftTeamIds||[]));
    const seen=new Set();
    output.players=list(raw.players,'球员').map(player=>{
      if(!player||!safeId(player.player_id,'player')||seen.has(player.player_id)||!text(player.name))throw new Error('球员身份无效或重复');
      seen.add(player.player_id);
      const fields=formatPlayer({...player,number:0});
      return {player_id:player.player_id,name:fields.name,photo:fields.photo,birthYear:fields.birthYear,position:fields.position,foot:fields.foot,notes:fields.notes};
    });
    const registered=new Set();
    output.registrations=list(raw.registrations,'球员报名').map(reg=>{
      if(!reg||!teamIds.has(reg.team_id)||!seen.has(reg.player_id)||registered.has(reg.player_id))throw new Error('球员报名关系无效或重复');
      registered.add(reg.player_id);
      const data=formatPlayer({...reg,name:'球员'});
      return {team_id:reg.team_id,player_id:reg.player_id,number:data.number,goalkeeper:data.goalkeeper,captain:data.captain,
        eligible:data.eligible,eligibility:data.eligibility,active:reg.active!==false};
    });
    const profileTeams=new Set();
    output.teamProfiles=list(raw.teamProfiles,'球队资料').map(profile=>{
      if(!profile||!teamIds.has(profile.team_id)||profileTeams.has(profile.team_id))throw new Error('球队资料关系无效或重复');
      profileTeams.add(profile.team_id);
      return profileData(profile.team_id,profile);
    });
    output.lineups={};
    return output;
  }
  function profileData(team_id,data){
    const profile={team_id,logo:imagePattern.test(data.logo||'')&&data.logo.length<=180000?data.logo:''};
    for(const key of ['leader','coach','phone','homeColor','awayColor','keeperColor','notes'])profile[key]=text(data[key]).slice(0,key==='notes'?300:60);
    return profile;
  }
  function teamRoster(state,teamId){
    const players=new Map(state.players.map(player=>[player.player_id,player]));
    return state.registrations.filter(reg=>reg.team_id===teamId&&reg.active).map(reg=>({...players.get(reg.player_id),...reg}))
      .sort((a,b)=>Number(a.number)-Number(b.number));
  }
  const nameKey = record => record.name.normalize('NFKC').replace(/\s+/g,'').toLowerCase();
  function duplicate(state,teamId,data,except){
    const active=new Map(state.registrations.filter(reg=>reg.active&&reg.player_id!==except).map(reg=>[reg.player_id,reg]));
    if([...active.values()].some(reg=>reg.team_id===teamId&&reg.number===data.number))return '本队球衣号码重复：'+data.number;
    if(state.players.some(player=>active.has(player.player_id)&&nameKey(player)===nameKey(data)&&
      (!player.birthYear||!data.birthYear||player.birthYear===data.birthYear)))return '赛事名单已有此球员：'+data.name;
    return '';
  }
  function savePlayer(state,teamId,data,playerId){
    if(!state.teamIds.includes(teamId))throw new Error('请选择一支球队');
    const fields=formatPlayer(data),error=duplicate(state,teamId,fields,playerId);
    if(error)throw new Error(error);
    const id=playerId||uid('player');
    const player={player_id:id,name:fields.name,photo:fields.photo,birthYear:fields.birthYear,position:fields.position,foot:fields.foot,notes:fields.notes};
    const reg={team_id:teamId,player_id:id,number:fields.number,goalkeeper:fields.goalkeeper,captain:fields.captain,
      eligible:fields.eligible,eligibility:fields.eligibility,active:true};
    if(playerId){
      const existing=state.registrations.find(item=>item.player_id===id&&item.team_id===teamId&&item.active);
      if(!existing)throw new Error('该球员已不在当前名单');
      Object.assign(existing,reg);
      Object.assign(state.players.find(item=>item.player_id===id),player);
    }else{state.players.push(player);state.registrations.push(reg)}
    return id;
  }
  function archivePlayer(state,teamId,id){
    const reg=state.registrations.find(item=>item.player_id===id&&item.team_id===teamId&&item.active);
    if(!reg)throw new Error('该球员已不在当前名单');
    reg.active=false;
  }
  function parseDelimited(source,delimiter){
    const rows=[];
    let cell='',row=[],quoted=false,line=1,start=1;
    const input=source.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n');
    for(let i=0;i<input.length;i++){
      const char=input[i];
      if(char==='"'){
        if(quoted&&input[i+1]==='"'){cell+='"';i++}
        else if(quoted||!cell)quoted=!quoted;
        else cell+=char;
      }else if(!quoted&&char===delimiter){row.push(cell);cell=''}
      else if(!quoted&&char==='\n'){row.push(cell);rows.push({line:start,values:row});row=[];cell='';start=line+1}
      else cell+=char;
      if(char==='\n')line++;
    }
    if(quoted)throw new Error('第 '+start+' 行的引号没有闭合');
    row.push(cell);rows.push({line:start,values:row});return rows;
  }
  function yesNo(value,fallback){
    const v=text(value).toLowerCase();
    if(!v)return fallback;
    if(['是','1','true','yes','y','可参赛','✔','✓'].includes(v))return true;
    if(['否','0','false','no','n','不可参赛','×'].includes(v))return false;
    throw new Error('是/否字段格式无效：'+v);
  }
  function preview(state,teamId,rows){
    const nonempty=rows.filter(row=>row.values.some(value=>text(value)));
    if(!nonempty.length)throw new Error('没有可读取的球员记录');
    const aliases={号码:'球衣号码','队长':'是否队长','门将':'是否门将','可参赛':'是否可参赛'};
    const keys=nonempty[0].values.map(value=>aliases[text(value)]||text(value));
    const hasHeader=keys.includes('姓名')||keys.includes('球衣号码');
    const columns=hasHeader?keys:['球衣号码','姓名','位置','备注'];
    if(hasHeader&&(!keys.includes('姓名')||!keys.includes('球衣号码')))throw new Error('表头须包含球衣号码及姓名');
    const entries=hasHeader?nonempty.slice(1):nonempty;
    if(!entries.length||entries.length>200)throw new Error('每次请预览 1–200 条球员记录');
    const snapshots=copy(state);
    return entries.map(({line,values})=>{
      const field=name=>{
        const value=text(values[columns.indexOf(name)]);
        return /^'[=+@-]/.test(value)?value.slice(1):value;
      };
      const small={line,name:field('姓名'),number:field('球衣号码')};
      try{
        const data=formatPlayer({name:small.name,number:small.number,position:field('位置'),birthYear:field('出生年份'),
          goalkeeper:yesNo(field('是否门将'),false),captain:yesNo(field('是否队长'),false),
          foot:field('惯用脚'),eligible:yesNo(field('是否可参赛'),true),eligibility:field('资格状态'),notes:field('备注')});
        savePlayer(snapshots,teamId,data);
        return {...small,data};
      }catch(error){return {...small,error:error.message}}
    });
  }
  function outputRows(state,teamId){
    const yes=value=>value?'是':'否';
    return [headers,...teamRoster(state,teamId).map(p=>[p.number,p.name,p.position,yes(p.goalkeeper),yes(p.captain),
      p.birthYear??'',p.foot,p.eligibility,yes(p.eligible),p.notes])];
  }
  function toCsv(rows){
    return '\uFEFF'+rows.map(row=>row.map(value=>'"'+String(value).replace(/^[=+@-]/,"'$&").replace(/"/g,'""')+'"').join(',')).join('\r\n');
  }
  return {normalize,profileData,teamRoster,savePlayer,archivePlayer,parseDelimited,preview,outputRows,toCsv,headers,positions,feet,eligibility,uid,copy,imagePattern};
})();
