'use strict';

const MatchPlayerUI = (() => {
  let modal, editor;
  const sideName={home:'主队',away:'客队'};
  const {sides,labels,roster,locked,name,participation}=MatchPlayers;
  const options=(values,blank)=>'<option value="">'+blank+'</option>'+values.map(([id,label])=>'<option value="'+esc(id)+'">'+esc(label)+'</option>').join('');
  const field=(title,control)=>'<label class="players-field">'+title+control+'</label>';
  const playerOptions=players=>players.map(p=>[p.player_id,name(p)]);
  const sideOptions=match=>sides.map(side=>[side,sideName[side]+' · '+teamName(match[side])]);
  function mount(){
    modal=document.createElement('dialog');
    modal.className='players-dialog';
    modal.innerHTML='<form id="matchPlayerForm"><h2 id="matchPlayerTitle"></h2><div id="matchPlayerFields"></div><div class="player-alert" id="matchPlayerError" role="alert"></div><div class="player-tools"><button class="btn pri" id="saveMatchPlayer">保存</button><button class="btn" type="button" id="closeMatchPlayer">关闭</button></div></form>';
    modal.setAttribute('aria-labelledby','matchPlayerTitle');
    document.body.append(modal);
    q('closeMatchPlayer').onclick=()=>modal.close();
    editor=q('matchPlayerForm');
  }
  function open(title,html,save){
    q('matchPlayerTitle').textContent=title;
    q('matchPlayerFields').innerHTML=html;
    q('matchPlayerError').textContent='';
    q('saveMatchPlayer').hidden=!save;
    editor.onsubmit=event=>{
      event.preventDefault();
      try{if(save?.()!==false)modal.close()}catch(error){q('matchPlayerError').textContent=error.message}
    };
    if(!modal.open)modal.showModal();
  }
  function lineup(match,side,editing=false){
    const current=S.lineups[match.id]?.[side];
    const isLocked=locked(S,match);
    const players=roster(S,match,side);
    const savedIds=[...(current?.starters||[]),...(current?.substitutes||[])];
    for(const id of savedIds){
      if(players.some(player=>player.player_id===id))continue;
      const person=S.players.find(player=>player.player_id===id);
      const registration=S.registrations.find(reg=>reg.team_id===current.team_id&&reg.player_id===id);
      players.push({...person,...registration});
    }
    const title=teamName(match[side])+' · 本场名单';
    if(isLocked&&!editing){
      const info=current?participation(S,match,current):null;
      const list=(ids,state)=>players.filter(p=>ids.includes(p.player_id)).map(p=>{
        const id=p.player_id;
        return [name(p),id===current.goalkeeper?'门将':'',id===current.captain?'队长':'',state&&info.appeared.has(id)?'已出场':''].filter(Boolean).join(' · ');
      }).join('、')||'无';
      open(title,'<p>比赛记录已锁定本场名单。</p>'+(current?'<p>首发　'+esc(list(current.starters,true))+'</p><p>替补　'+esc(list(current.substitutes,true))+'</p>':'<p>尚无本场名单。</p>')+
        '<button class="btn" type="button" id="forceLineup">强制修改名单</button>');
      q('forceLineup').onclick=()=>lineup(match,side,true);
      return;
    }
    const rows=players.map(p=>{
      const id=p.player_id;
      const selected=current?.starters.includes(id)?'start':current?.substitutes.includes(id)?'bench':'';
      return '<label class="lineup-row players-field"><span>'+esc(name(p))+'</span><select data-lineup-player="'+esc(id)+'">'+
        options([['start','首发'],['bench','替补']],'未入选').replace('value="'+selected+'"','value="'+selected+'" selected')+'</select></label>';
    });
    const entries=()=>Array.from(modal.querySelectorAll('[data-lineup-player]'));
    const ids=value=>entries().filter(input=>input.value===value).map(input=>input.dataset.lineupPlayer);
    open(title,'<div class="players-grid">'+field('门将','<select id="matchKeeper"></select>')+
      field('队长','<select id="matchCaptain"></select>')+'</div><div class="lineup-list">'+rows.join('')+'</div>'+
      (isLocked?field('强制修改原因','<input id="lineupReason" required maxlength="150">'):''),
    ()=>{
      if(isLocked&&!confirm('修改原因和修改前后的名单会保存在比赛记录中。确定修改？'))return false;
      PlayerUI.transaction(next=>MatchPlayers.saveLineup(next,byMatch(next,match.id),side,ids('start'),ids('bench'),q('matchKeeper').value,q('matchCaptain').value,q('lineupReason')?.value||''));
      renderLive();
      msg('本场名单已保存');
    });
    function refreshRoles(keeper,captain){
      const starting=ids('start');
      const starters=players.filter(player=>starting.includes(player.player_id));
      const markup=options(playerOptions(starters),'请选择首发球员');
      q('matchKeeper').innerHTML=markup;
      q('matchCaptain').innerHTML=markup;
      q('matchKeeper').value=starting.includes(keeper)?keeper:starters.find(p=>p.goalkeeper)?.player_id||'';
      q('matchCaptain').value=starting.includes(captain)?captain:starters.find(p=>p.captain)?.player_id||'';
    }
    refreshRoles(current?.goalkeeper,current?.captain);
    for(const entry of entries())entry.onchange=()=>refreshRoles(q('matchKeeper').value,q('matchCaptain').value);
  }
  const byMatch=(state,id)=>state.matches.find(match=>match.id===id);
  function canLink(match,side){
    return !!(S.lineups[match.id]?.[side]||roster(S,match,side).length);
  }
  function openEvent(match,type='',side=''){
    const eventTypes=match.status==='done'?['mvp']:Object.keys(labels).filter(key=>key!=='mvp');
    open('记录球员比赛事件',
      '<div class="players-grid">'+field('球队','<select id="eventSide" required>'+options(sideOptions(match),'请选择球队')+'</select>')+
      field('事件','<select id="eventType" required>'+options(eventTypes.map(key=>[key,labels[key]]),'请选择事件')+'</select>')+
      field('<span id="eventPlayerLabel">球员</span>','<select id="eventPlayer" required></select>')+
      field('比赛分钟（选填）','<input id="eventMinute" type="number" min="0" max="999" inputmode="numeric">')+
      '<div id="eventRelatedField">'+field('<span id="eventRelatedLabel"></span>','<select id="eventRelated"></select>')+'</div></div><p class="player-muted" id="eventPlayerHelp"></p>',
    ()=>{
      const minute=q('eventMinute').value;
      PlayerUI.transaction(next=>MatchPlayers.record(next,byMatch(next,match.id),q('eventSide').value,{
        type:q('eventType').value,player_id:q('eventPlayer').value,related_player_id:q('eventRelated').value,minute:minute===''?null:Number(minute)
      }));
      refreshScoreCard(match.id);
      renderLive();
      msg('比赛事件已保存');
    });
    q('eventSide').value=side;
    q('eventType').value=type;
    function refreshChoices(){
      const type=q('eventType').value, selectedSide=q('eventSide').value;
      const lineup=S.lineups[match.id]?.[selectedSide];
      const info=lineup?participation(S,match,lineup):null;
      const choices=ids=>S.registrations.filter(reg=>reg.team_id===lineup?.team_id&&ids.has(reg.player_id)).map(reg=>{
        const player=S.players.find(person=>person.player_id===reg.player_id);
        return [reg.player_id,name({...player,...reg})];
      });
      q('eventPlayerLabel').textContent=type==='sub'?'下场球员':'球员';
      q('eventPlayer').innerHTML=options(info?choices(type==='mvp'?info.appeared:info.on):[],'请选择球员');
      q('eventRelatedField').hidden=type!=='sub'&&type!=='goal';
      q('eventRelatedLabel').textContent=type==='sub'?'上场球员':'助攻球员（选填）';
      q('eventRelated').required=type==='sub';
      q('eventRelated').innerHTML=options(info?choices(type==='sub'?new Set([...info.bench].filter(id=>!info.appeared.has(id))):info.on):[],'请选择球员');
      q('eventPlayerHelp').textContent=selectedSide&&!lineup?'请关闭窗口并先保存该队本场名单。':'';
      q('saveMatchPlayer').disabled=!!selectedSide&&!lineup;
    }
    q('eventSide').onchange=refreshChoices;
    q('eventType').onchange=refreshChoices;
    refreshChoices();
  }
  function render(match){
    const box=q('matchPlayerTools');
    if(!box)return;
    box.hidden=!match||!sides.some(side=>canLink(match,side));
    if(box.hidden){box.replaceChildren();return}
    const sheet=S.lineups[match.id], isLocked=locked(S,match);
    box.innerHTML='<h3>本场名单与球员事件</h3><p class="player-muted">'+(isLocked?'名单已锁定':'比赛开始后，本场名单将锁定')+'</p><div class="player-tools"></div>';
    const actions=box.querySelector('.player-tools');
    function button(id,label,action){
      const el=document.createElement('button');
      el.id=id;el.className='btn';el.type='button';el.textContent=label;el.onclick=action;
      actions.append(el);
    }
    for(const side of sides){
      if(!canLink(match,side))continue;
      const line=sheet?.[side];
      const count=line?' · '+line.starters.length+' 首发 / '+line.substitutes.length+' 替补':'';
      button('lineup-'+side,sideName[side]+'名单'+count,()=>lineup(match,side));
    }
    if(!isLocked&&sheet)button('startPlayerMatch','开始比赛并锁定名单',()=>{
      if(!confirm('确定开始比赛并锁定本场名单？'))return;
      try{PlayerUI.transaction(next=>{next.lineups[match.id].locked=true});renderLive()}catch(error){msg(error.message)}
    });
    const mvp=(S.events[match.id]||[]).find(event=>event.type==='mvp');
    if(match.status!=='done')button('openPlayerEvent','记录球员事件',()=>openEvent(match));
    else if(!mvp)button('openPlayerEvent','记录本场 MVP',()=>openEvent(match,'mvp'));
  }
  function quickEvent(match,type){
    if(!sides.some(side=>canLink(match,side)))return false;
    openEvent(match,type);
    return true;
  }
  return {mount,render,canLink,openEvent,quickEvent};
})();
