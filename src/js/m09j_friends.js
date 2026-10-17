/* ================= playing with friends: ride in a friend's boat, and keep your progress on the server under your name =================
   Saves are kept by fisher name only (no password), as requested: typing your name on any device loads your progress. */
/* ---------- your save on the harbour server ---------- */
const CLOUD={t:0,busy:false};
function cloudOn(){return NET.mode==='ws'&&!!S.name}
async function cloudLogin(fresh){if(!cloudOn()||CLOUD.busy)return;CLOUD.busy=true;try{const r=await NET.req({t:'login',name:S.name});if(r.err)return;
    if(r.s&&(fresh||(r.ts||0)>(S.ts||0)+5000)){let j=null;try{j=migrate(JSON.parse(r.s))}catch(e){}if(j){applyCloudSave(j,fresh);return}}cloudSave(true)}finally{CLOUD.busy=false}}
function applyCloudSave(j,fresh){const name=S.name;S=j;S.name=S.name||name;storyInit();saveLocal();syncCrew();if(WORLD){applyGate();applyLocks();miniBase=null;mapBase=null;const sp=WORLD.spots.spawn;player.boat=null;player.ride=null;DIVE=null;setScene(WORLD,sp.x,sp.y,'up')}refreshAll();sendPresence(true);
  toast(fresh?`Welcome back, ${S.name}! Your progress was loaded from the harbour server.`:'Loaded your newer progress from another device.','lvl')}
function cloudSave(now){if(!cloudOn())return;const t=performance.now();if(!now&&t-CLOUD.t<15000)return;CLOUD.t=t;S.ts=Date.now();const s=JSON.stringify(S);if(s.length<380000)wsSend({t:'usave',name:S.name,s})}
// renaming: refuse a name another fisher already uses on this server
async function claimName(n){if(NET.mode!=='ws')return true;const r=await NET.req({t:'login',name:n,probe:1});if(r.err)return true;if(r.s&&n.toLowerCase()!==String(S.name||'').toLowerCase()){toast('That name belongs to another fisher on this server.','warn');return false}return true}
/* ---------- riding in a friend's boat ---------- */
const RIDERS=new Set();
function rideHost(){const r=player.ride;return r?NET.peers.get(r):null}
function friendBoatNear(){if(NET.mode!=='ws'||player.boat||player.ride||scene!==WORLD)return null;let best=null,bd=40;for(const[k,pe]of NET.peers){if(!pe.b||pe.sc!=='world'||pe.r)continue;const d=Math.hypot(pe.x-player.x,pe.y-player.y);if(d<bd){bd=d;best=[k,pe]}}return best}
function hopAboard(k,pe){if(MG)return;player.ride=k;player.path=null;player.goal=null;sfx('thud');splash(pe.x,pe.y+4,5);toast(`You hopped aboard ${pe.b.n?'"'+pe.b.n+'"':pe.n+"'s "+BOATI[pe.b.k].n.toLowerCase()}. Fish from the deck, or tap Hop off.`,'lvl');sendPresence(true);setLocation()}
function hopOff(reason){const host=rideHost();player.ride=null;let spot=null;if(host){for(let a=0;a<16&&!spot;a++){const an=a/16*6.283;for(const r of[16,24,32]){const x=host.x+Math.cos(an)*r,y=host.y+Math.sin(an)*r;const tx=Math.floor(x/16),ty=Math.floor(y/16);if(tx<0||ty<0||tx>=WORLD.w||ty>=WORLD.h)continue;const i=ty*WORLD.w+tx;if(WORLD.sol[i]||WORLD.g[i]==='o')continue;spot={x:tx*16+8,y:ty*16+10};break}}}
  if(!spot){spot=WORLD.spots.spawn;toast(reason||'Your skipper dropped you back at the quay.')}else toast(reason||'You hopped ashore.');closeMG();player.x=spot.x;player.y=spot.y;player.dir='down';sfx('thud');sendPresence(true);setLocation()}
function rideTick(dt){if(!player.ride)return;const h=rideHost();if(!h||!h.b||h.sc!=='world'||scene!==WORLD){hopOff(h?'Your skipper tied up. You stepped ashore.':'Your skipper left. A harbour taxi ran you back to the quay.');return}player.x=h.x;player.y=h.y;player.moving=false}
function rideAct(){if(!player.ride)return null;const h=rideHost();if(!h)return null;const z=zoneAtPx(h.x,h.y);if(!z)return null;const tier=BOATI[h.b.k].tier;
  if(ZONES[z].need>tier)return{label:'Too rough',icon:'storm',act:()=>toast(`Too rough to fish ${ZONES[z].n} from this boat.`)};
  const d={left:[-1,0],right:[1,0],up:[0,-1],down:[0,1]}[player.dir]||[0,1];return{label:'Cast',icon:'rod_'+S.gear.rod,act:()=>startFishing({x:h.x+d[0]*40,y:h.y+d[1]*40,zone:z})}}
// others riding with me, and me riding with others, drawn sitting in the boat
function drawRiders(list,t,Sc){if(Sc!==WORLD)return;const seat=(k,i)=>{const sp=BOAT_SPEC[k]||{};return sp.seats&&sp.seats[1+i]!=null?sp.seats[1+i]:6+i*5};
  const draw=(id,bx,by,h,k,i,name)=>{const ang=(typeof h==='number'&&h<16&&Number.isInteger(h)?h/16:h/(Math.PI*2))*Math.PI*2;const s=seat(k,i);const x=bx+Math.cos(ang)*s*.9,y=by+Math.sin(ang)*s*.9;list.push({sy:by+5,draw:()=>{drawChar(ctx,id,x-camX,y-camY+8,'down',0,0,18);if(name)nameTag(ctx,name,x-camX,y-camY+14,'#bfe8f4')}})};
  const seen=new Set();let i=0;
  for(const[k,pe]of NET.peers){if(!pe.r)continue;seen.add(k);if(pe.r===NET.you&&player.boat){draw(pe.id,player.boat.x,player.boat.y,player.boat.h,player.boat.k,i++,pe.n);if(!RIDERS.has(k)){RIDERS.add(k);toast(pe.n+' hopped aboard your boat!','lvl')}}
    else{const host=NET.peers.get(pe.r);if(host&&host.b)draw(pe.id,host.x,host.y,host.b.h,host.b.k,0,pe.n)}}
  for(const k of[...RIDERS])if(!seen.has(k)){RIDERS.delete(k);const pe=NET.peers.get(k);if(pe)toast(pe.n+' hopped off.')}
  if(player.ride){const h=rideHost();if(h&&h.b){const k=h.b.k;const ang=h.b.h/16*Math.PI*2;const s=seat(k,1);const x=h.x+Math.cos(ang)*s*.9,y=h.y+Math.sin(ang)*s*.9;list.push({sy:h.y+6,draw:()=>{drawChar(ctx,ACTIVE(),x-camX,y-camY+8,player.dir,MG&&MG.type==='fish'?(Math.floor(t*6)%2?1:2):0,0,18);if(player.bubble)bubble(ctx,player.bubble.text,x-camX,y-camY-14)}})}}}
