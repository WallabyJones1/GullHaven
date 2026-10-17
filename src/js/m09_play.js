/* ================= the player, scenes, interactables, catches and the hold ================= */
const player={x:0,y:0,dir:'down',f:0,ft:0,moving:false,boat:null,emoteK:null,emoteT:0,emote:null,bubble:null,swing:0,path:null,goal:null};
const floats=[],fx=[];let MG=null;
function blocked(Sc,x,y){const pts=[[x-4,y-2],[x+4,y-2],[x-4,y+2],[x+4,y+2]];for(const[px,py]of pts){const tx=Math.floor(px/16),ty=Math.floor(py/16);if(tx<0||ty<0||tx>=Sc.w||ty>=Sc.h)return true;if(Sc.sol[ty*Sc.w+tx])return true}return false}
function moveEnt(e,dx,dy,Sc){let moved=false;if(dx&&!blocked(Sc,e.x+dx,e.y)){e.x+=dx;moved=true}if(dy&&!blocked(Sc,e.x,e.y+dy)){e.y+=dy;moved=true}return moved}
function faceFrom(dx,dy,cur){if(Math.abs(dx)>Math.abs(dy))return dx<0?'left':'right';if(dy)return dy<0?'up':'down';return cur}
function floatText(x,y,text,col){floats.push({x,y,text,col,t:1.5})}
function burst(x,y,cols,n=10){for(let i=0;i<n;i++){const a=Math.random()*6.28,s=20+Math.random()*40;fx.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s-30,t:.6+Math.random()*.4,c:cols[i%cols.length]})}}
function splash(x,y,n=8){for(let i=0;i<n;i++){const a=-Math.PI/2+(Math.random()-.5)*2.2,s=25+Math.random()*35;fx.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s,t:.45+Math.random()*.3,c:i%2?'#e8fbff':'#9adcf0'})}}
const zoneAtPx=(x,y)=>{if(scene!==WORLD)return null;const tx=Math.floor(x/16),ty=Math.floor(y/16);const z=WORLD.zone[ty*WORLD.w+tx];return z===255||z===undefined?null:ZONE_ORDER[z]};
const isWaterT=t=>t==='o';
/* ---------- scenes ---------- */
function setScene(Sc,x,y,dir){scene=Sc;player.x=x;player.y=y;player.dir=dir||'down';player.path=null;player.goal=null;closeMG();sendPresence(true);updDock();updHUD();setLocation()}
function goWorld(from){let p=WORLD.spots.spawn;if(from&&WORLD.spots[from])p=WORLD.spots[from];setScene(WORLD,p.x,p.y+4,'down');sfx('door')}
function goInside(kind){const key='in:'+kind;if(!SCENES[key])SCENES[key]=genInterior(kind);const Sc=SCENES[key];setScene(Sc,Sc.spots.spawn.x,Sc.spots.spawn.y,'up');sfx('door');if(Sc.greet&&!goInside.seen[kind]){goInside.seen[kind]=1;setTimeout(()=>toast(Sc.greet),250)}bumpQuest('visit',kind)}
goInside.seen={};
/* ---------- boats: boarding and tying up ---------- */
function myBoatSpot(){if(!S.boat)return null;if(S.boatPos)return S.boatPos;const b=WORLD.berths[Math.abs(hashStr(S.name||String(S.av)))%Math.min(8,WORLD.berths.length)];return{x:b.x,y:b.y,h:b.dir==='n'?12:4}}
function hashStr(s){let h=0;for(const c of String(s))h=Math.imul(h^c.charCodeAt(0),16777619);return h}
function boardBoat(){if(!S.boat){toast('You need a boat first. The Boatyard sells them.');return}const sp=myBoatSpot();player.boat={k:S.boat,x:sp.x,y:sp.y,h:(sp.h||0)/16*Math.PI*2,v:0,tgt:null};player.x=sp.x;player.y=sp.y;player.path=null;S.boatPos=null;markDirty();sfx('thud');splash(sp.x,sp.y+4,6);setLocation();updHUD();bumpQuest('board');
  if(S.fuel<=0&&S.gear.engine>0)toast('Your tank is empty. Fill up at the fuel pump on the promenade, or row.','warn')}
