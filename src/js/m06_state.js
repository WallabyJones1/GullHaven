/* ================= game state (save v7, Gullhaven) ================= */
const SAVE_KEY='gullhaven.save';
const DEF=()=>({v:7,name:'',xVerified:false,av:1000+Math.floor(Math.random()*8000),active:0,
  shells:CFG.PLAY.startShells,reel:CFG.PLAY.startReel,
  licence:{no:'FREE',at:0},coop:null,coopAt:0,coopSwitch:{wk:-1,n:0},vote:null,
  gear:{rod:0,reel:0,line:0,hook:0,engine:0,tank:0,ice:0,sonar:-1,lamp:-1},
  boats:[],boat:null,paint:{},boatName:'',boatPos:null,fuel:0,
  bait:{dough:-1,worm:10,prawn:0},baitSel:'dough',
  creel:[],hold:[],pots:[],
  log:{},sets:{},titles:[],title:'',
  owned:[],crew:[],hired:0,
  stats:{casts:0,catches:0,lost:0,shells:0,sold:0,pulls:0,spent:0,won:0,trips:0,dug:0,salvaged:0},
  pts:{day:-1,raw:0,got:0},season:{},derby:{day:-1,in:false,best:0,id:''},
  comb:{key:'',dug:[]},salv:{},requests:null,quest:{i:0,prog:0,done:false},tutorial:0,
  home:{theme:'coastal',decor:[]},boatDecor:{},character:{template:1,mode:'template',look:null},islandBounties:{},visitedIslands:[],
  hist:[],mintsLocal:[],faucet:'',sound:1,music:1,ts:0,tz:0});
let S=DEF();
function migrate(j){if(!j||![6,7].includes(j.v))return null;const d=DEF();const n=Object.assign({},d,j);
  n.v=7;n.reel=0;n.licence=n.licence||d.licence;n.gear=Object.assign({},d.gear,j.gear||{});n.stats=Object.assign({},d.stats,j.stats||{});n.bait=Object.assign({dough:-1},j.bait||{});
  n.shells=Number.isFinite(n.shells)?Math.max(0,n.shells):CFG.PLAY.startShells;n.home=Object.assign({},d.home,j.home||{});n.home.decor=Array.isArray(n.home.decor)?n.home.decor:[];n.boatDecor=Object.assign({},j.boatDecor||{});
  n.character=j.character||{template:isNft(j.active)?j.active:1,mode:'legacy',look:null};n.islandBounties=j.islandBounties||{};n.visitedIslands=Array.isArray(j.visitedIslands)?j.visitedIslands:[];
  if(j.v===6&&n.quest&&n.quest.i===11)n.quest={i:11,prog:0};return n}
function loadLocal(){try{return migrate(JSON.parse(localStorage.getItem(SAVE_KEY)||'null'))}catch(e){return null}}
let dirty=false,lastSave=0;
function markDirty(){dirty=true;if(typeof INTRO==='undefined'||!INTRO.on)S.ts=Date.now()}
function saveLocal(){try{localStorage.setItem(SAVE_KEY,JSON.stringify(S))}catch(e){}}
const ACTIVE=()=>typeof characterId==='function'?characterId():S.active||S.av;
function myName(){return S.name||'Fisher'}
/* money (play mode keeps balances here; live mode mirrors the server) */
function addShells(n,why){S.shells=Math.max(0,Math.round(S.shells+n));if(n>0)S.stats.shells+=n;markDirty();updHUD()}
function payShells(n){if(S.shells<n){toast(`That costs ${fmt(n)} Shells. You have ${fmt(S.shells)}.`,'warn');sfx('error');return false}S.shells-=n;markDirty();updHUD();sfx('buy');return true}
// Compatibility for existing activity handlers: every price now spends ordinary Shells.
function payReel(n,why){return payShells(n)}
/* gear */
const gearTier=k=>S.gear[k];
function gearCtx(){const G=S.gear;return{rodT:G.rod,deepreel:!!GEAR.reel[G.reel].deep,lamp:G.lamp>=0&&isNightNow(),hookSnag:GEAR.hook[G.hook].snag,sonar:G.sonar}}
function curBoat(){return S.boat?BOATI[S.boat]:null}
function holdCap(){const b=curBoat();const fleet=myCoopFleetLvl();return(b?b.hold:0)+(S.coop==='brine'?1:0)+fleet}
const CREEL_CAP=6;
function fuelCap(){return GEAR.tank[S.gear.tank].cap}
function potCap(){return POTS.max+(S.coop==='mob'?1:0)}
/* freshness: fish lose value over town time unless they are iced */
const KEEP_MIN=90;
function freshOf(c,now){const e=CATI[c.id];if(!e||(e.cat!=='fish'&&e.cat!=='legend'))return 1;const mins=((now||Date.now())-c.t)/1000;return clamp(1-mins/(KEEP_MIN*GEAR.ice[S.gear.ice].keep)*.5,.5,1)}
function sellValue(c){const e=CATI[c.id];if(!e)return 0;let v=e.price;if(e.sz)v*=.7+.8*sizeFrac(e,c.cm||e.sz[0]);v*=c.v==='g'?5:c.v==='a'?3:1;v*=freshOf(c);v*=marketMul(e);return Math.max(1,Math.round(v))}
/* logbook */
function logged(id){return S.log[id]&&S.log[id].n>0}
function logCount(){let n=0;for(const e of CAT)if(logged(e.id))n++;return n}
function logEntry(id,cm,v,via){const e=CATI[id];const L=S.log[id]||(S.log[id]={n:0,best:0,first:Date.now(),vars:{}});const isNew=!L.n;L.n++;if(cm&&cm>L.best)L.best=cm;if(v)L.vars[v]=1;if(isNew){L.first=Date.now();L.via=via||''}markDirty();return isNew}
/* points for the co-op (play mode tallies locally; the server tallies in live mode) */
function addPoints(raw){const E=envAt();rollPts();if(S.pts.day!==E.day)S.pts={day:E.day,raw:0,got:0};const cap=CFG.CUP.softCap,tp=CFG.CUP.taper;let left=raw,got=0;
  while(left>0){const r0=S.pts.raw;const band=r0<cap[0]?0:r0<cap[1]?1:2;const room=band<2?cap[band]-r0:left;const take=Math.min(left,room);got+=take*tp[band];S.pts.raw+=take;left-=take}
  got=Math.round(got*10)/10;S.pts.got=Math.round((S.pts.got+got)*10)/10;if(S.coop)S.season[S.coop]=(S.season[S.coop]||0)+got;markDirty();return got}
