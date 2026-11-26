'use strict';

const PlayerUI = (() => {
  const {positions,feet,eligibility,headers}=EventPlayers;
  let workspace, editor, importer, selectedTeam, editId, photo, previewRows, xlsxLoad;
  const byId=id=>document.getElementById(id);
  const dropdown=(values,blank)=> (blank?'<option value="">'+blank+'</option>':'')+
    values.map(value=>'<option>'+value+'</option>').join('');
  const field=(label,control)=>'<label class="players-field">'+label+control+'</label>';
  const textField=(label,name,max=60)=>field(label,'<input name="'+name+'" maxlength="'+max+'">');
  function transaction(change){
    const next=EventPlayers.copy(S);
    change(next);
    if(!persist(next))throw new Error('保存失败，原数据已保留。请查看页面顶部提示。');
    S=next;
  }
  function message(message){
    byId('playerMessage').textContent=message;
  }
  function profile(){return S.teamProfiles.find(team=>team.team_id===selectedTeam)||{}}
  function mount(){
    workspace=byId('playerWorkspace');
    workspace.innerHTML='<div class="card">'+field('选择球队','<select id="rosterTeam"></select>')+
      '<div class="player-tools"><button id="playerAdd" class="btn pri" type="button">添加球员</button><button id="playerImport" class="btn" type="button">批量导入</button></div>'+
      '<div class="player-tools"><button id="rosterPrintButton" class="btn" type="button">A4 打印 / PDF</button>'+
      '<button id="rosterCSV" class="btn" type="button">导出 CSV</button><button id="rosterXLSX" class="btn" type="button">导出 XLSX</button></div>'+
      '<div id="playerMessage" class="player-alert" role="status"></div><div id="rosterRows"></div>'+
      '<details class="players-section"><summary>球队资料</summary><form id="teamProfileForm">'+
      '<div class="players-grid">'+textField('领队','leader')+textField('教练','coach')+textField('联系电话（仅本机保存）','phone')+
      textField('主场球衣颜色','homeColor')+textField('客场球衣颜色','awayColor')+textField('门将服颜色','keeperColor')+
      textField('球队备注','notes',300)+field('队徽图片','<input type="file" name="logoFile" accept="image/png,image/jpeg,image/webp">')+
      '</div><div class="player-tools"><button class="btn ok">保存球队资料</button></div></form></details></div>';
    editor=document.createElement('dialog');editor.className='players-dialog';editor.setAttribute('aria-labelledby','playerEditorTitle');
    editor.innerHTML='<h2 id="playerEditorTitle">球员资料</h2><form id="playerForm"><div class="players-grid">'+
      field('球衣号码','<input name="number" inputmode="numeric" pattern="[0-9]{1,3}" required>')+
      field('姓名','<input name="name" maxlength="60" required>')+
      field('位置','<select name="position">'+dropdown(positions)+'</select>')+
      field('出生年份','<input name="birthYear" inputmode="numeric" maxlength="4">')+
      field('惯用脚','<select name="foot">'+dropdown(feet,'未填写')+'</select>')+
      field('资格状态','<select name="eligibility">'+dropdown(eligibility)+'</select>')+
      field('球员照片','<input type="file" name="photoFile" accept="image/png,image/jpeg,image/webp">')+
      textField('备注','notes',300)+
      '<label class="players-field check"><input type="checkbox" name="goalkeeper">门将</label>'+
      '<label class="players-field check"><input type="checkbox" name="captain">队长</label>'+
      '<label class="players-field check"><input type="checkbox" name="eligible">可参赛</label></div>'+
      '<p id="playerError" class="player-alert" role="status"></p><div class="player-tools"><button class="btn pri" type="submit">保存球员</button>'+
      '<button id="playerRemove" class="btn bad" type="button">移出名单</button><button class="btn" type="button" data-close>取消</button></div></form>';
    importer=document.createElement('dialog');importer.className='players-dialog';importer.setAttribute('aria-labelledby','playerImportTitle');
    importer.innerHTML='<h2 id="playerImportTitle">导入球员名单</h2>'+
      field('粘贴球员名单（每行：号码 姓名 位置 备注）','<textarea id="rosterPaste" rows="4" placeholder="支持从微信或 Excel 粘贴"></textarea>')+
      '<div class="player-tools"><button id="previewPaste" class="btn" type="button">预览粘贴名单</button><button id="rosterTemplate" class="btn" type="button">下载 XLSX 模板</button></div>'+
      field('选择 CSV 或 XLSX 文件','<input id="rosterFile" type="file" accept=".csv,.xlsx">')+
      '<p id="importStatus" class="player-alert" role="status"></p><ul id="previewRows" class="preview-rows"></ul>'+
      '<div class="player-tools"><button id="commitImport" class="btn pri" type="button" disabled>确认导入</button><button class="btn" type="button" data-close>取消</button></div>';
    for(const dialog of [editor,importer]){
      document.body.append(dialog);
      dialog.querySelector('[data-close]').addEventListener('click',()=>dialog.close());
    }
    byId('rosterTeam').addEventListener('change',event=>{selectedTeam=event.target.value;message('');render()});
    byId('playerAdd').addEventListener('click',()=>openEditor(null));
    byId('playerForm').addEventListener('submit',saveForm);
    byId('playerRemove').addEventListener('click',removePlayer);
    byId('teamProfileForm').addEventListener('submit',saveProfile);
    byId('playerImport').addEventListener('click',()=>{resetPreview();byId('rosterPaste').value='';byId('rosterFile').value='';importer.showModal()});
    byId('previewPaste').addEventListener('click',()=>{
      try{
        const source=byId('rosterPaste').value;
        const rows=source.includes('\t')?EventPlayers.parseDelimited(source,'\t'):source.includes(',')?EventPlayers.parseDelimited(source,','):
          source.split(/\r?\n/).map((line,index)=>{
            const values=line.trim().split(/\s+/);
            return {line:index+1,values:values.slice(0,3).concat(values.slice(3).join(' '))};
          });
        showPreview(rows);
      }catch(error){resetPreview(error.message)}
    });
    byId('rosterFile').addEventListener('change',previewFile);
    byId('commitImport').addEventListener('click',commitImport);
    byId('rosterTemplate').addEventListener('click',()=>writeXlsx([headers],'SAGI-球员名单模板.xlsx',error=>resetPreview(error)));
    byId('rosterCSV').addEventListener('click',()=>{
      const csv=EventPlayers.toCsv(EventPlayers.outputRows(S,selectedTeam));
      const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));
      const link=document.createElement('a');link.href=url;link.download='SAGI-球员名单.csv';link.click();
      setTimeout(()=>URL.revokeObjectURL(url),1000);
    });
    byId('rosterXLSX').addEventListener('click',()=>writeXlsx(EventPlayers.outputRows(S,selectedTeam),'SAGI-球员名单.xlsx',message));
    byId('rosterPrintButton').addEventListener('click',printRoster);
    window.addEventListener('afterprint',()=>document.body.classList.remove('roster-print'));
  }
  function show(){
    const select=byId('rosterTeam');
    if(!S.teamIds.includes(selectedTeam))selectedTeam=S.teamIds[0];
    select.replaceChildren(...S.teams.map((team,index)=>new Option(team,S.teamIds[index])));
    select.value=selectedTeam;
    message('');render();
  }
  function render(){
    const list=byId('rosterRows'), players=EventPlayers.teamRoster(S,selectedTeam);
    list.replaceChildren();
    const count=document.createElement('p');count.className='player-summary';
    count.textContent=players.length?'参赛名单 · '+players.length+' 人':'这支球队还没有球员。可手工添加或批量导入。';
    list.append(count);
    for(const player of players){
      const row=document.createElement('div');row.className='player-card';row.dataset.playerId=player.player_id;
      const content=document.createElement('div'),name=document.createElement('strong'),details=document.createElement('small');
      name.textContent='#'+player.number+' · '+player.name;
      details.textContent=[player.position,player.goalkeeper?'门将':'',player.captain?'队长':'',player.eligible?player.eligibility:'不可参赛'].filter(Boolean).join(' · ');
      content.append(name,details);
      const button=document.createElement('button');button.className='btn';button.type='button';button.textContent='编辑';
      button.setAttribute('aria-label','编辑 '+player.name);button.addEventListener('click',()=>openEditor(player));
      row.append(content,button);list.append(row);
    }
    const form=byId('teamProfileForm'),team=profile();
    for(const input of form.elements)if(input.name&&input.type!=='file')input.value=team[input.name]||'';
    form.elements.logoFile.value='';
  }
  function openEditor(player){
    editId=player?.player_id||null;photo=player?.photo||'';
    const form=byId('playerForm');
    form.reset();byId('playerError').textContent='';
    byId('playerEditorTitle').textContent=player?'编辑球员':'添加球员';
    byId('playerRemove').hidden=!player;
    for(const input of form.elements){
      if(!input.name||input.type==='file')continue;
      if(input.type==='checkbox')input.checked=player?!!player[input.name]:input.name==='eligible';
      else if(player)input.value=player[input.name]??'';
    }
    if(!player)form.elements.position.value='其他';
    editor.showModal();
  }
  async function imageFile(file,fallback){
    if(!file)return fallback;
    if(file.size>130000||!['image/png','image/jpeg','image/webp'].includes(file.type))throw new Error('请选择不超过 130 KB 的 PNG、JPG 或 WebP 图片');
    return await new Promise((resolve,reject)=>{
      const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(new Error('图片读取失败'));reader.readAsDataURL(file);
    });
  }
  async function saveForm(event){
    event.preventDefault();
    const form=event.currentTarget,data=Object.fromEntries(new FormData(form)),team=selectedTeam,id=editId;
    const submit=form.querySelector('[type=submit]');
    submit.disabled=true;
    try{
      data.photo=await imageFile(form.elements.photoFile.files[0],photo);
      if(!editor.open)return;
      for(const name of ['goalkeeper','captain','eligible'])data[name]=form.elements[name].checked;
      transaction(next=>EventPlayers.savePlayer(next,team,data,id));
      editor.close();render();message(id?'球员已更新':'球员已添加');
    }catch(error){byId('playerError').textContent=error.message}
    finally{submit.disabled=false}
  }
  function removePlayer(){
    if(!confirm('从现役名单移出该球员？已保存的比赛名单和事件会保留。'))return;
    try{transaction(next=>EventPlayers.archivePlayer(next,selectedTeam,editId));editor.close();render();message('已移出当前名单')}
    catch(error){byId('playerError').textContent=error.message}
  }
  async function saveProfile(event){
    event.preventDefault();
    const team=selectedTeam,form=event.currentTarget,data=Object.fromEntries(new FormData(form));
    try{
      data.logo=await imageFile(form.elements.logoFile.files[0],profile().logo);
      transaction(next=>{
        const index=next.teamProfiles.findIndex(item=>item.team_id===team),record=EventPlayers.profileData(team,data);
        if(index<0)next.teamProfiles.push(record);else next.teamProfiles[index]=record;
      });
      render();message('球队资料已保存');
    }catch(error){message(error.message)}
  }
  function xlsx(){
    if(!xlsxLoad)xlsxLoad=new Promise((resolve,reject)=>{
      const script=document.createElement('script');script.src='./vendor/xlsx-0.20.3.min.js';
      script.onload=()=>window.XLSX?resolve(window.XLSX):reject(new Error('Excel 功能加载失败'));
      script.onerror=()=>reject(new Error('Excel 功能加载失败，请重试'));
      document.head.append(script);
    }).catch(error=>{xlsxLoad=null;throw error});
    return xlsxLoad;
  }
  async function writeXlsx(rows,file,fail){
    try{
      const api=await xlsx(),workbook=api.utils.book_new();
      api.utils.book_append_sheet(workbook,api.utils.aoa_to_sheet(rows),'球员名单');
      api.writeFile(workbook,file,{compression:true});
    }catch(error){fail(error.message)}
  }
  function resetPreview(reason=''){
    previewRows=null;byId('previewRows').replaceChildren();byId('importStatus').textContent=reason;byId('commitImport').disabled=true;
  }
  async function previewFile(event){
    const input=event.target,file=input.files[0];
    if(!file)return;
    resetPreview('正在读取文件…');
    try{
      if(file.size>5*1024*1024)throw new Error('文件大小不能超过 5 MB');
      let rows;
      if(/\.xlsx$/i.test(file.name)){
        const api=await xlsx(),data=await file.arrayBuffer();
        const book=api.read(data,{type:'array',sheetRows:202,sheets:0});
        const sheet=book.Sheets[book.SheetNames[0]];
        if(!sheet)throw new Error('未找到第一个工作表');
        rows=api.utils.sheet_to_json(sheet,{header:1,defval:'',raw:false,blankrows:true}).map((values,index)=>({values,line:index+1}));
      }else if(/\.csv$/i.test(file.name)){
        const bytes=await file.arrayBuffer();
        let source;
        try{source=new TextDecoder('utf-8',{fatal:true}).decode(bytes)}
        catch{source=new TextDecoder('gb18030').decode(bytes)}
        rows=EventPlayers.parseDelimited(source,',');
      }else throw new Error('请选择 CSV 或 XLSX 文件');
      if(importer.open&&input.files[0]===file)showPreview(rows);
    }catch(error){if(importer.open&&input.files[0]===file)resetPreview(error.message)}
    finally{if(input.files[0]===file)input.value=''}
  }
  function showPreview(rows){
    previewRows=EventPlayers.preview(S,selectedTeam,rows);
    const valid=previewRows.filter(row=>!row.error).length;
    const list=byId('previewRows');list.replaceChildren();
    for(const row of previewRows){
      const li=document.createElement('li');
      li.textContent='第 '+row.line+' 行 · '+[row.number,row.name].filter(Boolean).join(' ')+' · '+(row.error||'可导入');
      if(row.error)li.className='player-alert';
      list.append(li);
    }
    byId('importStatus').textContent=valid+' 条可导入，'+(previewRows.length-valid)+' 条有误。确认后只添加有效记录。';
    const button=byId('commitImport');button.disabled=!valid;button.textContent='确认导入 '+valid+' 人';
  }
  function commitImport(){
    if(!previewRows)return;
    const valid=previewRows.filter(row=>!row.error);
    if(!valid.length)return;
    try{
      transaction(next=>{for(const row of valid)EventPlayers.savePlayer(next,selectedTeam,row)});
      resetPreview();importer.close();render();message('已导入 '+valid.length+' 名球员');
    }catch(error){resetPreview(error.message+'，请重新预览。')}
  }
  async function printRoster(){
    const area=byId('rosterPrint'),team=profile(),roster=EventPlayers.teamRoster(S,selectedTeam);
    const heading=document.createElement('div');heading.className='roster-heading';
    if(team.logo){const logo=document.createElement('img');logo.src=team.logo;logo.alt='队徽';heading.append(logo)}
    const title=document.createElement('div'),h1=document.createElement('h1'),h2=document.createElement('h2');
    h1.textContent=(S.name||'未命名赛事')+' · 球员参赛名单';h2.textContent=S.teams[S.teamIds.indexOf(selectedTeam)];
    title.append(h1,h2);heading.append(title);
    const meta=document.createElement('p');
    meta.textContent='领队：'+(team.leader||'—')+'　教练：'+(team.coach||'—')+'　打印日期：'+new Date().toLocaleDateString('zh-CN');
    const table=document.createElement('table'),head=table.createTHead().insertRow();
    for(const label of ['号码','姓名','位置','门将','队长','可参赛','资格状态']){
      const cell=document.createElement('th');cell.scope='col';cell.textContent=label;head.append(cell);
    }
    const body=table.createTBody();
    for(const player of roster){
      const row=body.insertRow();
      for(const value of [player.number,player.name,player.position,player.goalkeeper?'是':'—',player.captain?'是':'—',player.eligible?'是':'否',player.eligibility])row.insertCell().textContent=value;
    }
    const signature=document.createElement('div');signature.className='roster-signatures';
    signature.innerHTML='<span>领队签字：____________</span><span>赛事管理员签字：____________</span>';
    area.replaceChildren(heading,meta,table,signature);
    const logo=area.querySelector('img');if(logo)await logo.decode().catch(()=>logo.remove());
    document.body.classList.add('roster-print');window.print();
  }
  return {mount,show,transaction};
})();
