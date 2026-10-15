/* ================= the wider world: hull damage and storms, the Mirrorlake puzzle, town cats and the Cat Café =================
   Open water is free to cross in any boat, but rough water beyond your boat's rating (and any storm) wears the hull down.
   A swamped boat is towed back to the harbour. */
const HULL={repairPerHp:6,tow:150};
function hullOf(k){S.hull=S.hull||{};const v=S.hull[k];return v==null?100:v}
function setHull(k,v){S.hull=S.hull||{};S.hull[k]=clamp(v,0,100);markDirty()}
let hullStep=4,roughZone=null;
function hullHit(n){if(player.boat){setHull(player.boat.k,hullOf(player.boat.k)-n);if(hullOf(player.boat.k)<=0)wreckBoat()}}
function hullTick(dt){const b=player.boat;if(!b||scene!==WORLD||MG&&MG.type!=='fish')return;const z=b.zone;if(!z){roughZone=null;return}const E=envAt(),B=BOATI[b.k],Z=ZONES[z];
  const over=Math.max(0,(Z.need||0)-B.tier);let d=over*.4;
  if(E.sky==='storm'&&!['harbour','lake','estuary'].includes(z))d+=({shallows:.5,reef:.9,kelp:1,wreck:1.3,blue:1.6,deep:1.9}[z]||1)*Math.max(.08,1-B.storm*.24);
  if(over&&roughZone!==z){roughZone=z;const need=BOATS.find(x=>x.tier>=Z.need);toast(`Rough water for a ${B.n.toLowerCase()}! ${Z.n} is ${need?need.n.toLowerCase():'big boat'} country. Your hull will take a beating.`,'warn');sfx('error')}if(!over)roughZone=null;
  if(!d)return;const h=hullOf(b.k)-d*dt;setHull(b.k,h);const step=Math.ceil(h/25);if(step<hullStep&&h>0){hullStep=step;toast(`Hull at ${Math.round(h)}%. ${h<30?'Head for the harbour!':'She is taking water.'}`,'warn');sfx('thud')}if(h<=0)wreckBoat()}
function wreckBoat(){const b=player.boat;if(!b)return;const k=b.k;closeMG();player.boat=null;S.boatPos=null;setHull(k,35);hullStep=4;
  const lost=Math.floor(S.hold.length/3);for(let i=0;i<lost;i++)S.hold.splice(Math.floor(Math.random()*S.hold.length),1);const fee=Math.min(S.shells,HULL.tow);S.shells-=fee;markDirty();
  const f=$('fade');f.hidden=false;f.textContent='Towed home...';sfx('rumble');
  setTimeout(()=>{f.hidden=true;const sp=WORLD.spots.spawn;setScene(WORLD,sp.x,sp.y,'up');updHUD();toast(`Your ${BOATI[k].n.toLowerCase()} was swamped! The harbour tug towed you home${fee?' for '+fee+' Shells':''}${lost?' and '+lost+' fish went overboard':''}. Repairs at the Boatyard.`,'warn')},1500)}