function canTieUp(){const b=player.boat;if(!b)return null;let best=null,bd=1e9;for(let a=0;a<16;a++){const an=a/16*6.283;for(const r of[14,20,26]){const x=b.x+Math.cos(an)*r,y=b.y+Math.sin(an)*r;const tx=Math.floor(x/16),ty=Math.floor(y/16);if(tx<0||ty<0||tx>=WORLD.w||ty>=WORLD.h)continue;const i=ty*WORLD.w+tx;if(WORLD.sol[i])continue;const t=WORLD.g[i];if(t==='o')continue;const d=r;if(d<bd){bd=d;best={x:tx*16+8,y:ty*16+10}}}}return best}
function tieUp(){const spot=canTieUp();if(!spot){toast('Steer next to a jetty, the beach or a rock to tie up.');return}const b=player.boat;S.boatPos={x:b.x,y:b.y,h:boatHeading(b.h)};player.boat=null;player.x=spot.x;player.y=spot.y;player.dir=faceFrom(spot.x-b.x,spot.y-b.y,'down');markDirty();sfx('thud');setLocation();updHUD()}
const boatHeading=h=>((Math.round(h/(Math.PI*2)*16)%16)+16)%16;
/* ---------- interactables ---------- */
function frontTile(){const d={down:[0,1],up:[0,-1],left:[-1,0],right:[1,0]}[player.dir];return[Math.floor((player.x+d[0]*10)/16),Math.floor((player.y-2+d[1]*12)/16),d]}
function waterAhead(){if(scene!==WORLD)return null;const[tx0,ty0,d]=frontTile();for(let k=0;k<3;k++){const tx=tx0+d[0]*k,ty=ty0+d[1]*k;const t=tileT(WORLD,tx,ty);if(t==='o')return{tx,ty,x:tx*16+8+d[0]*24,y:ty*16+8+d[1]*24,zone:ZONE_ORDER[WORLD.zone[ty*WORLD.w+tx]]}}return null}
function nearestAct(){const px=player.x,py=player.y;let best=null,bd=1e9;const consider=(x,y,r,a)=>{const d=Math.hypot(x-px,y-py);if(d<=r&&d<bd){bd=d;best=a}};
  if(player.boat)return boatAct();
  for(const a of scene.acts)consider(a.x,a.y,a.r,a);
  if(scene===WORLD){lifeActs(consider);
    if(S.boat&&!player.boat){const sp=myBoatSpot();consider(sp.x,sp.y,30,{label:'Board your '+BOATI[S.boat].n.toLowerCase(),icon:'boat',act:boardBoat})}
    for(const c of combSpots())consider(c.x,c.y,16,{label:c.where==='rocks'?'Search the pool':'Dig',icon:c.where==='rocks'?'hand':'shovel',act:()=>startDig(c)});
    const w=waterAhead();if(w&&!best)best={label:'Fish',icon:'rod_'+S.gear.rod,act:()=>startFishing({x:w.x,y:w.y,zone:w.zone,shore:true})}}
  return best}
function boatAct(){const b=player.boat;if(!b)return null;const z=zoneAtPx(b.x,b.y);
  for(const p of S.pots){if(Math.hypot(p.x-b.x,p.y-b.y)<28)return{label:'Haul pot',icon:'pot',act:()=>haulPot(p)}}
  for(const s of WORLD.salvage)if(!s.dead&&Math.hypot(s.x-b.x,s.y-b.y)<30)return{label:'Grapple',icon:'grapple',act:()=>startSalvage(s)};
  if(Math.hypot(WORLD.spots.fuel.x-b.x,WORLD.spots.fuel.y-b.y)<56&&S.gear.engine>0&&S.fuel<fuelCap()-1)return{label:'Refuel',icon:'fuel',act:refuel};
  if(Math.abs(b.v)>14)return null;const tie=canTieUp();if(tie&&Math.abs(b.v)<6&&(tileT(WORLD,Math.floor(tie.x/16),Math.floor(tie.y/16))==='pr'||!z||z==='harbour'))return{label:'Tie up',icon:'anchor',act:tieUp};
  if(z&&ZONES[z].need>boatTier()){const need=BOATS.find(x=>x.tier>=ZONES[z].need);return{label:'Too rough',icon:'storm',act:()=>toast(`Too rough to fish ${ZONES[z].n} from a ${BOATI[b.k].n.toLowerCase()}. You need a ${need?need.n.toLowerCase():'bigger boat'}.`)}}
  return z?{label:'Cast',icon:'rod_'+S.gear.rod,act:()=>startFishing({x:b.x+Math.cos(b.h)*40,y:b.y+Math.sin(b.h)*40,zone:z,boat:true})}:null}
