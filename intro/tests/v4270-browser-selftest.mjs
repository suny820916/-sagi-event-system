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
let seq=1,vmixCommands=[],matchdayPosts=[],graphics=makeGraphics(),reorderMatchdayWrites=false,failNextMatchdayPosts=0,failNextMatchdayGets=0;

function makeGraphics(overrides={}){
 return {
  commandId:'g_'+(seq++),revision:seq,fixtureKey:'selftest|'+HOME+'|'+AWAY,visualVersion:'V4.30.7-SELFTEST',
  scoreboardVisible:true,scoreboardFrozen:false,scoreTheme:'sagi-pro',competition:'TORANHE CUP',
  home:HOME,away:AWAY,homeShort:HOME,awayShort:AWAY,scoreHomeName:'新疆塔城地区',scoreAwayName:'AYFC',
  homeCrest:HOME_CREST,awayCrest:AWAY_CREST,eventLogo:'',
  homeColor:'#0c8b55',awayColor:'#3157b7',accentColor:'#20ed82',
  homeScore:0,awayScore:0,homePen:0,awayPen:0,homeRedCards:0,awayRedCards:0,stoppageTime:'',
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
function makeStoredProject(id='selftest_project_4300'){
 const homeRoster=makeValidRoster('h'),awayRoster=makeValidRoster('a'),projectPhoto='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#067347"/></svg>');
 const meta={competition:'TORANHE PROJECT CUP',round:'FINAL',home:'乌苏叶克备',away:'IPF',kickoff:'',venue:''};
 const core={activeSide:'HOME',matchConfig:{mode:'11',playerCount:11},package:{...meta,matchFormat:{mode:'11',playerCount:11}},teams:{HOME:{formation:'4-3-3',customPositions:{},roster:homeRoster},AWAY:{formation:'4-3-3',customPositions:{},roster:awayRoster}}};
 const matchday={homeScore:3,awayScore:1,scoreboardVisible:true,scoreboardFrozen:false,period:'2H',clockBase:4020,clockRunning:false,clockStartedAt:0,lastEvent:null,eventLog:[],replayMarkers:[],homeColor:'#0c8b55',awayColor:'#3157b7',accentColor:'#20ed82',homeShort:'少林足球',awayShort:'旧客队',homeRedCards:0,awayRedCards:0,homePen:0,awayPen:0,penaltyShootout:{started:false,rounds:5,firstSide:'HOME',history:[],winner:'',finished:false},simplePenalty:{visible:false,home:0,away:0,history:[],slots:5},stoppageTime:'',scoreTheme:'sagi-pro',overlayVisible:false,matchMeta:meta,savedAt:Date.now()};
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
  if(u.pathname==='/api/matchday'&&req.method==='GET'){if(failNextMatchdayGets>0){failNextMatchdayGets--;return json(res,{ok:false,error:'SIMULATED_TRANSIENT_GET_FAILURE'},503)}return json(res,graphics)}
  if(u.pathname==='/api/matchday'&&req.method==='POST'){const b=await readBody(req);if(failNextMatchdayPosts>0){failNextMatchdayPosts--;return json(res,{ok:false,error:'SIMULATED_TRANSIENT_FAILURE'},503)}try{const next=JSON.parse(b)||graphics;if(reorderMatchdayWrites&&Number(next.homeScore)===5)await new Promise(r=>setTimeout(r,450));graphics=next;matchdayPosts.push(graphics)}catch{}return json(res,{ok:true})}
  if(u.pathname==='/api/vmix/status')return json(res,{ok:true,active:'1',preview:'2',inputs:[{number:'1',key:'cam1',type:'Camera',title:'CAM 1',state:'Running'},{number:'2',key:'cam2',type:'Camera',title:'CAM 2',state:'Running'},{number:'4',key:'replay',type:'Video',title:'REPLAY',state:'Running'},{number:'5',key:'gfx',type:'Browser',title:'SAGI Browser',state:'Running'}],overlays:[]});
  if(u.pathname==='/api/vmix'&&req.method==='POST'){const b=await readBody(req);let cmd={};try{cmd=JSON.parse(b)}catch{}vmixCommands.push(cmd);return json(res,{ok:true,command:cmd})}
  if(u.pathname==='/api/projects')return json(res,{projects:[]});
  if(u.pathname==='/health')return json(res,{ok:true,port:PORT});
  if(u.pathname==='/')return text(res,'SAGI V4.30.7 SELFTEST');
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
 const control=await browser.newPage({viewport:{width:1440,height:1100}});
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
  assert(regular.home==='新疆塔城地区'&&regular.away==='AYFC','broadcast score names changed: '+JSON.stringify({home:regular.home,away:regular.away}));
  assert(regular.homeOverflow!=='ellipsis'&&regular.awayOverflow!=='ellipsis','ellipsis returned');
  assert(regular.homeFont>=11&&regular.awayFont>=11,'team name below readable floor');
  assert(regular.homeInside&&regular.awayInside,'team name clipped outside main scorebar');
  assert((regular.bugRight-42)<=540,'regular scorebar is still too long: '+(regular.bugRight-42));
  assert(regular.midTop>=regular.bugTop+regular.bugHeight-1,'clock ribbon is not below main scorebar');
  assert(regular.brandWidth>=60&&regular.logoWidth>=60,'event logo is not visually large enough');
  assert(regular.logoSrc.startsWith('data:image/svg+xml'),'offline TORANHE event logo is not embedded');
  assert(regular.logoDisplay!=='none','event logo hidden');
  const identityFusion=await page.evaluate(()=>{
    const brand=document.querySelector('.sbEventBrand'),mid=document.querySelector('.sbMid'),home=document.querySelector('.sbTeamBlock.home'),bug=document.querySelector('#scoreBug');
    const br=brand.getBoundingClientRect(),mr=mid.getBoundingClientRect(),hr=home.getBoundingClientRect(),bugr=bug.getBoundingClientRect();
    return{brandH:br.height,brandW:br.width,brandBottom:br.bottom,midTop:mr.top,midLeft:mr.left,brandRight:br.right,homeLeft:hr.left,bugLeft:bugr.left,homeClip:getComputedStyle(home).clipPath};
  });
  assert(identityFusion.brandH>=78&&identityFusion.brandW>=64,'event identity block is not integrated/tall enough: '+JSON.stringify(identityFusion));
  assert(identityFusion.midLeft<=identityFusion.brandRight-4&&Math.abs(identityFusion.midTop-(identityFusion.brandBottom-27))<=2,'clock rail is not fused into event identity: '+JSON.stringify(identityFusion));
  assert(identityFusion.homeLeft<identityFusion.brandRight&&identityFusion.homeClip!=='none','score ribbon does not tuck into event identity: '+JSON.stringify(identityFusion));
  const scorePair=await page.evaluate(()=>{
    const h=document.querySelector('#sbHomeScoreWrap'),a=document.querySelector('#sbAwayScoreWrap'),hc=getComputedStyle(h),ac=getComputedStyle(a),dash=getComputedStyle(h,':before');
    const hr=h.getBoundingClientRect(),ar=a.getBoundingClientRect(),crest=document.querySelector('#sbHomeCrest').getBoundingClientRect(),team=document.querySelector('.sbTeamBlock.home').getBoundingClientRect();
    return{gap:Math.round((ar.left-hr.right)*100)/100,combined:ar.right-hr.left,hBg:hc.backgroundColor,aBg:ac.backgroundColor,dash:dash.content,crestW:crest.width,teamW:team.width};
  });
  assert(Math.abs(scorePair.gap)<=1&&scorePair.combined<=78&&scorePair.hBg===scorePair.aBg&&scorePair.dash.includes('–'),'score pair is not visually unified: '+JSON.stringify(scorePair));
  assert(scorePair.crestW<=24&&scorePair.teamW<=150,'team identity spacing is not compact: '+JSON.stringify(scorePair));
  assert(regular.stopDisplay==='none','added-time block should stay hidden during normal regular play');
  assert(regular.burstWidth<=2&&!regular.goalExpand,'goal panel visible during regular play');
  const scoreHierarchy=await page.evaluate(()=>{
    const phase=document.querySelector('#sbPeriod'),clock=document.querySelector('#sbClock'),mid=document.querySelector('.sbMid'),home=document.querySelector('#sbHome'),away=document.querySelector('#sbAway');
    const cs=getComputedStyle(mid),ps=getComputedStyle(phase);
    return{phase:phase.textContent,phaseDisplay:ps.display,clock:clock.textContent,midTop:parseFloat(cs.top),midHeight:parseFloat(cs.height),midWidth:parseFloat(cs.width),home:home.textContent,away:away.textContent,homeOverflow:getComputedStyle(home).textOverflow,awayOverflow:getComputedStyle(away).textOverflow}
  });
  assert(scoreHierarchy.phaseDisplay==='none'&&scoreHierarchy.midTop>=54&&scoreHierarchy.midHeight>=27&&scoreHierarchy.midWidth<=90,'normal-half score rail is not clock-first/compact: '+JSON.stringify(scoreHierarchy));
  assert(scoreHierarchy.homeOverflow==='clip'&&scoreHierarchy.awayOverflow==='clip','team identity still uses ellipsis: '+JSON.stringify(scoreHierarchy));
  const stageSystem=await page.evaluate(()=>{
    const root=getComputedStyle(document.documentElement),brand=document.querySelector('.sbEventBrand'),match=document.querySelector('.matchCardStage'),evt=document.querySelector('#eventCard');
    const midStyle=getComputedStyle(document.querySelector('.sbMid'));return{blue:root.getPropertyValue('--sagiStageBlue').trim(),brandRadius:parseFloat(getComputedStyle(brand,':before').borderTopLeftRadius),matchRadius:parseFloat(getComputedStyle(match).borderTopLeftRadius),eventRadius:parseFloat(getComputedStyle(evt).borderTopLeftRadius),timeLeftRadius:parseFloat(midStyle.borderBottomLeftRadius),timeRightRadius:parseFloat(midStyle.borderBottomRightRadius)}
  });
  assert(stageSystem.blue==='#071d57'&&stageSystem.brandRadius>=12&&stageSystem.matchRadius>=24&&stageSystem.eventRadius>=14&&stageSystem.timeLeftRadius===0&&stageSystem.timeRightRadius>=8,'SAGI STAGE integrated broadcast system not applied: '+JSON.stringify(stageSystem));
  await page.screenshot({path:'selftest-artifacts/01-regular-toranhe-scorebug.png'});

  console.log('TEST 1A: score change uses restrained vertical roll without moving the clock rail');
  const railBefore=await page.evaluate(()=>{const r=document.querySelector('.sbMid').getBoundingClientRect();return{left:r.left,top:r.top,width:r.width}});
  graphics=makeGraphics({homeScore:1,event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#sbHomeScoreWrap')?.classList.contains('scoreRolling'),null,{timeout:3000});
  const rolling=await page.evaluate(()=>{const w=document.querySelector('#sbHomeScoreWrap'),s=document.querySelector('#sbHomeScore'),r=document.querySelector('.sbMid').getBoundingClientRect();return{old:w.dataset.oldScore,newScore:s.textContent,wrapRolling:w.classList.contains('scoreRolling'),scoreRolling:s.classList.contains('scoreRolling'),rail:{left:r.left,top:r.top,width:r.width}}});
  assert(rolling.old==='0'&&rolling.newScore==='1'&&rolling.wrapRolling&&rolling.scoreRolling,'score roll state missing: '+JSON.stringify(rolling));
  assert(Math.abs(rolling.rail.left-railBefore.left)<1&&Math.abs(rolling.rail.top-railBefore.top)<1,'score change moved clock rail: '+JSON.stringify({before:railBefore,after:rolling.rail}));
  await page.screenshot({path:'selftest-artifacts/01a-score-roll.png'});
  await wait(650);
  const rollDone=await page.evaluate(()=>({wrap:document.querySelector('#sbHomeScoreWrap').classList.contains('scoreRolling'),score:document.querySelector('#sbHomeScore').classList.contains('scoreRolling')}));
  assert(!rollDone.wrap&&!rollDone.score,'score roll did not clean up');
  graphics=makeGraphics({homeScore:0,event:{type:'CLEAR_EVENT'}});await wait(650);

  console.log('TEST 1B: legacy stale short-name cache cannot override current fixture identity');
  graphics=makeGraphics({home:'乌苏叶克备',away:'IPF',homeShort:'少林足球',awayShort:'旧客队',scoreHomeName:'乌苏叶克备',scoreAwayName:'IPF',event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#sbHome')?.textContent==='乌苏叶克备'&&document.querySelector('#sbAway')?.textContent==='IPF',null,{timeout:5000});await wait(300);
  const identityOutput=await page.evaluate(()=>({home:document.querySelector('#sbHome').textContent,away:document.querySelector('#sbAway').textContent}));
  assert(identityOutput.home==='乌苏叶克备'&&identityOutput.away==='IPF','legacy short-name cache overrode vMix output: '+JSON.stringify(identityOutput));
  await page.screenshot({path:'selftest-artifacts/01b-canonical-team-identity.png'});

  console.log('TEST 1C: director can edit broadcast short names without changing canonical fixture identity');
  await control.goto('http://127.0.0.1:'+PORT+'/intro/v45-lan.html',{waitUntil:'domcontentloaded'});
  await control.waitForFunction(()=>document.querySelector('#mdHomeShort')&&document.querySelector('#mdAwayShort'),null,{timeout:8000});
  await wait(300);
  const canonicalBefore=await control.evaluate(()=>({home:document.querySelector('#matchHome').value.trim(),away:document.querySelector('#matchAway').value.trim(),competition:document.querySelector('#matchCompetition').value.trim()}));
  await control.fill('#mdHomeShort','塔城地区');await control.dispatchEvent('#mdHomeShort','change');
  await control.fill('#mdAwayShort','阿勒泰');await control.dispatchEvent('#mdAwayShort','change');await wait(900);
  assert(graphics.home===canonicalBefore.home&&graphics.away===canonicalBefore.away,'editing broadcast name changed canonical fixture identity: '+JSON.stringify({director:canonicalBefore,after:{home:graphics.home,away:graphics.away,fixtureKey:graphics.fixtureKey}}));
  assert(graphics.scoreHomeName==='塔城地区'&&graphics.scoreAwayName==='阿勒泰','broadcast short names were not published: '+JSON.stringify({home:graphics.scoreHomeName,away:graphics.scoreAwayName}));
  await page.waitForFunction(()=>document.querySelector('#sbHome')?.textContent==='塔城地区'&&document.querySelector('#sbAway')?.textContent==='阿勒泰',null,{timeout:5000});
  await page.screenshot({path:'selftest-artifacts/01c-broadcast-short-names.png'});

  console.log('TEST 2: HOME goal = enlarged HOME crest + complete GOAL + lower player card');
  const photo='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="220"><rect width="100%" height="100%" fill="#17202a"/><circle cx="90" cy="70" r="35" fill="#d5a97a"/><rect x="45" y="110" width="90" height="105" rx="18" fill="#0c8b55"/></svg>');
  graphics=makeGraphics({homeScore:1,event:{type:'GOAL',side:'HOME',team:HOME,at:"91'",player:{number:'9',name:'TEST STRIKER',photo}}});
  await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('goalExpand'),null,{timeout:5000});await wait(1100);
  const homeGoal=await page.evaluate(({HOME_CREST})=>{
   const burst=document.querySelector('#sbGoalBurst'),word=document.querySelector('.sbGoalWord'),gc=document.querySelector('#sbGoalCrest'),rc=document.querySelector('#sbHomeCrest'),card=document.querySelector('#eventCard'),photo=document.querySelector('#eventPhoto'),rr=burst.getBoundingClientRect();
   return {letters:word.textContent.replace(/\s/g,''),ops:[...word.querySelectorAll('span')].map(x=>parseFloat(getComputedStyle(x).opacity)),burstWidth:rr.width,burstRight:rr.right,goalCrestSrc:gc.getAttribute('src')||'',goalCrestWidth:gc.getBoundingClientRect().width,regularCrestWidth:rc.getBoundingClientRect().width,eventGoal:card.classList.contains('on')&&card.classList.contains('goal'),photo:photo.getAttribute('src')||''};
  },{HOME_CREST});
  assert(homeGoal.letters==='GOAL'&&homeGoal.ops.every(x=>x>.9),'GOAL letters incomplete');
  assert(homeGoal.burstWidth>=250&&homeGoal.burstRight<=1918,'HOME goal panel size/frame failure');
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
  assert(awayGoal.letters==='GOAL'&&awayGoal.width>=250,'AWAY GOAL reveal failed');
  await page.screenshot({path:'selftest-artifacts/04-away-goal-expanded.png'});

  console.log('TEST 4A: yellow and red cards use real referee-card geometry, event colors and bilingual labels');
  graphics=makeGraphics({homeColor:'#d8b55b',event:{type:'YELLOW',side:'HOME',team:HOME,at:"55'",player:{number:'8',name:'CARD TEST'}}});
  await page.waitForFunction(()=>document.querySelector('#eventCard')?.classList.contains('yellow'),null,{timeout:5000});await wait(500);
  const yellowCard=await page.evaluate(()=>{const el=document.querySelector('#eventIcon'),cs=getComputedStyle(el);return{bg:cs.backgroundColor,kicker:getComputedStyle(document.querySelector('#eventKicker')).color,label:document.querySelector('#eventKicker').textContent,cls:document.querySelector('#eventCard').className,w:parseFloat(cs.width),h:parseFloat(cs.height),radius:parseFloat(cs.borderRadius),glyph:el.textContent.trim()}});
  assert(yellowCard.label==='黄牌 · YELLOW CARD'&&yellowCard.cls.includes('yellow'),'yellow card event class/label wrong');
  assert(yellowCard.bg==='rgb(242, 213, 54)'&&yellowCard.kicker==='rgb(242, 213, 54)','yellow card inherited team color: '+JSON.stringify(yellowCard));
  assert(yellowCard.h>=80&&yellowCard.w<=60&&yellowCard.h/yellowCard.w>=1.35&&yellowCard.radius<=8&&yellowCard.glyph==='','yellow card is not a clear referee-card shape: '+JSON.stringify(yellowCard));
  await page.screenshot({path:'selftest-artifacts/04a-yellow-card.png'});

  graphics=makeGraphics({homeColor:'#d8b55b',event:{type:'RED',side:'HOME',team:HOME,at:"56'",player:{number:'8',name:'CARD TEST'}}});
  await page.waitForFunction(()=>document.querySelector('#eventCard')?.classList.contains('red'),null,{timeout:5000});await wait(500);
  const redCard=await page.evaluate(()=>{const el=document.querySelector('#eventIcon'),cs=getComputedStyle(el);return{bg:cs.backgroundColor,kicker:getComputedStyle(document.querySelector('#eventKicker')).color,label:document.querySelector('#eventKicker').textContent,cls:document.querySelector('#eventCard').className,w:parseFloat(cs.width),h:parseFloat(cs.height),radius:parseFloat(cs.borderRadius),glyph:el.textContent.trim()}});
  assert(redCard.label==='红牌 · RED CARD'&&redCard.cls.includes('red'),'red card event class/label wrong');
  assert(redCard.bg==='rgb(227, 52, 64)'&&redCard.kicker==='rgb(227, 52, 64)','red card inherited yellow/team color: '+JSON.stringify(redCard));
  assert(redCard.h>=80&&redCard.w<=60&&redCard.h/redCard.w>=1.35&&redCard.radius<=8&&redCard.glyph==='','red card is not a clear referee-card shape: '+JSON.stringify(redCard));
  await page.screenshot({path:'selftest-artifacts/04b-red-card.png'});

  console.log('TEST 4C: vMix output ignores stale lower revisions for the same fixture');
  graphics=makeGraphics({commandId:'rev120',revision:120,fixtureKey:'SELFTEST-REVISION-GUARD',homeScore:2,awayScore:1,event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#sbHomeScore')?.textContent==='2',null,{timeout:5000});await wait(250);
  graphics=makeGraphics({commandId:'rev119-stale',revision:119,fixtureKey:'SELFTEST-REVISION-GUARD',homeScore:9,awayScore:9,event:{type:'CLEAR_EVENT'}});
  await wait(900);
  const staleGuard=await page.evaluate(()=>({home:document.querySelector('#sbHomeScore').textContent,away:document.querySelector('#sbAwayScore').textContent}));
  assert(staleGuard.home==='2'&&staleGuard.away==='1','stale lower revision rolled vMix output backward: '+JSON.stringify(staleGuard));

  console.log('TEST 3D: stoppage time is explicit and attached to the clock rail');
  graphics=makeGraphics({commandId:'stoppage-info',revision:140,fixtureKey:'SELFTEST-STOPPAGE',stoppageTime:'3',clock:{period:'2H',baseSeconds:5460,running:false,startedAt:null},event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#sbStoppage')?.classList.contains('on'),null,{timeout:4000});await wait(250);
  const stoppageInfo=await page.evaluate(()=>({text:document.querySelector('#sbStoppage').textContent,period:document.querySelector('#sbPeriod').textContent,periodDisplay:getComputedStyle(document.querySelector('#sbPeriod')).display,clock:document.querySelector('#sbClock').textContent,midWidth:document.querySelector('.sbMid').getBoundingClientRect().width,aria:document.querySelector('#scoreBug').getAttribute('aria-label')||''}));
  assert(stoppageInfo.text==='+3'&&stoppageInfo.periodDisplay==='none'&&stoppageInfo.aria.includes('补时 +3'),'added-time information is not explicit/compact: '+JSON.stringify(stoppageInfo));

  console.log('TEST 3E: exceptional match phases appear only when they matter');
  graphics=makeGraphics({commandId:'extra-time-phase',revision:145,fixtureKey:'SELFTEST-ET',stoppageTime:'',clock:{period:'ET1',baseSeconds:5520,running:false,startedAt:null},event:{type:'CLEAR_EVENT'}});
  await page.waitForFunction(()=>document.querySelector('#sbPeriod')?.classList.contains('special'),null,{timeout:4000});await wait(250);
  const extraPhase=await page.evaluate(()=>({text:document.querySelector('#sbPeriod').textContent,display:getComputedStyle(document.querySelector('#sbPeriod')).display,clock:document.querySelector('#sbClock').textContent,midWidth:document.querySelector('.sbMid').getBoundingClientRect().width}));
  assert(extraPhase.display!=='none'&&extraPhase.text.includes('加时'),'extra-time phase did not surface when relevant: '+JSON.stringify(extraPhase));
  await page.screenshot({path:'selftest-artifacts/04c-extra-time-phase.png'});

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
  const controlCards=await page.evaluate(()=>{const y=document.querySelector('#mdYellowBtn .refCardIcon'),r=document.querySelector('#mdRedBtn .refCardIcon'),ys=y?getComputedStyle(y):null,rs=r?getComputedStyle(r):null;return{yellow:!!y,red:!!r,yw:ys?parseFloat(ys.width):0,yh:ys?parseFloat(ys.height):0,rw:rs?parseFloat(rs.width):0,rh:rs?parseFloat(rs.height):0,yText:document.querySelector('#mdYellowBtn')?.textContent.trim()||'',rText:document.querySelector('#mdRedBtn')?.textContent.trim()||''}});
  assert(controlCards.yellow&&controlCards.red&&controlCards.yh>controlCards.yw&&controlCards.rh>controlCards.rw&&controlCards.yText==='黄牌'&&controlCards.rText==='红牌','director card controls unclear: '+JSON.stringify(controlCards));
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
    mmHomeName:document.querySelector('#mmHomeName').textContent,
    mmAwayName:document.querySelector('#mmAwayName').textContent,
    mirroredHome:document.querySelector('#mdHomeShort').value,
    mirroredAway:document.querySelector('#mdAwayShort').value,
    mirrorReadonly:document.querySelector('#mdHomeShort').readOnly&&document.querySelector('#mdAwayShort').readOnly,
    localProjects:localStorage.getItem('sagi_match_projects_v44')||''
  }));
  assert(loadedProject.competition==='TORANHE PROJECT CUP'&&loadedProject.home==='乌苏叶克备'&&loadedProject.away==='IPF','stored project match identity was not restored: '+JSON.stringify(loadedProject));
  assert(loadedProject.mmHomeName==='乌苏叶克备'&&loadedProject.mmAwayName==='IPF','mobile match control drifted from fixture identity: '+JSON.stringify(loadedProject));
  assert(loadedProject.mirroredHome==='乌苏叶克备'&&loadedProject.mirroredAway==='IPF'&&!loadedProject.mirrorReadonly,'broadcast short-name fields did not remain editable after project load: '+JSON.stringify(loadedProject));
  assert(loadedProject.mdHomeScore==='3'&&loadedProject.mdAwayScore==='1','selected project matchday was overwritten by stale Bridge state: '+loadedProject.mdHomeScore+'-'+loadedProject.mdAwayScore);
  const compactProjects=JSON.parse(loadedProject.localProjects||'[]');
  const compactProject=compactProjects.find(x=>x.id===storedProject.id);
  const compactPhotos=compactProject&&compactProject.assets&&compactProject.assets.photos||{};
  assert(Object.keys(compactPhotos.HOME||{}).length===0&&Object.keys(compactPhotos.AWAY||{}).length===0,'large project photos were duplicated into synchronous localStorage');

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
  await page.evaluate(()=>document.querySelector('#mmRestoreState').click());await wait(500);
  const afterStaleRestore=await page.evaluate(()=>({home:document.querySelector('#mdHomeScore').textContent,away:document.querySelector('#mdAwayScore').textContent,homeName:document.querySelector('#matchHome').value,awayName:document.querySelector('#matchAway').value}));
  assert(afterStaleRestore.home==='3'&&afterStaleRestore.away==='1','manual stale Bridge restore overwrote selected project: '+JSON.stringify(afterStaleRestore));
  assert(afterStaleRestore.homeName==='乌苏叶克备'&&afterStaleRestore.awayName==='IPF','stale Bridge restore changed selected fixture identity');
  await page.screenshot({path:'selftest-artifacts/09-project-load-ready.png'});

  console.log('TEST 8B: compact local project index rehydrates full project/photos from IndexedDB when Bridge project list is empty');
  await wait(500);
  await page.reload({waitUntil:'domcontentloaded'});await wait(2200);
  await page.selectOption('#projectSelect',storedProject.id);
  await page.click('#projectLoadBtn');
  await page.waitForFunction(()=>document.querySelector('#projectLoadBtn')?.textContent==='读取项目'&&document.querySelector('#projectName')?.value==='SELFTEST STORED MATCH',null,{timeout:8000});
  const photoReload=await page.evaluate(()=>{
    const raw=localStorage.getItem('sagi_match_projects_v44')||'[]',idx=JSON.parse(raw),p=idx[0]||{};
    const img=document.querySelector('#roster .playerRow:first-child .thumb img');
    return{photo:img&&img.getAttribute('src')||'',compact:!!p.__compact,localPhotoCount:Object.keys(p.assets&&p.assets.photos&&p.assets.photos.HOME||{}).length}
  });
  assert(photoReload.compact&&photoReload.localPhotoCount===0,'local project index did not stay compact after reload');
  assert(photoReload.photo.startsWith('data:image/svg+xml'),'full project/player photo did not rehydrate from IndexedDB when Bridge list was empty');
  await page.screenshot({path:'selftest-artifacts/09b-project-photo-rehydrate.png'});

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

  console.log('TEST 10: transient LAN failure is retried and last-good state is recorded');
  await page.click('#mdClockPause');await wait(250);failNextMatchdayPosts=1;matchdayPosts=[];
  await page.click('#mdHomePlus');
  await page.waitForFunction(()=>document.querySelector('#mdHomeScore')?.textContent==='4',null,{timeout:3000});await wait(1200);
  const reliability=await page.evaluate(()=>window.sagiMatchdayReliabilityDiagnostic());
  assert(Number(graphics.homeScore)===4,'retry did not deliver score state after transient failure: '+JSON.stringify(graphics));
  assert(reliability.metrics.retried>=1&&reliability.lastGood,'reliability retry/LKG diagnostics missing: '+JSON.stringify(reliability));

  console.log('TEST 10B: rapid score writes remain ordered even when the first network write is deliberately delayed');
  reorderMatchdayWrites=true;matchdayPosts=[];
  await page.evaluate(()=>{document.querySelector('#mdHomePlus').click();document.querySelector('#mdHomePlus').click()});
  await wait(1500);reorderMatchdayWrites=false;
  const ordered=matchdayPosts.filter(x=>x&&x.home==='乌苏叶克备'&&x.away==='IPF').slice(-4);
  assert(Number(graphics.homeScore)===6,'out-of-order network write rolled score backward: '+JSON.stringify(ordered.map(x=>({score:x.homeScore,revision:x.revision}))));
  const orderedScores=ordered.map(x=>Number(x.homeScore)).filter(x=>x>=5);
  assert(orderedScores.slice(-2).join(',')==='5,6','serialized score sequence failed: '+JSON.stringify(orderedScores));
  await page.screenshot({path:'selftest-artifacts/11-ordered-score-sync.png'});

  console.log('TEST 10C: duplicate operator event is blocked before it can double-count');
  await page.selectOption('#mdEventSide','HOME');
  await page.selectOption('#mdEventPlayer',{index:1});
  await page.evaluate(()=>{document.querySelector('#mdYellowBtn').click();document.querySelector('#mdYellowBtn').click()});
  await wait(350);
  const dupe=await page.evaluate(()=>({yellow:document.querySelector('#mdStatYellow').textContent,status:document.querySelector('#mdEventStatus').textContent}));
  assert(dupe.yellow==='1','duplicate yellow-card click created two events: '+JSON.stringify(dupe));
  await page.click('#mdClearEventBtn');

  console.log('TEST 11: consistency watchdog repairs score, identity, colors and exceptional-state drift');
  const authoritative=JSON.parse(JSON.stringify(graphics));
  graphics={...graphics,commandId:'corrupt_same_fixture',home:'乌苏叶克备',away:'IPF',homeShort:'少林足球',awayShort:'旧客队',
    scoreHomeName:'错误主队',scoreAwayName:'错误客队',homeScore:99,awayScore:88,homeColor:'#ff0000',awayColor:'#00ff00',accentColor:'#0000ff',
    stoppageTime:'99',scoreboardFrozen:!authoritative.scoreboardFrozen,homePen:7,awayPen:8,scoreTheme:'uefa'};
  await page.evaluate(()=>window.dispatchEvent(new Event('online')));await wait(1000);
  const repairUI=await page.evaluate(()=>({sync:document.querySelector('#mdSync').textContent,home:document.querySelector('#mmHomeName').textContent,away:document.querySelector('#mmAwayName').textContent,score:document.querySelector('#mdHomeScore').textContent,reliability:window.sagiMatchdayReliabilityDiagnostic()}));
  assert(Number(graphics.homeScore)===Number(authoritative.homeScore)&&Number(graphics.awayScore)===Number(authoritative.awayScore),'online recovery failed to restore authoritative score state: '+JSON.stringify(graphics));
  assert(repairUI.reliability.recovery.networkRestores>=1&&repairUI.reliability.recovery.lastReason==='ONLINE','online recovery metrics missing: '+JSON.stringify(repairUI.reliability));
  assert(graphics.scoreHomeName===authoritative.scoreHomeName&&graphics.scoreAwayName===authoritative.scoreAwayName,'watchdog failed to restore broadcast team names: '+JSON.stringify({expected:[authoritative.scoreHomeName,authoritative.scoreAwayName],actual:[graphics.scoreHomeName,graphics.scoreAwayName]}));
  assert(graphics.homeColor===authoritative.homeColor&&graphics.awayColor===authoritative.awayColor&&graphics.accentColor===authoritative.accentColor,'watchdog failed to restore broadcast colors');
  assert(String(graphics.stoppageTime||'')===String(authoritative.stoppageTime||'')&&!!graphics.scoreboardFrozen===!!authoritative.scoreboardFrozen&&Number(graphics.homePen||0)===Number(authoritative.homePen||0)&&Number(graphics.awayPen||0)===Number(authoritative.awayPen||0),'watchdog failed to restore exceptional score-center state');
  assert(repairUI.home==='乌苏叶克备'&&repairUI.away==='IPF'&&repairUI.score===String(authoritative.homeScore),'watchdog repair changed local control identity/state: '+JSON.stringify(repairUI));
  const diagPage=await browser.newPage({viewport:{width:1920,height:1080}});
  await diagPage.goto('http://127.0.0.1:'+PORT+'/intro/vmix-v45-lan.html',{waitUntil:'domcontentloaded'});
  await diagPage.waitForFunction(()=>window.sagiScoreCenterDiagnostic&&window.sagiScoreCenterDiagnostic().build==='V4.30.7',null,{timeout:5000});
  const outputDiag=await diagPage.evaluate(()=>window.sagiScoreCenterDiagnostic());
  assert(outputDiag&&outputDiag.build==='V4.30.7'&&outputDiag.home===authoritative.scoreHomeName,'vMix score-center diagnostic is not tracking authoritative state: '+JSON.stringify(outputDiag));
  await diagPage.screenshot({path:'selftest-artifacts/12-output-diagnostic.png'});

  console.log('TEST 11B: vMix output survives transient matchday read failures and catches up automatically');
  const recoveryScore=Number(authoritative.homeScore)+1;
  failNextMatchdayGets=2;
  graphics={...graphics,commandId:'output_get_recovery',revision:(Number(graphics.revision)||0)+20,homeScore:recoveryScore,event:{type:'CLEAR_EVENT'}};
  await wait(2400);
  const outputRecovery=await diagPage.evaluate(()=>window.sagiScoreCenterDiagnostic());
  assert(Number(outputRecovery.score[0])===recoveryScore,'vMix output did not catch up after transient GET failures: '+JSON.stringify(outputRecovery));
  assert(outputRecovery.health.pollFail>=2&&outputRecovery.health.recoveries>=1&&outputRecovery.health.consecutiveFailures===0,'output recovery health metrics wrong: '+JSON.stringify(outputRecovery.health));
  await diagPage.screenshot({path:'selftest-artifacts/12b-output-read-recovery.png'});
  await diagPage.close();
  await page.evaluate(()=>window.sagiMatchdayConsistencyCheck(true));await wait(800);
  assert(Number(graphics.homeScore)===Number(authoritative.homeScore),'control did not restore authoritative state after output recovery test');
  await page.screenshot({path:'selftest-artifacts/12-watchdog-repair.png'});

  console.log('TEST 12: accelerated long-session identity soak keeps names/scores stable');
  const soak=await page.evaluate(()=>window.sagiMatchdaySoakDiagnostic(5000));
  assert(soak.home==='乌苏叶克备'&&soak.away==='IPF'&&soak.mirrorHome==='乌苏叶克备'&&soak.mirrorAway==='IPF'&&soak.score==='6','accelerated long-session soak drifted state: '+JSON.stringify(soak));
  await page.screenshot({path:'selftest-artifacts/13-long-session-soak.png'});

  assert(pageErrors.length===0,'browser page errors: '+pageErrors.join(' | '));
  const report={ok:true,build:'V4.30.7',testedAt:new Date().toISOString(),tests:['compact score intelligence + fused event identity + unified score pair + restrained score roll + clock-only regular halves + conditional states','HOME goal enlarged HOME crest + complete GOAL + lower player card + collapse','AWAY goal enlarged AWAY crest','yellow/red referee-card shape + event colors + control icons','penalty >5 rounds/sudden death/miss/scores','two-camera Input 1 -> Input 2','event-logo replay stinger visual','manual replay stinger IN -> Input 4 -> OUT -> Input 1','stored project load wins over stale Bridge + optional time/venue do not block READY','compact project index rehydrates full photos from IndexedDB with empty Bridge list','clock-only refresh avoids repeated heavy match-control repaints','legacy stale short-name cache cannot override current vMix fixture identity','mobile match control mirrors current fixture identity and legacy fields are read-only','transient LAN failure retries automatically and records last-good state','rapid score writes are serialized under deliberate network reordering','duplicate operator events are gated before double-counting','vMix output ignores stale lower revisions within the same fixture','online/resume recovery repairs score/name/color/exceptional-state drift','vMix output survives transient matchday read failures and catches up automatically','accelerated 5000-cycle long-session identity soak'],vmixCommands:cuts};
  fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 }catch(e){
  fs.mkdirSync('selftest-artifacts',{recursive:true});try{await page.screenshot({path:'selftest-artifacts/FAIL.png',fullPage:true})}catch{}
  fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify({ok:false,error:String(e?.stack||e),pageErrors},null,2));console.error(e?.stack||e);process.exitCode=1;
 }finally{await browser.close();server.close()}
});