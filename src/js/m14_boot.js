/* ================= boot ================= */
function refreshAll(){syncCrew();syncMachine();updHUD();updQuestHUD();if(!$('panel').hidden)renderPanel();if(!$('book').hidden)renderBook()}
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
    requestAnimationFrame(t=>{lastT=t;loop(t)});INTRO.ready=true;
  },30));
  $('introGo').addEventListener('click',introGo);$('intro').addEventListener('pointerdown',introSkip);$('nameIn').addEventListener('keydown',e=>{if(e.key==='Enter')introGo()});
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