// the second button: pots from the boat, bait choice on foot
function secondAct(){if(player.boat){const ds=diveSiteNear();if(ds)return{label:'Dive',icon:'dive',act:()=>startDive(ds)};const z=zoneAtPx(player.boat.x,player.boat.y);if(z&&!['blue'].includes(z))return{label:S.pots.length>=potCap()?'Pots out':'Drop pot',icon:'pot',act:dropPot};return null}return{label:'Bait',icon:'bait_'+S.baitSel,act:()=>openPanel('hold','bait')}}
/* ---------- the town's fixed interactions ---------- */
function setupWorldActs(){const Sc=WORLD,s=Sc.spots;
  const door=(k,label,fn)=>act(Sc,s[k].x,s[k].y,16,label,'door',fn);
  door('market','Fish Market',()=>goInside('market'));door('tackle','Tackle Shop',()=>goInside('tackle'));door('boatyard','Boatyard',()=>goInside('boatyard'));door('exchange','Island Guild',()=>goInside('exchange'));
  door('aquarium','Aquarium',()=>goInside('aquarium'));door('tavern','The Salty Gull',()=>goInside('tavern'));door('harbourmaster','Harbourmaster',()=>goInside('harbourmaster'));door('home','Your cottage',()=>goInside('home'));
  for(const C of COOPS)door('hall_'+C.id,C.s+' hall',()=>goInside('hall_'+C.id));
  act(Sc,s.lighthouse.x,s.lighthouse.y,18,'Lighthouse','door',()=>goInside('lighthouse'));
  act(Sc,s.machine.x,s.machine.y,26,'Character atelier','crew',()=>openPanel('character'));
  for(const a of Sc.islandActs||[])act(Sc,a.x,a.y,20,a.label,a.icon||'talk',()=>a.kind==='shop'?openPanel(a.shopKind==='home'?'home':'shop',a.shopKind==='home'?null:a.shopKind):openPanel('island',a.id));
  act(Sc,s.tide.x,s.tide.y,18,'Tide board','tide',()=>openPanel('weather'));act(Sc,s.notice.x,s.notice.y,18,'Notice board','talk',()=>openPanel('notice'));
  act(Sc,s.bait.x,s.bait.y,20,'Bait stall','bait_prawn',()=>openPanel('shop','bait'));act(Sc,s.fuel.x,s.fuel.y,18,'Fuel pump','fuel',refuel);
  for(const h of(Sc.houses||[]))act(Sc,h.x,h.y,14,'Knock','door',()=>knock(h));wildsActs()}
function knock(h){const lines=['Nobody home. A gull watches you from the gutter.','"Out on the water, love. Try the tavern later."','A dog barks. Nobody answers.','"If you\'re selling bait, I\'ve got plenty!"','A note on the door: Gone fishing.'];toast(lines[(Math.abs(hashStr(h.x+','+h.y))+envAt().tday)%lines.length])}
function refuel(){if(S.gear.engine===0){toast('Oars don\'t need fuel. Buy an outboard at the Boatyard.');return}const need=Math.ceil(fuelCap()-S.fuel);if(need<=0){toast('Your tank is full.');return}const cost=need*2;if(S.shells<cost){const can=Math.floor(S.shells/2);if(can<=0){toast('Fuel is 2 Shells a litre.','warn');return}S.fuel+=can;S.shells-=can*2}else{S.fuel+=need;S.shells-=cost}markDirty();updHUD();sfx('buy');toast(`Tank ${Math.round(S.fuel)}/${fuelCap()} L.`)}
/* ---------- catches ---------- */
function holdUsed(){return S.hold.length}
function holdFull(){return S.hold.length>=CREEL_CAP+(S.boat?holdCap():0)}
function holdCapTotal(){return CREEL_CAP+(S.boat?holdCap():0)}
// everything that comes out of the water goes through here: the Logbook, the town's firsts, the Cup, the hold and the card
async function onCatch(r,via,opts={}){const e=r.e||CATI[r.id];if(!e)return;const cm=r.cm||0,v=r.v||'';S.stats.catches++;
  const isNew=logEntry(e.id,cm,v,via);let first=false;if(isNew&&NET.mode!=='solo')first=await creditFirst(e.id);else if(isNew&&!NET.shared.firsts[e.id]){first=true;NET.shared.firsts[e.id]=myName()}
  let pts=0;if(!opts.serverPts){let raw=catchPoints(e,cm,v);if(isNew)raw+=CFG.CUP.firstBonus*(e.r+1)/2;if(e.cat==='legend')raw+=CFG.CUP.legendBonus;pts=S.licence&&S.coop?addPoints(raw):0}else pts=opts.serverPts;
  if(S.licence&&S.coop&&pts>0)reportCatch(e,cm,pts);
  let kept=true,where='hold';if(e.release){kept=false;where='released'}else if(e.cat==='set'){kept=false;where='sets';(S.sets[e.set]=S.sets[e.set]||{})[e.id]=1;checkSet(e.set)}
  else if(holdFull()){kept=false;where='full'}
  if(kept)S.hold.push({id:e.id,cm,v,kg:r.kg||fishKg(e,cm),t:Date.now()});
  if(e.cat==='legend'){legendBounty(e);announce(`landed ${e.n}! (${cm} cm)`,'legend');sfx('jackpot')}else if(isNew&&first&&e.r>=2)announce(`caught the first ${e.n} in Gullhaven!`,'rare');else if(v)announce(`hooked a ${v==='g'?'golden':'albino'} ${e.n}!`,'rare');
  if(S.derby.day===envAt().day&&S.derby.in&&e.id===S.derby.id&&cm>S.derby.best){S.derby.best=cm;toast(`New derby best: ${cm} cm`,'lvl');derbyReport(cm)}
  showCatch(e,{cm,v,isNew,first,pts,where,kg:r.kg||fishKg(e,cm)});bumpQuest('catch',e);markDirty();updHUD();if(isNew)$('bookBadge').hidden=false;return{isNew,first,pts}}
