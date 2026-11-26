'use strict';

const MatchPlayers = (() => {
  const labels={goal:'进球',assist:'助攻',yellow:'黄牌',red:'红牌',second_yellow:'两黄变红',sub:'换人',penalty:'点球进球',shootout:'点球 / 单刀决胜',own_goal:'乌龙球',mvp:'MVP'};
  const sides=['home','away'];
  const roster=(state,match,side)=>EventPlayers.teamRoster(state,state.teamIds[match[side]])
    .filter(player=>player.eligible&&player.eligibility!=='不合格');
  const history=(state,match)=>state.events[match.id]||[];
  const locked=(state,match)=>state.lineups[match.id]?.locked||match.status==='done'||match.hs!=null||match.as!=null||history(state,match).length>0;
  const registered=(state,team,id)=>state.registrations.some(reg=>reg.team_id===team&&reg.player_id===id);
  const name=player=>'#'+player.number+' '+player.name;

  function validLineup(state,team,lineup){
    if(!lineup||lineup.team_id!==team||!Array.isArray(lineup.starters)||!Array.isArray(lineup.substitutes))return false;
    const ids=[...lineup.starters,...lineup.substitutes];
    return lineup.starters.length>0&&new Set(ids).size===ids.length&&ids.every(id=>registered(state,team,id))&&
      [lineup.goalkeeper,lineup.captain].every(id=>id==null||lineup.starters.includes(id));
  }
  function normalize(state,raw){
    const source=raw.lineups||{};
    for(const match of state.matches){
      const sheet=Object.hasOwn(source,match.id)?source[match.id]:null;
      if(sheet){
        const entry={locked:sheet.locked===true};
        for(const side of sides){
          if(!sheet[side])continue;
          const team=state.teamIds[match[side]], lineup=sheet[side];
          if(!team||!validLineup(state,team,lineup))throw new Error('本场名单含无效球员或球队');
          const {starters,substitutes,goalkeeper,captain}=lineup;
          entry[side]={team_id:team,starters,substitutes,goalkeeper:goalkeeper??null,captain:captain??null};
        }
        state.lineups[match.id]=entry;
      }
      const events=raw.events?.[match.id];
      if(!Array.isArray(events)||!state.events[match.id])continue;
      state.events[match.id]=events.map((event,index)=>{
        const saved=state.events[match.id][index];
        if(!event.type)return saved;
        const {type,team_id,player_id,related_player_id,minute,occurredAt,player,related,reason,before,after}=event;
        if(!sides.some(side=>state.teamIds[match[side]]===team_id))throw new Error('比赛事件含无效球队');
        if(type==='lineup_change'){
          if(typeof reason!=='string'||!reason.trim()||!validLineup(state,team_id,after)||(before&&!validLineup(state,team_id,before)))throw new Error('名单修改记录无效');
          return {...saved,type,team_id,reason,before,after,occurredAt};
        }
        if(!Object.hasOwn(labels,type)||!registered(state,team_id,player_id)||
          (type==='sub'&&!related_player_id)||
          (related_player_id&&!registered(state,team_id,related_player_id)))throw new Error('比赛事件含无效球员');
        return {...saved,type,team_id,player_id,related_player_id:related_player_id??null,minute,occurredAt,player,related};
      });
    }
    return state;
  }
  function saveLineup(state,match,side,starters,substitutes,goalkeeper,captain,reason){
    const team_id=state.teamIds[match[side]], before=state.lineups[match.id]?.[side]||null;
    const after={team_id,starters,substitutes,goalkeeper:goalkeeper||null,captain:captain||null};
    const eligible=new Set(roster(state,match,side).map(player=>player.player_id));
    const previous=new Set([...(before?.starters||[]),...(before?.substitutes||[])]);
    if(!validLineup(state,team_id,after)||[...starters,...substitutes].some(id=>!eligible.has(id)&&!previous.has(id)))throw new Error('至少选择一名首发。门将和队长须在首发名单中。');
    if(locked(state,match)){
      reason=reason.trim();
      if(!reason)throw new Error('请填写强制修改的原因');
      const upcoming=participation(state,match,after);
      if(upcoming.invalid)throw new Error('该名单会使已经记录的上场、换人或处罚失效');
      append(state,match,{type:'lineup_change',team_id,reason,before,after,text:'本场名单修改 · '+reason});
    }
    const entry=state.lineups[match.id]||={locked:false};
    entry[side]=after;
  }
  function participation(state,match,lineup){
    const on=new Set(lineup.starters), appeared=new Set(on);
    const bench=new Set(lineup.substitutes);
    let invalid=false;
    for(const event of history(state,match)){
      if(event.team_id!==lineup.team_id||!event.player_id)continue;
      if(event.type==='mvp'){if(!appeared.has(event.player_id))invalid=true;continue}
      if(!on.has(event.player_id)||(event.related_player_id&&event.type!=='sub'&&!on.has(event.related_player_id)))invalid=true;
      if(event.type==='sub'){
        if(!bench.has(event.related_player_id)||appeared.has(event.related_player_id))invalid=true;
        on.delete(event.player_id);
        appeared.add(event.related_player_id);
        on.add(event.related_player_id);
      }
      if(event.type==='red'||event.type==='second_yellow')on.delete(event.player_id);
    }
    return {on,appeared,bench,invalid};
  }
  function append(state,match,event){
    const now=new Date();
    (state.events[match.id]||=[]).push({...event,occurredAt:now.toISOString(),time:now.toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})});
  }
  function record(state,match,side,input){
    let {type,player_id,related_player_id,minute}=input;
    if(!Object.hasOwn(labels,type)||!sides.includes(side)||(match.status==='done')!==(type==='mvp'))throw new Error('当前比赛状态无法记录此事件');
    const lineup=state.lineups[match.id]?.[side];
    if(!lineup)throw new Error('请先保存该队本场名单');
    const {on,appeared,bench,invalid}=participation(state,match,lineup);
    if(invalid||!(type==='mvp'?appeared:on).has(player_id))throw new Error('该球员当前不可选');
    if(type==='mvp'&&history(state,match).some(event=>event.type==='mvp'))throw new Error('本场已记录 MVP');
    const priorYellow=history(state,match).some(event=>event.type==='yellow'&&event.player_id===player_id);
    if(type==='yellow'&&priorYellow)type='second_yellow';
    if(type==='second_yellow'&&!priorYellow)throw new Error('该球员尚未记录第一张黄牌');
    if(type==='sub'&&(!bench.has(related_player_id)||appeared.has(related_player_id)))throw new Error('请选择尚未出场的替补');
    if(type==='goal'&&related_player_id&&(!on.has(related_player_id)||related_player_id===player_id))throw new Error('请选择另一名在场球员作为助攻');
    if(type!=='goal'&&type!=='sub')related_player_id=null;
    if(minute!==null&&(!Number.isInteger(minute)||minute<0||minute>999))throw new Error('请输入有效的比赛分钟');

    const team_id=lineup.team_id;
    function snapshot(id){
      const person=state.players.find(player=>player.player_id===id);
      const reg=state.registrations.find(reg=>reg.player_id===id&&reg.team_id===team_id);
      if(!person||!reg)throw new Error('球员资料不存在');
      return {name:person.name,number:reg.number};
    }
    const player=snapshot(player_id),related=related_player_id?snapshot(related_player_id):null;
    const text=[minute===null?'':minute+'′',state.teams[match[side]],labels[type],name(player),
      related?(type==='sub'?'↓ / '+name(related)+' ↑':'· 助攻 '+name(related)):''].filter(Boolean).join(' ');
    if(['goal','penalty','own_goal'].includes(type)){
      const scoringSide=type==='own_goal'?(side==='home'?'away':'home'):side;
      const key=scoringSide==='home'?'hs':'as';
      if((match[key]||0)>=Number.MAX_SAFE_INTEGER)throw new Error('比分已达上限');
      match.hs??=0;match.as??=0;
      match[key]++;
    }
    state.lineups[match.id].locked=true;
    append(state,match,{type,team_id,player_id,related_player_id:related_player_id||null,minute,player,related,text});
  }
  return {labels,sides,roster,locked,normalize,name,saveLineup,participation,record};
})();
