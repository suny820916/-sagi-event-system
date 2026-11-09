(()=>{
const q=id=>document.getElementById(id);
const TEAM_KEY='sagi_teamwear_sales_v122';
const LEGACY_TEAM=['sagi_teamwear_sales_v12','sagi_teamwear_sales_v11','sagi_teamwear_sales_v10'];
const OS_KEY='sagi_content_os_v10';
const ZH_CACHE_KEY='sagi_content_os_zh_cache_v1';
const ZH_LAYER_VERSION=2;
const VIEW_META={
 matchday:['MATCHDAY MODE · 比赛日现场指挥','现场只标记值得剪的时刻，让电脑端优先分析正确的时间点。'],
 videojobs:['AI VIDEO JOB · 视频任务调度','手机下任务，电脑负责 VideoHighlighter / Cutpoint / FFmpeg。'],
 review:['REVIEW · 成片审核','不用手机重剪，一键给出返修指令。'],
 daily:['DAILY VIRAL · 每日爆款指挥官','互联网热点 + SAGI项目 + 历史数据，直接决定今天先发什么。'],
 today:['TODAY · 今日内容作战室','先决定今天最值得发布什么，再进入制作。'],
 trends:['LIVE RADAR · 互联网热点雷达','抓实时足球热点，再一键生成适合 SAGI 的流量内容方案。'],
 flow:['FLOW · 内容流水线','从项目到发布再到学习，统一看每条内容卡在哪一步。'],
 director:['AI DIRECTOR · AI内容导演','目标 → 形式 → Hook → 镜头 → 音乐 → 发布时间。'],
 calendar:['CALENDAR · 内容排期','跨球队、赛事、品牌统一安排内容。'],
 assets:['ASSETS · 素材库','把球队、赛事和品牌素材集中起来。'],
 video:['AI FOOTBALL VIDEO DIRECTOR · 足球视频导演','真实比赛镜头 + 中文热点资料 + 自动镜头编排，生成专业竖屏短片。'],
 create:['CREATE · 内容制作','导演方案进入故事板和制作执行。'],
 publish:['PUBLISH · 发布中心','管理待发布、已发布和发布后数据。'],
 learning:['LEARNING · 内容学习','让系统从真实发布结果中越来越懂 SAGI。'],
 viralgen:['VIRAL GEN · 爆款内容生成器','一个选题生成三套打法，由 SAGI VIRAL MODEL 自动选出今日冠军。'],
 viral:['VIRAL MODEL · 萨吉爆款模型','历史数据 + 实时热点 + 内容结构，发布前判断爆款潜力。'],
 account:['ACCOUNT DATA · 萨吉体育账号数据','把真实抖音作品表现接入学习引擎。'],
 performance:['PERFORMANCE · 表现与转化','播放不是终点，关注互动、询单和成交。'],
 projects:['PROJECTS · 内容项目','球队、赛事、品牌、产品、热点和人物故事统一建档。']
};
const CONTENT_TYPES={team:'球队',event:'赛事',brand:'品牌',product:'产品',hot:'热点',story:'人物故事'};
const ACCOUNT_PROFILE={platform:'douyin',name:'萨吉体育',douyinId:'181444241',brand:'SAGI SPORTS',positioning:'新疆足球与足球装备内容',voice:'专业、热血、真实、不过度标题党'};
let state={salesOrders:[],projects:[],contents:[],assetOverrides:{},currentProjectId:'',currentContentId:'',director:{},performanceTargetId:'',trendItems:[],trendSelected:null,trendFetchedAt:0,accountData:[],accountTrendData:[],accountImportPreview:null,viralVariants:[],viralGeneratorTopic:'',dailyCommand:null,dailyCommandLoading:false,videoDraft:null,videoRendering:false,footage:[],directorCut:[],directorMusic:null,directorAnalyzing:false,footageAnalysis:{selected:0,done:0,failed:0,errors:[]},matchday:{home:'主队',away:'客队',elapsed:0,running:false,runningSince:0,half:1,markers:[]},videoJobs:[],jobType:'hot15'};
function uid(p='id'){return p+'_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,7)}
function today(){const d=new Date(),z=n=>String(n).padStart(2,'0');return d.getFullYear()+'-'+z(d.getMonth()+1)+'-'+z(d.getDate())}
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
function num(v){return Math.max(0,Number(v)||0)}
function note(t){const el=q('notice');el.textContent=t;el.classList.add('show');clearTimeout(note.t);note.t=setTimeout(()=>el.classList.remove('show'),1800)}
function fmt(n){return num(n).toLocaleString('zh-CN')}
function save(){localStorage.setItem(OS_KEY,JSON.stringify({projects:state.projects,contents:state.contents,assetOverrides:state.assetOverrides,currentProjectId:state.currentProjectId,accountData:state.accountData,accountTrendData:state.accountTrendData,viralVariants:state.viralVariants,viralGeneratorTopic:state.viralGeneratorTopic,dailyCommand:state.dailyCommand,videoDraft:state.videoDraft,matchday:state.matchday,videoJobs:state.videoJobs,jobType:state.jobType}))}
function load(){
 try{const x=JSON.parse(localStorage.getItem(OS_KEY)||'{}');state.projects=Array.isArray(x.projects)?x.projects:[];state.contents=Array.isArray(x.contents)?x.contents:[];state.assetOverrides=x.assetOverrides&&typeof x.assetOverrides==='object'?x.assetOverrides:{};state.currentProjectId=x.currentProjectId||'';state.accountData=Array.isArray(x.accountData)?x.accountData:[];state.accountTrendData=Array.isArray(x.accountTrendData)?x.accountTrendData:[];state.viralVariants=Array.isArray(x.viralVariants)?x.viralVariants:[];state.viralGeneratorTopic=x.viralGeneratorTopic||'';state.dailyCommand=x.dailyCommand&&typeof x.dailyCommand==='object'?x.dailyCommand:null;state.videoDraft=x.videoDraft&&typeof x.videoDraft==='object'?x.videoDraft:null;state.matchday=x.matchday&&typeof x.matchday==='object'?{home:'主队',away:'客队',elapsed:0,running:false,runningSince:0,half:1,markers:[],...x.matchday}:state.matchday;state.videoJobs=Array.isArray(x.videoJobs)?x.videoJobs:[];state.jobType=x.jobType||'hot15'}catch(e){}
 seedSagiAccountHistory();seedSagiTrendHistory();loadSales()
}
function loadSales(){
 let x=null;try{x=JSON.parse(localStorage.getItem(TEAM_KEY)||'null');for(const k of LEGACY_TEAM)if(!x)x=JSON.parse(localStorage.getItem(k)||'null')}catch(e){}
 state.salesOrders=x&&Array.isArray(x.orders)?x.orders:[];
 if(!state.currentProjectId){const first=state.salesOrders[0];state.currentProjectId=first?'sale:'+first.id:(state.projects[0]?'local:'+state.projects[0].id:'')}
}
function allProjects(){
 const sale=state.salesOrders.map(o=>({id:'sale:'+o.id,source:'sales',sourceId:o.id,type:'team',name:o.teamName||o.projectName||'未命名球队',tag:[o.city,o.competition].filter(Boolean).join(' · '),desc:o.marketingTagline||o.customerNotes||'',teamLogo:o.teamLogo||'',sales:o}));
 const local=state.projects.map(p=>({...p,id:'local:'+p.id,source:'local',sourceId:p.id}));
 return [...sale,...local]
}
function project(){return allProjects().find(p=>p.id===state.currentProjectId)||null}
function baseAssets(p){
 if(!p)return{};if(p.source==='sales'){const o=p.sales,m=o.mediaArchive||{};return{logo:o.teamLogo||'',design:m.design||'',poster:m.poster||'',wearing:m.jersey||'',match:'',delivery:m.delivery||''}}
 return p.assets||{}
}
function assets(p=project()){return{...baseAssets(p),...(state.assetOverrides[p?.id]||{})}}
function projectContent(pid=state.currentProjectId){return state.contents.filter(x=>x.projectId===pid)}
function syncSales(){loadSales();renderAll();note('已同步 SALES OS 数据 · '+state.salesOrders.length+' 个球队项目')}


function seedSagiAccountHistory(){
 const id='sagi_real_cr7_retirement_20261105';
 if(state.accountData.some(x=>x.id===id))return;
 state.accountData.push({
   id,accountName:'萨吉体育',douyinId:'181444241',source:'user-confirmed',title:'C罗官宣国家队退役｜葡萄牙7号只有一个',
   date:'2026-11-05',format:'poster',views:456000,likes:7524,comments:1135,saves:439,shares:null,
   inquiries:0,orders:0,revenue:0,hook:'234次出场、146球、20多年7号｜葡萄牙7号只有一个',
   note:'用户确认的真实历史表现样本',recordedAt:Date.parse('2026-11-05T12:00:00+08:00')
 });
 try{save()}catch(e){}
}

function seedSagiTrendHistory(){
 const seed=[["2026-10-10",1,6130,92,9,16,47.99,42.2,79.12,33.86],["2026-10-11",0,4563,70,2,10,40.11,48.37,100,14.42],["2026-10-12",0,2017,9,0,-4,35.87,48.48,17.14,14.31],["2026-10-13",0,1491,16,3,0,35.69,50.65,68.95,12.62],["2026-10-14",0,1033,9,9,0,35.33,54.17,19.2,12.94],["2026-10-15",1,3054,46,21,4,33.24,53.36,100,9.19],["2026-10-16",1,1937,47,3,2,32.52,58.01,40.09,8.93],["2026-10-17",3,10963,184,43,4,38.09,54.44,100,6.68],["2026-10-18",1,6687,102,8,-1,33.12,52.36,100,5.94],["2026-10-19",0,2602,31,5,2,32.77,51.27,100,7.13],["2026-10-20",1,2354,46,2,2,28.56,53.22,77.5,6.58],["2026-10-21",0,1556,16,2,0,31.78,52.04,100,6.8],["2026-10-22",0,1324,11,4,5,32.03,54.31,53.42,6.62],["2026-10-23",0,1253,10,9,1,33.92,55.39,100,8.38],["2026-10-24",0,1099,-28,1,1,31.02,56.38,82.72,8.09],["2026-10-25",0,796,4,0,1,30.12,61.59,65.71,6.64],["2026-10-26",0,2265,45,0,5,47.27,45.16,47.97,8.58],["2026-10-27",0,548,-4,0,0,29.03,56.18,100,6.62],["2026-10-28",0,551,11,1,1,28.03,59.66,100,6.79],["2026-10-29",0,521,5,7,1,33.95,61.32,33.95,8.1],["2026-10-30",1,2350,85,2,5,40.74,41.22,11.39,9.36],["2026-10-31",0,748,9,1,1,33.72,52.08,50.82,7.92],["2026-11-01",1,2497,74,10,14,37.64,52.92,100,12.59],["2026-11-02",0,1335,1,2,1,40.2,52.9,100,12.46],["2026-11-03",1,1826,30,1,4,29.47,55.78,75.21,8.21],["2026-11-04",1,4058,113,8,11,43.18,44.87,49.22,17.7],["2026-11-05",1,27986,624,207,98,38.8,45.67,17.88,9.74],["2026-11-06",1,430684,6965,965,1042,40.36,43.64,17.55,9.85],["2026-11-07",2,42254,702,55,65,36.61,48.3,19.41,9.54],["2026-11-08",0,12859,180,14,16,30.91,49.48,51.63,7.58]];
 const map=new Map((state.accountTrendData||[]).map(x=>[x.date,x]));
 seed.forEach(r=>{if(!map.has(r[0]))map.set(r[0],{date:r[0],posts:r[1],views:r[2],likes:r[3],shares:r[4],comments:r[5],fiveSecCompletion:r[6],twoSecBounce:r[7],coverCtr:r[8],avgWatchTime:r[9],source:'douyin-export-20261109'})});
 state.accountTrendData=Array.from(map.values()).sort((a,b)=>String(a.date).localeCompare(String(b.date)));
 try{save()}catch(e){}
}

function accountTrendHeaderKey(k){
 const s=String(k||'').trim().replace(/\s+/g,'');
 const map={'日期':'date','投稿量':'posts','总播放量':'views','总点赞量':'likes','总分享量':'shares','总评论量':'comments','5秒完播率':'fiveSecCompletion','2秒跳出率':'twoSecBounce','封面点击率':'coverCtr','平均播放时长':'avgWatchTime'};
 return map[s]||''
}
function isAccountTrendRows(rows){
 if(!Array.isArray(rows)||!rows.length)return false;
 const keys=Object.keys(rows[0]||{}).map(accountTrendHeaderKey).filter(Boolean);
 return ['date','posts','views','fiveSecCompletion','twoSecBounce'].every(k=>keys.includes(k))
}
function trendNumber(v){const n=Number(String(v??'').replace(/[,，%s秒\s]/g,''));return Number.isFinite(n)?n:0}
function normalizeTrendRecord(x){
 const o={};Object.entries(x||{}).forEach(([k,v])=>{const m=accountTrendHeaderKey(k);if(m)o[m]=v});
 return{
   date:String(o.date||'').slice(0,10),posts:Math.max(0,trendNumber(o.posts)),views:Math.max(0,trendNumber(o.views)),
   likes:trendNumber(o.likes),shares:trendNumber(o.shares),comments:trendNumber(o.comments),
   fiveSecCompletion:trendNumber(o.fiveSecCompletion),twoSecBounce:trendNumber(o.twoSecBounce),coverCtr:trendNumber(o.coverCtr),
   avgWatchTime:trendNumber(o.avgWatchTime),source:'douyin-daily-trend'
 }
}
function mergeAccountTrendData(records){
 const map=new Map((state.accountTrendData||[]).map(x=>[x.date,x]));let added=0,updated=0;
 records.map(normalizeTrendRecord).filter(x=>x.date).forEach(r=>{if(map.has(r.date))updated++;else added++;map.set(r.date,{...(map.get(r.date)||{}),...r})});
 state.accountTrendData=Array.from(map.values()).sort((a,b)=>String(a.date).localeCompare(String(b.date)));save();renderAll();return{added,updated,total:records.length}
}
function renderAccountTrend(){
 const rows=state.accountTrendData||[],days=rows.length,views=rows.reduce((a,x)=>a+num(x.views),0),posts=rows.reduce((a,x)=>a+num(x.posts),0);
 const peak=rows.slice().sort((a,b)=>num(b.views)-num(a.views))[0];
 q('trendDays').textContent=days;q('trendViews').textContent=fmt(views);q('trendPosts').textContent=fmt(posts);
 q('trendPeakDate').textContent=peak?.date?peak.date.slice(5):'—';q('trendPeakViews').textContent=peak?fmt(peak.views)+' 播放':'暂无数据';
 q('accountTrendBadge').textContent=days+' DAYS';
 if(!days){q('accountTrendInsight').textContent='导入抖音“短视频全量指标”后，这里会显示账号的流量峰值与趋势。';return}
 const share=peak&&views?peak.views/views*100:0,top3=rows.slice().sort((a,b)=>num(b.views)-num(a.views)).slice(0,3).reduce((a,x)=>a+num(x.views),0);
 q('accountTrendInsight').textContent='这段周期共 '+fmt(views)+' 播放、'+fmt(posts)+' 次投稿。峰值 '+(peak?.date||'')+' 达 '+fmt(peak?.views||0)+' 播放，占周期 '+share.toFixed(1)+'%；TOP3 日期合计占 '+(views?top3/views*100:0).toFixed(1)+'%。注意：每日点赞/评论可能出现负值，按后台趋势增减理解，不当作单条作品绝对值。'
}

function accountHeaderKey(k){
 const s=String(k||'').trim().toLowerCase().replace(/\s+/g,'');
 const map={
   '标题':'title','作品标题':'title','视频标题':'title','作品':'title','title':'title','caption':'title',
   '发布日期':'date','发布时间':'date','作品发布时间':'date','视频发布时间':'date','日期':'date','date':'date','publishedat':'date',
   '播放':'views','播放量':'views','播放数':'views','播放次数':'views','视频播放量':'views','views':'views','play':'views',
   '点赞':'likes','点赞量':'likes','点赞数':'likes','点赞次数':'likes','likes':'likes',
   '评论':'comments','评论量':'comments','评论数':'comments','评论次数':'comments','comments':'comments',
   '收藏':'saves','收藏量':'saves','收藏数':'saves','收藏次数':'saves','saves':'saves','favorites':'saves',
   '分享':'shares','分享量':'shares','分享数':'shares','分享次数':'shares','shares':'shares',
   '内容形式':'format','作品类型':'format','视频类型':'format','形式':'format','类型':'format','format':'format','type':'format',
   '新增粉丝':'newFollowers','涨粉':'newFollowers','涨粉数':'newFollowers','粉丝增量':'newFollowers','newfollowers':'newFollowers',
   '完播率':'completionRate','视频完播率':'completionRate','completionrate':'completionRate',
   '平均观看时长':'avgWatchTime','平均播放时长':'avgWatchTime','人均观看时长':'avgWatchTime','avgwatchtime':'avgWatchTime',
   '询单':'inquiries','询单数':'inquiries','inquiries':'inquiries',
   '订单':'orders','订单数':'orders','orders':'orders',
   '销售额':'revenue','成交额':'revenue','revenue':'revenue'
 };
 return map[s]||s
}
function parseCsv(text){
 const rows=[];let row=[],cell='',quote=false;
 for(let i=0;i<text.length;i++){const ch=text[i],n=text[i+1];
   if(ch==='"'){if(quote&&n==='"'){cell+='"';i++}else quote=!quote}
   else if(ch===','&&!quote){row.push(cell);cell=''}
   else if((ch==='\n'||ch==='\r')&&!quote){if(ch==='\r'&&n==='\n')i++;row.push(cell);cell='';if(row.some(v=>String(v).trim()))rows.push(row);row=[]}
   else cell+=ch
 }
 row.push(cell);if(row.some(v=>String(v).trim()))rows.push(row);
 if(rows.length<2)return[];
 const headers=rows[0].map(accountHeaderKey);
 return rows.slice(1).map(r=>{const o={};headers.forEach((h,i)=>o[h]=r[i]??'');return o})
}
function normalizeAccountRecord(x,i=0){
 const title=String(x.title||x.作品标题||x.标题||('未命名作品 '+(i+1))).trim();
 const date=String(x.date||x.发布日期||x.发布时间||'').slice(0,10);
 let format=String(x.format||x.type||x.内容形式||'video15').toLowerCase();
 if(/图|海报|poster/.test(format))format='poster';else if(/25/.test(format))format='video25';else if(/15|视频|video/.test(format))format='video15';else if(/image|图片/.test(format))format='image';
 const clean=v=>{const n=Number(String(v??'').replace(/[,，\s]/g,''));return Number.isFinite(n)?Math.max(0,n):0};
 const pct=v=>{const raw=String(v??'').trim();if(!raw)return 0;const n=Number(raw.replace('%',''));if(!Number.isFinite(n))return 0;return raw.includes('%')?n:(n<=1?n*100:n)};
 const key=(date+'|'+title).toLowerCase();
 let h=0;for(let j=0;j<key.length;j++)h=(h*31+key.charCodeAt(j))>>>0;
 return{id:'sagi_import_'+h.toString(36),accountName:'萨吉体育',douyinId:'181444241',source:'import',title,date,format,
   views:clean(x.views),likes:clean(x.likes),comments:clean(x.comments),saves:clean(x.saves),shares:clean(x.shares),
   newFollowers:clean(x.newFollowers),completionRate:pct(x.completionRate),avgWatchTime:String(x.avgWatchTime||'').trim(),
   inquiries:clean(x.inquiries),orders:clean(x.orders),revenue:clean(x.revenue),hook:title,recordedAt:date?Date.parse(date+'T12:00:00+08:00'):Date.now()}
}
function mergeAccountData(records){
 const before=new Map((state.accountData||[]).map(x=>[x.id,x])),map=new Map(before);let added=0,updated=0;
 records.forEach((x,i)=>{const r=normalizeAccountRecord(x,i);if(!r.title)return;if(map.has(r.id))updated++;else added++;map.set(r.id,{...(map.get(r.id)||{}),...r})});
 state.accountData=Array.from(map.values()).sort((a,b)=>(b.recordedAt||0)-(a.recordedAt||0));save();renderAll();return{added,updated,total:records.length}
}
function recognizedHeaderScore(rows){
 if(!Array.isArray(rows)||!rows.length)return 0;
 const keys=Object.keys(rows[0]||{}).map(accountHeaderKey),good=new Set(['title','date','views','likes','comments','saves','shares','format','newFollowers','completionRate','avgWatchTime']);
 return keys.reduce((n,k)=>n+(good.has(k)?1:0),0)
}
function workbookRows(ab){
 if(!window.XLSX)throw new Error('Excel解析组件未加载，请确认当前网络可访问后重试');
 const wb=XLSX.read(ab,{type:'array',cellDates:false}),candidates=wb.SheetNames.map(name=>{
   const ws=wb.Sheets[name],rows=XLSX.utils.sheet_to_json(ws,{defval:'',raw:false});
   return{name,rows,score:recognizedHeaderScore(rows)}
 }).filter(x=>x.rows.length);
 if(!candidates.length)throw new Error('Excel中没有找到数据');
 candidates.sort((a,b)=>b.score-a.score||b.rows.length-a.rows.length);
 return candidates[0]
}
async function parseAccountFile(f){
 const ext=f.name.toLowerCase().split('.').pop();
 if(ext==='xlsx'||ext==='xls'){const ab=await f.arrayBuffer(),best=workbookRows(ab);return{rows:best.rows,sheet:best.name,type:'Excel'}}
 const raw=await f.text();
 if(ext==='json'){const obj=JSON.parse(raw),rows=Array.isArray(obj)?obj:(obj.records||obj.data||obj.items||[]);return{rows,sheet:'JSON',type:'JSON'}}
 return{rows:parseCsv(raw),sheet:'CSV',type:'CSV'}
}
function previewAccountRows(parsed,f){
 const rows=parsed.rows||[];if(!rows.length)throw new Error('没有识别到数据行');
 if(isAccountTrendRows(rows)){
   const normalized=rows.map(normalizeTrendRecord).filter(x=>x.date),existing=new Set((state.accountTrendData||[]).map(x=>x.date)),duplicates=normalized.filter(x=>existing.has(x.date)).length;
   const totalViews=normalized.reduce((a,x)=>a+num(x.views),0),totalPosts=normalized.reduce((a,x)=>a+num(x.posts),0),peak=normalized.slice().sort((a,b)=>num(b.views)-num(a.views))[0];
   state.accountImportPreview={fileName:f.name,rows,type:parsed.type,sheet:parsed.sheet,mode:'trend',normalized,duplicates};
   const box=q('accountImportPreview');box.style.display='block';
   box.innerHTML='<div class="previewHead"><div><b>'+esc(f.name)+'</b><span>'+esc(parsed.type)+' · '+esc(parsed.sheet||'-')+' · 账号每日趋势</span></div><span class="pill good">趋势表已识别</span></div>'+
   '<div class="previewStats"><div class="previewStat"><span>趋势天数</span><b>'+normalized.length+'</b></div><div class="previewStat"><span>周期播放</span><b>'+fmt(totalViews)+'</b></div><div class="previewStat"><span>周期投稿</span><b>'+fmt(totalPosts)+'</b></div><div class="previewStat"><span>峰值日</span><b>'+(peak?.date?.slice(5)||'—')+'</b></div></div>'+
   '<div class="previewCols">已识别：日期 · 投稿量 · 总播放量 · 总点赞量 · 总分享量 · 总评论量 · 5秒完播率 · 2秒跳出率 · 封面点击率 · 平均播放时长</div>'+
   '<div class="previewRows">'+normalized.slice(-3).reverse().map(x=>'<div>'+esc(x.date)+' · '+fmt(x.views)+'播放 · '+fmt(x.posts)+'投稿 · 5秒完播 '+x.fiveSecCompletion.toFixed(2)+'%</div>').join('')+'</div>';
   q('accountImportStatus').textContent='已识别为“账号每日趋势”而非逐条作品：'+normalized.length+'天，'+duplicates+'天与现有数据重复。点击“确认导入”。';return
 }
 const normalized=rows.map((x,i)=>normalizeAccountRecord(Object.fromEntries(Object.entries(x).map(([k,v])=>[accountHeaderKey(k),v])),i));
 const existing=new Set((state.accountData||[]).map(x=>x.id)),valid=normalized.filter(x=>x.title),duplicates=valid.filter(x=>existing.has(x.id)).length;
 const headers=Object.keys(rows[0]||{}),matched=headers.map(h=>[h,accountHeaderKey(h)]).filter(x=>x[0]!==x[1]||['title','date','views','likes','comments','saves','shares','format','newFollowers','completionRate','avgWatchTime'].includes(x[1]));
 state.accountImportPreview={fileName:f.name,rows,type:parsed.type,sheet:parsed.sheet,normalized,duplicates};
 const box=q('accountImportPreview');box.style.display='block';
 box.innerHTML='<div class="previewHead"><div><b>'+esc(f.name)+'</b><span>'+esc(parsed.type)+' · 工作表 '+esc(parsed.sheet||'-')+'</span></div><span class="pill good">识别成功</span></div>'+
 '<div class="previewStats"><div class="previewStat"><span>识别行数</span><b>'+valid.length+'</b></div><div class="previewStat"><span>已有重复</span><b>'+duplicates+'</b></div><div class="previewStat"><span>预计新增</span><b>'+Math.max(0,valid.length-duplicates)+'</b></div><div class="previewStat"><span>识别字段</span><b>'+matched.length+'</b></div></div>'+
 '<div class="previewCols">识别表头：'+matched.slice(0,12).map(x=>esc(x[0])+' → '+esc(x[1])).join(' · ')+'</div>'+
 '<div class="previewRows">'+valid.slice(0,3).map(x=>'<div>'+esc(x.date||'无日期')+' · '+esc(x.title)+' · '+fmt(x.views)+'播放</div>').join('')+'</div>';
 q('accountImportStatus').textContent='分析完成：'+valid.length+' 条作品，'+duplicates+' 条与现有数据重复。确认无误后点击“确认导入”。'
}
async function analyzeAccountFile(){
 const f=q('accountImportFile').files?.[0];state.accountImportPreview=null;q('accountImportPreview').style.display='none';
 if(!f){q('accountImportStatus').textContent='请选择 Excel / CSV / JSON 文件';return}
 q('accountImportStatus').textContent='正在智能识别 '+f.name+' …';
 try{const parsed=await parseAccountFile(f);previewAccountRows(parsed,f)}
 catch(e){q('accountImportStatus').textContent='分析失败：'+e.message;note('文件分析失败')}
}
async function importAccountFile(){
 const f=q('accountImportFile').files?.[0];if(!f){note('请先选择 Excel / CSV / JSON 文件');return}
 try{
   if(!state.accountImportPreview||state.accountImportPreview.fileName!==f.name){const parsed=await parseAccountFile(f);previewAccountRows(parsed,f)}
   const p=state.accountImportPreview;if(!p?.rows?.length)throw new Error('没有可导入数据');
   if(p.mode==='trend'){
     const result=mergeAccountTrendData(p.rows);
     q('accountImportStatus').textContent='账号趋势导入完成：新增 '+result.added+' 天 · 更新 '+result.updated+' 天';
   }else{
     const canonical=p.rows.map(x=>Object.fromEntries(Object.entries(x).map(([k,v])=>[accountHeaderKey(k),v])));
     const result=mergeAccountData(canonical);
     q('accountImportStatus').textContent='作品数据导入完成：新增 '+result.added+' · 更新 '+result.updated+' · LEARNING 已自动更新';
   }
   q('accountImportFile').value='';state.accountImportPreview=null;q('accountImportPreview').style.display='none';
   note('萨吉体育数据已导入 · 新增'+result.added+' 更新'+result.updated)
 }catch(e){q('accountImportStatus').textContent='导入失败：'+e.message;note('导入失败')}
}
function downloadAccountTemplate(){
 const csv='标题,发布日期,内容形式,播放量,点赞,评论,收藏,分享,询单,订单,销售额\n示例内容,2026-11-09,video15,10000,500,30,20,10,0,0,0\n';
 const blob=new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='SAGI_Douyin_Data_Template.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),500)
}
function renderAccountData(){
 const rows=(state.accountData||[]).slice().sort((a,b)=>(b.recordedAt||0)-(a.recordedAt||0));
 const sum=rows.reduce((a,x)=>{a.v+=num(x.views);a.l+=num(x.likes);a.c+=num(x.comments);return a},{v:0,l:0,c:0});
 q('accountWorks').textContent=rows.length;q('accountViews').textContent=fmt(sum.v);q('accountLikes').textContent=fmt(sum.l);q('accountComments').textContent=fmt(sum.c);q('accountDataBadge').textContent=rows.length+' RECORDS';
 const body=q('accountDataTable');body.innerHTML=rows.length?'':'<tr><td colspan="8">暂无账号数据</td></tr>';
 rows.slice(0,50).forEach(x=>{const tr=document.createElement('tr');tr.innerHTML='<td class="accountTableTitle"><b>'+esc(x.title)+'</b><div class="sub">'+esc(x.source==='user-confirmed'?'真实历史样本':'批量导入')+'</div></td><td>'+esc(x.date||'')+'</td><td>'+formatLabel(x.format)+'</td><td>'+fmt(x.views)+'</td><td>'+fmt(x.likes)+'</td><td>'+fmt(x.comments)+'</td><td>'+fmt(x.saves)+'</td><td><span class="pill '+(performanceScore(x)>=60?'good':'')+'">'+performanceScore(x)+'</span></td>';body.appendChild(tr)})
}
function openDouyinApiDocs(){window.open('https://open.douyin.com/','_blank','noopener')}

function performanceRates(x){
 const views=num(x.views),likes=num(x.likes),comments=num(x.comments),saves=num(x.saves),shares=num(x.shares),inq=num(x.inquiries),orders=num(x.orders),inter=likes+comments+saves+shares;
 return{views,interactions:inter,engagementRate:views?inter/views:0,valueRate:views?(saves+shares)/views:0,inquiryPerK:views?inq/views*1000:0,orderRate:inq?orders/inq:0}
}
function performanceScore(x){const r=performanceRates(x);return Math.round(Math.min(100,r.engagementRate*650+r.valueRate*900+Math.min(25,r.inquiryPerK*4)+Math.min(20,num(x.orders)*8)))}
function allPerformance(){
 const rows=[];
 (state.accountData||[]).forEach(x=>rows.push({...x,id:'account:'+x.id,projectId:'account:sagi',goal:x.goal||'reach',source:'douyin-account'}));
 state.contents.forEach(c=>{if(c.metrics&&(num(c.metrics.views)||num(c.metrics.inquiries)||num(c.metrics.orders)))rows.push({...c.metrics,id:'os:'+c.id,contentId:c.id,projectId:c.projectId,title:c.title,format:c.format,hook:c.hook,goal:c.goal,recordedAt:c.metrics.recordedAt||c.updatedAt||0,source:'contentos'})});
 const osIds=new Set(state.contents.map(c=>c.id));state.salesOrders.forEach(o=>(o.contentPerformanceHistory||[]).forEach(x=>{if(x.contentOsId&&osIds.has(x.contentOsId))return;rows.push({...x,id:'saleperf:'+x.id,projectId:'sale:'+o.id,title:x.title||o.teamName,format:x.contentType||'image',hook:x.hook||'',goal:x.directorGoal||x.douyinGoal||'',source:'sales'})}));
 const seen=new Set();return rows.filter(x=>{const key=x.id||[x.projectId,x.title,x.recordedAt].join('|');if(seen.has(key))return false;seen.add(key);return true})
}
function formatLabel(v){return({image:'图片模式',video15:'15秒视频',video25:'25秒品牌片',poster:'海报 / 图文'})[v]||v||'内容'}
function goalLabel(v){return({reach:'传播 / 播放',follow:'涨粉 / 关注',interaction:'互动 / 评论',brand:'品牌 / SAGI识别',sales:'销售 / 询单',event:'赛事 / 报名',story:'故事 / 情绪'})[v]||'品牌'}
function styleLabel(v){return({premium:'顶级品牌广告感',dynamic:'快速动感',north:'北疆风 / 风感',emotion:'人物情绪',product:'产品细节'})[v]||'顶级品牌广告感'}
function hookType(v){const s=String(v||'');if(/[0-9０-９]/.test(s))return'数字型';if(/[？?]/.test(s))return'疑问型';if(/为什么|故事|梦想|历史|不会停|属于|终于/.test(s))return'情绪型';if(/球衣|队服|战袍|设计|上身|细节|配色/.test(s))return'产品型';return'结果型'}
function learningProfile(){
 const rows=allPerformance(),groups={};
 rows.forEach(x=>{const k=x.format||x.contentType||'image',r=performanceRates(x);if(!groups[k])groups[k]={type:k,n:0,score:0,views:0,inq:0,ipk:0};const g=groups[k];g.n++;g.score+=performanceScore(x);g.views+=r.views;g.inq+=num(x.inquiries);g.ipk+=r.inquiryPerK});
 const formats=Object.values(groups).map(g=>({...g,avgScore:g.score/g.n,avgViews:g.views/g.n,avgInq:g.inq/g.n,avgIpk:g.ipk/g.n})).sort((a,b)=>b.avgScore-a.avgScore||b.avgIpk-a.avgIpk);
 const hooks={};rows.forEach(x=>{const k=hookType(x.hook||x.title);if(!hooks[k])hooks[k]={n:0,s:0};hooks[k].n++;hooks[k].s+=performanceScore(x)});
 const hookBest=Object.entries(hooks).map(([name,g])=>({name,avg:g.s/g.n,n:g.n})).sort((a,b)=>b.avg-a.avg)[0]||null;
 const conversion=formats.slice().sort((a,b)=>b.avgIpk-a.avgIpk)[0]||null;
 return{rows,formats,best:formats[0]||null,conversion,hookBest,confidence:rows.length?Math.min(96,20+rows.length*8):0,high:rows.filter(x=>performanceScore(x)>=60).length}
}

function median(nums){const a=nums.filter(Number.isFinite).sort((x,y)=>x-y);if(!a.length)return 0;const m=Math.floor(a.length/2);return a.length%2?a[m]:(a[m-1]+a[m])/2}
function viralModelProfile(){
 const works=allPerformance().filter(x=>num(x.views)>0),trends=(state.accountTrendData||[]).filter(x=>num(x.views)>0);
 const trendViews=trends.reduce((a,x)=>a+num(x.views),0),peak=trends.slice().sort((a,b)=>num(b.views)-num(a.views))[0];
 const weighted=field=>trendViews?trends.reduce((a,x)=>a+num(x.views)*Math.max(0,Number(x[field])||0),0)/trendViews:0;
 const views=works.map(x=>num(x.views)).filter(Boolean),eng=works.map(x=>performanceRates(x).engagementRate);
 const confidence=Math.min(96,Math.round(18+Math.min(42,works.length*7)+Math.min(36,trends.length*1.2)));
 return{
   works,trends,confidence,medianViews:median(views),medianEngagement:median(eng),
   fiveSec:weighted('fiveSecCompletion'),twoSecBounce:weighted('twoSecBounce'),coverCtr:weighted('coverCtr'),avgWatch:weighted('avgWatchTime'),
   peak,peakShare:peak&&trendViews?num(peak.views)/trendViews:0,trendViews
 }
}
function viralCurrentPlan(){
 if(state.director?.generatedAt)return state.director;
 const c=currentContent();if(!c)return null;
 return{theme:c.title||'',hook:c.hook||c.title||'',goal:c.goal||'reach',format:c.format||'video15',style:c.style||'dynamic',platform:c.platform||'douyin',cta:c.cta||'',shots:c.shots||shotsFor(c.format||'video15'),scheduleAt:c.scheduleAt||defaultTime(),cover:c.cover||c.title||'',internetSource:c.internetSource||null}
}
function viralTextSignals(plan,p){
 const t=((plan?.theme||'')+' '+(plan?.hook||'')+' '+(plan?.cover||'')).toLowerCase(),cta=(plan?.cta||'').toLowerCase();
 return{
  number:/\d|一|二|三|四|五|六|七|八|九|十|百|千|万/.test(t),
  question:/[?？]|为什么|你怎么看|打几分|你会/.test(t),
  urgency:/刚刚|今天|今晚|官宣|突发|最新|此刻|终于/.test(t),
  event:/绝杀|冠军|决赛|退役|纪录|记录|官宣|淘汰|逆转|夺冠|世界纪录|历史|破纪录|final|record|champion|retire|official|win/.test(t),
  star:/c罗|cristiano|ronaldo|梅西|messi|姆巴佩|mbapp|哈兰德|haaland|皇马|real madrid|巴萨|barcelona/.test(t),
  local:/新疆|塔城|乌苏|额敏|托里|托朗戈|长风|乡村杯|青训|北疆|球队|业余足球/.test(t),
  emotion:/只有一个|最后|梦想|坚持|离开|告别|传奇|青春|热爱|平凡|历史|终于|遗憾/.test(t),
  resultFirst:/结果|先看|刚刚|绝杀|夺冠|官宣|最终|比分|冠军/.test(t),
  commentCta:/评论|你怎么看|告诉我|打几分|你会选|同意吗/.test(cta+' '+t),
  brand:/sagi|萨吉|足球|球衣|队服|赛事|比赛/.test(t)
 }
}
function viralScoreForPlan(plan,p=project()){
 if(!plan)return null;
 const sig=viralTextSignals(plan,p),a=assets(p),model=viralModelProfile(),hook=String(plan.hook||''),hot=num(plan.internetSource?.score||state.trendSelected?.score||0);
 let topic=45+(sig.event?18:0)+(sig.star?14:0)+(sig.local?10:0)+(hot?Math.min(18,hot*.18):0);
 let stop2=48+(sig.urgency?14:0)+(sig.resultFirst?13:0)+(sig.number?10:0)+(hook.length>=8&&hook.length<=32?12:hook.length>42?-8:5);
 let retention=50+(sig.emotion?12:0)+(sig.number?8:0)+(Array.isArray(plan.shots)&&plan.shots.length>=5?10:0)+(plan.format==='video15'?8:plan.format==='image'?5:0);
 let interaction=42+(sig.question?17:0)+(sig.commentCta?20:0)+(sig.emotion?12:0)+(sig.event?6:0);
 let fit=48+(sig.local?23:0)+(sig.star?12:0)+(sig.brand?12:0)+(p?.type==='hot'?8:0);
 let proof=48+(a.wearing||a.match?24:0)+(a.poster||a.design?12:0)+(p?.source==='sales'?7:0);
 const lp=learningProfile();if(lp.hookBest&&hookType(hook)===lp.hookBest.name){stop2+=5;interaction+=4}
 if(model.fiveSec>=38)retention+=3;if(model.twoSecBounce&&model.twoSecBounce<=46)stop2+=3;
 [topic,stop2,retention,interaction,fit,proof]=[topic,stop2,retention,interaction,fit,proof].map(x=>Math.max(20,Math.min(99,Math.round(x))));
 const total=Math.max(1,Math.min(99,Math.round(topic*.22+stop2*.22+retention*.16+interaction*.17+fit*.15+proof*.08)));
 const verdict=total>=86?'抢发级':total>=78?'高潜力':total>=68?'值得测试':total>=58?'需要优化':'暂缓发布';
 const risks=[],actions=[];
 if(stop2<72){risks.push(['前2秒风险','开头还不够直接，用户可能没来得及理解就划走。']);actions.push('前0.8秒先给人物/结果，不要Logo开场；第二屏再解释。')}
 if(topic<70){risks.push(['选题强度不足','主题缺少重大节点、时效或明显信息差。']);actions.push('把“发生了什么”写得更明确；如果不是热点，就强化新疆现场独家性。')}
 if(interaction<72){risks.push(['评论驱动偏弱','内容看完以后缺少一个必须表达立场的问题。']);actions.push('结尾改成具体问题：你怎么看 / 你给几分 / 如果是你会怎么选。')}
 if(fit<72){risks.push(['SAGI适配一般','可能有流量，但与萨吉体育长期账号身份连接不够。']);actions.push('增加新疆足球、现场、普通球员或萨吉体育独有观察角度。')}
 if(proof<68){risks.push(['证据画面不足','缺少真实人物、现场或有说服力的视觉证据。']);actions.push('优先补真实现场/人物/上身图，而不是继续堆文字。')}
 if(!risks.length){risks.push(['结构健康','当前内容已进入萨吉体育高流量结构，可优先抢时效。'])}
 if(total>=78)actions.unshift('当前方案可以进入制作；优先保证发布时间，不要为了继续精修错过热点窗口。');
 else actions.unshift('先完成最高风险项再发布，修改后重新跑一次 VIRAL MODEL。');
 return{total,verdict,confidence:model.confidence,factors:[['选题强度',topic],['前2秒停留',stop2],['5秒留存结构',retention],['互动潜力',interaction],['SAGI适配',fit],['真实素材',proof]],risks,actions,signals:sig,model}
}
function renderViralModel(){
 const m=viralModelProfile(),plan=viralCurrentPlan(),v=viralScoreForPlan(plan);
 q('viralConfidence').textContent=m.confidence+'%';q('viralWorkSamples').textContent=m.works.length;q('viralTrendDays').textContent=m.trends.length;q('viralPeakShare').textContent=(m.peakShare*100).toFixed(1)+'%';
 q('viralB5').textContent=m.fiveSec?m.fiveSec.toFixed(2)+'%':'—';q('viralB2').textContent=m.twoSecBounce?m.twoSecBounce.toFixed(2)+'%':'—';q('viralBCover').textContent=m.coverCtr?m.coverCtr.toFixed(2)+'%':'—';q('viralBWatch').textContent=m.avgWatch?m.avgWatch.toFixed(2)+'s':'—';q('viralBMedian').textContent=m.medianViews?fmt(Math.round(m.medianViews)):'—';
 if(!v){
   q('viralDial').style.setProperty('--viral','0%');q('viralScore').textContent='0';q('viralVerdict').textContent='等待内容方案';q('viralReason').textContent='先在 AI DIRECTOR 生成一条内容，爆款模型会立即分析。';q('viralFactors').innerHTML='<div class="empty">暂无可分析方案</div>';q('viralRisks').innerHTML='<div class="empty">暂无风险判断</div>';q('viralActions').innerHTML='<div class="empty">暂无优化动作</div>';
 }else{
   q('viralDial').style.setProperty('--viral',v.total+'%');q('viralScore').textContent=v.total;q('viralVerdict').textContent=v.verdict;
   q('viralReason').textContent='基于萨吉体育 '+m.works.length+' 条作品样本 + '+m.trends.length+' 天趋势数据；这是发布前结构指数，不是“必爆概率”。';
   q('viralFactors').innerHTML=v.factors.map(x=>'<div class="viralFactor"><span>'+esc(x[0])+'</span><div class="bar"><i style="width:'+x[1]+'%"></i></div><b>'+x[1]+'</b></div>').join('');
   q('viralRisks').innerHTML=v.risks.map(x=>'<div class="viralItem"><b>'+esc(x[0])+'</b><span>'+esc(x[1])+'</span></div>').join('');
   q('viralActions').innerHTML=v.actions.map((x,i)=>'<div class="viralItem"><b>'+(i+1)+'. '+esc(x)+'</b></div>').join('');
 }
 const rows=state.contents.map(c=>({c,v:viralScoreForPlan({theme:c.title,hook:c.hook,goal:c.goal,format:c.format,style:c.style,platform:c.platform,cta:c.cta,shots:c.shots,cover:c.cover,scheduleAt:c.scheduleAt},allProjects().find(p=>p.id===c.projectId))})).filter(x=>x.v).sort((a,b)=>b.v.total-a.v.total);
 q('viralQueue').innerHTML=rows.length?rows.slice(0,6).map(x=>'<div class="viralQueueRow"><div><b>'+esc(x.c.title||'未命名内容')+'</b><span>'+esc(statusLabel(x.c.status))+' · '+esc(formatLabel(x.c.format))+' · '+esc(x.v.verdict)+'</span></div><em>'+x.v.total+'</em></div>').join(''):'<div class="empty">还没有内容任务</div>'
}
function optimizeCurrentForViral(){
 const p=state.director;if(!p?.generatedAt){switchView('director');note('先生成 AI DIRECTOR 方案');return}
 let best={hook:p.hook,score:-1};(p.hooks||[p.hook]).forEach(h=>{const test={...p,hook:h},v=viralScoreForPlan(test,project());if(v&&v.total>best.score)best={hook:h,score:v.total}});
 p.hook=best.hook;
 if(['reach','interaction','story'].includes(p.goal))p.cta='你怎么看？评论区说说你的答案。';
 if(Array.isArray(p.shots)&&p.shots.length){
   p.shots=p.shots.map((x,i)=>i===0?[x[0],'人物 / 结果先出现，禁止 Logo 开场']:i===1?[x[0],'用数字、冲突或一句强结论建立信息差']:x);
 }
 p.score=scoreDirector(p.format,p.hook,p.goal,project());p.viral=viralScoreForPlan(p,project());save();renderAll();switchView('viral');note('已按萨吉爆款模型优化 · '+p.viral.total+'分')
}

function chooseFormat(goal,p){
 const lp=learningProfile();if(lp.rows.length>=4&&lp.best&&['image','video15','video25','poster'].includes(lp.best.type))return lp.best.type;
 const a=assets(p);if(goal==='story')return a.wearing?'video25':'image';if(goal==='sales'||goal==='reach'||goal==='interaction')return a.wearing?'video15':'image';if(goal==='event')return a.match?'video15':(a.poster?'image':'poster');return a.wearing?'video15':((a.poster||a.design)?'image':'poster')
}
function themeFor(goal,p){const n=p?.name||'SAGI';if(goal==='sales')return n+'｜从设计到真正上身';if(goal==='event')return n+'｜比赛日与现场';if(goal==='story')return n+'｜一群人继续踢球的理由';if(goal==='interaction')return n+'｜这套你打几分？';if(goal==='reach')return n+'｜第一眼就让人停下来';if(goal==='follow')return n+'｜继续记录身边的足球';return n+'｜建立自己的赛场识别'}
function hooksFor(goal,p){
 const n=p?.name||'SAGI';
 if(goal==='sales')return['如果你的球队也想统一比赛服，先看完这15秒。',n+'这一套，从设计图到真正上身。','一支球队的完整视觉，到底应该做到什么程度？','11个人，一套真正属于球队自己的比赛服。','不是换一件球衣，是把整支球队的形象统一起来。'];
 if(goal==='event')return['这个周末，'+n+'继续开踢。','比赛还没开始，风已经到了。','为什么这个冬天，我们还要继续踢？',n+'比赛日｜真正的足球从来不只在大球场。','下一场，见。'];
 if(goal==='story')return[n+'为什么值得被记录？','一件球衣背后，是一群人继续踢球的理由。','我们记录的不是球衣，是他们还在踢球。','从一张照片，到一个普通人的足球梦。',n+'的故事，从这里开始。'];
 if(goal==='interaction')return['这套内容，你第一眼看哪里？','如果满分10分，你给它打几分？','前面和背面，你更喜欢哪一个？','如果这是你的球队，你会选这个配色吗？','只看3秒，你能记住它吗？'];
 if(goal==='reach')return['先别划走，结果先给你看。','第一眼像不像职业赛事内容？','这不是效果图，真正现场是这样。','3秒看完今天最值得看的足球内容。','先给结果，再告诉你为什么。'];
 return['一支球队，也应该有自己的颜色。',n+'的新赛季视觉，终于完整了。','这不是模板，是属于'+n+'的识别。','如果球队的性格能穿在身上，会是什么样？','从队徽到号码，把一支球队真正做完整。']
}
function shotsFor(format){
 if(format==='poster')return[['主视觉','一张最强人物 / 产品图作为绝对主角'],['标题','一句强标题，控制信息密度'],['品牌','SAGI 与项目识别清晰出现']];
 if(format==='image')return[['01 COVER','结果先给｜最强主图'],['02 RESULT','人物 / 上身 / 现场'],['03 WHY','设计或故事逻辑'],['04 DETAIL','细节 / 数据 / 证据'],['05 PROOF','真实项目或现场证明'],['06 CTA','一句行动语 + 话题']];
 if(format==='video25')return[['0–1s','最强结果画面'],['1–3s','Hook 抛问题'],['3–6s','故事 / 设计逻辑'],['6–9s','细节切换'],['9–13s','人物 / 产品爆发'],['13–17s','现场动态'],['17–21s','真实证明'],['21–25s','CTA + SAGI Logo']];
 return[['0–0.8s','最强结果画面'],['0.8–2.2s','Hook 建立信息差'],['2.2–4.3s','故事 / 设计推进'],['4.3–6.8s','细节切换'],['6.8–10.2s','人物 / 动作峰值'],['10.2–12.7s','真实证明'],['12.7–15s','CTA + SAGI Logo']]
}
function musicFor(goal,style){if(style==='north')return'风声 + 北疆鼓点 + 电吉他';if(style==='emotion')return'低频氛围 + 克制钢琴 + 后段抬升';if(style==='dynamic')return'快速鼓点 + 低频重击 + 电吉他';if(style==='product')return'极简电子节拍 + 材质音效 + Logo Hit';if(goal==='event')return'风声 + 低频 + 鼓点推进 + Logo重击';return'低频轰鸣 + 心跳鼓点 + 电吉他抬升'}
function ctaFor(goal){if(goal==='sales')return'你的球队，也该有自己的比赛服';if(goal==='event')return'这个周末，球场见';if(goal==='interaction')return'评论区告诉我，你给它打几分';if(goal==='follow')return'关注 SAGI，继续记录身边的足球';if(goal==='story')return'记录平凡人的足球梦';return'为身边的足球加油'}
function defaultTime(){return today()+'T19:40'}
function scoreDirector(format,hook,goal,p){
 const lp=learningProfile(),a=assets(p),hookS=hook.length>=8&&hook.length<=30?92:(hook?78:55),assetS=a.wearing||a.match?95:(a.poster&&a.design?88:(a.poster||a.design?78:55)),learnS=lp.rows.length?Math.min(95,68+Math.round((lp.best?.avgScore||50)*.25)):70,brandS=(p?.name&&(a.logo||p?.source==='sales'))?92:(p?.name?82:65),ctaS=goal==='sales'||goal==='interaction'?92:85,bonus=lp.best&&lp.best.type===format?4:0,total=Math.min(100,Math.round(hookS*.24+assetS*.22+learnS*.20+brandS*.18+ctaS*.16+bonus));
 return{total,rows:[['Hook',hookS],['素材',assetS],['学习匹配',learnS],['项目识别',brandS],['CTA',ctaS]]}
}
function generateDirector(silent=false){
 const p=project();if(!p){if(!silent)note('请先创建或选择一个内容项目');return null}
 const goal=q('directorGoal').value,requested=q('directorFormat').value,style=q('directorStyle').value,platform=q('directorPlatform').value,format=requested==='auto'?chooseFormat(goal,p):requested,theme=q('directorTheme').value.trim()||themeFor(goal,p),hooks=hooksFor(goal,p),lp=learningProfile();
 let hook=hooks[0];if(lp.hookBest){const x=hooks.find(h=>hookType(h)===lp.hookBest.name);if(x)hook=x}
 const plan={goal,requested,format,style,platform,theme,note:q('directorNote').value.trim(),hooks,hook,shots:shotsFor(format),music:musicFor(goal,style),cta:ctaFor(goal),scheduleAt:defaultTime(),cover:theme.replace(/｜.*/,'')+'｜'+(goal==='event'?'MATCH DAY':'CONTENT'),generatedAt:Date.now()};
 plan.score=scoreDirector(format,hook,goal,p);plan.viral=viralScoreForPlan(plan,p);state.director=plan;renderDirector();renderTodayRecommendation();if(!silent)note('AI导演方案已生成 · '+formatLabel(format)+' · '+plan.score.total+'分');return plan
}
function renderDirector(){
 const p=state.director;if(!p?.generatedAt){q('briefTitle').textContent='等待生成导演方案';q('briefMeta').textContent='AI会结合当前项目素材与历史表现。';q('briefGrid').innerHTML='';q('hookList').innerHTML='<div class="empty">先生成导演方案</div>';q('shotList').innerHTML='<div class="empty">先生成导演方案</div>';q('directorScore').textContent='0';q('scoreRows').innerHTML='';q('directorViralScore').textContent='0';q('directorViralVerdict').textContent='等待爆款模型分析';return}
 q('briefTitle').textContent=p.theme;q('briefMeta').textContent=goalLabel(p.goal)+' · '+formatLabel(p.format)+' · '+styleLabel(p.style)+' · '+p.platform.toUpperCase();
 q('briefGrid').innerHTML=[['推荐形式',formatLabel(p.format)],['建议时长',p.format==='video15'?'15秒':p.format==='video25'?'25秒':p.format==='image'?'6张':'单张'],['发布时间',p.scheduleAt.replace('T',' ')],['音乐方向',p.music],['行动目标',p.cta],['学习样本',learningProfile().rows.length+' 条']].map(x=>'<div class="briefCell"><span>'+esc(x[0])+'</span><b>'+esc(x[1])+'</b></div>').join('');
 q('directorScore').textContent=p.score.total;q('scoreRows').innerHTML=p.score.rows.map(x=>'<div class="scoreRow"><span>'+esc(x[0])+'</span><div class="bar"><i style="width:'+x[1]+'%"></i></div><b>'+x[1]+'</b></div>').join('');const vv=p.viral||viralScoreForPlan(p,project());q('directorViralScore').textContent=vv?.total||0;q('directorViralVerdict').textContent=vv?vv.verdict+' · '+(vv.risks[0]?.[0]||'结构健康'):'等待分析';
 q('hookList').innerHTML=p.hooks.map((h,i)=>'<div class="hook"><strong>0'+(i+1)+'</strong><b>'+esc(h)+'</b><button class="btn" data-hook="'+i+'" type="button">'+(h===p.hook?'已选':'应用')+'</button></div>').join('');
 q('hookList').querySelectorAll('[data-hook]').forEach(b=>b.onclick=()=>{p.hook=p.hooks[Number(b.dataset.hook)];p.score=scoreDirector(p.format,p.hook,p.goal,project());p.viral=viralScoreForPlan(p,project());renderDirector();renderViralModel();note('已应用新的 Hook')});
 q('shotList').innerHTML=p.shots.map(x=>'<div class="shot"><span>'+esc(x[0])+'</span><b>'+esc(x[1])+'</b></div>').join('')
}
function saveDirectorAsContent(){
 const p=state.director?.generatedAt?state.director:generateDirector(true);if(!p)return;
 const c={id:uid('content'),projectId:state.currentProjectId,title:p.theme,goal:p.goal,format:p.format,style:p.style,platform:p.platform,hook:p.hook,hooks:p.hooks,shots:p.shots,music:p.music,cta:p.cta,cover:p.cover,tags:'#新疆足球 #足球队服 #SAGI',scheduleAt:p.scheduleAt,status:'draft',score:p.score.total,viralIndex:(p.viral||viralScoreForPlan(p,project()))?.total||0,createdAt:Date.now(),updatedAt:Date.now(),metrics:null};
 state.contents.unshift(c);state.currentContentId=c.id;save();writeBackDirector(c);renderAll();note('导演方案已保存为内容任务')
}
function writeBackDirector(c){
 if(!c.projectId.startsWith('sale:'))return;patchSales(c.projectId.slice(5),o=>{o.contentDirector={goal:c.goal,format:c.format,style:c.style,theme:c.title,hook:c.hook,shots:c.shots,music:c.music,cta:c.cta,scheduleAt:c.scheduleAt,score:c.score,generatedAt:c.createdAt};o.updatedAt=Date.now()})
}
function patchSales(id,fn){
 try{let x=JSON.parse(localStorage.getItem(TEAM_KEY)||'null');if(!x||!Array.isArray(x.orders))return;const o=x.orders.find(v=>v.id===id);if(!o)return;fn(o);localStorage.setItem(TEAM_KEY,JSON.stringify(x));loadSales()}catch(e){}
}
function addTodayPlan(){
 if(state.currentContentId){const c=state.contents.find(x=>x.id===state.currentContentId);if(c){c.scheduleAt=today()+'T19:40';c.updatedAt=Date.now();save();renderAll();note('已加入今日计划');return}}
 saveDirectorAsContent();const c=state.contents[0];if(c){c.scheduleAt=today()+'T19:40';save();renderAll()}
}
function currentContent(){return state.contents.find(x=>x.id===state.currentContentId)||null}
function renderTodayRecommendation(){
 const p=project(),d=state.director;
 if(!p){q('todayHeroTitle').textContent='创建或选择一个项目，开始建立你的内容系统。';q('todayHeroMeta').textContent='球队 · 赛事 · 品牌 · 产品 · 热点 · 人物故事';return}
 if(d?.generatedAt){q('todayHeroTitle').textContent=d.theme;q('todayHeroMeta').textContent=goalLabel(d.goal)+' · '+formatLabel(d.format)+' · '+d.scheduleAt.replace('T',' ')+' · 导演评分 '+d.score.total}
 else{const f=chooseFormat('brand',p);q('todayHeroTitle').textContent=themeFor(p.type==='event'?'event':'brand',p);q('todayHeroMeta').textContent='建议 '+formatLabel(f)+' · 先让 AI DIRECTOR 生成完整执行方案'}
}
function renderKpis(){
 const t=today();q('kpiToday').textContent=state.contents.filter(c=>(c.scheduleAt||'').slice(0,10)===t).length;q('kpiDraft').textContent=state.contents.filter(c=>c.status==='draft').length;q('kpiReady').textContent=state.contents.filter(c=>c.status==='ready').length;q('kpiLearned').textContent=allPerformance().length
}
function statusLabel(s){return({draft:'待制作',ready:'待发布',published:'已发布'})[s]||s}
function renderToday(){
 const t=today(),list=state.contents.filter(c=>(c.scheduleAt||'').slice(0,10)===t).sort((a,b)=>(a.scheduleAt||'').localeCompare(b.scheduleAt||'')),w=q('todayQueue');w.innerHTML=list.length?'':'<div class="empty">今天还没有安排内容。</div>';
 list.forEach(c=>{const p=allProjects().find(x=>x.id===c.projectId),d=document.createElement('div');d.className='task';d.innerHTML='<div><b>'+esc(c.title)+'</b><span>'+esc(p?.name||'未命名项目')+' · '+formatLabel(c.format)+' · '+esc((c.scheduleAt||'').slice(11,16))+'</span></div><div><span class="pill '+(c.status==='published'?'good':c.status==='ready'?'warn':'')+'">'+statusLabel(c.status)+'</span> <button class="btn" data-open type="button">打开</button></div>';d.querySelector('[data-open]').onclick=()=>openContent(c.id,'create');w.appendChild(d)});
 const p=project(),lp=learningProfile();let msg='当前没有足够数据，先保持内容形式多样化。';if(p){const a=assets(p),missing=[];if(!a.poster&&!a.design)missing.push('主视觉');if(!a.wearing&&!a.match)missing.push('人物/现场');if(missing.length)msg='当前项目还缺 '+missing.join('、')+'。先补齐素材，AI导演评分会明显提高。';else if(lp.best)msg='历史数据目前更支持「'+formatLabel(lp.best.type)+'」；平均评分 '+Math.round(lp.best.avgScore)+'。今天可以优先沿用结构，再换新的 Hook。';else msg='当前项目素材完整，建议直接生成一条 AI 导演方案开始测试。'}q('opportunityBox').textContent=msg;
 renderWeek(q('weekCalendar'))
}
function renderWeek(el){
 const mix=['品牌内容','人物故事','产品内容','足球热点','比赛预热','MATCH DAY','赛果 / MVP'],t=new Date();
 el.innerHTML=mix.map((name,i)=>{const d=new Date(t);d.setDate(t.getDate()+i);const ds=(d.getMonth()+1)+'/'+d.getDate(),planned=state.contents.find(c=>(c.scheduleAt||'').slice(0,10)===isoDate(d));return'<div class="day '+(i===0?'today':'')+'"><span>'+ds+(i===0?' · 今天':'')+'</span><b>'+esc(planned?.title||name)+'</b><em>'+esc(planned?formatLabel(planned.format):'建议结构')+'</em></div>'}).join('')
}
function isoDate(d){const z=n=>String(n).padStart(2,'0');return d.getFullYear()+'-'+z(d.getMonth()+1)+'-'+z(d.getDate())}


const TREND_PROFILES={
 global:{label:'全球足球',query:'(football OR soccer)',boost:['world cup','champions league','premier league','transfer','final','record','goal']},
 china:{label:'中国足球',query:'(football OR soccer) sourcecountry:China',boost:['china','chinese','super league','national team','champion']},
 xinjiang:{label:'新疆足球',query:'Xinjiang (football OR soccer)',boost:['xinjiang','youth','academy','champion','tournament']},
 stars:{label:'C罗 / 梅西',query:'("Cristiano Ronaldo" OR Ronaldo OR Messi OR "Lionel Messi")',boost:['ronaldo','cristiano','messi','record','goal','retire','final']}
};
const BIG5_LEAGUES={
 premier:{label:'英超',en:'Premier League',re:/premier league|arsenal|liverpool|manchester city|man city|manchester united|man utd|chelsea|tottenham|spurs|newcastle|aston villa|brighton|west ham/i},
 laliga:{label:'西甲',en:'La Liga',re:/la liga|laliga|real madrid|barcelona|atletico madrid|atlético madrid|athletic bilbao|real sociedad|villarreal|real betis|sevilla/i},
 seriea:{label:'意甲',en:'Serie A',re:/serie a|juventus|inter milan|internazionale|ac milan|napoli|as roma|\broma\b|lazio|atalanta|fiorentina/i},
 bundesliga:{label:'德甲',en:'Bundesliga',re:/bundesliga|bayern munich|bayern münchen|borussia dortmund|dortmund|bayer leverkusen|leverkusen|rb leipzig|eintracht frankfurt|stuttgart/i},
 ligue1:{label:'法甲',en:'Ligue 1',re:/ligue 1|paris saint-germain|paris st-germain|\bpsg\b|marseille|olympique lyon|\blyon\b|monaco|lille/i}
};
const BIG5_QUERY='("Premier League" OR "La Liga" OR "Serie A" OR Bundesliga OR "Ligue 1" OR Arsenal OR Liverpool OR "Manchester United" OR "Manchester City" OR Chelsea OR Tottenham OR Barcelona OR "Real Madrid" OR "Atletico Madrid" OR Juventus OR "Inter Milan" OR "AC Milan" OR Napoli OR "Bayern Munich" OR Dortmund OR Leverkusen OR PSG OR "Paris Saint-Germain" OR Marseille)';
const BIG5_HOT_MAX_HOURS=18;
const TREND_CACHE_KEY='sagi_content_os_trend_cache_v1';
const TREND_CACHE_MS=10*60*1000;
const TREND_MIN_GAP_MS=6500;
let trendRequestInFlight=null,trendLastRequestAt=0;
function trendEndpoint(query,maxrecords=80){
 const u=new URL('https://api.gdeltproject.org/api/v2/doc/doc');
 u.searchParams.set('query',query);u.searchParams.set('mode','artlist');u.searchParams.set('maxrecords',String(maxrecords));u.searchParams.set('format','json');u.searchParams.set('timespan','24h');u.searchParams.set('sort','hybridrel');
 return u.toString()
}
function sleep(ms){return new Promise(r=>setTimeout(r,ms))}

function hasChineseText(v){return /[\u3400-\u9fff]/.test(String(v||''))}
function zhCacheRead(){try{const x=JSON.parse(localStorage.getItem(ZH_CACHE_KEY)||'{}');return x&&typeof x==='object'?x:{}}catch(e){return{}}}
function zhCacheKey(text){let h=2166136261,s=String(text||'');for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return 'z_'+(h>>>0).toString(36)}
function zhCacheGet(text){const x=zhCacheRead()[zhCacheKey(text)];return x&&x.source===String(text||'')?x.zh:''}
function zhCachePut(text,zh){
 try{
  const cache=zhCacheRead(),key=zhCacheKey(text);cache[key]={source:String(text||''),zh:String(zh||''),at:Date.now()};
  const entries=Object.entries(cache);if(entries.length>320)entries.sort((a,b)=>(b[1]?.at||0)-(a[1]?.at||0)).slice(320).forEach(([k])=>delete cache[k]);
  localStorage.setItem(ZH_CACHE_KEY,JSON.stringify(cache))
 }catch(e){}
}
function sourceLanguageCode(name){
 const n=String(name||'').trim().toLowerCase(),map={
  english:'en',spanish:'es',french:'fr',german:'de',italian:'it',portuguese:'pt',russian:'ru',turkish:'tr',arabic:'ar',
  japanese:'ja',korean:'ko',dutch:'nl',polish:'pl',ukrainian:'uk',greek:'el',romanian:'ro',czech:'cs',swedish:'sv',
  norwegian:'no',danish:'da',finnish:'fi',indonesian:'id',vietnamese:'vi',thai:'th','simplified chinese':'zh','traditional chinese':'zh'
 };
 return map[n]||''
}
function sourceCountryZh(v){
 const n=String(v||''),k=n.toLowerCase(),map={china:'中国','united states':'美国','united kingdom':'英国',spain:'西班牙',france:'法国',germany:'德国',italy:'意大利',portugal:'葡萄牙',brazil:'巴西',argentina:'阿根廷','saudi arabia':'沙特阿拉伯',saudiarabia:'沙特阿拉伯',turkey:'土耳其',japan:'日本','south korea':'韩国',russia:'俄罗斯',mexico:'墨西哥'};
 return map[k]||n
}
function languageZh(v){
 const n=String(v||''),k=n.toLowerCase(),map={english:'英语',spanish:'西班牙语',french:'法语',german:'德语',italian:'意大利语',portuguese:'葡萄牙语',russian:'俄语',turkish:'土耳其语',arabic:'阿拉伯语',japanese:'日语',korean:'韩语',dutch:'荷兰语',chinese:'中文','simplified chinese':'中文','traditional chinese':'中文'};
 return map[k]||n
}
async function fetchWithTimeout(url,opts={},ms=6500){
 const c=new AbortController(),t=setTimeout(()=>c.abort(),ms);
 try{return await fetch(url,{...opts,signal:c.signal})}finally{clearTimeout(t)}
}
async function translateTextToChinese(text,language=''){
 const source=String(text||'').trim();if(!source||hasChineseText(source))return source;
 const cached=zhCacheGet(source);if(cached)return cached;
 let zh='';
 try{
  const r=await fetchWithTimeout('https://libretranslate.com/translate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({q:source,source:'auto',target:'zh',format:'text'})},7000);
  if(r.ok){const j=await r.json();zh=String(j?.translatedText||'').trim()}
 }catch(e){}
 if(!zh||zh===source){
  const code=sourceLanguageCode(language);
  if(code&&code!=='zh')try{
   const u='https://api.mymemory.translated.net/get?q='+encodeURIComponent(source.slice(0,450))+'&langpair='+encodeURIComponent(code+'|zh-CN');
   const r=await fetchWithTimeout(u,{cache:'no-store'},6500);
   if(r.ok){const j=await r.json();zh=String(j?.responseData?.translatedText||'').trim()}
  }catch(e){}
 }
 if(zh&&zh!==source&&!/QUERY LENGTH LIMIT|INVALID LANGUAGE|MYMEMORY WARNING/i.test(zh)){zhCachePut(source,zh);return zh}
 return source
}
async function localizeTrendItems(items,max=24){
 const out=(items||[]).map(a=>({...a})),count=Math.min(max,out.length),batch=4;
 for(let i=0;i<count;i+=batch){
  const translated=await Promise.all(out.slice(i,i+batch).map(async a=>{
   const original=String(a.originalTitle||a.title||'').trim(),zh=await translateTextToChinese(original,a.language);
   return{...a,originalTitle:original,title:zh||original,translated:!!zh&&zh!==original,sourcecountryZh:sourceCountryZh(a.sourcecountry),languageZh:languageZh(a.language)}
  }));
  translated.forEach((x,j)=>out[i+j]=x)
 }
 for(let i=count;i<out.length;i++){const a=out[i],original=String(a.originalTitle||a.title||'').trim();out[i]={...a,originalTitle:original,sourcecountryZh:sourceCountryZh(a.sourcecountry),languageZh:languageZh(a.language)}}
 return out
}

function trendReadCache(){
 try{const x=JSON.parse(localStorage.getItem(TREND_CACHE_KEY)||'null');return x&&Array.isArray(x.items)?x:null}catch(e){return null}
}
function trendWriteCache(query,items){
 try{localStorage.setItem(TREND_CACHE_KEY,JSON.stringify({query,items,fetchedAt:Date.now()}))}catch(e){}
}
function trendCachedItems(maxAge=TREND_CACHE_MS){
 const x=trendReadCache();return x&&Date.now()-num(x.fetchedAt)<=maxAge?x.items:[]
}
function profileMatch(a,profile){
 const t=((a.title||'')+' '+(a.sourcecountry||'')+' '+(a.domain||'')).toLowerCase();
 if(profile==='stars')return /ronaldo|cristiano|messi|lionel/.test(t);
 if(profile==='china')return /china|chinese|中国|中超|国足|csl/.test(t)||(a.sourcecountry||'').toLowerCase()==='china';
 if(profile==='xinjiang')return /xinjiang|新疆|urumqi|乌鲁木齐|tacheng|塔城/.test(t);
 return /football|soccer|goal|match|cup|league|player|coach|team|ronaldo|messi/.test(t)
}
function scoreTrendItems(articles,profile='global'){
 const seen=new Set(),items=[];
 (articles||[]).forEach(a=>{
   const key=(a.url||'')+'|'+(a.title||'');if(!a.title||seen.has(key))return;seen.add(key);
   const raw=trendScore(a,profile),fit=accountFitScore(a),score=Math.round(raw*.62+fit*.38);
   items.push({...a,score,rawTrendScore:raw,fit,reason:trendReason(a,score)})
 });
 return items.sort((a,b)=>b.score-a.score||trendAgeHours(a.seendate)-trendAgeHours(b.seendate))
}
async function trendFetchShared(query,{profile='global',force=false,maxrecords=80}={}){
 const cached=trendReadCache();
 if(!force&&cached&&cached.query===query&&Date.now()-num(cached.fetchedAt)<=TREND_CACHE_MS)return{items:cached.items,cached:true,limited:false,cacheAgeMs:Date.now()-num(cached.fetchedAt)};
 if(trendRequestInFlight)return trendRequestInFlight;
 trendRequestInFlight=(async()=>{
   const gap=Date.now()-trendLastRequestAt;if(gap<TREND_MIN_GAP_MS)await sleep(TREND_MIN_GAP_MS-gap);
   let attempt=0,lastErr=null;
   while(attempt<2){
     attempt++;trendLastRequestAt=Date.now();
     try{
       const res=await fetch(trendEndpoint(query,maxrecords),{cache:'no-store'});
       if(res.status===429){
         const retry=Math.max(TREND_MIN_GAP_MS,Math.min(15000,(Number(res.headers.get('retry-after'))||6)*1000));
         if(attempt<2){await sleep(retry);continue}
         const fallback=trendCachedItems(24*60*60*1000);if(fallback.length){const c=trendReadCache();return{items:fallback,cached:true,limited:true,cacheAgeMs:c?Date.now()-num(c.fetchedAt):24*60*60*1000}};
         throw new Error('热点源限流 HTTP 429')
       }
       if(!res.ok)throw new Error('HTTP '+res.status);
       const data=await res.json(),items=scoreTrendItems(data.articles||[],profile).slice(0,maxrecords);
       trendWriteCache(query,items);return{items,cached:false,limited:false,cacheAgeMs:0}
     }catch(e){lastErr=e;if(attempt<2)await sleep(TREND_MIN_GAP_MS)}
   }
   const fallback=trendCachedItems(24*60*60*1000);if(fallback.length){const c=trendReadCache();return{items:fallback,cached:true,limited:true,cacheAgeMs:c?Date.now()-num(c.fetchedAt):24*60*60*1000}};
   throw lastErr||new Error('热点源暂时不可用')
 })();
 try{return await trendRequestInFlight}finally{trendRequestInFlight=null}
}
function trendAgeHours(seendate){
 if(!seendate)return 24;
 const m=String(seendate).match(/(\d{4})(\d{2})(\d{2})T?(\d{2})(\d{2})(\d{2})?Z?/);
 if(!m)return 24;
 const d=Date.UTC(+m[1],+m[2]-1,+m[3],+m[4],+m[5],+(m[6]||0));
 return Math.max(0,(Date.now()-d)/36e5)
}
function trendScore(a,profile){
 const age=trendAgeHours(a.seendate);let score=48;
 score+=age<=2?28:age<=6?20:age<=12?12:age<=18?6:0;
 if(a.socialimage)score+=5;
 const title=(a.title||'').toLowerCase(),domain=(a.domain||'').toLowerCase();
 const boost=(TREND_PROFILES[profile]?.boost||[]);
 boost.forEach(k=>{if(title.includes(k))score+=4});
 if(/reuters|bbc|espn|guardian|xinhua|apnews|skysports|marca|goal\.com/.test(domain))score+=6;
 if(/[!?]|breaking|record|final|champion|wins|goal|injury|retire|transfer|official/.test(title))score+=5;
 return Math.max(1,Math.min(99,Math.round(score)))
}
function accountFitScore(a){
 const t=(a.title||'').toLowerCase();let s=55;
 if(/football|soccer|goal|match|cup|league|player|coach|team|ronaldo|messi/.test(t))s+=18;
 if(/china|chinese|xinjiang|youth|academy|kit|jersey|football shirt/.test(t))s+=14;
 if(/transfer|record|final|champion|retire|injury|official/.test(t))s+=8;
 return Math.max(1,Math.min(99,s))
}
function trendReason(a,score){
 const age=trendAgeHours(a.seendate),r=[];
 r.push(age<2?'刚出现，时效性高':age<6?'近6小时，仍在窗口期':age<12?'半日内热点':'近24小时信号');
 if(a.socialimage)r.push('有可视化新闻素材');
 if(score>=85)r.push('建议立即做');else if(score>=70)r.push('值得测试');else r.push('先观察');
 return r.join(' · ')
}
function trendProfileQuery(){
 const p=q('trendProfile').value;
 if(p==='custom')return q('trendQuery').value.trim();
 return TREND_PROFILES[p]?.query||TREND_PROFILES.global.query
}
async function fetchInternetTrends(){
 const profile=q('trendProfile').value,query=trendProfileQuery();if(!query){note('请输入自定义关键词');return}
 q('trendStatus').textContent='正在连接互联网并抓取近24小时热点…';q('trendRefreshBtn').disabled=true;
 try{
   let result;
   if(profile!=='custom'){
     result=await trendFetchShared(TREND_PROFILES.global.query,{profile:'global',force:false,maxrecords:80});
     let pool=result.items||[];
     if(profile!=='global'){
       const filtered=pool.filter(a=>profileMatch(a,profile));
       if(filtered.length>=3)pool=scoreTrendItems(filtered,profile);
       else{
         const specific=await trendFetchShared(query,{profile,force:true,maxrecords:50});
         pool=specific.items||[];result={...specific,specific:true}
       }
     }
     state.trendItems=pool.slice(0,24);q('trendStatus').textContent='热点已获取，正在翻译成中文…';state.trendItems=await localizeTrendItems(state.trendItems,24)
   }else{
     result=await trendFetchShared(query,{profile:'global',force:true,maxrecords:50});
     state.trendItems=(result.items||[]).slice(0,24);q('trendStatus').textContent='热点已获取，正在翻译成中文…';state.trendItems=await localizeTrendItems(state.trendItems,24)
   }
   state.trendFetchedAt=Date.now();renderTrends();
   const mode=result?.limited?'缓存兜底':result?.cached?'缓存':'已联网';
   q('trendStatus').textContent=mode+' · '+state.trendItems.length+' 条信号 · '+new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})+' 更新';
   note((result?.limited?'热点源繁忙，已使用缓存 · ':'互联网热点已刷新 · ')+state.trendItems.length+'条')
 }catch(err){
   const fallback=trendCachedItems(24*60*60*1000);
   if(fallback.length){state.trendItems=await localizeTrendItems(fallback.slice(0,24),24);renderTrends();q('trendStatus').textContent='热点源暂时不可用 · 已使用最近缓存 '+state.trendItems.length+' 条';note('已切换最近热点缓存')}
   else{q('trendStatus').textContent='热点源暂时不可用：'+err.message+'。DAILY VIRAL 仍会使用本地项目继续排序。';note('热点源暂时不可用')}
 }finally{q('trendRefreshBtn').disabled=false}
}
function renderTrends(){
 const w=q('trendGrid'),items=state.trendItems||[];
 if(!items.length){w.innerHTML='<div class="empty trendEmpty">还没有热点数据。点击“刷新互联网热点”。</div>';return}
 w.innerHTML=items.map((a,i)=>{
   const img=a.socialimage?'<div class="trendImg" style="background-image:url(&quot;'+esc(a.socialimage)+'&quot;)"></div>':'<div class="trendImg">LIVE NEWS</div>';
   const original=a.originalTitle&&a.originalTitle!==a.title?'<div class="trendOriginal">原文：'+esc(a.originalTitle)+'</div>':'';
   return '<article class="trendCard">'+img+'<div class="trendBody"><div class="trendTop"><span class="heat">SAGI '+a.score+'</span><span class="trendSource">'+esc(a.domain||a.sourcecountryZh||a.sourcecountry||'互联网')+'</span></div><h3>'+esc(a.title)+(a.translated?'<span class="zhBadge">中文</span>':'')+'</h3>'+original+'<p>'+esc((a.sourcecountryZh||a.sourcecountry||'')+(a.languageZh||a.language?' · '+(a.languageZh||a.language):'')+(a.seendate?' · '+a.seendate:''))+'</p><div class="trendReason">'+esc(a.reason)+'</div><div class="trendActions"><button class="btn primary" data-trend-video="'+i+'" type="button">直接制作视频</button><button class="btn" data-trend-gen="'+i+'" type="button">3套打法</button><button class="btn" data-trend-use="'+i+'" type="button">单方案</button><button class="btn" data-trend-open="'+i+'" type="button">原文</button></div></div></article>'
 }).join('');
 w.querySelectorAll('[data-trend-video]').forEach(b=>b.onclick=()=>videoFromTrend(Number(b.dataset.trendVideo),true));w.querySelectorAll('[data-trend-gen]').forEach(b=>b.onclick=()=>generatorFromTrend(Number(b.dataset.trendGen)));w.querySelectorAll('[data-trend-use]').forEach(b=>b.onclick=()=>useTrendForDirector(Number(b.dataset.trendUse)));
 w.querySelectorAll('[data-trend-open]').forEach(b=>b.onclick=()=>{const a=items[Number(b.dataset.trendOpen)];if(a?.url)window.open(a.url,'_blank','noopener')})
}



function releaseFootage(){
 (state.footage||[]).forEach(a=>{try{if(a.url)URL.revokeObjectURL(a.url);if(a.el?.pause)a.el.pause()}catch(e){}});
 if(state.directorMusic?.url)try{URL.revokeObjectURL(state.directorMusic.url)}catch(e){}
 state.footage=[];state.directorCut=[];state.directorMusic=null
}
function waitMedia(el,event='loadedmetadata',ms=12000){
 return new Promise((ok,bad)=>{
   const ready=()=>event==='loadedmetadata'?el.readyState>=1:el.readyState>=2;
   if(ready())return ok(el);
   let done=false;
   const finish=v=>{if(done)return;done=true;clearTimeout(t);el.removeEventListener(event,on);el.removeEventListener('loadeddata',on);el.removeEventListener('canplay',on);el.removeEventListener('error',err);v?ok(el):bad(new Error('media timeout'))};
   const on=()=>finish(true),err=()=>finish(false),t=setTimeout(()=>finish(false),ms);
   el.addEventListener(event,on,{once:true});el.addEventListener('loadeddata',on,{once:true});el.addEventListener('canplay',on,{once:true});el.addEventListener('error',err,{once:true});
   try{el.load?.()}catch(e){}
 })
}
async function seekMedia(video,t){
 return new Promise(resolve=>{let done=false;const finish=()=>{if(done)return;done=true;clearTimeout(tm);video.removeEventListener('seeked',finish);resolve()};const tm=setTimeout(finish,1500);video.addEventListener('seeked',finish,{once:true});try{video.currentTime=Math.max(0,Math.min(t,Math.max(0,video.duration-.05)))}catch(e){finish()}})
}
function sampleVideoFrame(video,canvas){
 const ctx=canvas.getContext('2d',{willReadFrequently:true}),w=canvas.width,h=canvas.height;ctx.drawImage(video,0,0,w,h);return ctx.getImageData(0,0,w,h).data
}
function frameDifference(a,b){
 if(!a||!b||a.length!==b.length)return 0;let sum=0,n=0;for(let i=0;i<a.length;i+=16){const da=Math.abs(a[i]-b[i])+Math.abs(a[i+1]-b[i+1])+Math.abs(a[i+2]-b[i+2]);sum+=da/3;n++}return n?Math.min(100,sum/n/1.8):0
}
function promiseTimeout(p,ms,fallback){return Promise.race([p,new Promise(resolve=>setTimeout(()=>resolve(fallback),ms))])}
async function analyzeVideoMotion(video){
 if(!Number.isFinite(video.duration)||video.duration<.35)return 20;
 const c=document.createElement('canvas');c.width=96;c.height=54;const pts=[.28,.64].map(x=>Math.max(.05,video.duration*x)),frames=[];
 for(const t of pts){
   await promiseTimeout(seekMedia(video,t),650,null);
   try{frames.push(sampleVideoFrame(video,c))}catch(e){}
 }
 if(frames.length<2)return 28;
 return Math.round(frameDifference(frames[0],frames[1]))
}
function mediaQualityScore(a){
 const pixels=(a.width||0)*(a.height||0),res=pixels>=1920*1080?48:pixels>=1280*720?40:pixels>=720*720?31:pixels>=640*360?22:12;
 const aspect=a.height&&a.width?Math.min(a.width,a.height)/Math.max(a.width,a.height):.56,aspectScore=aspect>.48?14:10;
 const durationScore=a.type==='video'?(a.duration>=2&&a.duration<=30?16:a.duration>=1?11:6):12;
 const motionScore=a.type==='video'?Math.min(22,(a.motion||0)*.32):8;
 return Math.max(1,Math.min(100,Math.round(res+aspectScore+durationScore+motionScore)))
}
function footageQualityClass(q){return q>=78?'high':q>=58?'mid':'low'}
function fileLooksLikeVideo(file){const t=String(file?.type||'').toLowerCase(),n=String(file?.name||'').toLowerCase();return t.startsWith('video/')||/\.(mov|mp4|m4v|hevc|webm|mkv|avi)$/i.test(n)||t==='application/octet-stream'}
function fileLooksLikeImage(file){const t=String(file?.type||'').toLowerCase(),n=String(file?.name||'').toLowerCase();return t.startsWith('image/')||/\.(jpg|jpeg|png|webp|heic|heif)$/i.test(n)}
function createFootageShell(file,index){
 const url=URL.createObjectURL(file),id='foot_'+Date.now().toString(36)+'_'+index,video=fileLooksLikeVideo(file),image=fileLooksLikeImage(file);
 if(video){
   return{id,file,url,el:null,type:'video',name:file.name||('视频'+(index+1)),duration:0,width:0,height:0,motion:34,thumb:'',size:file.size||0,mime:file.type||'video/unknown',analysis:'REGISTERED',ready:false,quality:45}
 }
 if(image){
   return{id,file,url,el:null,type:'image',name:file.name||('图片'+(index+1)),duration:0,width:0,height:0,motion:0,thumb:url,size:file.size||0,mime:file.type||'image/unknown',analysis:'REGISTERED',ready:false,quality:40}
 }
 return{id,file,url,el:null,type:'unknown',name:file.name||('素材'+(index+1)),duration:0,width:0,height:0,motion:0,thumb:'',size:file.size||0,mime:file.type||'',analysis:'UNSUPPORTED',ready:false,quality:20}
}
async function hydrateFootageAsset(a){
 if(!a||a.type==='unknown')return a;
 a.analysis='DECODING';
 if(a.type==='video'){
   const v=document.createElement('video');v.preload='metadata';v.muted=true;v.playsInline=true;v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');v.src=a.url;a.el=v;
   await promiseTimeout(waitMedia(v,'loadedmetadata',1500),1650,null);
   a.duration=Number(v.duration)||0;a.width=v.videoWidth||0;a.height=v.videoHeight||0;
   if(a.width&&a.height){a.ready=true;a.analysis='READY';a.quality=mediaQualityScore(a)}
   else{a.analysis='DECODE WAIT';a.quality=42;try{v.pause();v.removeAttribute('src');v.load()}catch(e){};a.el=null}
   return a
 }
 const img=new Image();a.el=img;img.src=a.url;
 await promiseTimeout(new Promise(resolve=>{if(img.complete)return resolve();img.onload=resolve;img.onerror=resolve}),1200,null);
 a.width=img.naturalWidth||0;a.height=img.naturalHeight||0;a.ready=!!(a.width&&a.height);a.analysis=a.ready?'READY':'DECODE WAIT';a.quality=mediaQualityScore(a);if(!a.ready)a.el=null;return a
}
async function hydrateFootagePool(){
 const list=(state.footage||[]).filter(a=>a.type!=='unknown'),queue=list.slice();
 state.directorAnalyzing=true;renderDirectorBin();
 while(queue.length){
   const a=queue.shift();state.footageAnalysis.currentName=a.name;
   try{await hydrateFootageAsset(a);if(a.ready)state.footageAnalysis.done++;else state.footageAnalysis.failed++}
   catch(e){a.analysis='DECODE WAIT';a.el=null;state.footageAnalysis.failed++;state.footageAnalysis.errors.push(a.name+'：'+(e?.message||'读取失败'))}
   renderDirectorBin();await new Promise(resolve=>setTimeout(resolve,30))
 }
 state.directorAnalyzing=false;buildDirectorCut();renderVideoEngine()
}
async function analyzeFootageFiles(){
 const input=q('directorFootageInput'),files=Array.from(input?.files||[]);if(!files.length){note('请先选择真实视频素材');return}
 releaseFootage();
 state.footage=files.map(createFootageShell);
 state.footageAnalysis={selected:files.length,done:0,failed:0,errors:[],selectedFiles:files.map((f,i)=>({name:f.name||('素材'+(i+1)),type:f.type||'',size:f.size||0,kind:fileLooksLikeVideo(f)?'video':fileLooksLikeImage(f)?'image':'unknown'}))};
 buildDirectorCut();renderVideoEngine();note('素材已立即进入镜头库 · '+files.length+' 个');
 hydrateFootagePool().catch(e=>{state.directorAnalyzing=false;state.footageAnalysis.errors.push(e?.message||'快速读取失败');renderDirectorBin()})
}

let footageSelectionTimer=null;
function handleFootageSelection(){
 const input=q('directorFootageInput'),files=Array.from(input?.files||[]);clearTimeout(footageSelectionTimer);
 if(!files.length){releaseFootage();state.footageAnalysis={selected:0,done:0,failed:0,errors:[],selectedFiles:[]};renderDirectorBin();return}
 footageSelectionTimer=setTimeout(()=>analyzeFootageFiles(),40)
}
function handleMusicSelection(){
 const f=q('directorMusicInput')?.files?.[0];
 if(!f)return;
 if(state.directorMusic?.url)try{URL.revokeObjectURL(state.directorMusic.url)}catch(e){}
 state.directorMusic={file:f,url:URL.createObjectURL(f),name:f.name};renderDirectorBin();note('配乐已选择 · '+f.name)
}

function directorRoleScores(a){
 return{
  HOOK:(a.quality||0)*.55+(a.motion||0)*.9,
  ACTION:(a.quality||0)*.5+(a.motion||0)*.8,
  DETAIL:(a.quality||0)*.75+(100-(a.motion||0))*.2,
  EMOTION:(a.quality||0)*.7+Math.max(0,55-Math.abs((a.motion||0)-30))*.35,
  IMPACT:(a.quality||0)*.55+(a.motion||0)*.85,
  CTA:(a.quality||0)*.8+(a.type==='image'?16:0)+(100-(a.motion||0))*.12
 }
}
function pickFootageForRoles(roles){
 const ready=(state.footage||[]).filter(a=>a.ready&&a.el),pool=ready.length?ready:(state.footage||[]),used=new Set();
 return roles.map((role,i)=>{
   const ranked=pool.map(a=>({a,score:directorRoleScores(a)[role]||a.quality||0})).sort((x,y)=>y.score-x.score);
   let pick=ranked.find(x=>!used.has(x.a.id))||ranked[0];if(pick&&pool.length>1)used.add(pick.a.id);return pick?.a||null
 })
}
function directorSceneTexts(){
 const d=state.videoDraft||{},f=d.facts||[],title=trimFact(d.title||project()?.name||'萨吉体育足球现场',34);
 return{title,facts:[f[0]||'真正的足球，先让画面说话。',f[1]||'速度、对抗、情绪，决定这条片子的节奏。',f[2]||'萨吉体育记录身边的足球。'],cta:'你怎么看？评论区说说你的答案。'}
}
function buildDirectorCut(){
 if(!(state.footage||[]).length){state.directorCut=[];renderVideoEngine();return[]}
 const duration=Number(q('directorDuration')?.value||15),is25=duration===25;
 const defs=is25?[
  ['HOOK',0,1.5],['ACTION',1.5,5],['DETAIL',5,8],['ACTION',8,12],['EMOTION',12,16],['IMPACT',16,20.5],['DETAIL',20.5,22.5],['CTA',22.5,25]
 ]:[
  ['HOOK',0,1.2],['ACTION',1.2,4.1],['DETAIL',4.1,6.7],['IMPACT',6.7,9.7],['EMOTION',9.7,12.4],['CTA',12.4,15]
 ];
 const roles=defs.map(x=>x[0]),picks=pickFootageForRoles(roles),txt=directorSceneTexts();
 state.directorCut=defs.map((x,i)=>{
   const [role,start,end]=x,a=picks[i],dur=end-start,maxIn=a?.type==='video'?Math.max(0,(a.duration||0)-dur):0,inPoint=maxIn?Math.min(maxIn,(i*.83)%Math.max(.1,maxIn)):0;
   const text=role==='HOOK'?txt.title:role==='ACTION'?txt.facts[0]:role==='DETAIL'?txt.facts[Math.min(1,i%3)]:role==='IMPACT'?txt.facts[2]:role==='EMOTION'?'这就是足球最值得留下的一刻。':txt.cta;
   return{id:'cut_'+i,role,start,end,assetId:a?.id||'',assetName:a?.name||'互联网视觉兜底',assetType:a?.type||'fallback',inPoint,text}
 });
 renderVideoEngine();return state.directorCut
}
function directorMode(){
 const videos=(state.footage||[]).filter(x=>x.type==='video'),ready=videos.filter(x=>x.ready),high=ready.filter(x=>x.quality>=58);
 return videos.length>=3?{name:high.length>=3?'FOOTAGE DIRECTOR':'FOOTAGE READY',cls:'pro',score:Math.min(99,65+ready.length*5)}:videos.length>=1?{name:'HYBRID CUT',cls:'mid',score:55+ready.length*5}:{name:'NEWS MOTION',cls:'low',score:38}
}
function renderDirectorBin(){
 const grid=q('directorFootageGrid'),sum=q('directorFootageSummary'),badge=q('directorQualityBadge'),cut=q('directorCutList'),cutBadge=q('directorCutBadge');if(!grid)return;
 const items=state.footage||[],mode=directorMode(),a=state.footageAnalysis||{selected:0,done:0,failed:0,errors:[]},selectedNow=q('directorFootageInput')?.files?.length||a.selected||0;
 if(state.directorAnalyzing){badge.textContent='QUEUE '+(a.done+a.failed)+'/'+selectedNow}
 else if(items.length){badge.textContent=mode.name}
 else if(selectedNow){badge.textContent=selectedNow+' SELECTED'}
 else badge.textContent='NO FOOTAGE';
 if(!items.length){
   const selectedFiles=a.selectedFiles||[];grid.innerHTML=selectedFiles.length?selectedFiles.map((f,i)=>'<div class="footageCard"><div class="footageThumb">'+(f.kind==='video'?'VIDEO':f.kind==='image'?'IMAGE':'FILE')+'</div><div class="footageCardBody"><b>'+esc(f.name)+'</b><div class="footageMeta"><span>'+((f.size||0)/1024/1024).toFixed(1)+' MB</span><span class="qualityTag '+(f.kind==='unknown'?'low':'mid')+'">'+esc(f.type||'MIME?')+'</span></div><div class="footageMeta"><span>'+(state.directorAnalyzing?'正在解析':'已选择')+'</span><span>'+f.kind.toUpperCase()+'</span></div></div></div>').join(''):'';
   if(state.directorAnalyzing)sum.textContent='已选择 '+selectedNow+' 个素材 · 快速读取 '+(a.current||1)+' / '+selectedNow+' · 已可用 '+a.done+(a.failed?' · 跳过 '+a.failed:'')+(a.currentName?' · '+a.currentName:'');
   else if(selectedNow&&a.failed>=selectedNow)sum.textContent='已选择 '+selectedNow+' 个素材，但当前浏览器未能解码。'+(a.errors?.slice(0,3).join('；')||'请确认视频已下载到本机，而不是仅存在 iCloud。');
   else if(selectedNow)sum.textContent='已选择 '+selectedNow+' 个素材 · 等待自动分析'+(a.failed?' · 已失败 '+a.failed+' 个':'')+(a.errors?.length?(' · '+a.errors.slice(0,2).join('；')):'');
   else sum.textContent='还没有选择真实视频。选择文件后会立即显示数量并自动分析。';
 }else{
   const videos=items.filter(x=>x.type==='video'),ready=items.filter(x=>x.ready).length,pending=items.filter(x=>!x.ready&&x.type!=='unknown').length;sum.textContent='素材已进入镜头库 '+items.length+' 个 · 已就绪 '+ready+(state.directorAnalyzing?' · 后台逐个解码中':'')+(pending?' · 待处理 '+pending:'')+' · 视频 '+videos.length+' 段 · '+mode.name+(state.directorMusic?' · 音乐 '+state.directorMusic.name:'');
   grid.innerHTML=items.map(a=>'<div class="footageCard"><div class="footageThumb" style="'+(a.thumb?'background-image:url(&quot;'+esc(a.thumb)+'&quot;)':'')+'">'+(a.type==='video'?'VIDEO':'IMAGE')+'</div><div class="footageCardBody"><b>'+esc(a.name)+'</b><div class="footageMeta"><span>'+a.width+'×'+a.height+(a.duration?' · '+a.duration.toFixed(1)+'s':'')+'</span><span class="qualityTag '+footageQualityClass(a.quality)+'">Q'+a.quality+'</span></div><div class="footageMeta"><span>'+(a.ready?'已就绪':a.analysis==='DECODE WAIT'?'待解码':'已登记')+'</span><span>'+a.type.toUpperCase()+'</span></div><div class="motionMeter"><i style="width:'+Math.min(100,a.motion||0)+'%"></i></div></div></div>').join('')
 }
 const rows=state.directorCut||[];cutBadge.textContent=rows.length?directorMode().name:'WAITING';
 cut.innerHTML=rows.length?rows.map((x,i)=>'<div class="directorCutRow"><span>'+x.start.toFixed(1)+'–'+x.end.toFixed(1)+'s</span><strong>'+esc(x.role)+'</strong><b>'+esc(x.assetName)+'<br><span>'+esc(x.text)+'</span></b><em>'+(x.assetType==='video'?'REAL VIDEO':'FALLBACK')+'</em></div>').join(''):'<div class="empty">导入真实视频后生成导演时间线。</div>'
}
function clearDirectorFootage(){releaseFootage();state.footageAnalysis={selected:0,done:0,failed:0,errors:[]};q('directorFootageInput').value='';q('directorMusicInput').value='';renderVideoEngine();note('本地导演素材已清空')}
function directorAsset(id){return(state.footage||[]).find(x=>x.id===id)||null}
function drawDirectorMedia(ctx,a,w,h,local,sceneIndex){
 if(!a?.el)return false;const el=a.el,iw=a.type==='video'?(el.videoWidth||a.width):(el.naturalWidth||a.width),ih=a.type==='video'?(el.videoHeight||a.height):(el.naturalHeight||a.height);if(!iw||!ih)return false;
 const zoom=1.04+.08*easeInOut(local),r=Math.max(w/iw,h/ih)*zoom,dw=iw*r,dh=ih*r,dir=sceneIndex%2?1:-1,px=dir*(1-local)*58,py=((sceneIndex%3)-1)*(1-local)*36;
 ctx.save();ctx.filter='contrast(1.08) saturate(.96) brightness(.88)';ctx.drawImage(el,(w-dw)/2+px,(h-dh)/2+py,dw,dh);ctx.filter='none';ctx.restore();return true
}
function drawDirectorFrame(d,cut,t,webAssets=[]){
 const c=q('videoCanvas'),ctx=c.getContext('2d'),w=c.width,h=c.height,scene=cut.find(x=>t>=x.start&&t<x.end)||cut[cut.length-1],idx=Math.max(0,cut.indexOf(scene)),local=scene?Math.max(0,Math.min(1,(t-scene.start)/(scene.end-scene.start))):0,a=directorAsset(scene?.assetId);
 ctx.fillStyle='#050708';ctx.fillRect(0,0,w,h);let media=false;if(a)media=drawDirectorMedia(ctx,a,w,h,local,idx);
 if(!media&&webAssets.length){const img=webAssets[idx%webAssets.length];drawPremiumBackground(ctx,w,h,t,img,idx,local)}else if(media){const ov=ctx.createLinearGradient(0,0,0,h);ov.addColorStop(0,'rgba(0,0,0,.12)');ov.addColorStop(.55,'rgba(0,0,0,.22)');ov.addColorStop(1,'rgba(0,0,0,.70)');ctx.fillStyle=ov;ctx.fillRect(0,0,w,h)}
 drawTopBrand(ctx,w,idx);if(!scene)return;
 const e=easeOutCubic(Math.min(1,local*1.8)),y=scene.role==='HOOK'?1250:scene.role==='CTA'?1320:1390;
 ctx.save();ctx.globalAlpha=e;ctx.fillStyle='#d7b568';ctx.font="900 34px -apple-system,'PingFang SC',sans-serif";ctx.fillText(scene.role,84,y-120);
 ctx.fillStyle='#f5f7f8';ctx.font=(scene.role==='HOOK'?"1000 82px ":"900 58px ")+"-apple-system,'PingFang SC','Microsoft YaHei',sans-serif";canvasWrapLines(ctx,scene.text,w-168,scene.role==='HOOK'?3:4).forEach((line,i)=>ctx.fillText(line,84,y+i*(scene.role==='HOOK'?100:76)));ctx.restore();
 ctx.fillStyle='rgba(255,255,255,.14)';ctx.fillRect(84,h-132,w-168,8);ctx.fillStyle='#d7b568';ctx.fillRect(84,h-132,(w-168)*Math.min(1,t/(cut[cut.length-1]?.end||15)),8)
}
function prepareDirectorPlayback(cut){
 let active=null;
 return function sync(t){
   const scene=cut.find(x=>t>=x.start&&t<x.end)||cut[cut.length-1],a=directorAsset(scene?.assetId);
   if(a?.id!==active?.id){
     if(active?.type==='video')try{active.el.pause()}catch(e){}
     active=a;
     if(active?.type==='video'){try{active.el.currentTime=Math.max(0,scene.inPoint||0);active.el.muted=true;active.el.play().catch(()=>{})}catch(e){}}
   }
   return a
 }
}
function createMusicTrack(duration){
 const m=state.directorMusic;if(!m?.url)return null;
 try{
   const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return null;const ac=new AC(),dest=ac.createMediaStreamDestination(),audio=new Audio(m.url);audio.preload='auto';audio.loop=true;const src=ac.createMediaElementSource(audio),g=ac.createGain();g.gain.value=.65;src.connect(g);g.connect(dest);audio.currentTime=0;audio.play().catch(()=>{});ac.resume().catch(()=>{});return{ac,dest,audio}
 }catch(e){return null}
}
async function renderDirectorVideo(){
 const d=state.videoDraft,cut=state.directorCut?.length?state.directorCut:buildDirectorCut();if(!cut?.length){return renderInternetVideo()}
 if(state.videoRendering)return;const canvas=q('videoCanvas');if(!canvas.captureStream||!window.MediaRecorder)return renderInternetVideo();
 state.videoRendering=true;renderVideoEngine();q('videoDownload').classList.remove('show');q('videoPreview').style.display='none';q('videoRenderBadge').textContent='DIRECTOR';
 const webAssets=await loadVideoAssets(),duration=cut[cut.length-1].end,fps=30,canvasStream=canvas.captureStream(fps),music=createMusicTrack(duration),beat=!music&&q('videoUseAudio')?.checked?createBeatTrack(duration):null;
 const tracks=[...canvasStream.getVideoTracks()];if(music?.dest?.stream?.getAudioTracks()?.length)tracks.push(...music.dest.stream.getAudioTracks());else if(beat?.dest?.stream?.getAudioTracks()?.length)tracks.push(...beat.dest.stream.getAudioTracks());
 const stream=new MediaStream(tracks),mime=bestRecorderType(),chunks=[];let rec;try{rec=new MediaRecorder(stream,mime?{mimeType:mime,videoBitsPerSecond:18000000}:undefined)}catch(e){rec=new MediaRecorder(stream)}
 q('videoFormatText').textContent=(rec.mimeType||mime||'浏览器默认').replace(';codecs=',' · ');const done=new Promise(resolve=>{rec.ondataavailable=e=>{if(e.data?.size)chunks.push(e.data)};rec.onstop=resolve});rec.start(200);
 const sync=prepareDirectorPlayback(cut),started=performance.now(),total=duration*1000;
 await new Promise(resolve=>{function frame(now){const p=Math.min(1,(now-started)/total),t=p*duration;sync(t);drawDirectorFrame(d,cut,t,webAssets);q('videoProgressBar').style.width=(p*100).toFixed(1)+'%';q('videoProgressText').textContent='AI导演渲染 '+Math.round(p*100)+'% · '+directorMode().name;if(p<1)requestAnimationFrame(frame);else resolve()}requestAnimationFrame(frame)});
 rec.stop();await done;(state.footage||[]).forEach(a=>a.type==='video'&&a.el.pause());canvasStream.getTracks().forEach(t=>t.stop());music?.audio?.pause();music?.dest?.stream?.getTracks()?.forEach(t=>t.stop());music?.ac?.close?.().catch(()=>{});beat?.dest?.stream?.getTracks()?.forEach(t=>t.stop());beat?.ac?.close?.().catch(()=>{});releaseVideoAssets(webAssets);
 const type=rec.mimeType||mime||'video/webm',blob=new Blob(chunks,{type}),url=URL.createObjectURL(blob),preview=q('videoPreview'),link=q('videoDownload'),ext=type.includes('mp4')?'mp4':'webm';if(preview.dataset.url)URL.revokeObjectURL(preview.dataset.url);preview.dataset.url=url;preview.src=url;preview.style.display='block';link.href=url;link.download='SAGI_DIRECTOR_'+today().replace(/-/g,'')+'.'+ext;link.classList.add('show');link.textContent='保存导演版视频 · '+ext.toUpperCase();q('videoProgressText').textContent='导演版完成 · '+(blob.size/1024/1024).toFixed(1)+' MB';q('videoProgressBar').style.width='100%';q('videoRenderBadge').textContent='DONE';state.videoRendering=false;renderVideoEngine();note('AI FOOTBALL VIDEO DIRECTOR 成片已生成')
}
function smartRenderVideo(){return (state.footage||[]).filter(x=>x.type==='video').length?renderDirectorVideo():renderInternetVideo()}

function trimFact(v,max=52){
 const s=String(v||'').replace(/\[[^\]]+\]\([^\)]+\)/g,'').replace(/[#>*_`]/g,'').replace(/\s+/g,' ').trim();
 return s.length>max?s.slice(0,max-1)+'…':s
}
function videoReaderUrl(url){return 'https://r.jina.ai/'+String(url||'').trim()}
async function readInternetArticle(source){
 if(!source?.url)return[];
 try{
  const r=await fetchWithTimeout(videoReaderUrl(source.url),{headers:{'Accept':'text/plain'},cache:'no-store'},12000);
  if(!r.ok)throw new Error('Reader HTTP '+r.status);
  const text=await r.text(),body=text.includes('Markdown Content:')?text.split('Markdown Content:').slice(1).join('Markdown Content:'):text;
  const lines=body.split(/\n+/).map(x=>x.trim()).filter(x=>{
    if(!x||x.length<28||x.length>320)return false;
    if(/^(Title|URL Source|Published Time|Markdown Content):/i.test(x))return false;
    if(/^https?:\/\//i.test(x)||/^!\[/.test(x)||/^#{1,6}\s/.test(x))return false;
    return /[A-Za-z\u3400-\u9fff]/.test(x)
  });
  const seen=new Set(),picked=[];
  for(const line of lines){
   const clean=line.replace(/\[[^\]]+\]\([^\)]+\)/g,'').replace(/[*_>#]/g,'').replace(/\s+/g,' ').trim();
   const key=clean.toLowerCase().slice(0,80);if(seen.has(key))continue;seen.add(key);picked.push(clean);if(picked.length>=5)break
  }
  return picked
 }catch(e){return[]}
}

function cleanMediaUrl(v){
 let u=String(v||'').trim().replace(/&amp;/g,'&');
 if(!/^https?:\/\//i.test(u))return'';
 try{const x=new URL(u);if(/logo|icon|avatar|sprite|tracking|pixel|emoji/i.test(x.pathname))return'';return x.href}catch(e){return''}
}
async function readInternetVisuals(source){
 const urls=[],push=u=>{u=cleanMediaUrl(u);if(u&&!urls.includes(u))urls.push(u)};
 push(source?.socialimage||'');
 if(!source?.url)return urls.slice(0,8);
 try{
   const r=await fetchWithTimeout(videoReaderUrl(source.url),{headers:{Accept:'text/plain'},cache:'no-store'},12000);
   if(!r.ok)return urls.slice(0,8);
   const text=await r.text();
   for(const m of text.matchAll(/!\[[^\]]*\]\((https?:\/\/[^)\s]+)\)/g))push(m[1]);
   for(const m of text.matchAll(/(?:Image|image|图片|Photo|photo)[^\n]{0,100}?(https?:\/\/[^\s)"']+)/g))push(m[1]);
   for(const m of text.matchAll(/https?:\/\/[^\s)"']+\.(?:jpg|jpeg|png|webp)(?:\?[^\s)"']*)?/gi))push(m[0]);
 }catch(e){}
 return urls.slice(0,8)
}
function imageProxyUrl(url){
 try{return 'https://images.weserv.nl/?url='+encodeURIComponent(url)+'&w=1080&h=1920&fit=cover&q=92&output=jpg'}catch(e){return url}
}
async function loadImageUrl(url){
 const attempt=async src=>{
   const r=await fetchWithTimeout(src,{mode:'cors',cache:'force-cache'},10000);if(!r.ok)throw new Error('HTTP '+r.status);
   const blob=await r.blob();if(!/^image\//i.test(blob.type))throw new Error('not image');
   const objectUrl=URL.createObjectURL(blob),img=new Image();
   await new Promise((ok,bad)=>{img.onload=ok;img.onerror=bad;img.src=objectUrl});img._objectUrl=objectUrl;return img
 };
 try{return await attempt(url)}catch(e){try{return await attempt(imageProxyUrl(url))}catch(e2){return null}}
}
async function loadVideoAssets(){
 if(!q('videoUseImage')?.checked)return[];
 const urls=state.videoDraft?.visuals||[];
 const out=[];
 for(const u of urls.slice(0,6)){const img=await loadImageUrl(u);if(img)out.push(img);if(out.length>=5)break}
 return out
}
function releaseVideoAssets(arr){(arr||[]).forEach(img=>{if(img?._objectUrl)URL.revokeObjectURL(img._objectUrl)})}
function videoAssetTier(count){return count>=3?{name:'PRO ASSET CUT',cls:'pro'}:count>=1?{name:'LIMITED ASSETS',cls:'mid'}:{name:'MOTION ONLY',cls:'low'}}

async function chineseFactsFromArticle(source){
 const raw=await readInternetArticle(source),facts=[];
 for(const line of raw.slice(0,4)){
  const zh=await translateTextToChinese(line,source.language||'');
  const f=trimFact(zh,52);if(f&&!facts.includes(f))facts.push(f);if(facts.length>=3)break
 }
 if(!facts.length){
  const fallback=trimFact(source.title||source.originalTitle||'',52);
  if(fallback)facts.push(fallback)
 }
 return facts
}
function buildVideoScenes(draft){
 const f=draft?.facts||[],title=trimFact(draft?.title||'今日足球热点',44),source=draft?.source?.domain||draft?.source?.sourcecountryZh||'互联网';
 return[
  {start:0,end:1.0,kicker:'NOW',text:title,layout:'impact'},
  {start:1.0,end:3.7,kicker:'刚刚发生',text:title,layout:'headline'},
  {start:3.7,end:6.6,kicker:'FACT 01',text:f[0]||title,layout:'fact'},
  {start:6.6,end:9.5,kicker:'FACT 02',text:f[1]||'更多信息正在持续更新',layout:'stat'},
  {start:9.5,end:12.5,kicker:'FACT 03',text:f[2]||'萨吉体育继续跟进后续公开信息',layout:'fact'},
  {start:12.5,end:15,kicker:'SAGI SPORTS',text:'你怎么看？\n评论区说说你的答案。',layout:'cta',source}
 ]
}
async function prepareVideoSource(source,autoRender=false){
 if(!source)return;
 const title=await translateTextToChinese(source.title||source.originalTitle||'',source.language||'');
 state.videoDraft={source:{url:source.url||'',domain:source.domain||'',sourcecountry:source.sourcecountry||'',sourcecountryZh:source.sourcecountryZh||sourceCountryZh(source.sourcecountry),language:source.language||'',languageZh:source.languageZh||languageZh(source.language),socialimage:source.socialimage||'',seendate:source.seendate||'',score:source.score||0,originalTitle:source.originalTitle||source.title||''},title:title||source.title||'',facts:[],preparedAt:Date.now()};
 save();switchView('video');renderVideoEngine();q('videoReaderStatus').textContent='正在读取新闻原文并提取中文事实…';
 const [facts,visuals]=await Promise.all([chineseFactsFromArticle({...source,title}),readInternetVisuals({...source,title})]);
 state.videoDraft.facts=facts;state.videoDraft.visuals=visuals;state.videoDraft.scenes=buildVideoScenes(state.videoDraft);state.videoDraft.preparedAt=Date.now();save();renderVideoEngine();
 const tier=videoAssetTier(visuals.length);
 q('videoReaderStatus').textContent=(facts.length>1?'原文读取完成 · '+facts.length+' 条中文事实':'正文读取受限 · 已使用标题与来源')+' · 发现 '+visuals.length+' 张视觉素材 · '+tier.name;
 if(autoRender){
   if(visuals.length>=2)renderInternetVideo();
   else{q('videoProgressText').textContent='视觉素材不足，已暂停自动成片；可手动生成 MOTION ONLY 版';q('videoRenderBadge').textContent='ASSET LOW';note('素材不足2张 · 建议补素材或手动生成')}
 }
}
function videoFromTrend(i,autoRender=true){
 const a=(state.trendItems||[])[i];if(!a)return;state.trendSelected=a;prepareVideoSource(a,autoRender)
}
function renderVideoEngine(){
 const d=state.videoDraft,box=q('videoSourceBox'),facts=q('videoFacts'),tl=q('videoTimeline');
 renderDirectorBin();q('videoRenderBtn').disabled=!!state.videoRendering;
 if(!d){
  q('videoSourceBadge').textContent='NO SOURCE';box.className='videoEmpty';box.innerHTML='还没有选择互联网热点。去 LIVE RADAR 点击“直接制作视频”。';facts.innerHTML='<div class="empty">等待资料</div>';tl.innerHTML='<div class="empty">等待生成脚本</div>';drawVideoPoster(null,0);return
 }
 box.className='videoSource';q('videoSourceBadge').textContent='SAGI '+(d.source?.score||0);
 box.innerHTML='<span class="pill good">中文标题</span><h3>'+esc(d.title||'')+'</h3><p>原文：'+esc(d.source?.originalTitle||'')+'</p><p>'+esc(d.source?.domain||'互联网')+' · '+esc(d.source?.sourcecountryZh||d.source?.sourcecountry||'')+' · '+esc(d.source?.languageZh||d.source?.language||'')+'</p>';
 facts.innerHTML=(d.facts||[]).length?(d.facts||[]).map((x,i)=>'<div class="factItem"><span>FACT '+String(i+1).padStart(2,'0')+'</span><b>'+esc(x)+'</b></div>').join(''):'<div class="empty">正在读取原文…</div>';
 const tier=videoAssetTier((d.visuals||[]).length),assetStatus=q('videoAssetStatus');if(assetStatus)assetStatus.innerHTML='<span class="assetQuality '+tier.cls+'">'+tier.name+' · '+(d.visuals||[]).length+' 张候选图</span>'+(d.visuals||[]).length?'<div class="videoAssetStrip">'+d.visuals.slice(0,6).map((u,i)=>'<div class="videoAssetThumb" style="background-image:url(&quot;'+esc(u)+'&quot;)"><i>0'+(i+1)+'</i></div>').join('')+'</div>':'';
 const scenes=d.scenes||buildVideoScenes(d);d.scenes=scenes;
 tl.innerHTML=scenes.map(x=>'<div class="timelineRow"><span>'+x.start.toFixed(1)+'–'+x.end.toFixed(1)+'s</span><b>'+esc(x.kicker)+'｜'+esc(x.text).replace(/\n/g,' / ')+'</b></div>').join('');
 drawVideoPoster(d,0)
}
function copyVideoScript(){
 const d=state.videoDraft;if(!d){note('还没有视频脚本');return}
 const text=(d.scenes||buildVideoScenes(d)).map(x=>x.start.toFixed(1)+'–'+x.end.toFixed(1)+'s｜'+x.kicker+'｜'+x.text).join('\n');
 navigator.clipboard?.writeText(text).then(()=>note('15秒视频脚本已复制')).catch(()=>note('复制失败'))
}
function canvasWrapLines(ctx,text,maxWidth,maxLines=4){
 const chars=Array.from(String(text||'')),lines=[];let line='';
 for(const ch of chars){
  if(ch==='\n'){if(line)lines.push(line);line='';if(lines.length>=maxLines)break;continue}
  const test=line+ch;if(ctx.measureText(test).width>maxWidth&&line){lines.push(line);line=ch;if(lines.length>=maxLines)break}else line=test
 }
 if(line&&lines.length<maxLines)lines.push(line);
 if(lines.length===maxLines&&chars.join('').length>lines.join('').length)lines[maxLines-1]=lines[maxLines-1].replace(/[，。；：、\s]*$/,'')+'…';
 return lines
}
function easeOutCubic(x){return 1-Math.pow(1-Math.max(0,Math.min(1,x)),3)}
function easeInOut(x){x=Math.max(0,Math.min(1,x));return x<.5?2*x*x:1-Math.pow(-2*x+2,2)/2}
function sceneAt(d,t){const scenes=d?.scenes||buildVideoScenes(d||{});return scenes.find(x=>t>=x.start&&t<x.end)||scenes[scenes.length-1]}
function sceneIndexAt(d,t){const scenes=d?.scenes||buildVideoScenes(d||{});return Math.max(0,scenes.findIndex(x=>t>=x.start&&t<x.end))}
function extractBigNumber(text){
 const m=String(text||'').match(/(?:\d{1,3}(?:[.,]\d{3})+|\d+(?:\.\d+)?)(?:\s*[%万亿球次场岁年分秒])?/);return m?m[0]:''
}
function drawPremiumBackground(ctx,w,h,t,img=null,sceneIdx=0,local=0){
 const g=ctx.createLinearGradient(0,0,w,h);g.addColorStop(0,'#050708');g.addColorStop(.52,'#0d1519');g.addColorStop(1,'#231a09');ctx.fillStyle=g;ctx.fillRect(0,0,w,h);
 if(img){
  const dir=sceneIdx%2===0?1:-1,zoom=1.07+.10*easeInOut(local),r=Math.max(w/img.width,h/img.height)*zoom,iw=img.width*r,ih=img.height*r,panX=dir*(1-local)*52,panY=(sceneIdx%3-1)*(1-local)*34;
  ctx.save();ctx.globalAlpha=.58;ctx.filter='contrast(1.12) saturate(.94) brightness(.88)';ctx.drawImage(img,(w-iw)/2+panX,(h-ih)/2+panY,iw,ih);ctx.filter='none';ctx.restore();
 }
 const ov=ctx.createLinearGradient(0,0,0,h);ov.addColorStop(0,'rgba(2,5,6,.28)');ov.addColorStop(.45,'rgba(2,5,6,.44)');ov.addColorStop(1,'rgba(2,5,6,.92)');ctx.fillStyle=ov;ctx.fillRect(0,0,w,h);
 const glow=ctx.createRadialGradient(w*.82,h*.18,20,w*.82,h*.18,w*.68);glow.addColorStop(0,'rgba(215,181,104,.16)');glow.addColorStop(1,'rgba(215,181,104,0)');ctx.fillStyle=glow;ctx.fillRect(0,0,w,h);
 ctx.save();ctx.globalAlpha=.16;ctx.strokeStyle='#d7b568';ctx.lineWidth=2;
 for(let i=-4;i<11;i++){const x=i*170+(t*55)%170;ctx.beginPath();ctx.moveTo(x,-80);ctx.lineTo(x+620,h+80);ctx.stroke()}
 ctx.restore();
 ctx.save();ctx.globalAlpha=.08;ctx.fillStyle='#fff';
 for(let i=0;i<55;i++){const x=(i*199+(t*31))%w,y=(i*331+(t*17))%h;ctx.fillRect(x,y,2,2)}
 ctx.restore()
}
function drawTopBrand(ctx,w,sceneIdx){
 ctx.fillStyle='#d7b568';ctx.fillRect(84,112,146,9);
 ctx.fillStyle='#f2f5f6';ctx.font="800 42px -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif";ctx.fillText('SAGI SPORTS',84,180);
 ctx.fillStyle='#819097';ctx.font="600 24px -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif";ctx.fillText('萨吉体育 · FOOTBALL NOW',84,224);
 ctx.textAlign='right';ctx.fillStyle='#d7b568';ctx.font="900 34px -apple-system,'PingFang SC',sans-serif";ctx.fillText(String(sceneIdx+1).padStart(2,'0'),w-84,176);ctx.textAlign='left'
}
function drawKicker(ctx,kicker,x,y,alpha=1){
 ctx.save();ctx.globalAlpha=alpha;ctx.fillStyle='#d7b568';ctx.font="900 38px -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif";ctx.fillText(String(kicker||'').toUpperCase(),x,y);ctx.restore()
}
function drawKineticLines(ctx,text,x,y,maxWidth,fontSize,maxLines,enter){
 ctx.font="900 "+fontSize+"px -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif";
 const lines=canvasWrapLines(ctx,text,maxWidth,maxLines),lh=fontSize*1.22;
 lines.forEach((line,i)=>{
  const delay=i*.08,p=Math.max(0,Math.min(1,(enter-delay)/(1-delay))),e=easeOutCubic(p);
  ctx.save();ctx.globalAlpha=e;ctx.translate((1-e)*70,0);ctx.fillStyle='#f4f6f7';ctx.fillText(line,x,y+i*lh);ctx.restore()
 });
}
function drawImpactLayout(ctx,scene,w,h,local){
 const e=easeOutCubic(Math.min(1,local*1.8)),pulse=1+.035*Math.sin(local*Math.PI);
 ctx.save();ctx.translate(w/2,h/2);ctx.scale(pulse,pulse);ctx.translate(-w/2,-h/2);
 ctx.fillStyle='#d7b568';ctx.font="1000 210px -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif";ctx.globalAlpha=.12+.18*e;ctx.fillText('NOW',70,810);ctx.restore();
 drawKicker(ctx,'刚刚',84,540,e);drawKineticLines(ctx,scene.text,84,680,w-168,92,5,e)
}
function drawHeadlineLayout(ctx,scene,w,h,local){
 const e=easeOutCubic(local),exit=Math.max(0,(local-.82)/.18);
 drawKicker(ctx,scene.kicker,84,535,e*(1-exit));
 ctx.save();ctx.globalAlpha=e*(1-exit);ctx.fillStyle='#d7b568';ctx.fillRect(84,580,(w-168)*e,7);ctx.restore();
 drawKineticLines(ctx,scene.text,84,710,w-168,86,5,e*(1-exit))
}
function drawFactLayout(ctx,scene,w,h,local,idx){
 const e=easeOutCubic(local),n=extractBigNumber(scene.text);
 ctx.save();ctx.globalAlpha=.10;ctx.fillStyle='#fff';ctx.font="1000 310px -apple-system,'PingFang SC',sans-serif";ctx.fillText(String(idx).padStart(2,'0'),720,720);ctx.restore();
 drawKicker(ctx,scene.kicker,84,570,e);
 if(n){ctx.save();ctx.globalAlpha=.16+.30*e;ctx.fillStyle='#d7b568';ctx.font="1000 190px -apple-system,'PingFang SC',sans-serif";ctx.fillText(n,84,805);ctx.restore();drawKineticLines(ctx,scene.text,84,990,w-168,68,5,e)}
 else drawKineticLines(ctx,scene.text,84,760,w-168,72,6,e)
 ctx.save();ctx.globalAlpha=e;ctx.fillStyle='#d7b568';ctx.fillRect(84,1370,Math.min(w-168,(w-168)*(.28+.72*local)),8);ctx.restore()
}
function drawStatLayout(ctx,scene,w,h,local){
 const e=easeOutCubic(local),n=extractBigNumber(scene.text)||'02';
 drawKicker(ctx,scene.kicker,84,520,e);
 ctx.save();ctx.globalAlpha=.96*e;ctx.fillStyle='#d7b568';ctx.font="1000 260px -apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif";ctx.fillText(n,76,900);ctx.restore();
 ctx.save();ctx.globalAlpha=.12;ctx.strokeStyle='#d7b568';ctx.lineWidth=5;ctx.strokeRect(70,610,w-140,360);ctx.restore();
 drawKineticLines(ctx,scene.text,84,1105,w-168,66,5,e)
}
function drawCtaLayout(ctx,scene,w,h,local,d){
 const e=easeOutCubic(local);
 ctx.save();ctx.globalAlpha=e;ctx.fillStyle='#d7b568';ctx.font="1000 110px -apple-system,BlinkMacSystemFont,'PingFang SC',sans-serif";ctx.fillText('SAGI',84,650);ctx.restore();
 drawKineticLines(ctx,scene.text,84,820,w-168,82,4,e);
 ctx.save();ctx.globalAlpha=e;ctx.fillStyle='#9aa7ac';ctx.font="600 27px -apple-system,'PingFang SC',sans-serif";ctx.fillText('资料来源 · '+(d?.source?.domain||scene.source||'互联网'),84,1510);ctx.fillText('为身边的足球加油',84,1560);ctx.restore()
}
function drawTransition(ctx,w,h,local){
 const edge=Math.min(local,1-local),strength=edge<.08?(1-edge/.08):0;if(strength<=0)return;
 ctx.save();ctx.globalAlpha=.18*strength;ctx.fillStyle='#f6e2a7';ctx.fillRect(0,0,w,h);ctx.globalAlpha=.35*strength;ctx.fillStyle='#d7b568';ctx.fillRect(0,h*(.48-strength*.1),w,8+36*strength);ctx.restore()
}
function drawVideoPoster(d,progress=0,assets=null){
 const c=q('videoCanvas');if(!c)return;const ctx=c.getContext('2d'),w=c.width,h=c.height,t=Math.max(0,Math.min(15,progress*15)),scene=sceneAt(d,t),idx=sceneIndexAt(d,t);
 const local=scene?Math.max(0,Math.min(1,(t-scene.start)/(scene.end-scene.start))):0,img=Array.isArray(assets)&&assets.length?assets[idx%assets.length]:assets;
 drawPremiumBackground(ctx,w,h,t,img,idx,local);drawTopBrand(ctx,w,idx);
 if(!scene){ctx.fillStyle='#fff';ctx.font="900 92px -apple-system,'PingFang SC',sans-serif";ctx.fillText('等待互联网资料',84,900);return}
 if(scene.layout==='impact')drawImpactLayout(ctx,scene,w,h,local);
 else if(scene.layout==='headline')drawHeadlineLayout(ctx,scene,w,h,local);
 else if(scene.layout==='stat')drawStatLayout(ctx,scene,w,h,local);
 else if(scene.layout==='cta')drawCtaLayout(ctx,scene,w,h,local,d);
 else drawFactLayout(ctx,scene,w,h,local,idx);
 drawTransition(ctx,w,h,local);
 ctx.fillStyle='rgba(255,255,255,.12)';ctx.fillRect(84,h-132,w-168,8);ctx.fillStyle='#d7b568';ctx.fillRect(84,h-132,(w-168)*Math.min(1,t/15),8);
 ctx.fillStyle='#819097';ctx.font="600 24px -apple-system,'PingFang SC',sans-serif";ctx.fillText('SOURCE · '+(d?.source?.domain||'SAGI CONTENT OS'),84,h-72);
 ctx.textAlign='right';ctx.fillText(Math.min(15,t).toFixed(1)+' / 15.0s',w-84,h-72);ctx.textAlign='left'
}
function bestRecorderType(){
 const types=['video/mp4;codecs=avc1.42E01E,mp4a.40.2','video/mp4','video/webm;codecs=vp9,opus','video/webm;codecs=vp8,opus','video/webm'];
 return types.find(t=>window.MediaRecorder?.isTypeSupported?.(t))||''
}
function createBeatTrack(duration=15){
 try{
  const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return null;
  const ac=new AC(),dest=ac.createMediaStreamDestination(),master=ac.createGain();master.gain.value=.13;master.connect(dest),start=ac.currentTime+.06;
  const hit=(at,freq=70,len=.16,vol=.20,type='sine')=>{const o=ac.createOscillator(),g=ac.createGain();o.type=type;o.frequency.setValueAtTime(freq,at);o.frequency.exponentialRampToValueAtTime(Math.max(35,freq*.55),at+len);g.gain.setValueAtTime(.0001,at);g.gain.exponentialRampToValueAtTime(vol,at+.01);g.gain.exponentialRampToValueAtTime(.0001,at+len);o.connect(g);g.connect(master);o.start(at);o.stop(at+len+.02)};
  const noise=(at,len=.08,vol=.035)=>{const b=ac.createBuffer(1,Math.max(1,ac.sampleRate*len),ac.sampleRate),d=b.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1)*(1-i/d.length);const src=ac.createBufferSource(),g=ac.createGain(),f=ac.createBiquadFilter();src.buffer=b;f.type='highpass';f.frequency.value=1200;g.gain.setValueAtTime(vol,at);g.gain.exponentialRampToValueAtTime(.0001,at+len);src.connect(f);f.connect(g);g.connect(master);src.start(at)};
  for(let bar=0;bar<duration*2;bar++){const at=start+bar*.5;hit(at,bar%4===0?58:78,bar%4===0?.22:.12,bar%4===0?.25:.10,bar%4===0?'sawtooth':'sine');if(bar%2===1)noise(at+.02,.07,.045)}
  [0,1,3.7,6.6,9.5,12.5].forEach((sec,i)=>{hit(start+sec,42,.32,i===0?.34:.24,'sawtooth');noise(start+sec,.12,.055)});
  const rise=ac.createOscillator(),rg=ac.createGain();rise.type='sine';rise.frequency.setValueAtTime(100,start+11.8);rise.frequency.exponentialRampToValueAtTime(360,start+12.5);rg.gain.setValueAtTime(.0001,start+11.8);rg.gain.linearRampToValueAtTime(.06,start+12.45);rg.gain.exponentialRampToValueAtTime(.0001,start+12.7);rise.connect(rg);rg.connect(master);rise.start(start+11.8);rise.stop(start+12.8);
  ac.resume().catch(()=>{});return{ac,dest}
 }catch(e){return null}
}
async function renderInternetVideo(){
 const d=state.videoDraft;if(!d){note('请先从 LIVE RADAR 选择热点');switchView('trends');return}
 if(state.videoRendering)return;
 const canvas=q('videoCanvas');if(!canvas.captureStream||!window.MediaRecorder){q('videoProgressText').textContent='当前浏览器不支持直接录制，请使用脚本进入其他视频工具';note('当前浏览器不支持直接成片');return}
 state.videoRendering=true;renderVideoEngine();q('videoRenderBadge').textContent='RENDERING';q('videoProgressText').textContent='正在生成 15 秒视频…';q('videoDownload').classList.remove('show');q('videoPreview').style.display='none';
 const assets=await loadVideoAssets(),tier=videoAssetTier(assets.length),fps=30,canvasStream=canvas.captureStream(fps),beat=q('videoUseAudio')?.checked?createBeatTrack(15):null;
 q('videoRenderBadge').textContent=tier.name;
 q('videoProgressText').textContent='正在生成 15 秒视频 · '+tier.name+' · '+assets.length+' 张可用图';
 const tracks=[...canvasStream.getVideoTracks()];if(beat?.dest?.stream?.getAudioTracks()?.length)tracks.push(...beat.dest.stream.getAudioTracks());
 const stream=new MediaStream(tracks),mime=bestRecorderType(),chunks=[];
 let rec;try{rec=new MediaRecorder(stream,mime?{mimeType:mime,videoBitsPerSecond:16000000}:undefined)}catch(e){rec=new MediaRecorder(stream)}
 q('videoFormatText').textContent=(rec.mimeType||mime||'浏览器默认').replace(';codecs=',' · ');
 const done=new Promise(resolve=>{rec.ondataavailable=e=>{if(e.data?.size)chunks.push(e.data)};rec.onstop=()=>resolve()});
 rec.start(250);const started=performance.now(),duration=15000;
 await new Promise(resolve=>{
  function frame(now){
   const p=Math.min(1,(now-started)/duration);drawVideoPoster(d,p,assets);q('videoProgressBar').style.width=(p*100).toFixed(1)+'%';q('videoProgressText').textContent='渲染 '+Math.round(p*100)+'%';
   if(p<1)requestAnimationFrame(frame);else resolve()
  }requestAnimationFrame(frame)
 });
 rec.stop();await done;canvasStream.getTracks().forEach(t=>t.stop());beat?.dest?.stream?.getTracks()?.forEach(t=>t.stop());beat?.ac?.close?.().catch(()=>{});releaseVideoAssets(assets);
 const type=rec.mimeType||mime||'video/webm',blob=new Blob(chunks,{type}),url=URL.createObjectURL(blob),preview=q('videoPreview'),a=q('videoDownload'),ext=type.includes('mp4')?'mp4':'webm';
 if(preview.dataset.url)URL.revokeObjectURL(preview.dataset.url);preview.dataset.url=url;preview.src=url;preview.style.display='block';a.href=url;a.download='SAGI_NEWS_'+today().replace(/-/g,'')+'.'+ext;a.classList.add('show');a.textContent='保存视频文件 · '+ext.toUpperCase();
 q('videoProgressText').textContent='生成完成 · '+(blob.size/1024/1024).toFixed(1)+' MB';q('videoRenderBadge').textContent='DONE';q('videoProgressBar').style.width='100%';state.videoRendering=false;renderVideoEngine();note('15秒热点视频已生成')
}

function generatorShortTopic(t,max=34){
 const s=String(t||'').replace(/^热点[｜|:\s]*/,'').replace(/\s+/g,' ').trim();
 return s.length>max?s.slice(0,max-1)+'…':s
}
function generatorInternetSource(topic){
 const a=state.trendSelected;
 if(a&&String(topic).includes(generatorShortTopic(a.title,22)))return{url:a.url,domain:a.domain,title:a.title,seendate:a.seendate,score:a.score};
 if(a&&state.viralGeneratorTopic===a.title)return{url:a.url,domain:a.domain,title:a.title,seendate:a.seendate,score:a.score};
 return state.director?.internetSource||null
}
function variantPlan(strategy,topic,p,srcOverride=null){
 const t=generatorShortTopic(topic),src=srcOverride||generatorInternetSource(topic),now=Date.now();
 let goal='reach',style='dynamic',hook='',cover='',cta='',format=chooseFormat('reach',p),label='',desc='';
 if(strategy==='speed'){
   label='A · SPEED FIRST';desc='抢时效 / 强结果 / 前0.8秒直给';
   hook='刚刚｜'+t;cover='刚刚｜'+t;cta='这条消息你怎么看？评论区聊聊。'
 }else if(strategy==='emotion'){
   label='B · EMOTION';desc='强人物 / 强记忆 / 情绪扩散';
   goal='story';style='emotion';format=chooseFormat('story',p);
   hook='别只看结果，真正让人记住的是这一刻｜'+t;cover='这一刻｜'+t;cta='这件事最打动你的是什么？评论区说说。'
 }else{
   label='C · DEBATE';desc='强观点 / 强提问 / 评论驱动';
   goal='interaction';style='premium';format=chooseFormat('interaction',p);
   hook='你怎么看？｜'+t;cover='你怎么看｜'+t;cta='你的答案是什么？评论区说说理由。'
 }
 const plan={strategy,label,desc,goal,requested:'auto',format,style,platform:'douyin',theme:t,note:'SAGI V1.6 三方案生成；保留事实，不夸大未证实信息。',hooks:[hook],hook,shots:shotsFor(format),music:musicFor(goal,style),cta,scheduleAt:defaultTime(),cover,generatedAt:now,internetSource:src};
 plan.score=scoreDirector(format,hook,goal,p);plan.viral=viralScoreForPlan(plan,p);
 return plan
}
function generateViralVariants(topic){
 let raw=String(topic??q('generatorTopic')?.value??'').trim();
 if(!raw&&state.trendSelected?.title)raw=state.trendSelected.title;
 if(!raw&&state.director?.theme)raw=state.director.theme;
 if(!raw){const p=project();if(p)raw=themeFor(p.type==='event'?'event':p.type==='story'?'story':p.type==='product'?'sales':'reach',p)}
 if(!raw){note('请先输入主题或从 LIVE RADAR 选择热点');return[]}
 let p=project();
 if(state.trendSelected&&(!p||p.type!=='hot'))p=ensureHotProject();
 if(!p)p=ensureHotProject();
 state.viralGeneratorTopic=raw;q('generatorTopic').value=raw;
 state.viralVariants=['speed','emotion','debate'].map(k=>variantPlan(k,raw,p)).sort((a,b)=>(b.viral?.total||0)-(a.viral?.total||0));
 save();renderViralGenerator();note('已生成3套打法 · 冠军 '+(state.viralVariants[0]?.viral?.total||0)+'分');return state.viralVariants
}
function renderViralGenerator(){
 const input=q('generatorTopic');if(input&&!input.value)input.value=state.viralGeneratorTopic||state.trendSelected?.title||'';
 const src=q('generatorSources');if(src){
   const list=[];
   if(state.trendSelected)list.push('<span class="on">LIVE RADAR · '+esc(generatorShortTopic(state.trendSelected.title,22))+'</span>');
   if(project())list.push('<span>PROJECT · '+esc(project().name)+'</span>');
   if(state.director?.generatedAt)list.push('<span>DIRECTOR · '+esc(generatorShortTopic(state.director.theme,22))+'</span>');
   src.innerHTML=list.length?list.join(''):'<span>可直接输入主题生成</span>'
 }
 const vars=state.viralVariants||[],grid=q('variantGrid'),pick=q('generatorPick');
 if(!vars.length){grid.innerHTML='<div class="empty genEmpty">输入主题或从 LIVE RADAR 选择热点，然后生成3套打法。</div>';pick.style.display='none';return}
 const best=vars[0];pick.style.display='block';q('generatorPickTitle').textContent=best.label+'｜'+best.hook;q('generatorPickMeta').textContent='VIRAL '+best.viral.total+' · '+best.viral.verdict+' · '+best.desc+' · 建议优先制作';
 grid.innerHTML=vars.map((v,i)=>{
   const factors=(v.viral?.factors||[]).slice(0,4).map(x=>'<i>'+esc(x[0])+' '+x[1]+'</i>').join('');
   return '<article class="variantCard '+(i===0?'best':'')+'">'+(i===0?'<span class="bestBadge">TODAY PICK</span>':'')+
    '<div class="variantTop"><strong>'+esc(v.label)+'</strong><div class="variantScore">'+(v.viral?.total||0)+'<small>/99</small></div></div>'+
    '<div class="variantMeta">'+esc(v.desc)+' · '+esc(formatLabel(v.format))+' · '+esc(v.viral?.verdict||'')+'</div>'+
    '<div class="variantBlock"><span>HOOK</span><b>'+esc(v.hook)+'</b></div>'+
    '<div class="variantBlock"><span>COVER</span><b>'+esc(v.cover)+'</b></div>'+
    '<div class="variantBlock"><span>CTA</span><b>'+esc(v.cta)+'</b></div>'+
    '<div class="variantFactors">'+factors+'</div>'+
    '<div class="variantActions"><button class="btn '+(i===0?'primary':'')+'" data-variant-apply="'+i+'" type="button">采用这套</button><button class="btn" data-variant-director="'+i+'" type="button">查看导演方案</button></div></article>'
 }).join('');
 grid.querySelectorAll('[data-variant-apply]').forEach(b=>b.onclick=()=>applyViralVariant(Number(b.dataset.variantApply),true));
 grid.querySelectorAll('[data-variant-director]').forEach(b=>b.onclick=()=>applyViralVariant(Number(b.dataset.variantDirector),false))
}
function applyViralVariant(i,toCreate=false){
 const v=(state.viralVariants||[])[i];if(!v)return;
 state.director=JSON.parse(JSON.stringify(v));state.director.generatedAt=Date.now();state.currentContentId='';
 q('directorGoal').value=v.goal;q('directorFormat').value=v.format;q('directorStyle').value=v.style;q('directorPlatform').value='douyin';q('directorTheme').value=v.theme;q('directorNote').value=v.note;
 save();renderAll();
 if(toCreate){saveDirectorAsContent();switchView('create');note('冠军打法已进入制作 · VIRAL '+(v.viral?.total||0))}
 else{switchView('director');note('已载入 '+v.label+' · VIRAL '+(v.viral?.total||0))}
}
function saveBestViralVariant(){
 if(!(state.viralVariants||[]).length){const v=generateViralVariants();if(!v.length)return}
 applyViralVariant(0,true)
}
function generatorFromTrend(i){
 const a=state.trendItems[i];if(!a)return;state.trendSelected=a;ensureHotProject();state.viralGeneratorTopic=a.title;state.viralVariants=[];save();switchView('viralgen');q('generatorTopic').value=a.title;generateViralVariants(a.title)
}

function ensureHotProject(){
 let p=allProjects().find(x=>x.source==='local'&&x.type==='hot');
 if(p){state.currentProjectId=p.id;return p}
 const raw={id:uid('project'),type:'hot',name:'互联网热点',tag:'LIVE TREND',desc:'由 LIVE RADAR 抓取的互联网足球热点',assets:{},createdAt:Date.now(),updatedAt:Date.now()};
 state.projects.unshift(raw);state.currentProjectId='local:'+raw.id;save();return allProjects().find(x=>x.id===state.currentProjectId)
}
function trafficHooks(title){
 const t=title.replace(/\s+/g,' ').trim();
 return[
   '刚刚，'+t,
   '这条消息，可能正在改变接下来的足球话题｜'+t,
   '别只看结果，真正值得关注的是这一点｜'+t,
   '为什么这件事突然冲上讨论？｜'+t,
   '如果你今天只看一条足球消息，就看这个｜'+t
 ]
}
function useTrendForDirector(i){
 const a=state.trendItems[i];if(!a)return;ensureHotProject();state.trendSelected=a;
 q('directorGoal').value='reach';q('directorFormat').value='auto';q('directorStyle').value=a.score>=85?'dynamic':'premium';q('directorPlatform').value='douyin';q('directorTheme').value='热点｜'+a.title;q('directorNote').value='抖音账号：萨吉体育。来自互联网实时热点；优先抢时效，保留事实，不夸大未证实信息；内容口吻专业、热血、真实，并保留SAGI品牌识别。';
 const p=project(),format=chooseFormat('reach',p),hooks=trafficHooks(a.title);
 const plan={goal:'reach',requested:'auto',format,style:q('directorStyle').value,platform:'douyin',theme:'热点｜'+a.title,note:q('directorNote').value,hooks,hook:hooks[0],shots:shotsFor(format),music:musicFor('reach',q('directorStyle').value),cta:'你怎么看？评论区聊聊。',scheduleAt:defaultTime(),cover:'刚刚｜'+a.title,generatedAt:Date.now(),internetSource:{url:a.url,domain:a.domain,title:a.title,seendate:a.seendate,score:a.score}};
 plan.score=scoreDirector(format,plan.hook,'reach',p);plan.score.total=Math.min(100,Math.max(plan.score.total,a.score));
 state.director=plan;state.currentContentId='';save();renderAll();switchView('director');note('已按「萨吉体育」账号画像送入 AI DIRECTOR · SAGI '+a.score)
}
function openGoogleTrends(){
 const term=q('trendProfile').value==='custom'?(q('trendQuery').value.trim()||'football'):(q('trendProfile').value==='stars'?'Cristiano Ronaldo Messi':q('trendProfile').value==='china'?'Chinese football':q('trendProfile').value==='xinjiang'?'Xinjiang football':'football');
 window.open('https://trends.google.com/trends/explore?q='+encodeURIComponent(term),'_blank','noopener')
}


function dailyVirtualHotProject(){return{id:'daily:hot',source:'local',type:'hot',name:'互联网热点',tag:'DAILY VIRAL',assets:{}}}
function dailyGoalForProject(p){return p?.type==='event'?'event':p?.type==='story'?'story':p?.type==='product'?'sales':p?.type==='hot'?'reach':'brand'}
function dailyProjectPlan(p){
 const goal=dailyGoalForProject(p),format=chooseFormat(goal,p),hooks=hooksFor(goal,p),hook=hooks[0],style=goal==='story'?'emotion':goal==='event'?'north':goal==='sales'?'product':'premium';
 const plan={sourceType:'project',sourceId:p.id,goal,format,requested:'auto',style,platform:'douyin',theme:themeFor(goal,p),hook,hooks,shots:shotsFor(format),music:musicFor(goal,style),cta:ctaFor(goal),scheduleAt:defaultTime(),cover:themeFor(goal,p),generatedAt:Date.now()};
 plan.score=scoreDirector(format,hook,goal,p);plan.viral=viralScoreForPlan(plan,p);return plan
}
function dailyExistingPlan(c,p){
 const plan={sourceType:'content',sourceId:c.id,goal:c.goal||'reach',format:c.format||'video15',style:c.style||'dynamic',platform:c.platform||'douyin',theme:c.title||'',hook:c.hook||c.title||'',hooks:c.hooks||[c.hook||c.title||''],shots:c.shots||shotsFor(c.format||'video15'),music:c.music||'',cta:c.cta||'',scheduleAt:c.scheduleAt||defaultTime(),cover:c.cover||c.title||'',generatedAt:c.updatedAt||Date.now()};
 plan.viral=viralScoreForPlan(plan,p);plan.score=scoreDirector(plan.format,plan.hook,plan.goal,p);return plan
}
function compactViral(v){if(!v)return null;return{total:v.total,verdict:v.verdict,confidence:v.confidence,factors:(v.factors||[]).map(x=>[x[0],x[1]]),risks:(v.risks||[]).slice(0,3),actions:(v.actions||[]).slice(0,3)}}
function dailyCompactPlan(plan){const p={...plan};p.viral=compactViral(plan?.viral);return p}
function dailyCandidate(plan,label,source,p,bonus=0,meta={}){
 const viral=plan?.viral||viralScoreForPlan(plan,p),base=viral?.total||0;
 return{plan:dailyCompactPlan(plan),label,source,projectId:p?.id||'',priority:Math.min(99,Math.round(base+bonus)),viral:base,verdict:viral?.verdict||'',why:viral?.risks?.[0]?.[1]||'结构健康',meta}
}
const DAILY_COMMAND_SCHEMA_VERSION=4;
const DAILY_COMMAND_MAX_AGE_MS=20*60*1000;
const DAILY_HOT_MAX_HOURS=12;
function trustedFootballDomain(a){
 const d=String(a?.domain||'').toLowerCase();
 return /(^|\.)(reuters|bbc|espn|skysports|theguardian|apnews|goal|marca|as|fifa|uefa|the-afc|news|xinhuanet|cctv|sina|premierleague|laliga|bundesliga|ligue1|lequipe|football-italia)\./.test(d)||/sports\.sina\.com\.cn|news\.cn|legaseriea\.it/.test(d)
}
function classifyBig5(a){
 const text=String((a?.title||'')+' '+(a?.url||'')+' '+(a?.domain||''));
 for(const [key,v] of Object.entries(BIG5_LEAGUES))if(v.re.test(text))return{key,label:v.label,en:v.en};
 return null
}
function footballArticleRelevant(a){
 const title=String(a?.title||'').toLowerCase(),url=String(a?.url||'').toLowerCase(),all=title+' '+url;
 if(/\bnfl\b|american football|college football|rugby|australian rules|\bafl\b/.test(all))return false;
 if(classifyBig5(a))return true;
 return /\/soccer\/|\/football\/|football|soccer|premier league|champions league|europa league|world cup|nations league|la liga|laliga|serie a|bundesliga|ligue 1|uefa|fifa|中超|国足|足协杯|足球|ronaldo|cristiano|messi|mbapp[eé]|yamal/.test(all)
}
function eventWords(v){
 const stop=new Set(['the','a','an','and','or','to','of','in','on','for','with','at','from','after','before','as','is','are','was','were','will','has','have','had','football','soccer','team','teams','player','players','match','game','games','league','cup','club','clubs','latest','news','today']);
 return String(v||'').toLowerCase().replace(/[^a-z0-9\u3400-\u9fff]+/g,' ').split(/\s+/).filter(x=>x.length>2&&!stop.has(x)).slice(0,18)
}
function wordSimilarity(a,b){
 const A=new Set(eventWords(a)),B=new Set(eventWords(b));if(!A.size||!B.size)return 0;let hit=0;A.forEach(x=>{if(B.has(x))hit++});return hit/Math.max(1,Math.min(A.size,B.size))
}
function clusterDailyEvents(items){
 const clusters=[];
 (items||[]).forEach(a=>{
   let c=clusters.find(x=>wordSimilarity(x.seed.title,a.title)>=.34);
   if(!c){c={seed:a,items:[],domains:new Set()};clusters.push(c)}
   c.items.push(a);if(a.domain)c.domains.add(String(a.domain).toLowerCase())
 });
 return clusters.map(c=>({items:c.items,domains:[...c.domains],support:c.domains.size}))
}
function dailySourceMode(result){
 if(result?.limited)return result.cacheAgeMs<=30*60*1000?'FRESH CACHE':'CACHE';
 return result?.cached?'FRESH CACHE':'LIVE VERIFIED'
}
function dailyCommandNeedsRefresh(){
 const d=state.dailyCommand;
 return !d||d.schemaVersion!==DAILY_COMMAND_SCHEMA_VERSION||d.date!==today()||d.zhVersion!==ZH_LAYER_VERSION||!d.updatedAt||Date.now()-d.updatedAt>DAILY_COMMAND_MAX_AGE_MS
}
function trendMetaText(a){
 const age=Math.max(0,trendAgeHours(a?.seendate)),support=Math.max(1,Number(a?.eventSupport)||1);
 return (a?.leagueLabel?(a.leagueLabel+' · '):'')+(age<1?'<1h':age.toFixed(1)+'h')+' · '+support+'源 · '+(a?.eventVerified?'已验证':'单源')
}
async function fetchDailyTrendPool(forceFresh=false){
 const globalResult=await trendFetchShared(TREND_PROFILES.global.query,{profile:'global',force:forceFresh,maxrecords:100});
 const big5Result=await trendFetchShared(BIG5_QUERY,{profile:'global',force:forceFresh,maxrecords:100});
 const channels=[
  {name:'GLOBAL',result:globalResult,maxHours:DAILY_HOT_MAX_HOURS,items:globalResult.items||[]},
  {name:'BIG5',result:big5Result,maxHours:BIG5_HOT_MAX_HOURS,items:big5Result.items||[]}
 ];
 const merged=new Map(),modes=[];
 channels.forEach(ch=>{
   const mode=dailySourceMode(ch.result);modes.push(mode);
   const cacheTooOld=mode==='CACHE'&&Number(ch.result.cacheAgeMs||0)>30*60*1000;
   const fresh=(ch.items||[]).filter(a=>footballArticleRelevant(a)&&trendAgeHours(a.seendate)<=24);
   const clusters=clusterDailyEvents(fresh);
   clusters.forEach(c=>c.items.forEach(a=>{
     const league=classifyBig5(a),profiles=['global','china','xinjiang','stars'],best=profiles.map(p=>{const raw=trendScore(a,p),fit=accountFitScore(a);return{p,score:Math.round(raw*.62+fit*.38)}}).sort((x,y)=>y.score-x.score)[0];
     const age=trendAgeHours(a.seendate),trusted=trustedFootballDomain(a),verified=c.support>=2||(trusted&&age<=(ch.name==='BIG5'?12:6));
     const leagueBoost=league?6:0,base=best.score+(c.support>=2?Math.min(14,(c.support-1)*5):0)+(trusted?5:0)+leagueBoost-(age>12?8:0)-(!verified?8:0);
     const item={...a,score:Math.max(1,Math.min(99,Math.round(base))),dailyProfile:best.p,eventSupport:Math.max(1,c.support),eventVerified:verified,dailyEligible:!cacheTooOld&&age<=ch.maxHours&&verified,sourceMode:mode,channel:ch.name,league:league?.key||'',leagueLabel:league?.label||'',leagueEn:league?.en||'',reason:trendReason(a,base)+(league?(' · '+league.label):'')+(verified?' · '+Math.max(1,c.support)+'个来源':' · 单源观察')};
     const key=(a.url||'')||String(a.title||'').toLowerCase();const prev=merged.get(key);if(!prev||item.score>prev.score)merged.set(key,item)
   }))
 });
 const rescored=[...merged.values()].sort((a,b)=>(Number(b.dailyEligible)-Number(a.dailyEligible))||(Number(!!b.league)-Number(!!a.league))||b.score-a.score||trendAgeHours(a.seendate)-trendAgeHours(b.seendate));
 const sourceMode=modes.includes('LIVE VERIFIED')?'LIVE VERIFIED':modes.includes('FRESH CACHE')?'FRESH CACHE':'CACHE';
 const items=await localizeTrendItems(rescored.slice(0,36),36);
 return{items,sourceMode,cacheAgeMs:Math.max(Number(globalResult.cacheAgeMs||0),Number(big5Result.cacheAgeMs||0)),verifiedCount:items.filter(x=>x.dailyEligible).length,big5Count:items.filter(x=>x.dailyEligible&&x.league).length}
}
function selectDailyHotItems(items,limit=8){
 const eligible=(items||[]).filter(a=>a.dailyEligible),picked=[],used=new Set();
 ['premier','laliga','seriea','bundesliga','ligue1'].forEach(key=>{
   const x=eligible.filter(a=>a.league===key).sort((a,b)=>b.score-a.score)[0];
   if(x){picked.push(x);used.add(x.url||x.title)}
 });
 eligible.sort((a,b)=>b.score-a.score||trendAgeHours(a.seendate)-trendAgeHours(b.seendate)).forEach(x=>{
   const k=x.url||x.title;if(picked.length<limit&&!used.has(k)){picked.push(x);used.add(k)}
 });
 return picked.slice(0,limit)
}
function dailyBestTrendCandidate(a){
 const p=dailyVirtualHotProject(),src={url:a.url,domain:a.domain,title:a.title,originalTitle:a.originalTitle||a.title,seendate:a.seendate,score:a.score},plans=['speed','emotion','debate'].map(k=>variantPlan(k,a.title,p,src)).sort((x,y)=>(y.viral?.total||0)-(x.viral?.total||0)),best=plans[0];
 const freshness=trendAgeHours(a.seendate)<=3?6:trendAgeHours(a.seendate)<=8?4:1,supportBonus=Math.min(8,Math.max(0,(Number(a.eventSupport)||1)-1)*3);
 return dailyCandidate(best,generatorShortTopic(a.title,42),'LIVE RADAR',p,freshness+supportBonus,{trend:{url:a.url,domain:a.domain,title:a.title,originalTitle:a.originalTitle||a.title,seendate:a.seendate,score:a.score,sourcecountry:a.sourcecountry,sourcecountryZh:a.sourcecountryZh,language:a.language,languageZh:a.languageZh,socialimage:a.socialimage,reason:a.reason,translated:a.translated,eventSupport:a.eventSupport,eventVerified:a.eventVerified,sourceMode:a.sourceMode,channel:a.channel,league:a.league,leagueLabel:a.leagueLabel,leagueEn:a.leagueEn,freshness:trendMetaText(a)}})
}
function dailyCommandCard(el,c,kind){
 if(!c){el.innerHTML='<div class="commandLabel">'+kind+'</div><h3>暂无合适候选</h3>';return}
 const fresh=c.meta?.trend?.freshness?(' · '+c.meta.trend.freshness):'';
 el.innerHTML='<div class="commandLabel">'+kind+' · '+esc(c.source)+'</div><h3>'+esc(c.label)+'</h3><div class="commandScore">'+c.priority+'<small>/99</small></div><div class="commandMeta">'+esc(c.verdict||'')+' · VIRAL '+c.viral+esc(fresh)+'</div><div class="commandWhy">'+esc(c.why||'')+'</div><div class="toolbar"><button class="btn '+(kind.startsWith('P1')?'primary':'')+'" data-daily-action type="button">'+(c.source==='CONTENT TASK'?'打开任务':'采用方案')+'</button></div>';
 el.querySelector('[data-daily-action]').onclick=()=>executeDailyCandidate(c)
}
function renderDailyBig5(){
 const host=q('dailyBig5Grid');if(!host)return;
 const d=state.dailyCommand,rows=d?.big5Leagues||[],order=['premier','laliga','seriea','bundesliga','ligue1'],labels={premier:'英超',laliga:'西甲',seriea:'意甲',bundesliga:'德甲',ligue1:'法甲'};
 const map=new Map(rows.map(x=>[x.key,x]));
 host.innerHTML=order.map(key=>{
   const x=map.get(key);
   if(!x)return '<article class="big5Card emptyLeague"><div class="big5League">'+labels[key]+'</div><h3>暂无新鲜信号</h3><p>等待下一轮联网抓取</p></article>';
   const status=x.eligible?'已验证':'观察',klass=x.eligible?'verified':'watch';
   return '<article class="big5Card '+klass+'"><div class="big5League">'+labels[key]+'<span>'+status+'</span></div><h3>'+esc(x.title)+'</h3><p>'+esc(x.meta)+'</p><div class="toolbar"><button class="btn '+(x.eligible?'primary':'')+'" data-big5-key="'+key+'" type="button">'+(x.eligible?'采用这条':'查看原文')+'</button></div></article>'
 }).join('');
 host.querySelectorAll('[data-big5-key]').forEach(b=>b.onclick=()=>{
   const x=map.get(b.dataset.big5Key);if(!x)return;
   if(x.eligible&&x.candidate){executeDailyCandidate(x.candidate);return}
   if(x.url)window.open(x.url,'_blank','noopener')
 })
}
function renderDailyCommand(){
 const d=state.dailyCommand,m=viralModelProfile(),badge=q('dailyInternetBadge');
 q('dailyModelBadge').textContent='MODEL · '+m.confidence+'%';q('dailyConfidence').textContent=m.confidence+'%';
 if(!d||d.date!==today()||d.zhVersion!==ZH_LAYER_VERSION){
   badge.textContent=state.dailyCommandLoading?'INTERNET · SCANNING':'INTERNET · WAITING';
   q('dailyUpdated').textContent='未更新';q('dailyTrendCount').textContent='0';q('dailyProjectCount').textContent='0';
   q('dailyRanking').innerHTML='<div class="empty">今日指挥尚未生成。</div>';q('dailyCommandInsight').textContent='系统会联网扫描热点，再与现有内容任务和项目一起排序。';
   dailyCommandCard(q('dailyP1'),null,'P1 · NOW');dailyCommandCard(q('dailyP2'),null,'P2 · NEXT');dailyCommandCard(q('dailyHold'),null,'HOLD');renderDailyBig5();return
 }
 badge.textContent=d.sourceMode==='LIVE VERIFIED'?'INTERNET · LIVE VERIFIED':d.sourceMode==='FRESH CACHE'?'INTERNET · FRESH CACHE':d.sourceMode==='CACHE'?'INTERNET · CACHE':'INTERNET · LOCAL';
 q('dailyUpdated').textContent=d.updatedText||'今日';q('dailyTrendCount').textContent=d.trendCount;q('dailyProjectCount').textContent=d.localCount;
 const ranked=d.ranked||[],p1=ranked[0]||null,p2=ranked[1]||null,hold=d.hold||null;
 dailyCommandCard(q('dailyP1'),p1,'P1 · NOW');dailyCommandCard(q('dailyP2'),p2,'P2 · NEXT');dailyCommandCard(q('dailyHold'),hold,'HOLD');
 q('dailyRanking').innerHTML=ranked.length?ranked.slice(0,8).map((c,i)=>'<div class="dailyRankRow"><strong>'+String(i+1).padStart(2,'0')+'</strong><div><b>'+esc(c.label)+'</b><span>'+esc(c.source)+' · '+esc(c.verdict)+' · VIRAL '+c.viral+(c.meta?.trend?.freshness?' · '+esc(c.meta.trend.freshness):'')+'</span></div><em>'+c.priority+'</em></div>').join(''):'<div class="empty">暂无候选</div>';
 q('dailyCommandInsight').textContent=d.insight||'今日优先级已生成。';renderDailyBig5()
}
async function runDailyViralCommand(auto=false){
 if(state.dailyCommandLoading)return;state.dailyCommandLoading=true;renderDailyCommand();q('dailyRunBtn').disabled=true;
 let trendResult={items:[],sourceMode:'LOCAL',verifiedCount:0},online=false;
 try{trendResult=await fetchDailyTrendPool(!auto);online=trendResult.sourceMode!=='CACHE'&&trendResult.items.length>0}catch(e){}
 const trends=trendResult.items||[],eligible=trends.filter(a=>a.dailyEligible),selectedHot=selectDailyHotItems(trends,8),big5Leagues=['premier','laliga','seriea','bundesliga','ligue1'].map(key=>{const x=trends.filter(a=>a.league===key).sort((a,b)=>(Number(b.dailyEligible)-Number(a.dailyEligible))||b.score-a.score||trendAgeHours(a.seendate)-trendAgeHours(b.seendate))[0];if(!x)return null;return{key,label:x.leagueLabel,title:x.title,url:x.url,eligible:!!x.dailyEligible,score:x.score,meta:trendMetaText(x)+' · '+(x.domain||'互联网'),candidate:x.dailyEligible?dailyBestTrendCandidate(x):null}}).filter(Boolean);
 if(trends.length){state.trendItems=trends;state.trendFetchedAt=Date.now();q('trendStatus').textContent='DAILY VIRAL 已同步 · '+eligible.length+' 条已验证 · 五大联赛 '+(trendResult.big5Count||0)+' 条 / '+trends.length+' 条信号';renderTrends()}
 const candidates=[],hot=selectedHot.map(dailyBestTrendCandidate);candidates.push(...hot);
 const localProjects=allProjects().filter(p=>p.type!=='hot').slice(0,10);
 localProjects.forEach(p=>{const plan=dailyProjectPlan(p),scheduled=projectContent(p.id).some(c=>(c.scheduleAt||'').slice(0,10)===today()),bonus=scheduled?4:0;candidates.push(dailyCandidate(plan,p.name,'SAGI PROJECT',p,bonus))});
 state.contents.filter(c=>c.status!=='published').forEach(c=>{const p=allProjects().find(x=>x.id===c.projectId),plan=dailyExistingPlan(c,p),bonus=(c.status==='ready'?8:0)+((c.scheduleAt||'').slice(0,10)===today()?5:0);candidates.push(dailyCandidate(plan,c.title||'未命名内容','CONTENT TASK',p,bonus,{contentId:c.id,status:c.status}))});
 const ranked=candidates.filter(c=>c.viral>0).sort((a,b)=>b.priority-a.priority||b.viral-a.viral),hold=ranked.slice().reverse().find(c=>c.priority<70)||ranked[ranked.length-1]||null;
 const hasStrongHot=ranked.some(c=>c.source==='LIVE RADAR'&&c.priority>=78),hasLocal=ranked.some(c=>c.source!=='LIVE RADAR'&&c.priority>=68);
 const sourceNote=trendResult.sourceMode==='CACHE'?'互联网源当前只剩旧缓存，旧闻不进入P1/P2。':eligible.length?'今日热点采用“全球突发 + 五大联赛专属雷达”；五大联赛近18小时合格内容保留曝光位。':'当前没有通过验证的强热点，不为了热点而硬发。';
 const insight=(hasStrongHot&&hasLocal?'建议“热点拉新 + 本地内容留人”：P1抢真实热点，P2保持新疆足球身份。':hasStrongHot?'今天存在已验证强热点，优先抢时效；本地内容放第二顺位。':hasLocal?'今天没有已验证强热点，优先发萨吉体育自己的赛事、球队或人物内容。':'今天候选整体偏弱，优先继续制作和补素材。')+' '+sourceNote;
 state.dailyCommand={schemaVersion:DAILY_COMMAND_SCHEMA_VERSION,date:today(),zhVersion:ZH_LAYER_VERSION,updatedAt:Date.now(),updatedText:new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})+' · '+trendResult.sourceMode,online,sourceMode:trendResult.sourceMode,trendCount:hot.length,verifiedTrendCount:eligible.length,big5Count:trendResult.big5Count||0,big5Leagues,localCount:Math.max(0,candidates.length-hot.length),ranked:ranked.slice(0,12),hold,insight};
 state.dailyCommandLoading=false;save();renderAll();q('dailyRunBtn').disabled=false;if(!auto)note('今日指挥已刷新 · 已验证热点 '+eligible.length+' 条')
}
function executeDailyCandidate(c){
 if(!c)return;
 if(c.source==='CONTENT TASK'&&c.meta?.contentId){openContent(c.meta.contentId,c.meta.status==='ready'?'publish':'create');return}
 if(c.source==='LIVE RADAR'&&c.meta?.trend){
   state.trendSelected=c.meta.trend;ensureHotProject();state.viralGeneratorTopic=c.meta.trend.title;state.viralVariants=[];save();renderAll();switchView('viralgen');generateViralVariants(c.meta.trend.title);return
 }
 if(c.projectId&&c.projectId!=='daily:hot')state.currentProjectId=c.projectId;
 state.director=JSON.parse(JSON.stringify(c.plan));state.director.generatedAt=Date.now();state.currentContentId='';save();renderAll();switchView('director')
}
function executeDailyP1(){const c=state.dailyCommand?.ranked?.[0];if(c)executeDailyCandidate(c);else runDailyViralCommand(false)}

function flowStageOf(c){
 if(c.metrics)return 'LEARNED';
 if(c.status==='published')return 'PUBLISHED';
 if(c.status==='ready')return 'READY';
 return 'CREATE'
}
function flowPriority(){
 const now=Date.now(),todayStr=today();
 const pending=state.contents.filter(c=>c.status!=='published'||!c.metrics).map(c=>{
   let score=0;
   const ds=(c.scheduleAt||'').slice(0,10);
   if(ds&&ds<todayStr)score+=90;else if(ds===todayStr)score+=75;else if(ds)score+=30;
   if(c.status==='ready')score+=55;else if(c.status==='draft')score+=40;else if(c.status==='published'&&!c.metrics)score+=50;
   score+=Math.min(20,Math.round((now-(c.updatedAt||c.createdAt||now))/86400000));
   return{c,score}
 }).sort((a,b)=>b.score-a.score);
 if(pending.length){
   const c=pending[0].c,p=allProjects().find(x=>x.id===c.projectId);
   if(c.status==='ready')return{kind:'view',view:'publish',contentId:c.id,title:'发布这条已经准备好的内容',meta:(p?.name||'未命名项目')+' · '+c.title+' · 已进入待发布状态'};
   if(c.status==='published'&&!c.metrics)return{kind:'metric',contentId:c.id,title:'回填这条内容的真实表现数据',meta:(p?.name||'未命名项目')+' · '+c.title+' · 让 LEARNING 开始真正学习'};
   return{kind:'view',view:'create',contentId:c.id,title:'先完成当前优先级最高的制作任务',meta:(p?.name||'未命名项目')+' · '+c.title+' · '+((c.scheduleAt||'').replace('T',' ')||'未排期')};
 }
 const p=project()||allProjects()[0];
 if(state.director?.generatedAt)return{kind:'save',title:'把当前 AI 导演方案保存为内容任务',meta:(p?.name||'当前项目')+' · '+(state.director.theme||'导演方案')};
 if(p)return{kind:'view',view:'director',projectId:p.id,title:'为当前项目生成下一条 AI 导演方案',meta:p.name+' · 目前没有待处理内容'};
 return{kind:'view',view:'projects',title:'先建立第一个内容项目',meta:'球队、赛事、品牌、产品、热点或人物故事都可以作为项目'}
}
function runFlowNext(){
 const a=flowPriority();
 if(a.projectId)state.currentProjectId=a.projectId;
 if(a.contentId){
   const c=state.contents.find(x=>x.id===a.contentId);
   if(c){state.currentProjectId=c.projectId;openContent(c.id,a.view||'create')}
   if(a.kind==='metric')openPerformanceModal(a.contentId);
   return
 }
 if(a.kind==='save'){saveDirectorAsContent();switchView('flow');return}
 switchView(a.view||'today')
}
function renderFlow(){
 const projects=allProjects(),ideas=projects.filter(p=>!projectContent(p.id).length).length;
 const directorLive=state.director?.generatedAt&&(!state.currentContentId||!state.contents.some(c=>c.id===state.currentContentId))?1:0;
 const counts={IDEA:ideas,DIRECTOR:directorLive,CREATE:0,READY:0,PUBLISHED:0,LEARNED:0};
 state.contents.forEach(c=>{counts[flowStageOf(c)]++});
 const defs=[['IDEA','待启动项目'],['DIRECTOR','导演方案'],['CREATE','制作中'],['READY','待发布'],['PUBLISHED','待回填'],['LEARNED','已学习']];
 q('flowStages').innerHTML=defs.map(([k,n])=>'<div class="flowStage '+(counts[k]?'active':'')+'"><strong>'+k+'</strong><b>'+counts[k]+'</b><span>'+n+'</span></div>').join('');
 const a=flowPriority();q('flowNextTitle').textContent=a.title;q('flowNextMeta').textContent=a.meta;
 const rows=state.contents.slice().sort((a,b)=>{
   const order={ready:0,draft:1,published:2};return (order[a.status]??3)-(order[b.status]??3)||String(a.scheduleAt||'').localeCompare(String(b.scheduleAt||''))
 }).slice(0,12),w=q('flowQueue');
 w.innerHTML=rows.length?'':'<div class="empty">还没有内容任务。先进入 AI DIRECTOR 生成第一条。</div>';
 rows.forEach(c=>{const p=allProjects().find(x=>x.id===c.projectId),stage=flowStageOf(c),d=document.createElement('div');d.className='flowRow';d.innerHTML='<strong>'+stage+'</strong><div><b>'+esc(c.title)+'</b><span>'+esc(p?.name||'')+' · '+esc((c.scheduleAt||'未排期').replace('T',' '))+'</span></div><button class="btn" type="button">打开</button>';d.querySelector('button').onclick=()=>{if(stage==='PUBLISHED')openPerformanceModal(c.id);else openContent(c.id,stage==='READY'?'publish':'create')};w.appendChild(d)});
 const metrics=allPerformance().length,published=state.contents.filter(c=>c.status==='published').length,total=state.contents.length;
 q('flowHealth').innerHTML=[['内容项目',projects.length],['内容任务',total],['已发布',published],['学习样本',metrics]].map(x=>'<div><span>'+x[0]+'</span><b>'+x[1]+'</b></div>').join('');
 let insight='系统状态正常：继续保持“制作 → 发布 → 回填 → 学习”的闭环。';
 if(total&&!published)insight='现在最大的瓶颈不是创意，而是发布：已经有内容任务，但还没有形成真实发布数据。';
 else if(published&&!metrics)insight='已经开始发布，但学习引擎还没有数据。优先回填播放、互动、询单和成交。';
 else if(projects.length>2&&total<projects.length)insight='项目数量已经增加，但内容任务偏少。建议优先把空项目送进 AI DIRECTOR。';
 q('flowInsight').textContent=insight
}

function renderCalendar(){
 renderWeek(q('calendarFull'));const future=state.contents.filter(c=>c.scheduleAt&&c.scheduleAt.slice(0,10)>=today()).sort((a,b)=>a.scheduleAt.localeCompare(b.scheduleAt)),w=q('scheduledList');w.innerHTML=future.length?'':'<div class="empty">未来还没有安排内容。</div>';future.forEach(c=>{const p=allProjects().find(x=>x.id===c.projectId),d=document.createElement('div');d.className='task';d.innerHTML='<div><b>'+esc(c.title)+'</b><span>'+esc(p?.name||'')+' · '+esc(c.scheduleAt.replace('T',' '))+'</span></div><button class="btn" data-open type="button">打开</button>';d.querySelector('button').onclick=()=>openContent(c.id,'create');w.appendChild(d)})
}
function assetSlots(){return[['logo','Logo / 队徽'],['design','设计效果图'],['poster','宣传海报'],['wearing','球员上身 / 人物'],['match','比赛 / 现场'],['delivery','交付 / 证明']]}
function renderAssets(){
 const p=project(),a=assets(p);q('assetProjectName').textContent=p?p.name:'未选择项目';const w=q('assetGrid');if(!p){w.innerHTML='<div class="empty">请选择内容项目</div>';return}
 w.innerHTML=assetSlots().map(([k,n])=>'<div class="asset"><div class="assetPreview" id="assetPrev_'+k+'"'+(a[k]?' style="background-image:url(&quot;'+a[k]+'&quot;)"':'')+'>'+(a[k]?'':'暂无素材')+'</div><div class="assetBody"><b>'+n+'</b><span>'+(p.source==='sales'&&baseAssets(p)[k]?'来自 SALES OS':'CONTENT OS 素材')+'</span><div class="assetActions"><input type="file" accept="image/*" data-file="'+k+'" style="display:none"><button class="btn" data-upload="'+k+'" type="button">上传/替换</button><button class="btn" data-clear="'+k+'" type="button">清除覆盖</button></div></div></div>').join('');
 w.querySelectorAll('[data-upload]').forEach(b=>b.onclick=()=>w.querySelector('[data-file="'+b.dataset.upload+'"]').click());
 w.querySelectorAll('[data-file]').forEach(inp=>inp.onchange=e=>{const f=e.target.files[0];if(f)saveAsset(inp.dataset.file,f);inp.value=''});
 w.querySelectorAll('[data-clear]').forEach(b=>b.onclick=()=>{const id=p.id;if(state.assetOverrides[id])delete state.assetOverrides[id][b.dataset.clear];save();renderAssets();renderDirector();renderToday();note('已清除 CONTENT OS 覆盖素材')})
}
function saveAsset(slot,file){
 const p=project();if(!p)return;const r=new FileReader();r.onload=()=>{const im=new Image();im.onload=()=>{const max=1400,scale=Math.min(1,max/Math.max(im.width,im.height)),cv=document.createElement('canvas');cv.width=Math.round(im.width*scale);cv.height=Math.round(im.height*scale);cv.getContext('2d').drawImage(im,0,0,cv.width,cv.height);const data=cv.toDataURL('image/jpeg',.84);state.assetOverrides[p.id]={...(state.assetOverrides[p.id]||{}),[slot]:data};save();renderAssets();renderDirector();renderToday();note('素材已保存到 CONTENT OS')};im.src=r.result};r.readAsDataURL(file)
}
function selectedAssetForScene(i){
 const a=assets(),keys=['poster','wearing','design','match','delivery','logo'],pref=[['poster','wearing','design'],['wearing','match','poster'],['design','poster','match'],['design','wearing','poster'],['match','delivery','wearing'],['poster','logo','wearing']][i%6];for(const k of pref)if(a[k])return a[k];for(const k of keys)if(a[k])return a[k];return''
}
function ensureContentFromDirector(){
 let c=currentContent();if(c)return c;if(!state.director?.generatedAt)generateDirector(true);saveDirectorAsContent();return currentContent()
}
function renderCreate(){
 const c=currentContent(),p=state.director?.generatedAt?state.director:(c?{...c,generatedAt:c.createdAt,score:{total:c.score||0,rows:[]}}:null),w=q('storyboard');if(!p){w.innerHTML='<div class="empty">先在 AI DIRECTOR 生成一条内容方案。</div>';return}
 const shots=p.shots||shotsFor(p.format);w.innerHTML=shots.map((x,i)=>{const im=selectedAssetForScene(i);return'<div class="scene"><div class="sceneVisual"'+(im?' style="background-image:url(&quot;'+im+'&quot;)"':'')+'><div class="sceneOverlay"><small>'+esc(x[0])+'</small><b>'+esc(i===0?(p.hook||p.theme):x[1])+'</b></div></div><div class="sceneBody"><span>'+esc(x[1])+'</span></div></div>'}).join('');
 q('packageCover').value=p.cover||p.theme||'';q('packageCta').value=p.cta||'';if(c?.tags)q('packageTags').value=c.tags
}
function markReady(){
 const c=ensureContentFromDirector();if(!c)return;c.status='ready';c.cover=q('packageCover').value.trim();c.cta=q('packageCta').value.trim();c.tags=q('packageTags').value.trim();c.updatedAt=Date.now();save();renderAll();note('已标记为待发布')
}
function copyPackage(){
 const p=state.director?.generatedAt?state.director:currentContent();if(!p){note('暂无制作方案');return}
 const lines=['SAGI CONTENT OS · 制作执行单','主题：'+(p.theme||p.title),'形式：'+formatLabel(p.format),'Hook：'+(p.hook||''),'音乐：'+(p.music||''),'CTA：'+(q('packageCta').value||p.cta||''),'','SHOT LIST',...(p.shots||[]).map(x=>x[0]+'｜'+x[1])];navigator.clipboard?.writeText(lines.join('\n')).then(()=>note('制作执行单已复制')).catch(()=>note('复制失败'))
}
function renderPublish(){
 const body=q('publishTable');const list=state.contents.slice().sort((a,b)=>(b.updatedAt||0)-(a.updatedAt||0));body.innerHTML=list.length?'':'<tr><td colspan="6">暂无内容任务</td></tr>';
 list.forEach(c=>{const p=allProjects().find(x=>x.id===c.projectId),tr=document.createElement('tr');tr.innerHTML='<td><b>'+esc(c.title)+'</b><div class="sub">'+esc(c.hook||'')+'</div></td><td>'+esc(p?.name||'')+'</td><td>'+formatLabel(c.format)+'</td><td>'+esc((c.scheduleAt||'未安排').replace('T',' '))+'</td><td><span class="pill '+(c.status==='published'?'good':c.status==='ready'?'warn':'')+'">'+statusLabel(c.status)+'</span></td><td><button class="btn" data-open type="button">打开</button> '+(c.status!=='published'?'<button class="btn good" data-pub type="button">标记已发布</button>':'<button class="btn blue" data-metric type="button">回填数据</button>')+'</td>';tr.querySelector('[data-open]').onclick=()=>openContent(c.id,'create');tr.querySelector('[data-pub]')?.addEventListener('click',()=>markPublished(c.id));tr.querySelector('[data-metric]')?.addEventListener('click',()=>openPerformanceModal(c.id));body.appendChild(tr)})
}
function markPublished(id){
 const c=state.contents.find(x=>x.id===id);if(!c)return;c.status='published';c.publishedAt=Date.now();c.updatedAt=Date.now();save();if(c.projectId.startsWith('sale:'))patchSales(c.projectId.slice(5),o=>{o.marketingStatus={...(o.marketingStatus||{}),douyinPublished:c.platform==='douyin'||c.platform==='multi',momentsPublished:c.platform==='wechat'||c.platform==='multi'};o.douyinContent={...(o.douyinContent||{}),status:'published',publishedAt:new Date().toISOString(),mode:c.format,hook:c.hook,coverTitle:c.cover,cta:c.cta,scheduleAt:c.scheduleAt};o.updatedAt=Date.now()});renderAll();note('已标记发布 · 记得回填表现数据')
}
function openPerformanceModal(id){
 const c=state.contents.find(x=>x.id===id);if(!c)return;state.performanceTargetId=id;q('performanceModalTitle').textContent=c.title;const m=c.metrics||{};['Views','Likes','Comments','Saves','Shares','Inquiries','Orders','Revenue'].forEach(k=>q('m'+k).value=m[k.toLowerCase()]||0);q('performanceModal').classList.add('show')
}
function savePerformance(){
 const c=state.contents.find(x=>x.id===state.performanceTargetId);if(!c)return;const m={views:num(q('mViews').value),likes:num(q('mLikes').value),comments:num(q('mComments').value),saves:num(q('mSaves').value),shares:num(q('mShares').value),inquiries:num(q('mInquiries').value),orders:num(q('mOrders').value),revenue:num(q('mRevenue').value),recordedAt:Date.now()};c.metrics=m;c.status='published';c.updatedAt=Date.now();save();
 if(c.projectId.startsWith('sale:'))patchSales(c.projectId.slice(5),o=>{const rec={id:'perf_'+Date.now().toString(36),contentOsId:c.id,contentType:c.format,dataDate:today(),title:c.title,...m,recordedAt:Date.now(),recordedAtText:new Date().toLocaleString('zh-CN'),channel:c.platform,hook:c.hook,coverTitle:c.cover,directorGoal:c.goal,angle:c.goal==='event'?'departure':'launch'};o.contentPerformanceHistory=[rec,...(o.contentPerformanceHistory||[])].slice(0,100);o.updatedAt=Date.now()});
 q('performanceModal').classList.remove('show');renderAll();note('表现数据已保存，学习引擎已更新')
}
function renderLearning(){
 const p=learningProfile();q('learnCount').textContent=p.rows.length;q('learnHigh').textContent=p.high;q('learnConfidence').textContent=p.confidence+'%';
 const patterns=[];if(p.best)patterns.push(['01 · 形式赢家','目前「'+formatLabel(p.best.type)+'」平均得分 '+Math.round(p.best.avgScore)+'，平均播放 '+Math.round(p.best.avgViews).toLocaleString('zh-CN')+'。']);if(p.hookBest)patterns.push(['02 · Hook 赢家','当前「'+p.hookBest.name+'」在已有样本中的平均分更高。']);if(p.conversion&&p.conversion.avgIpk>0)patterns.push(['03 · 商业赢家','「'+formatLabel(p.conversion.type)+'」每千次播放平均带来 '+p.conversion.avgIpk.toFixed(1)+' 个询单。']);if(!patterns.length)patterns.push(['等待第一批数据','发布 3–5 条并回填数据后，系统会开始形成 SAGI 自己的内容规律。']);q('learnPatterns').textContent=patterns.length;
 q('learningInsight').textContent=p.best?'目前最值得继续测试的是「'+formatLabel(p.best.type)+'」。不要机械复制成品，而是保留有效结构，同时继续测试不同 Hook、封面和人物。':'目前样本不足。先完成“发布 → 数据回填”，学习引擎才有真实依据。';
 q('winningPatterns').innerHTML=patterns.map(x=>'<div class="pattern"><b>'+esc(x[0])+'</b><span>'+esc(x[1])+'</span></div>').join('')
}
function renderPerformance(){
 const rows=allPerformance(),sum=rows.reduce((a,x)=>{const r=performanceRates(x);a.v+=r.views;a.e+=r.interactions;a.i+=num(x.inquiries);a.o+=num(x.orders);return a},{v:0,e:0,i:0,o:0});q('perfViews').textContent=fmt(sum.v);q('perfEngagement').textContent=fmt(sum.e);q('perfInquiries').textContent=sum.i;q('perfOrders').textContent=sum.o;
 const sorted=rows.slice().sort((a,b)=>num(b.inquiries)-num(a.inquiries)||performanceScore(b)-performanceScore(a)||num(b.views)-num(a.views)),w=q('performanceRank');w.innerHTML=sorted.length?'':'<div class="empty">还没有表现数据</div>';sorted.slice(0,8).forEach((x,i)=>{const p=allProjects().find(v=>v.id===x.projectId),d=document.createElement('div');d.className='rankItem';d.innerHTML='<strong>'+(i+1)+'</strong><div><b>'+esc(x.title||'未命名内容')+'</b><span>'+esc(p?.name||x.accountName||'萨吉体育')+' · '+fmt(x.views)+'播放 · '+num(x.inquiries)+'询单</span></div><em>'+performanceScore(x)+'分</em>';w.appendChild(d)});
 const lp=learningProfile();q('performanceInsight').textContent=lp.best?'当前「'+formatLabel(lp.best.type)+'」综合表现最好；'+(lp.conversion&&lp.conversion.avgIpk>0?'转化端每千播放 '+lp.conversion.avgIpk.toFixed(1)+' 询单。':'继续积累询单数据。'):'继续回填发布数据，系统会把播放、互动和商业结果一起纳入判断。'
}
function renderProjects(){
 const w=q('projectList'),list=allProjects();w.innerHTML=list.length?'':'<div class="empty">还没有内容项目</div>';list.forEach(p=>{const count=projectContent(p.id).length,d=document.createElement('div');d.className='projectCard';d.innerHTML='<b>'+esc(p.name)+'</b><span>'+esc(CONTENT_TYPES[p.type]||p.type)+' · '+esc(p.tag||'')+'</span><span>内容任务 '+count+' · '+(p.source==='sales'?'来自 SALES OS':'CONTENT OS 独立项目')+'</span><div class="toolbar"><button class="btn" data-open type="button">打开项目</button>'+(p.source==='local'?'<button class="btn danger" data-del type="button">删除</button>':'')+'</div>';d.querySelector('[data-open]').onclick=()=>{state.currentProjectId=p.id;state.currentContentId='';state.director={};save();renderAll();switchView('today')};d.querySelector('[data-del]')?.addEventListener('click',()=>deleteProject(p.sourceId));w.appendChild(d)})
}
function deleteProject(id){if(!confirm('删除这个 CONTENT OS 项目？相关内容任务也会删除。'))return;const pid='local:'+id;state.projects=state.projects.filter(x=>x.id!==id);state.contents=state.contents.filter(x=>x.projectId!==pid);delete state.assetOverrides[pid];if(state.currentProjectId===pid)state.currentProjectId='';save();renderAll();note('项目已删除')}
function renderProjectSelect(){
 const list=allProjects(),sel=q('projectSelect');sel.innerHTML='<option value="">选择内容项目</option>'+list.map(p=>'<option value="'+esc(p.id)+'">'+(p.source==='sales'?'球队｜':'')+esc(p.name)+'</option>').join('');sel.value=state.currentProjectId||''
}
function createProject(){
 const name=q('newProjectName').value.trim();if(!name){note('请填写项目名称');return}const p={id:uid('project'),type:q('newProjectType').value,name,tag:q('newProjectTag').value.trim(),desc:q('newProjectDesc').value.trim(),assets:{},createdAt:Date.now(),updatedAt:Date.now()};state.projects.unshift(p);state.currentProjectId='local:'+p.id;state.director={};state.currentContentId='';save();q('projectModal').classList.remove('show');['newProjectName','newProjectTag','newProjectDesc'].forEach(id=>q(id).value='');renderAll();switchView('today');note('CONTENT 项目已创建')
}
function openContent(id,view='create'){
 const c=state.contents.find(x=>x.id===id);if(!c)return;state.currentContentId=id;state.currentProjectId=c.projectId;state.director={goal:c.goal,format:c.format,requested:c.format,style:c.style,platform:c.platform,theme:c.title,hooks:c.hooks||[c.hook],hook:c.hook,shots:c.shots||shotsFor(c.format),music:c.music,cta:c.cta,scheduleAt:c.scheduleAt,cover:c.cover,generatedAt:c.createdAt,score:scoreDirector(c.format,c.hook,c.goal,allProjects().find(p=>p.id===c.projectId))};save();renderAll();switchView(view)
}
function autoCalendar(){const p=project();if(!p){note('请先选择项目');return}const names=['品牌','人物故事','产品','足球热点','比赛预热','MATCH DAY','赛果 / MVP'];note('已生成7天内容结构建议');renderWeek(q('calendarFull'))}
function switchView(v){document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===v));document.querySelectorAll('[data-view-panel]').forEach(p=>p.classList.toggle('active',p.dataset.viewPanel===v));q('viewTitle').textContent=VIEW_META[v][0];q('viewDesc').textContent=VIEW_META[v][1];if(v==='matchday')window.SAGI_MOBILE?.renderMatchday?.();if(v==='videojobs')window.SAGI_MOBILE?.renderVideoJobs?.();if(v==='review')window.SAGI_MOBILE?.renderReview?.();if(v==='daily'){if(dailyCommandNeedsRefresh()&&!state.dailyCommandLoading)runDailyViralCommand(true);else renderDailyCommand()}if(v==='trends')renderTrends();if(v==='flow')renderFlow();if(v==='viralgen')renderViralGenerator();if(v==='viral')renderViralModel();if(v==='account')renderAccountData();if(v==='assets')renderAssets();if(v==='video')renderVideoEngine();if(v==='create')renderCreate();if(v==='publish')renderPublish();if(v==='learning')renderLearning();if(v==='performance')renderPerformance();if(v==='projects')renderProjects();if(v==='calendar')renderCalendar()}
function isMobileRuntime(){return typeof matchMedia==='function'&&matchMedia('(max-width:900px)').matches}
function renderAll(){
 window.SAGI_MOBILE?.renderAll?.();
 renderProjectSelect();renderKpis();renderTodayRecommendation();renderToday();renderDailyCommand();renderPublish();
 if(isMobileRuntime())return;
 renderTrends();renderFlow();renderDirector();renderCalendar();renderAssets();renderVideoEngine();renderCreate();renderLearning();renderViralGenerator();renderViralModel();renderAccountData();renderAccountTrend();renderPerformance();renderProjects()
}
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>switchView(b.dataset.view));
q('projectSelect').onchange=()=>{state.currentProjectId=q('projectSelect').value;state.currentContentId='';state.director={};const p=project();if(p){q('directorGoal').value=p.type==='event'?'event':p.type==='story'?'story':p.type==='product'?'sales':p.type==='hot'?'reach':'brand'}save();renderAll()};
q('videoRenderBtn').onclick=smartRenderVideo;q('directorFootageInput').onchange=handleFootageSelection;q('directorFootageInput').oninput=handleFootageSelection;q('directorMusicInput').onchange=handleMusicSelection;q('directorMusicInput').oninput=handleMusicSelection;q('directorAnalyzeFootageBtn').onclick=analyzeFootageFiles;q('directorBuildCutBtn').onclick=buildDirectorCut;q('directorClearFootageBtn').onclick=clearDirectorFootage;q('directorDuration').onchange=()=>{if(state.footage.length)buildDirectorCut()};q('videoReloadBtn').onclick=()=>state.videoDraft?.source&&prepareVideoSource({...state.videoDraft.source,title:state.videoDraft.title},false);q('videoCopyScriptBtn').onclick=copyVideoScript;q('dailyRunBtn').onclick=()=>runDailyViralCommand(false);q('dailyOpenP1Btn').onclick=executeDailyP1;q('dailyOpenRadarBtn').onclick=()=>switchView('trends');q('syncSalesBtn').onclick=syncSales;q('accountImportBtn').onclick=importAccountFile;q('accountImportFile').onchange=analyzeAccountFile;q('accountTemplateBtn').onclick=downloadAccountTemplate;q('accountApiDocsBtn').onclick=openDouyinApiDocs;q('trendRefreshBtn').onclick=fetchInternetTrends;q('trendOpenGoogleBtn').onclick=openGoogleTrends;q('trendProfile').onchange=()=>{q('trendQuery').disabled=q('trendProfile').value!=='custom'};q('flowNextBtn').onclick=runFlowNext;q('flowTodayBtn').onclick=()=>switchView('today');q('newProjectBtn').onclick=q('projectCreateTopBtn').onclick=()=>q('projectModal').classList.add('show');document.querySelectorAll('[data-close-modal]').forEach(b=>b.onclick=()=>b.closest('.modalMask').classList.remove('show'));q('createProjectBtn').onclick=createProject;
q('generatorRunBtn').onclick=()=>generateViralVariants();q('generatorSaveBestBtn').onclick=saveBestViralVariant;q('generatorTopic').onkeydown=e=>{if(e.key==='Enter')generateViralVariants()};q('viralAnalyzeBtn').onclick=()=>{renderViralModel();note('爆款模型已重新分析')};q('viralOptimizeBtn').onclick=optimizeCurrentForViral;q('generateDirectorBtn').onclick=()=>generateDirector(false);q('saveDirectorBtn').onclick=saveDirectorAsContent;q('todayGenerateBtn').onclick=()=>{generateDirector(false);switchView('director')};q('todayOpenDirectorBtn').onclick=()=>switchView('director');q('todayAddPlanBtn').onclick=addTodayPlan;q('calendarAutoBtn').onclick=autoCalendar;q('createFromDirectorBtn').onclick=()=>{if(!state.director?.generatedAt)generateDirector(true);renderCreate();note('故事板已生成')};q('markReadyBtn').onclick=markReady;q('packageCopyBtn').onclick=copyPackage;q('savePerformanceBtn').onclick=savePerformance;
window.SAGI_CORE={q,uid,today,esc,note,save,switchView,renderAll,get state(){return state}};
load();renderAll();if(!isMobileRuntime()&&dailyCommandNeedsRefresh())runDailyViralCommand(true);

function registerContentOSApp(){
 if(!('serviceWorker' in navigator))return;
 let refreshing=false;
 navigator.serviceWorker.addEventListener('controllerchange',()=>{
   if(refreshing)return;refreshing=true;location.reload();
 });
 navigator.serviceWorker.register('./sw.js',{updateViaCache:'none'}).then(reg=>{
   const activate=worker=>{if(worker&&worker.state==='installed'&&navigator.serviceWorker.controller)worker.postMessage({type:'SKIP_WAITING'})};
   if(reg.waiting)reg.waiting.postMessage({type:'SKIP_WAITING'});
   reg.addEventListener('updatefound',()=>{const w=reg.installing;if(w)w.addEventListener('statechange',()=>activate(w))});
   const check=()=>reg.update().catch(()=>{});
   check();
   document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')check()});
   setInterval(check,30*60*1000);
 }).catch(()=>{});
}
registerContentOSApp();
})();