function legendBounty(e){const E=envAt();const key=E.day+':'+e.id;S.bounties=S.bounties||{};if(S.bounties[key]||CHAIN.live)return;const pool=cupPools(E.day,E.dmin).bounty;const amt=Math.floor(pool*CFG.BOUNTY.share);if(amt>0&&S.licence){S.bounties[key]=amt;addShells(amt);S.stats.won+=amt;toast(`Legendary bounty: +${fmt(amt)} Shells`,'rare')}}
function checkSet(set){const need=catOf('set').filter(x=>x.set===set&&x.how!=='gift');const got=need.filter(x=>logged(x.id)).length;if(got<need.length||S.sets['done_'+set])return;S.sets['done_'+set]=1;const R=SETS[set];addShells(R.shells);toast(`${R.n} complete! ${R.reward}. +${fmt(R.shells)} Shells`,'rare');sfx('fanfare2');
  if(set==='coins'){logEntry('the_first_reel',0,'','gift');(S.sets.coins=S.sets.coins||{}).the_first_reel=1}}
function sellItem(i){const c=S.hold[i];if(!c)return 0;const v=sellValue(c);S.hold.splice(i,1);addShells(v);S.stats.sold++;markDirty();return v}
function sellAll(filter){let tot=0,n=0;for(let i=S.hold.length-1;i>=0;i--){const c=S.hold[i];const e=CATI[c.id];if(c.id==='oyster'||(e&&CHESTS.has(e.id)))continue;if(filter&&!filter(e))continue;tot+=sellItem(i);n++}if(n){sfx('coin');toast(`Sold ${n} for ${fmt(tot)} Shells.`);bumpQuest('sell',tot)}return tot}
/* ---------- crab pots ---------- */
function dropPot(){if(S.pots.length>=potCap()){toast(`All ${potCap()} pots are out. Haul one first.`);return}const b=player.boat;const z=zoneAtPx(b.x,b.y);if(!z){toast('Drop pots in open water.');return}
  const bait=S.baitSel==='crabbait'||S.baitSel==='pilchard'?S.baitSel:null;if(bait&&!useBait(bait))return;
  S.pots.push({x:Math.round(b.x+Math.cos(b.h+1.57)*14),y:Math.round(b.y+Math.sin(b.h+1.57)*14),zone:z,at:Date.now(),bait});markDirty();splash(b.x,b.y+6,6);sfx('splash');toast(`Pot down in the ${ZONES[z].short}. Come back after ${POTS.soakMin/60} town hours.`);bumpQuest('pot')}
