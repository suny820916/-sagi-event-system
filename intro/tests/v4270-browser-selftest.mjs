import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const ROOT=process.cwd();
const PORT=4174;
const HOME='新疆塔城地区青年足球俱乐部';
const AWAY='ALTAI YOUTH FOOTBALL CLUB';
const crest=(fill,label)=>'data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120"><path d="M60 4 108 22v38c0 31-20 48-48 56C32 108 12 91 12 60V22Z" fill="'+fill+'"/><text x="60" y="70" text-anchor="middle" font-size="30" font-family="Arial" font-weight="900" fill="white">'+label+'</text></svg>');
const HOME_CREST=crest('#0c8b55','H');
const AWAY_CREST=crest('#3157b7','A');
let seq=1,vmixCommands=[],matchdayPosts=[],graphics=makeGraphics();

function makeGraphics(overrides={}){
 return {
  commandId:'g_'+(seq++),visualVersion:'V4.27.3-SELFTEST',
  scoreboardVisible:true,scoreboardFrozen:false,scoreTheme:'sagi-pro',competition:'TORANHE CUP',
  home:HOME,away:AWAY,homeShort:HOME,awayShort:AWAY,
  homeCrest:HOME_CREST,awayCrest:AWAY_CREST,eventLogo:'',
  homeColor:'#0c8b55',awayColor:'#3157b7',accentColor:'#20ed82',
  homeScore:0,awayScore:0,homePen:0,awayPen:0,homeRedCards:0,awayRedCards:0,stoppageTime:'+3',
  clock:{period:'2H',baseSeconds:5480,running:false,startedAt:null},
  penaltyShootout:{started:false,finished:false,history:[],rounds:5,currentRound:1,nextSide:'HOME'},
  simplePenalty:{visible:false,home:0,away:0,history:[],round:1},
  event:{type:'CLEAR_EVENT'},...overrides
 };
}
function makeValidRoster(prefix){
 const roles=[['1','GK','GK'],['2','DF','RB'],['3','DF','LB'],['4','DF','CB'],['5','DF','CB'],['6','MF','CM'],['8','MF','CM'],['10','MF','AM'],['7','FW','RW'],['9','FW','ST'],['11','FW','LW']];
 return roles.map(([number,role,position],i)=>({id:prefix+(i+1),name:prefix.toUpperCase()+' PLAYER '+(i+1),number,squadType:'STARTER',role,position,captain:i===3}));
}
function makeStoredProject(id='selftest_project_4273'){
 const homeRoster=makeValidRoster('h'),awayRoster=makeValidRoster('a'),projectPhoto='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#067347"/></svg>');
 const meta={competition:'TORANHE PROJECT CUP',round:'FINAL',home:'PROJECT HOME FC',away:'PROJECT AWAY FC',kickoff:'',venue:''};
 const core={activeSide:'HOME',matchConfig:{mode:'11',playerCount:11},package:{...meta,matchFormat:{mode:'11',playerCount:11}},teams:{HOME:{formation:'4-3-3',customPositions:{},roster:homeRoster},AWAY:{formation:'4-3-3',customPositions:{},roster:awayRoster}}};
 const matchday={homeScore:3,awayScore:1,scoreboardVisible:true,scoreboardFrozen:false,period:'2H',clockBase:4020,clockRunning:false,clockStartedAt:0,lastEvent:null,eventLog:[],replayMarkers:[],homeColor:'#0c8b55',awayColor:'#3157b7',accentColor:'#20ed82',homeShort:'PHF',awayShort:'PAF',homeRedCards:0,awayRedCards:0,homePen:0,awayPen:0,penaltyShootout:{started:false,rounds:5,firstSide:'HOME',history:[],winner:'',finished:false},simplePenalty:{visible:false,home:0,away:0,history:[],slots:5},stoppageTime:'',scoreTheme:'sagi-pro',overlayVisible:false,matchMeta:meta,savedAt:Date.now()};
 return{id,name:'SELFTEST STORED MATCH',savedAt:Date.now(),meta,core:JSON.stringify(core),show:'',matchday:JSON.stringify(matchday),vmix:JSON.stringify({cam1:'1',cam2:'2',drone:'',replay:'4',graphics:'5',transition:'Cut',duration:0,overlay:'1',cam1Role:'MAIN_WIDE',cam2Role:'SIDELINE_CLOSE',droneRole:'DRONE',replayRole:'REPLAY'}),assets:{homeCrest:HOME_CREST,awayCrest:AWAY_CREST,stadium:'',eventLogo:'',photos:{HOME:{h1:projectPhoto},AWAY:{}}}}
}
function json(res,obj,status=200){const body=JSON.stringify(obj);res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Access-Control-Allow-Origin':'*'});res.end(body)}
function text(res,body,type='text/plain; charset=utf-8',status=200){res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','Access-Control-Allow-Origin':'*'});res.end(body)}
function mime(p){if(p.endsWith('.html'))return'text/html; charset=utf-8';if(p.endsWith('.js')||p.endsWith('.mjs'))return'text/javascript; charset=utf-8';if(p.endsWith('.css'))return'text/css; charset=utf-8';if(p.endsWith('.svg'))return'image/svg+xml';if(p.endsWith('.png'))return'image/png';return'application/octet-stream'}
function readBody(req){return new Promise((resolve,reject)=>{let d='';req.setEncoding('utf8');req.on('data',c=>d+=c);req.on('end',()=>resolve(d));req.on('error',reject)})}
const server=http.createServer(async(req,res)=>{
 const u=new URL(req.url,'http://127.0.0.1:'+PORT);
 try{
  if(u.pathname==='/api/state')return json(res,{lineupIntro:null});
  if(u.pathname==='/api/matchday'&&req.method==='GET')return json(res,graphics);
  if(u.pathname==='/api/matchday'&&req.method==='POST'){const b=await readBody(req);try{graphics=JSON.parse(b)||graphics;matchdayPosts.push(graphics)}catch{}return json(res,{ok:true})}
  if(u.pathname==='/api/vmix/status')return json(res,{ok:true,active:'1',preview:'2',inputs:[{number:'1',key:'cam1',type:'Camera',title:'CAM 1',state:'Running'},{number:'2',key:'cam2',type:'Camera',title:'CAM 2',state:'Running'},{number:'4',key:'replay',type:'Video',title:'REPLAY',state:'Running'},{number:'5',key:'gfx',type:'Browser',title:'SAGI Browser',state:'Running'}],overlays:[]});
  if(u.pathname==='/api/vmix'&&req.method==='POST'){const b=await readBody(req);let cmd={};try{cmd=JSON.parse(b)}catch{}vmixCommands.push(cmd);return json(res,{ok:true,command:cmd})}
  if(u.pathname==='/api/projects')return json(res,{projects:[]});
  if(u.pathname==='/health')return json(res,{ok:true,port:PORT});
  if(u.pathname==='/')return text(res,'SAGI V4.27.3 SELFTEST');
  const rel=decodeURIComponent(u.pathname).replace(/^\/+/,'');const file=path.resolve(ROOT,rel);
  if(!file.startsWith(ROOT)||!fs.existsSync(file)||fs.statSync(file).isDirectory())return text(res,'Not found','text/plain',404);
  res.writeHead(200,{'Content-Type':mime(file),'Cache-Control':'no-store','Access-Control-Allow-Origin':'*'});res.end(fs.readFileSync(file));
 }catch(e){return text(res,String(e?.stack||e),'text/plain',500)}
});
function assert(cond,msg){if(!cond)throw new Error('ASSERT FAILED: '+msg)}
const wait=ms=>new Promise(r=>setTimeout(r,ms));

server.listen(PORT,'127.0.0.1',async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:1920,height:1080}});
 const pageErrors=[];page.on('pageerror',e=>pageErrors.push(String(e)));
 try{
  console.log('TEST 1: regular TORANHE scorebug composition');
  await page.goto('http://127.0.0.1:'+PORT+'/intro/vmix-v45-lan.html',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('on'),null,{timeout:8000});
  await wait(700);
  const regular=await page.evaluate(({HOME,AWAY})=>{
   const bug=document.querySelector('#scoreBug'),h=document.querySelector('#sbHome'),a=document.querySelector('#sbAway'),mid=document.querySelector('.sbMid'),brand=document.querySelector('.sbEventBrand'),logo=document.querySelector('#sbEventLogo'),burst=document.querySelector('#sbGoalBurst'),stop=document.querySelector('#sbStoppage');
   const br=bug.getBoundingClientRect(),hr=h.getBoundingClientRect(),ar=a.getBoundingClientRect(),mr=mid.getBoundingClientRect(),brandr=brand.getBoundingClientRect(),logoStyle=getComputedStyle(logo);
   return {home:h.textContent,away:a.textContent,homeOverflow:getComputedStyle(h).textOverflow,awayOverflow:getComputedStyle(a).textOverflow,homeFont:parseFloat(getComputedStyle(h).fontSize),awayFont:parseFloat(getComputedStyle(a).fontSize),homeInside:hr.left>=br.left-1&&hr.right<=br.right+1,awayInside:ar.left>=br.left-1&&ar.right<=br.right+1,bugRight:br.right,midTop:mr.top,bugTop:br.top,bugHeight:br.height,brandWidth:brandr.width,logoWidth:logo.getBoundingClientRect().width,logoSrc:logo.getAttribute('src')||'',logoDisplay:logoStyle.display,stopText:stop.textContent,stopDisplay:getComputedStyle(stop).display,burstWidth:burst.getBoundingClientRect().width,goalExpand:bug.classList.contains('goalExpand'),paper:getComputedStyle(document.querySelector('.sbTeamBlock.home')).backgroundColor};
  },{HOME,AWAY});
  assert(regular.home===HOME&&regular.away===AWAY,'team names changed');
  assert(regular.homeOverflow!=='ellipsis'&&regular.awayOverflow!=='ellipsis','ellipsis returned');
  assert(regular.homeFont>=11&&regular.awayFont>=11,'team name below readable floor');
  assert(regular.homeInside&&regular.awayInside,'team name clipped outside main scorebar');
  assert(regular.bugRight<=1918,'regular scorebar exceeds frame');
  assert(regular.midTop>=regular.bugTop+regular.bugHeight-1,'clock ribbon is not below main scorebar');
  assert(regular.brandWidth>=60&&regular.logoWidth>=60,'event logo is not visually large enough');
  assert(regular.logoSrc.startsWith('data:image/svg+xml'),'offline TORANHE event logo is not embedded');
  assert(regular.logoDisplay!=='none','event logo hidden');
  assert(regular.stopText==='+3'&&regular.stopDisplay!=='none','stoppage-time ribbon missing');
  assert(regular.burstWidth<=2&&!regular.goalExpand,'goal panel visible during regular play');
  await page.screenshot({path:'selftest-artifacts/01-regular-toranhe-scorebug.png'});

  console.log('TEST 2: HOME goal = enlarged HOME crest + complete GOAL + lower player card');
  const photo='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="220"><rect width="100%" height="100%" fill="#17202a"/><circle cx="90" cy="70" r="35" fill="#d5a97a"/><rect x="45" y="110" width="90" height="105" rx="18" fill="#0c8b55"/></svg>');
  graphics=makeGraphics({homeScore:1,event:{type:'GOAL',side:'HOME',team:HOME,at:"91'",player:{number:'9',name:'TEST STRIKER',photo}}});
  await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('goalExpand'),null,{timeout:5000});await wait(1100);
  const homeGoal=await page.evaluate(({HOME_CREST})=>{
   const burst=document.querySelector('#sbGoalBurst'),word=document.querySelector('.sbGoalWord'),gc=document.querySelector('#sbGoalCrest'),rc=document.querySelector('#sbHomeCrest'),card=document.querySelector('#eventCard'),photo=document.querySelector('#eventPhoto'),rr=burst.getBoundingClientRect();
   return {letters:word.textContent.replace(/\s/g,''),ops:[...word.querySelectorAll('span')].map(x=>parseFloat(getComputedStyle(x).opacity)),burstWidth:rr.width,burstRight:rr.right,goalCrestSrc:gc.getAttribute('src')||'',goalCrestWidth:gc.getBoundingClientRect().width,regularCrestWidth:rc.getBoundingClientRect().width,eventGoal:card.classList.contains('on')&&card.classList.contains('goal'),photo:photo.getAttribute('src')||''};
  },{HOME_CREST});
  assert(homeGoal.letters==='GOAL'&&homeGoal.ops.every(x=>x>.9),'GOAL letters incomplete');
  assert(homeGoal.burstWidth>=320&&homeGoal.burstRight<=1918,'HOME goal panel size/frame failure');
  assert(homeGoal.goalCrestSrc===HOME_CREST,'HOME goal did not use HOME crest');
  assert(homeGoal.goalCrestWidth>homeGoal.regularCrestWidth*2,'scoring crest did not enlarge');
  assert(homeGoal.eventGoal&&homeGoal.photo.startsWith('data:image/svg+xml'),'lower goal-player card/photo missing');
  await page.screenshot({path:'selftest-artifacts/02-home-goal-expanded.png'});

  await wait(3500);
  const collapsed=await page.evaluate(()=>({expand:document.querySelector('#scoreBug').classList.contains('goalExpand'),width:document.querySelector('#sbGoalBurst').getBoundingClientRect().width,on:document.querySelector('#scoreBug').classList.contains('on')}));
  assert(!collapsed.expand&&collapsed.width<=2&&collapsed.on,'goal panel did not return to regular scorebar');
  await page.screenshot({path:'selftest-artifacts/03-goal-collapsed.png'});

  console.log('TEST 3: AWAY goal uses AWAY crest');
  graphics=makeGraphics({homeScore:1,awayScore:1,event:{type:'GOAL',side:'AWAY',team:AWAY,at:"92'",player:{number:'10',name:'AWAY STRIKER',photo}}});
  await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('goalExpand'),null,{timeout:5000});await wait(900);
  const awayGoal=await page.evaluate(()=>({crest:document.querySelector('#sbGoalCrest').getAttribute('src')||'',letters:document.querySelector('.sbGoalWord').textContent.replace(/\s/g,''),width:document.querySelector('#sbGoalBurst').getBoundingClientRect().width}));
  assert(awayGoal.crest===AWAY_CREST,'AWAY goal did not use AWAY crest');
  assert(awayGoal.letters==='GOAL'&&awayGoal.width>=320,'AWAY GOAL reveal failed');
  await page.screenshot({path:'selftest-artifacts/04-away-goal-expanded.png'});

  console.log('TEST 4A: yellow and red cards use event colors, not team colors');
  graphics=makeGraphics({homeColor:'#d8b55b',event:{type:'YELLOW',side:'HOME',team:HOME,at:"55'",player:{number:'8',name:'CARD TEST'}}});
  await page.waitForFunction(()=>document.querySelector('#eventCard')?.classList.contains('yellow'),null,{timeout:5000});await wait(500);
  const yellowCard=await page.evaluate(()=>({bg:getComputedStyle(document.querySelector('#eventIcon')).backgroundColor,kicker:getComputedStyle(document.querySelector('#eventKicker')).color,label:document.querySelector('#eventKicker').textContent,cls:document.querySelector('#eventCard').className}));
  assert(yellowCard.label==='黄牌'&&yellowCard.cls.includes('yellow'),'yellow card event class/label wrong');
  assert(yellowCard.bg==='rgb(242, 213, 54)'&&yellowCard.kicker==='rgb(242, 213, 54)','yellow card inherited team color: '+JSON.stringify(yellowCard));
  await page.screenshot({path:'selftest-artifacts/04a-yellow-card.png'});

  graphics=makeGraphics({homeColor:'#d8b55b',event:{type:'RED',side:'HOME',team:HOME,at:"56'",player:{number:'8',name:'CARD TEST'}}});
  await page.waitForFunction(()=>document.querySelector('#eventCard')?.classList.contains('red'),null,{timeout:5000});await wait(500);
  const redCard=await page.evaluate(()=>({bg:getComputedStyle(document.querySelector('#eventIcon')).backgroundColor,kicker:getComputedStyle(document.querySelector('#eventKicker')).color,label:document.querySelector('#eventKicker').textContent,cls:document.querySelector('#eventCard').className}));
  assert(redCard.label==='红牌'&&redCard.cls.includes('red'),'red card event class/label wrong');
  assert(redCard.bg==='rgb(227, 52, 64)'&&redCard.kicker==='rgb(227, 52, 64)','red card inherited yellow/team color: '+JSON.stringify(redCard));
  await page.screenshot({path:'selftest-artifacts/04b-red-card.png'});

  console.log('TEST 4: penalty shootout remains isolated and supports >5 rounds');
  const hist=[['HOME','GOAL'],['AWAY','GOAL'],['HOME','GOAL'],['AWAY','MISS'],['HOME','MISS'],['AWAY','GOAL'],['HOME','GOAL'],['AWAY','GOAL'],['HOME','GOAL'],['AWAY','GOAL'],['HOME','MISS'],['AWAY','GOAL']].map(([side,result],i)=>({side,result,at:String(i)}));
  graphics=makeGraphics({homeScore:1,awayScore:1,clock:{period:'PEN',baseSeconds:0,running:false,startedAt:null},penaltyShootout:{started:true,finished:false,history:hist,rounds:5,currentRound:6,nextSide:'HOME',homeGoals:4,awayGoals:5},simplePenalty:{visible:false,history:[]},event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#simplePenaltyBoard')?.classList.contains('on'),null,{timeout:5000});await wait(500);
  const pk=await page.evaluate(({HOME,AWAY})=>{const board=document.querySelector('#simplePenaltyBoard'),bug=document.querySelector('#scoreBug'),hn=document.querySelector('#spbHomeName'),an=document.querySelector('#spbAwayName');return{home:hn.textContent,away:an.textContent,phase:document.querySelector('#spbPhase').textContent,homeDots:document.querySelectorAll('#spbHomeDots .spbDot').length,awayDots:document.querySelectorAll('#spbAwayDots .spbDot').length,misses:document.querySelectorAll('.spbDot.miss').length,boardOn:board.classList.contains('on'),scorebugOn:bug.classList.contains('on'),homeScore:document.querySelector('#spbHomeScore').textContent,awayScore:document.querySelector('#spbAwayScore').textContent}}, {HOME,AWAY});
  assert(pk.boardOn&&!pk.scorebugOn,'PK board not isolated');
  assert(pk.home===HOME&&pk.away===AWAY,'PK names changed');
  assert(pk.phase.includes('突然死亡')&&pk.homeDots===5&&pk.awayDots===5&&pk.misses>=1,'PK >5 round/miss display failed');
  assert(pk.homeScore==='4'&&pk.awayScore==='5','PK scores unsynchronized');
  await page.screenshot({path:'selftest-artifacts/05-penalty-round6.png'});

  console.log('TEST 5: two-camera manual switching still sends Input 1 -> Input 2');
  vmixCommands=[];
  await page.evaluate(()=>localStorage.setItem('sagi_vmix_director_v42',JSON.stringify({cam1:'1',cam2:'2',drone:'',replay:'',graphics:'5',transition:'Cut',duration:0,overlay:'1',cam1Role:'MAIN_WIDE',cam2Role:'SIDELINE_CLOSE',droneRole:'DRONE',replayRole:'REPLAY'})));
  await page.goto('http://127.0.0.1:'+PORT+'/intro/v45-lan.html',{waitUntil:'domcontentloaded'});await wait(1800);
  await page.locator('#matchCompetition').fill('SAGI SELF TEST CUP');await page.locator('#matchHome').fill('SELF TEST HOME');await page.locator('#matchAway').fill('SELF TEST AWAY');await page.locator('#matchKickoff').fill('2026-11-17T20:00');await page.locator('#matchVenue').fill('SELF TEST STADIUM');
  assert(await page.locator('#vdCam1').inputValue()==='1'&&await page.locator('#vdCam2').inputValue()==='2','saved camera mapping not restored');
  await page.click('#setupValidateBtn');await page.waitForFunction(()=>!document.querySelector('#setupReadyBtn')?.disabled,null,{timeout:5000});await page.click('#setupReadyBtn');await page.waitForFunction(()=>document.querySelector('#setupReadyBadge')?.textContent.includes('可以播出'),null,{timeout:5000});
  await page.click('#vdTakeCam1');await page.waitForFunction(()=>document.querySelector('#vdStatus')?.textContent.includes('已执行'),null,{timeout:4000});await page.click('#vdTakeCam2');await wait(800);
  const cuts=vmixCommands.filter(x=>['Cut','Fade','Stinger1'].includes(x.functionName));
  assert(cuts.length===2&&String(cuts[0].input)==='1'&&String(cuts[1].input)==='2','camera switching wrong: '+JSON.stringify(cuts));
  await page.screenshot({path:'selftest-artifacts/06-two-camera-control.png'});

  console.log('TEST 6: event-logo replay stinger visual');
  const replayPage=await browser.newPage({viewport:{width:1920,height:1080}});
  const EVENT_LOGO='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300"><circle cx="150" cy="150" r="130" fill="#067347"/><path d="M80 170 150 55l70 115-70 75Z" fill="#6cff3f"/></svg>');
  graphics=makeGraphics({eventLogo:EVENT_LOGO,event:{type:'REPLAY_STINGER',phase:'IN',title:'INSTANT REPLAY'}});
  await replayPage.goto('http://127.0.0.1:'+PORT+'/intro/vmix-v45-lan.html',{waitUntil:'domcontentloaded'});
  await replayPage.waitForFunction(()=>document.querySelector('#replayStinger')?.classList.contains('on'),null,{timeout:5000});
  await wait(520);
  const replayVisual=await replayPage.evaluate(()=>{const s=document.querySelector('#replayStinger'),logo=document.querySelector('#rsLogo');return{on:s.classList.contains('on'),src:logo.getAttribute('src')||'',title:document.querySelector('#rsTitle').textContent,kicker:document.querySelector('#rsKicker').textContent,left:document.querySelector('.rsLeft').getBoundingClientRect().width,right:document.querySelector('.rsRight').getBoundingClientRect().width,opacity:parseFloat(getComputedStyle(document.querySelector('.rsCenter')).opacity)}});
  assert(replayVisual.on&&replayVisual.src.startsWith('data:image/svg+xml'),'replay stinger event logo missing');
  assert(replayVisual.title==='INSTANT REPLAY'&&replayVisual.kicker==='精彩回放','replay labels wrong');
  assert(replayVisual.left>1000&&replayVisual.right>1000&&replayVisual.opacity>.8,'replay stinger did not fully cover/display');
  await replayPage.screenshot({path:'selftest-artifacts/07-replay-stinger-visual.png'});
  await wait(1100);
  assert(!(await replayPage.locator('#replayStinger').evaluate(el=>el.classList.contains('on'))),'replay stinger did not auto clear');
  await replayPage.close();

  console.log('TEST 7: manual replay uses logo stinger IN, then OUT back to live');
  vmixCommands=[];matchdayPosts=[];
  await page.evaluate(()=>localStorage.setItem('sagi_vmix_director_v42',JSON.stringify({cam1:'1',cam2:'2',drone:'',replay:'4',graphics:'5',transition:'Cut',duration:0,overlay:'1',cam1Role:'MAIN_WIDE',cam2Role:'SIDELINE_CLOSE',droneRole:'DRONE',replayRole:'REPLAY'})));
  await page.reload({waitUntil:'domcontentloaded'});await wait(1800);
  await page.locator('#matchCompetition').fill('SAGI SELF TEST CUP');await page.locator('#matchHome').fill('SELF TEST HOME');await page.locator('#matchAway').fill('SELF TEST AWAY');await page.locator('#matchKickoff').fill('2026-11-17T20:00');await page.locator('#matchVenue').fill('SELF TEST STADIUM');
  await page.click('#setupValidateBtn');await page.waitForFunction(()=>!document.querySelector('#setupReadyBtn')?.disabled,null,{timeout:5000});await page.click('#setupReadyBtn');
  await page.click('#vdTakeReplay');await wait(1900);
  await page.click('#vdTakeCam1');await wait(1900);
  const replayCuts=vmixCommands.filter(x=>['Cut','Fade','Stinger1'].includes(x.functionName));
  const replayEvents=matchdayPosts.map(x=>x&&x.event).filter(Boolean);
  assert(replayCuts.length>=2&&String(replayCuts[0].input)==='4'&&String(replayCuts[1].input)==='1','replay camera sequence wrong: '+JSON.stringify(replayCuts));
  assert(replayEvents.some(e=>e.type==='REPLAY_STINGER'&&e.phase==='IN'),'missing replay IN stinger event');
  assert(replayEvents.some(e=>e.type==='REPLAY_STINGER'&&e.phase==='OUT'),'missing replay OUT stinger event');
  assert(replayEvents.filter(e=>e.type==='CLEAR_EVENT').length>=2,'replay stinger clear events missing');
  await page.screenshot({path:'selftest-artifacts/08-replay-control.png'});

  console.log('TEST 8: stored project load is deterministic and optional match metadata does not block READY');
  graphics=makeGraphics({commandId:'stale_bridge_state',home:'STALE BRIDGE HOME',away:'STALE BRIDGE AWAY',homeScore:9,awayScore:9,scoreboardVisible:true,clock:{period:'2H',baseSeconds:5399,running:false,startedAt:null},event:{type:'CLEAR_EVENT'}});
  const storedProject=makeStoredProject();
  await page.evaluate(({storedProject})=>{
    localStorage.setItem('sagi_match_projects_v44',JSON.stringify([storedProject]));
    localStorage.removeItem('sagi_player_intro_v40');
    localStorage.removeItem('sagi_matchday_graphics_v47');
  },{storedProject});
  await page.reload({waitUntil:'domcontentloaded'});await wait(2200);
  await page.selectOption('#projectSelect',storedProject.id);
  await page.click('#projectLoadBtn');
  await page.waitForFunction(()=>document.querySelector('#projectLoadBtn')?.textContent==='读取项目'&&document.querySelector('#projectName')?.value==='SELFTEST STORED MATCH',null,{timeout:8000});
  await page.click('#setupValidateBtn');await wait(350);
  const loadedProject=await page.evaluate(()=>({
    competition:document.querySelector('#matchCompetition').value,
    home:document.querySelector('#matchHome').value,
    away:document.querySelector('#matchAway').value,
    kickoff:document.querySelector('#matchKickoff').value,
    venue:document.querySelector('#matchVenue').value,
    readyDisabled:document.querySelector('#setupReadyBtn').disabled,
    summary:document.querySelector('#setupSummary').textContent,
    mdHomeScore:document.querySelector('#mdHomeScore').textContent,
    mdAwayScore:document.querySelector('#mdAwayScore').textContent,
    localProjects:localStorage.getItem('sagi_match_projects_v44')||''
  }));
  assert(loadedProject.competition==='TORANHE PROJECT CUP'&&loadedProject.home==='PROJECT HOME FC'&&loadedProject.away==='PROJECT AWAY FC','stored project match identity was not restored: '+JSON.stringify(loadedProject));
  assert(loadedProject.mdHomeScore==='3'&&loadedProject.mdAwayScore==='1','selected project matchday was overwritten by stale Bridge state: '+loadedProject.mdHomeScore+'-'+loadedProject.mdAwayScore);
  assert(!loadedProject.localProjects.includes('data:image/svg+xml'),'large project photos were duplicated into synchronous localStorage');

  // Whatever defaults the UI chooses for old projects, explicitly clear the optional fields
  // and verify that daily broadcast READY remains available.
  await page.locator('#matchKickoff').fill('');
  await page.locator('#matchVenue').fill('');
  await page.click('#setupValidateBtn');await wait(300);
  const optionalCheck=await page.evaluate(()=>({
    kickoff:document.querySelector('#matchKickoff').value,
    venue:document.querySelector('#matchVenue').value,
    readyDisabled:document.querySelector('#setupReadyBtn').disabled,
    summary:document.querySelector('#setupSummary').textContent
  }));
  assert(optionalCheck.kickoff===''&&optionalCheck.venue==='','optional metadata fields could not be cleared');
  assert(!optionalCheck.readyDisabled&&optionalCheck.summary.includes('赛前检查通过')&&optionalCheck.summary.includes('不影响'),'optional time/venue incorrectly blocked READY: '+optionalCheck.summary);

  // Manual restore from Bridge must also reject a different fixture instead of overwriting 3-1.
  await page.locator('#mmRestoreState').click({force:true});await wait(500);
  const afterStaleRestore=await page.evaluate(()=>({home:document.querySelector('#mdHomeScore').textContent,away:document.querySelector('#mdAwayScore').textContent,homeName:document.querySelector('#matchHome').value,awayName:document.querySelector('#matchAway').value}));
  assert(afterStaleRestore.home==='3'&&afterStaleRestore.away==='1','manual stale Bridge restore overwrote selected project: '+JSON.stringify(afterStaleRestore));
  assert(afterStaleRestore.homeName==='PROJECT HOME FC'&&afterStaleRestore.awayName==='PROJECT AWAY FC','stale Bridge restore changed selected fixture identity');
  await page.screenshot({path:'selftest-artifacts/09-project-load-ready.png'});

  console.log('TEST 9: running clock updates clock only without repeatedly repainting heavy match controls');
  await page.click('#setupReadyBtn');await page.waitForFunction(()=>document.querySelector('#setupReadyBadge')?.textContent.includes('可以播出'),null,{timeout:3000});
  const perfStart=await page.evaluate(()=>{
    window.__sagiPerf={clock:0,penalty:0,log:0};
    const watch=(sel,key,opt={childList:true,subtree:true,characterData:true})=>{const el=document.querySelector(sel);if(!el)return null;const ob=new MutationObserver(ms=>window.__sagiPerf[key]+=ms.length);ob.observe(el,opt);return ob};
    window.__sagiPerfObservers=[watch('#mdClock','clock'),watch('#spHomeDots','penalty'),watch('#mdEventLog','log')].filter(Boolean);
    return !!document.querySelector('#mdClockStart');
  });
  assert(perfStart,'clock start button missing');
  await page.click('#mdClockStart');await wait(1800);
  const perf=await page.evaluate(()=>{
    for(const ob of window.__sagiPerfObservers||[])ob.disconnect();
    return window.__sagiPerf;
  });
  assert(perf.clock>=2,'running clock did not visibly update');
  assert(perf.penalty<=2&&perf.log<=1,'clock loop is still repainting heavy controls: '+JSON.stringify(perf));
  await page.screenshot({path:'selftest-artifacts/10-clock-stability.png'});

  assert(pageErrors.length===0,'browser page errors: '+pageErrors.join(' | '));
  const report={ok:true,build:'V4.27.3',testedAt:new Date().toISOString(),tests:['regular white score ribbon + lower time/stoppage ribbon + TORANHE event logo','HOME goal enlarged HOME crest + complete GOAL + lower player card + collapse','AWAY goal enlarged AWAY crest','yellow/red card event colors locked independently of team colors','penalty >5 rounds/sudden death/miss/scores','two-camera Input 1 -> Input 2','event-logo replay stinger visual','manual replay stinger IN -> Input 4 -> OUT -> Input 1','stored project load wins over stale Bridge + optional time/venue do not block READY','clock-only refresh avoids repeated heavy match-control repaints'],vmixCommands:cuts};
  fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 }catch(e){
  fs.mkdirSync('selftest-artifacts',{recursive:true});try{await page.screenshot({path:'selftest-artifacts/FAIL.png',fullPage:true})}catch{}
  fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify({ok:false,error:String(e?.stack||e),pageErrors},null,2));console.error(e?.stack||e);process.exitCode=1;
 }finally{await browser.close();server.close()}
});