function repairCost(k){return Math.ceil((100-hullOf(k))*HULL.repairPerHp)}
function hullRow(){if(!S.boat)return el('div');const k=S.boat,h=hullOf(k),c=repairCost(k);return itemRow(boatIcon(k),'Hull '+Math.round(h)+'%',h>=100?'Shipshape. Storms and rough water wear it down.':'Repairs cost '+fmt(c)+' Shells',h>=100?el('b',null,'OK'):btn('Repair',()=>{if(!payShells(c))return;setHull(k,100);hullStep=4;sfx('buy');toast('Good as new.');renderPanel()},'sm gold'))}
function updHullChip(){const c=$('hullChip');if(!c)return;const b=player.boat;const E=envAt();const show=b&&(hullOf(b.k)<100||E.sky==='storm');c.hidden=!show;if(!show)return;const h=hullOf(b.k);$('hullTxt').textContent='Hull '+Math.round(h)+'%';$('hullSub').textContent=E.sky==='storm'?'Storm! Small boats suffer':roughZone?'Rough water':'Repair at the Boatyard';paintIcon($('hullIc'),uiIcon(E.sky==='storm'?'storm':'boat'))}
/* ---------- Mirrorlake: four riddles, one gate ---------- */
function storyInit(){S.story=S.story||{};S.story.clues=S.story.clues||{};S.story.dials=Array.isArray(S.story.dials)&&S.story.dials.length===4?S.story.dials:[4,5,6,7];S.catLove=S.catLove||{};S.hull=S.hull||{}}
function applyGate(){if(WORLD&&WORLD.lakeGate)for(const i of WORLD.lakeGate.tiles)WORLD.sol[i]=lakeOpen()?0:1}
function clue(i){const c=STORY_CLUES[i];const fresh=!S.story.clues[c.id];S.story.clues[c.id]=1;markDirty();toast(`${c.who}: "${c.text}"`,fresh?'lvl':null);if(fresh){sfx('pin');const n=Object.keys(S.story.clues).length;if(n===4&&!lakeOpen())setTimeout(()=>toast('You have all four riddles. The old gate in the south wood is waiting.','rare'),3500)}}
const NPC_TALK={tideglass:['"Tideglass grows the best bait in the sea, and the slowest gossip."','"The wardens left a riddle with my gran. I keep it for anyone who asks."'],mossbank:['"Mind the flowers! Everything here grows sideways from the salt."','"There was a gate in the south wood, once. My riddle opens a quarter of it."'],lantern:['"Out here the kelp sings when a storm comes. Head home when it does."','"Old wardens, old lake, old riddle. Here, take it."']};
function wildsActs(){storyInit();applyGate();const W=WORLD,s=W.spots;
  if(W.lakeGate){const gy=Math.min(...W.lakeGate.tiles.map(i=>Math.floor(i/W.w)));act(W,W.lakeGate.x,gy*16-4,22,'Old gate','map',()=>lakeOpen()?toast('The gate stands open. Mirrorlake lies beyond.'):openPanel('gate'))}
  if(s.carving)act(W,s.carving.x,s.carving.y,20,'Read the old carving','book',()=>clue(0));
  for(const n of W.npcs||[]){const i=STORY_CLUES.findIndex(c=>c.id===n.island);act(W,n.x,n.y,20,'Talk to '+n.n,'talk',()=>{const l=NPC_TALK[n.island];if(S.story.clues[n.island]&&Math.random()<.5){toast(n.n+': '+l[0]);return}toast(n.n+': '+l[1]);setTimeout(()=>clue(i),1800)})}
  if(s.lakeSign)act(W,s.lakeSign.x,s.lakeSign.y,18,'Signpost','map',()=>toast('MIRRORLAKE. Freshwater only. Mind the cod.'));
  if(s.cafe)act(W,s.cafe.x,s.cafe.y,16,'Cat Café','door',()=>openPanel('cafe'));
  if(s.bakery)act(W,s.bakery.x,s.bakery.y,16,'Bakery','door',()=>toast(['Nora: "Fresh loaves at dawn. Bread dough bait is always free, love."','Nora: "The cats get the crusts. Don\'t tell the café."','The bakery smells of cinnamon and warm bread.'][Math.floor(Math.random()*3)]));
  if(s.fountain)act(W,s.fountain.x,s.fountain.y,22,'Toss a Shell','shell',()=>{if(!payShells(1))return;sfx('coin');splash(s.fountain.x,s.fountain.y-20,4);toast(['You wish for a big one.','You wish for calm seas.','You wish for a legend on the line.','A gull eyes your wish suspiciously.'][Math.floor(Math.random()*4)])});
  spawnCats()}