function haulPot(p){const soak=(Date.now()-p.at)/1000;if(soak<POTS.soakMin*.5){toast(`Too soon. Give it ${Math.ceil((POTS.soakMin-soak)/60)} more town hours.`);return}
  startPotHaul(p,()=>{const got=CHAIN.live?null:rollPot(p.zone,envAt(),p.bait,soak);S.pots.splice(S.pots.indexOf(p),1);markDirty();if(!got||!got.length){toast('Empty. Something had the bait.');return}
    let i=0;const next=()=>{if(i>=got.length)return;const g=got[i++];onCatch({id:g.id,cm:g.cm,kg:fishKg(CATI[g.id],g.cm)},'pot').then(()=>setTimeout(next,1300))};next()})}
/* ---------- beachcombing ---------- */
function combKey(){const E=envAt();return E.tday*2+(E.hour>=12?1:0)}
function combSpots(){if(scene!==WORLD||player.boat)return[];const E=envAt();if(E.tide>.25)return[];const key=combKey();if(S.comb.key!==key){S.comb={key,dug:[]}}if(combSpots.k===key)return combSpots.list.filter(c=>!S.comb.dug.includes(c.i));
  const r=rng(key*7919+(Math.abs(hashStr(S.name||String(S.av)))%997));const out=[];const B=WORLD.combTiles.beach,Rk=WORLD.combTiles.rocks;for(let i=0;i<9&&B.length;i++){const[x,y]=B[Math.floor(r()*B.length)];out.push({i,x:x*16+8,y:y*16+8,where:'beach'})}for(let i=0;i<6&&Rk.length;i++){const[x,y]=Rk[Math.floor(r()*Rk.length)];out.push({i:100+i,x:x*16+8,y:y*16+8,where:'rocks'})}
  combSpots.k=key;combSpots.list=out;return out.filter(c=>!S.comb.dug.includes(c.i))}
function dugSpot(c){S.comb.dug.push(c.i);S.stats.dug++;markDirty();const E=envAt();const got=rollComb(c.where,E);if(!got||!CATI[got.id]&&got.id!=='oyster'){toast('Just sand.');return}
  if(got.id==='oyster'){if(holdFull()){toast('Your hold is full.');return}S.hold.push({id:'oyster',cm:0,v:'',t:Date.now()});toast('A pearl oyster! Open it from your hold.','lvl');markDirty();updHUD();return}
  onCatch({id:got.id,cm:0},c.where)}
function openOysterAt(i){const c=S.hold[i];if(!c||c.id!=='oyster')return;S.hold.splice(i,1);const p=openOyster(envAt());markDirty();if(!p){toast('No pearl this time. The gulls get a snack.');sfx('crumble');renderPanel();return}closePanel();onCatch({id:p.id,cm:0},'oyster')}
/* ---------- salvage ---------- */
const SALV_COOL=180*1000;// three town hours between grapples at one site
function salvageReady(s){const i=WORLD.salvage.indexOf(s);return Date.now()-(S.salv[i]||0)>SALV_COOL}
function salvageDone(s){const i=WORLD.salvage.indexOf(s);S.salv[i]=Date.now();S.stats.salvaged++;markDirty();const got=rollSalvage(s.zone,envAt());if(!got){toast('Nothing but weed.');return}onCatch({id:got.id,cm:0},'salvage')}
/* ---------- bait ---------- */
function baitCount(k){return k==='dough'?Infinity:(S.bait[k]||0)}
function useBait(k){if(k==='dough')return true;const B=BAIT[k];if(B.lure)return(S.bait[k]||0)>0;if((S.bait[k]||0)<=0){toast(`Out of ${B.n.toLowerCase()}. Switched to bread dough.`);S.baitSel='dough';return false}S.bait[k]--;markDirty();if(S.bait[k]<=0&&S.baitSel===k){S.baitSel='dough';toast(`That was your last ${B.n.toLowerCase()}. Back to bread dough.`)}return true}
function loseLure(){const k=S.baitSel;if(BAIT[k]&&BAIT[k].lure){S.bait[k]=Math.max(0,(S.bait[k]||0)-1);if(!S.bait[k]){S.baitSel='dough';toast(`Your ${BAIT[k].n.toLowerCase()} went with the line.`)}markDirty()}}
/* ---------- market prices ---------- */
function catchOfDay(day){const pool=CAT.filter(e=>e.cat==='fish'&&e.r<=2&&!e.release&&e.how==='fish');return pool[Math.floor(hsh(day,909)*pool.length)]}
function marketMul(e){const E=envAt();if(e.cat!=='fish'&&e.cat!=='legend')return 1;const cod=catchOfDay(E.day);if(cod&&cod.id===e.id)return 2;const h=hsh(E.day,CAT.indexOf(e),910);return h<.12?1.3:h>.9?.75:1}
