/* ================= boot ================= */
function refreshAll(){syncCrew();syncMachine();updHUD();updQuestHUD();if(!$('panel').hidden)renderPanel();if(!$('book').hidden)renderBook()}
// the intro picture: you, in a dinghy, on a little sea
const INTRO={t:0,on:true};
function introFrame(dt){if(!INTRO.on)return;INTRO.t+=dt;const t=INTRO.t;const g=$('introCv').getContext('2d');g.imageSmoothingEnabled=false;g.clearRect(0,0,120,60);
  for(let y=0;y<34;y++)R(g,0,y,120,1,y<12?'#7fc8ec':y<24?'#a4dcf2':'#cdeef8');ell(g,96,14,7,7,'#fff2b0');ell(g,96,14,5,5,'#ffe070');
  R(g,0,26,40,8,'#5a8a5a');R(g,6,22,14,4,'#6a9a6a');R(g,14,18,4,8,'#e8e2d0');R(g,13,16,6,2,'#c8443a');if(Math.floor(t*2)%2)P(g,15,17,'#fff6c0');
  for(let y=34;y<60;y++)R(g,0,y,120,1,y<40?'#4f9fd0':y<50?'#3f86bd':'#2f6f9e');for(let i=0;i<12;i++){const x=Math.round((i*23+t*(4+i%3*3))%140)-10,y=36+(i*7)%22;R(g,x,y,5,1,'#8fd0f0')}
  const bob=Math.round(Math.sin(t*2)*1.2);const bs=boatSide('dinghy',S.boat?S.paint[S.boat]:null);const bx=48,by=24+bob;g.drawImage(sheet(ACTIVE()),0,0,SW,SH,bx+Math.round(bs.width/2)-8,by-8,SW,SH);g.drawImage(bs,bx,by+8);
  const rx=bx+Math.round(bs.width/2)+6;g.strokeStyle='#5a3a2a';g.beginPath();g.moveTo(rx,by+6);g.lineTo(rx+16,by-6);g.stroke();g.strokeStyle='rgba(255,255,255,.7)';g.beginPath();g.moveTo(rx+16,by-6);g.quadraticCurveTo(rx+22,by+12,rx+26,38+bob);g.stroke();
  const gxp=Math.round(20+((t*14)%110)),gyp=8+Math.round(Math.sin(t*3)*2);const wf=Math.floor(t*6)%2;P(g,gxp,gyp,'#ffffff');P(g,gxp-1,gyp-wf,'#ffffff');P(g,gxp+1,gyp-wf,'#ffffff');P(g,gxp-2,gyp-1+wf,'#c8d0d8');P(g,gxp+2,gyp-1+wf,'#c8d0d8')}
function introText(l){const nr=$('nameRow');if(l&&S.name){nr.hidden=true;$('introTxt').textContent=`Welcome back, ${S.name}. ${fmt(S.shells)} Shells, ${logCount()} of ${CAT.length} in your Logbook${S.coop?', fishing for '+COOPI[S.coop].s:''}.`;$('introGo').textContent='Back to the harbour'}
  else{nr.hidden=false;$('nameIn').value=S.name||'';$('introGo').textContent='Set sail'}$('introGo').disabled=false}
function introGo(){const v=$('nameIn').value.replace(/^@/,'').trim();if(!$('nameRow').hidden&&v){if(!HANDLE_RE.test(v)){toast('Use letters, numbers and _ (up to 15).','warn');return}S.name=v;markDirty()}
  $('intro').hidden=true;INTRO.on=false;audioUnlock();startMusic();updHUD();sendPresence(true);if(NET.db)pushMyDoc(true);setTimeout(updQuestHUD,50);
  if(!S.tutorial){S.tutorial=1;markDirty();toast('Tap the ground to walk. Tap the water to fish from the shore.');setTimeout(()=>toast('Hold the button to wind up a cast, let go to throw. Strike on the bite!'),4200);setTimeout(()=>toast(S.name?'The quest chip on the left walks you through your first season.':'Name your fisher in Menu so the town knows who caught what.'),8800)}}
function dayTick(){rollPts();settleCup();settleDerby();updEnvHUD()}
function boot(){
  const l=loadLocal();if(l)S=l;
  // solo mode keeps its own aquarium plaques and town firsts
  if(S.aqLocal)for(const[id,at]of Object.entries(S.aqLocal))NET.shared.aquarium[id]={n:myName(),at};if(S.firstsLocal)for(const id of Object.keys(S.firstsLocal))NET.shared.firsts[id]=myName();
  introText(l);
  let last=performance.now();const introLoop=now=>{if(!INTRO.on)return;introFrame(Math.min(.05,(now-last)/1000));last=now;requestAnimationFrame(introLoop)};requestAnimationFrame(introLoop);
  // let the intro paint before the (heavier) world generation runs
  requestAnimationFrame(()=>setTimeout(()=>{
    WORLD=genWorld();SCENES.world=WORLD;setupWorldActs();spawnLife();resize();paintDock();
    const sp=WORLD.spots.spawn;scene=WORLD;player.x=sp.x;player.y=sp.y;player.dir='up';
    syncCrew();syncMachine();dayTick();updHUD();updQuestHUD();setLocation();buildMiniBase();drawMini();upd2Button();setActButton(null);
    initNet().then(()=>{syncMachine();refreshAll();sendPresence(true);if(NET.db)pushMyDoc(true)});
    requestAnimationFrame(t=>{lastT=t;loop(t)});
  },30));
  $('introGo').addEventListener('click',introGo);$('nameIn').addEventListener('keydown',e=>{if(e.key==='Enter')introGo()});
  setInterval(()=>{if(scene)setLocation()},1000);setInterval(dayTick,30000);
  window.addEventListener('pagehide',()=>saveLocal());
  document.addEventListener('visibilitychange',()=>{if(document.hidden){saveLocal();if(NET.db)remoteSave()}});
}
// a small test and debugging handle
window.RT={state:()=>S,setState:fn=>{fn(S);refreshAll()},env:t=>envAt(t),cat:()=>CAT,catArt,panel:(n,t,c)=>openPanel(n,t,c),book:()=>toggleBook(true),open:()=>openGacha(),pull:i=>pull(i),mach:()=>MACH,
  tp:(x,y,d)=>{player.x=x;player.y=y;if(d)player.dir=d;cancelPath()},tap:(wx,wy)=>tapWorld(wx,wy),player:()=>player,scene:()=>scene,world:()=>WORLD,go:k=>k==='world'?goWorld():goInside(k),
  board:()=>boardBoat(),fish:()=>{const w=waterAhead();if(w)startFishing({x:w.x,y:w.y,zone:w.zone,shore:true});return!!w},mg:()=>MG,net:()=>NET,cup:()=>({pools:cupPools(),rows:cupStandings()}),
  hook:ctx=>rollHook(Object.assign({zone:'harbour',bait:'dough',gear:gearCtx(),env:envAt(),near:{}},ctx||{}))};
boot();