function panelGate(body,H){head('The old gate','Four rusted dials on a brass lock',uiIcon('map'));tabs(null);
  if(lakeOpen()){H('p','The gate stands open. Mirrorlake is yours to fish.');return}
  H('p','Cut into the pillar: "Four keepers of the sea each hold a mark. Ask at the point, and on every isle." Tap a dial to turn it.');
  const l=el('div','list');STORY_CLUES.forEach((c,i)=>{const got=S.story.clues[c.id];l.append(itemRow(uiIcon(got?'book':'map'),got?c.text:'Riddle '+(i+1)+': not found yet',got?c.who:'Somewhere around the sea'))});body.append(l);
  const d=S.story.dials;const row=el('div','row');row.style.cssText='margin:12px 0;justify-content:center;gap:10px';d.forEach((v,i)=>{const b=el('button','btn alt');b.setAttribute('aria-label','Dial '+(i+1)+': '+LOCK_SYMS[v]);const ic=cvIcon(uiIcon(LOCK_SYMS[v]));ic.style.width=ic.style.height='32px';b.append(ic);b.onclick=()=>{d[i]=(d[i]+1)%LOCK_SYMS.length;sfx('click');markDirty();renderPanel()};row.append(b)});body.append(row);
  body.append(btn('Try the lock',()=>{if(!d.every((v,i)=>LOCK_SYMS[v]===STORY_CLUES[i].sym)){sfx('error');toast('The dials grind, but the lock holds.');return}
    S.story.lake=1;markDirty();applyGate();closePanel();sfx('fanfare2');addShells(500);bumpQuest('zone','lake');toast('The old gate swings open! Mirrorlake: freshwater fish, and an old cod nobody has landed. +500 Shells','rare')},'gold'))}
/* ---------- the town cats (art from Catoshi's Catch) ---------- */
const TOWN_CATS=[];let petF=null;
function spawnCats(){TOWN_CATS.length=0;const s=WORLD.spots;const I=k=>(WORLD.islands||[]).find(i=>i.id===k);
  const homes=[s.cafe,s.cafe,s.cafe,s.fountain,s.spawn,s.carving,I('tideglass')&&I('tideglass').bounty,I('mossbank')&&I('mossbank').bounty,s.lakeSign,s.market];
  COATS.forEach((c,i)=>{const h=homes[i]||s.spawn;if(!h)return;const x=h.x+((i*37)%5-2)*10,y=h.y+8+((i*13)%3)*6;TOWN_CATS.push({k:c.k,n:c.name,x,y,hx:x,hy:y,dir:0,f:0,ft:0,t:Math.random()*4,mv:null,heart:0})})}
function catsTick(dt){for(const c of TOWN_CATS){if(c.heart>0)c.heart-=dt;c.t-=dt;
    if(c.mv){const dx=c.mv.x-c.x,dy=c.mv.y-c.y,d=Math.hypot(dx,dy);if(d<1.5||c.t<=0){c.mv=null;c.t=3+Math.random()*7;continue}const sp=Math.min(d,20*dt),nx=c.x+dx/d*sp,ny=c.y+dy/d*sp;if(!walkablePx(nx,ny)){c.mv=null;c.t=2;continue}c.x=nx;c.y=ny;c.dir=Math.abs(dx)>Math.abs(dy)?(dx<0?1:2):(dy<0?3:0);c.ft+=dt;if(c.ft>.15){c.ft=0;c.f=c.f?0:1}}
    else if(c.t<=0){const a=Math.random()*6.28,r=10+Math.random()*40;const tx=c.hx+Math.cos(a)*r,ty=c.hy+Math.sin(a)*r*.6;if(walkablePx(tx,ty)){c.mv={x:tx,y:ty};c.t=5}else c.t=1.5;c.f=0}}
  // your adopted cat trots after you
  if(S.pet&&COATI[S.pet]){if(!petF||petF.sc!==scene){petF={x:player.x-12,y:player.y+4,dir:0,f:0,ft:0,sc:scene}}const tx=player.x-(player.dir==='right'?14:player.dir==='left'?-14:0),ty=player.y+(player.dir==='up'?12:player.dir==='down'?-10:4);
    const dx=tx-petF.x,dy=ty-petF.y,d=Math.hypot(dx,dy);if(d>60){petF.x=tx;petF.y=ty}else if(d>6){const sp=Math.min(d,(d>24?90:60)*dt);petF.x+=dx/d*sp;petF.y+=dy/d*sp;petF.dir=Math.abs(dx)>Math.abs(dy)?(dx<0?1:2):(dy<0?3:0);petF.ft+=dt;if(petF.ft>.13){petF.ft=0;petF.f=petF.f?0:1}}else petF.f=0}}
