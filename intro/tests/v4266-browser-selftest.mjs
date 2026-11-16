import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const ROOT = process.cwd();
const PORT = 4173;
const HOME = '新疆塔城地区青年足球俱乐部';
const AWAY = 'ALTAI YOUTH FOOTBALL CLUB';
let seq = 1;
let vmixCommands = [];
let graphics = makeGraphics();

function makeGraphics(overrides={}) {
  return {
    commandId: 'g_' + (seq++),
    visualVersion: 'V4.26.6-SELFTEST',
    scoreboardVisible: true,
    scoreboardFrozen: false,
    scoreTheme: 'sagi-pro',
    competition: 'SAGI SELF TEST',
    home: HOME, away: AWAY,
    homeShort: HOME, awayShort: AWAY,
    homeColor: '#8b2e2e', awayColor: '#3457d5', accentColor: '#f4f0e8',
    homeScore: 0, awayScore: 0, homePen: 0, awayPen: 0,
    homeRedCards: 0, awayRedCards: 0, stoppageTime: '',
    clock: {period:'1H', baseSeconds:61, running:false, startedAt:null},
    penaltyShootout: {started:false, finished:false, history:[], rounds:5, currentRound:1, nextSide:'HOME'},
    simplePenalty: {visible:false, home:0, away:0, history:[], round:1},
    event: {type:'CLEAR_EVENT'},
    ...overrides
  };
}