function drawCats(list,t,Sc){const one=(k,x,y,dir,f,heart)=>list.push({sy:y,draw:()=>{const im=catWalk(k,dir,f);ctx.drawImage(im,Math.round(x-camX)-10,Math.round(y-camY)-17);if(heart>0)ctx.drawImage(artHeart(),Math.round(x-camX)-3,Math.round(y-camY)-26-Math.round((1.5-heart)*8))}});
  if(Sc===WORLD)for(const c of TOWN_CATS){if(c.k===S.pet||!inView(c.x-12,c.y-20,24,24))continue;one(c.k,c.x,c.y,c.dir,c.mv?c.f:0,c.heart)}
  if(S.pet&&petF&&petF.sc===Sc&&!player.boat)one(S.pet,petF.x,petF.y,petF.dir,petF.f,0)}
function catActs(consider){for(const c of TOWN_CATS){if(c.k===S.pet)continue;consider(c.x,c.y-4,18,{label:'Pet '+c.n,icon:'hand',act:()=>petCat(c)})}}
function petCat(c){c.mv=null;c.t=4;c.heart=1.5;c.dir=0;sfx('purr');const now=Date.now();S.catPet=S.catPet||{};const love=S.catLove[c.k]||0;
  if(now-(S.catPet[c.k]||0)>90000&&love<5){S.catPet[c.k]=now;S.catLove[c.k]=love+1;markDirty();toast(love+1>=5?`${c.n} adores you! Visit the Cat Café to take ${c.n} home.`:`${c.n} purrs. (${'♥'.repeat(love+1)}${'♡'.repeat(4-love)})`,love+1>=5?'rare':null)}
  else toast(`${c.n} ${['purrs happily.','headbutts your hand.','rolls over for a belly rub. It is a trap.','blinks slowly at you.'][Math.floor(Math.random()*4)]}`)}
function panelCafe(body,H){head('Cat Café','Tea, cake and the harbour cats',uiIcon('home'));tabs(null);
  H('p','Every cat in Gullhaven drops by. Pet a cat around town to earn its trust (one heart every couple of minutes). At five hearts it will come home with you and follow you about.');
  const l=el('div','list');for(const c of COATS){const love=S.catLove[c.k]||0,mine=S.pet===c.k;
    l.append(itemRow(catFace(c.k),c.name+' · '+c.n,love?'♥'.repeat(love)+'♡'.repeat(5-love):'Not met yet. Look around town.',mine?btn('Send home',()=>{S.pet=null;petF=null;markDirty();renderPanel()},'sm alt'):love>=5?btn('Adopt',()=>{S.pet=c.k;petF=null;markDirty();sfx('purr');toast(c.name+' is your companion now.','lvl');renderPanel()},'sm gold'):null))}
  body.append(l)}
function worldTick(dt){catsTick(dt);hullTick(dt);worldTick.t=(worldTick.t||0)+dt;if(worldTick.t>.5){worldTick.t=0;updHullChip()}}
const EXTRA_PANELS={gate:panelGate,cafe:panelCafe};
// background music follows where you are
function musMode(){if(typeof gachaOpen!=='undefined'&&gachaOpen)return'arcade';const h=ghour(),night=h<6||h>=20.5;if(!scene||!WORLD)return night?'night':'day';
  if(scene!==WORLD)return scene.homeOwner?'home':'inside';const E=envAt();if(E.sky==='storm')return'storm';const px=player.x/16,py=player.y/16;
  if(Math.hypot(px-LAKE.x,(py-LAKE.y)*1.3)<LAKE.RX)return'lake';if((WORLD.islands||[]).some(I=>Math.hypot(px-I.x,py-I.y)<I.r+6))return'island';
  if(player.boat){const z=player.boat.zone;if(z==='blue'||z==='deep')return'deep';if(z&&z!=='harbour')return'sea'}return night?'night':'day'}