function json(res, obj, status=200){
  const body = JSON.stringify(obj);
  res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});
  res.end(body);
}
function text(res, body, type='text/plain; charset=utf-8', status=200){
  res.writeHead(status, {'Content-Type':type,'Cache-Control':'no-store'});
  res.end(body);
}
function mime(p){
  if(p.endsWith('.html')) return 'text/html; charset=utf-8';
  if(p.endsWith('.js')||p.endsWith('.mjs')) return 'text/javascript; charset=utf-8';
  if(p.endsWith('.css')) return 'text/css; charset=utf-8';
  if(p.endsWith('.svg')) return 'image/svg+xml';
  return 'application/octet-stream';
}
function readBody(req){
  return new Promise((resolve,reject)=>{
    let d=''; req.setEncoding('utf8');
    req.on('data',c=>d+=c); req.on('end',()=>resolve(d)); req.on('error',reject);
  });
}
const server = http.createServer(async (req,res)=>{
  const u = new URL(req.url, 'http://127.0.0.1:'+PORT);
  try{
    if(u.pathname==='/api/state') return json(res,{lineupIntro:null});
    if(u.pathname==='/api/matchday' && req.method==='GET') return json(res,graphics);
    if(u.pathname==='/api/matchday' && req.method==='POST'){
      const b=await readBody(req); try{graphics=JSON.parse(b)||graphics}catch{}; return json(res,{ok:true});
    }
    if(u.pathname==='/api/vmix/status') return json(res,{
      ok:true, active:'1', preview:'2',
      inputs:[
        {number:'1',key:'cam1',type:'Camera',title:'CAM 1',state:'Running'},
        {number:'2',key:'cam2',type:'Camera',title:'CAM 2',state:'Running'},
        {number:'5',key:'gfx',type:'Browser',title:'SAGI Browser',state:'Running'}
      ], overlays:[]
    });
    if(u.pathname==='/api/vmix' && req.method==='POST'){
      const b=await readBody(req); let cmd={}; try{cmd=JSON.parse(b)}catch{}
      vmixCommands.push(cmd); return json(res,{ok:true,command:cmd});
    }
    if(u.pathname==='/api/projects') return json(res,{projects:[]});
    if(u.pathname==='/health') return json(res,{ok:true,port:PORT});
    if(u.pathname==='/') return text(res,'SAGI V4.26.6 SELFTEST');
    const rel = decodeURIComponent(u.pathname).replace(/^\/+/,'');
    const file = path.resolve(ROOT, rel);
    if(!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return text(res,'Not found','text/plain',404);
    return text(res,fs.readFileSync(file),mime(file));
  }catch(e){ return text(res,String(e?.stack||e),'text/plain',500); }
});

function assert(cond,msg){ if(!cond) throw new Error('ASSERT FAILED: '+msg); }
async function wait(ms){ return new Promise(r=>setTimeout(r,ms)); }

server.listen(PORT,'127.0.0.1',async()=>{
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1920,height:1080}});
  const pageErrors=[];
  page.on('pageerror',e=>pageErrors.push(String(e)));
  page.on('console',m=>{ if(m.type()==='error') console.log('[browser console error]',m.text()); });

  try{
    console.log('TEST 1: regular scorebug full team names + compact state');
    await page.goto('http://127.0.0.1:'+PORT+'/intro/vmix-v45-lan.html',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('on'),null,{timeout:8000});
    await wait(500);

    const regular = await page.evaluate(({HOME,AWAY})=>{
      const bug=document.querySelector('#scoreBug'),h=document.querySelector('#sbHome'),a=document.querySelector('#sbAway'),burst=document.querySelector('#sbGoalBurst');
      const br=bug.getBoundingClientRect(),hr=h.getBoundingClientRect(),ar=a.getBoundingClientRect();
      const hs=getComputedStyle(h),as=getComputedStyle(a),bs=getComputedStyle(burst);
      return {
        home:h.textContent,away:a.textContent,
        homeOverflow:hs.textOverflow,awayOverflow:as.textOverflow,
        homeFont:parseFloat(hs.fontSize),awayFont:parseFloat(as.fontSize),
        homeInside:hr.left>=br.left-0.5&&hr.right<=br.right+0.5,
        awayInside:ar.left>=br.left-0.5&&ar.right<=br.right+0.5,
        bugRight:br.right,burstWidth:parseFloat(bs.width),goalExpand:bug.classList.contains('goalExpand')
      };
    },{HOME,AWAY});
    assert(regular.home===HOME,'regular home team name changed/truncated');
    assert(regular.away===AWAY,'regular away team name changed/truncated');
    assert(regular.homeOverflow!=='ellipsis'&&regular.awayOverflow!=='ellipsis','ellipsis still active');
    assert(regular.homeFont>=11&&regular.awayFont>=11,'team name shrank below readable floor');
    assert(regular.homeInside&&regular.awayInside,'team name extends outside scorebug and can be clipped');
    assert(regular.bugRight<=1918,'regular scorebug exceeds 1920 frame');
    assert(regular.burstWidth<=1.5&&!regular.goalExpand,'normal scorebug is not compact');
    await page.screenshot({path:'selftest-artifacts/01-regular-scorebug.png'});

    console.log('TEST 2: GOAL full letters + player card + timed collapse');
    const photo='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="220"><rect width="100%" height="100%" fill="#17202a"/><circle cx="90" cy="70" r="35" fill="#d5a97a"/><rect x="45" y="110" width="90" height="105" rx="18" fill="#8b2e2e"/></svg>');
    graphics = makeGraphics({homeScore:1,event:{type:'GOAL',side:'HOME',team:HOME,at:"23'",player:{number:'9',name:'TEST STRIKER',photo}}});
    await page.waitForFunction(()=>document.querySelector('#scoreBug')?.classList.contains('goalExpand'),null,{timeout:5000});
    await wait(1000);
    const goal = await page.evaluate(()=>{
      const bug=document.querySelector('#scoreBug'),burst=document.querySelector('#sbGoalBurst'),word=document.querySelector('.sbGoalWord'),card=document.querySelector('#eventCard'),photo=document.querySelector('#eventPhoto');
      const br=bug.getBoundingClientRect(),rr=burst.getBoundingClientRect();
      return {
        letters:word.textContent.replace(/\s/g,''),
        opacities:[...word.querySelectorAll('span')].map(x=>parseFloat(getComputedStyle(x).opacity)),
        burstWidth:rr.width,bugRight:br.right,
        eventGoal:card.classList.contains('on')&&card.classList.contains('goal'),
        photo:photo.getAttribute('src')||''
      };
    });
    assert(goal.letters==='GOAL','GOAL four letters are not complete');
    assert(goal.opacities.length===4&&goal.opacities.every(x=>x>.9),'one or more GOAL letters are still invisible');
    assert(goal.burstWidth>=250,'GOAL panel did not fully expand');
    assert(goal.bugRight<=1918,'expanded GOAL panel exceeds 1920 frame');
    assert(goal.eventGoal,'goal player lower card is not visible');
    assert(goal.photo.startsWith('data:image/svg+xml'),'goal player photo was lost');
    await page.screenshot({path:'selftest-artifacts/02-goal-expanded.png'});

    await wait(3600);
    const collapsed = await page.evaluate(()=>{
      const bug=document.querySelector('#scoreBug'),burst=document.querySelector('#sbGoalBurst');
      return {expand:bug.classList.contains('goalExpand'),width:burst.getBoundingClientRect().width,on:bug.classList.contains('on')};
    });
    assert(!collapsed.expand&&collapsed.width<=2,'GOAL scorebug did not collapse after timer');
    assert(collapsed.on,'scorebug disappeared after GOAL collapse');
    await page.screenshot({path:'selftest-artifacts/03-goal-collapsed.png'});

    console.log('TEST 3: penalty shootout >5 rounds + miss red marker + full names');
    const hist=[
      ['HOME','GOAL'],['AWAY','GOAL'],
      ['HOME','GOAL'],['AWAY','MISS'],
      ['HOME','MISS'],['AWAY','GOAL'],
      ['HOME','GOAL'],['AWAY','GOAL'],
      ['HOME','GOAL'],['AWAY','GOAL'],
      ['HOME','MISS'],['AWAY','GOAL']
    ].map(([side,result],i)=>({side,result,at:String(i)}));
    graphics = makeGraphics({
      homeScore:1,awayScore:1,
      clock:{period:'PEN',baseSeconds:0,running:false,startedAt:null},
      penaltyShootout:{started:true,finished:false,history:hist,rounds:5,currentRound:6,nextSide:'HOME',homeGoals:4,awayGoals:5},
      simplePenalty:{visible:false,history:[]},
      event:{type:'CLEAR_EVENT'}
    });
    await page.waitForFunction(()=>document.querySelector('#simplePenaltyBoard')?.classList.contains('on'),null,{timeout:5000});
    await wait(500);
    const pk = await page.evaluate(({HOME,AWAY})=>{
      const board=document.querySelector('#simplePenaltyBoard'),bug=document.querySelector('#scoreBug'),hn=document.querySelector('#spbHomeName'),an=document.querySelector('#spbAwayName');
      const hrect=hn.getBoundingClientRect(),arect=an.getBoundingClientRect();
      return {
        home:hn.textContent,away:an.textContent,phase:document.querySelector('#spbPhase').textContent,
        homeDots:document.querySelectorAll('#spbHomeDots .spbDot').length,
        awayDots:document.querySelectorAll('#spbAwayDots .spbDot').length,
        misses:document.querySelectorAll('.spbDot.miss').length,
        boardOn:board.classList.contains('on'),scorebugOn:bug.classList.contains('on'),
        homeOverflow:getComputedStyle(hn).textOverflow,awayOverflow:getComputedStyle(an).textOverflow,
        homeInFrame:hrect.left>=0&&hrect.right<=1920,awayInFrame:arect.left>=0&&arect.right<=1920,
        homeScore:document.querySelector('#spbHomeScore').textContent,
        awayScore:document.querySelector('#spbAwayScore').textContent
      };
    },{HOME,AWAY});
    assert(pk.boardOn&&!pk.scorebugOn,'dedicated PK board is not exclusively displayed');
    assert(pk.home===HOME&&pk.away===AWAY,'PK team names changed/truncated');
    assert(pk.homeOverflow!=='ellipsis'&&pk.awayOverflow!=='ellipsis','PK team names still use ellipsis');
    assert(pk.homeInFrame&&pk.awayInFrame,'PK team name falls outside frame');
    assert(pk.phase.includes('突然死亡'),'round 6 is not represented as sudden death');
    assert(pk.homeDots===5&&pk.awayDots===5,'PK >5 round rolling dots are not stable');
    assert(pk.misses>=1,'miss marker class is missing');
    assert(pk.homeScore==='4'&&pk.awayScore==='5','PK scores are not synchronized');
    await page.screenshot({path:'selftest-artifacts/04-penalty-round6.png'});

    console.log('TEST 4: two-camera manual switching sends distinct vMix inputs');
    vmixCommands=[];
    await page.goto('http://127.0.0.1:'+PORT+'/intro/v45-lan.html',{waitUntil:'domcontentloaded'});
    await wait(1800);

    // Use only the real operator UI: fill match information, run preflight, press READY,
    // then press the two camera buttons. No internal page functions are called.
    await page.locator('#matchCompetition').fill('SAGI SELF TEST CUP');
    await page.locator('#matchHome').fill('SELF TEST HOME');
    await page.locator('#matchAway').fill('SELF TEST AWAY');
    await page.locator('#matchKickoff').fill('2026-11-17T20:00');
    await page.locator('#matchVenue').fill('SELF TEST STADIUM');

    await page.locator('#vdCam1').selectOption('1');
    await page.locator('#vdCam2').selectOption('2');
    await page.locator('#vdGraphics').selectOption('5');
    await page.locator('#vdDuration').fill('0');
    await page.locator('#vdDuration').dispatchEvent('change');
    await page.locator('#vdTransition').selectOption('Cut');

    await page.click('#setupValidateBtn');
    await page.waitForFunction(()=>!document.querySelector('#setupReadyBtn')?.disabled,null,{timeout:5000});
    await page.click('#setupReadyBtn');
    await page.waitForFunction(()=>document.querySelector('#setupReadyBadge')?.textContent.includes('可以播出'),null,{timeout:5000});

    await page.click('#vdTakeCam1');
    await page.waitForFunction(()=>document.querySelector('#vdStatus')?.textContent.includes('已执行'),null,{timeout:4000});
    await page.click('#vdTakeCam2');
    await wait(800);
    const cuts=vmixCommands.filter(x=>['Cut','Fade','Stinger1'].includes(x.functionName));
    assert(cuts.length===2,'camera buttons emitted duplicate/missing program switch commands: '+JSON.stringify(cuts));
    assert(String(cuts[0].input)==='1','CAM1 did not switch to Input 1');
    assert(String(cuts[1].input)==='2','CAM2 did not switch to Input 2');
    assert(String(cuts[0].input)!==String(cuts[1].input),'two camera buttons map to the same input');
    await page.screenshot({path:'selftest-artifacts/05-two-camera-control.png'});

    assert(pageErrors.length===0,'browser page errors: '+pageErrors.join(' | '));
    const report = {
      ok:true, build:'V4.26.6', testedAt:new Date().toISOString(),
      tests:[
        'regular full team names/no ellipsis/inside frame',
        'GOAL four letters/full expansion/player lower card/4.2s collapse',
        'penalty round 6/sudden death/miss markers/full names/scores',
        'two-camera manual program switching Input 1 -> Input 2'
      ],
      vmixCommands:cuts
    };
    fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify(report,null,2));
    console.log(JSON.stringify(report,null,2));
  } catch(e) {
    fs.mkdirSync('selftest-artifacts',{recursive:true});
    try{await page.screenshot({path:'selftest-artifacts/FAIL.png',fullPage:true})}catch{}
    fs.writeFileSync('selftest-artifacts/report.json',JSON.stringify({ok:false,error:String(e?.stack||e),pageErrors},null,2));
    console.error(e?.stack||e);
    process.exitCode=1;
  } finally {
    await browser.close();
    server.close();
  }
});
