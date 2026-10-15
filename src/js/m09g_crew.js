/* ================= crew fishing trips =================
   Small Shells fees buy supplies. Crew return with fish to sell and co-op points.
   Every character has the same fishing ability; appearance never changes rewards. */
// the Crew Fund: shared on the server; in play mode it is the seed plus everyone's fees in, minus cheques out
function crewFund(){if(NET.mode==='ws'&&NET.shared.crewFund!=null)return NET.shared.crewFund;const sh=NET.shared.mpool||{},my=S.mpool||{};return CFG.CREW.fund.seed+(sh.cput||0)+(my.cput||0)-(sh.cpaid||0)-(my.cpaid||0)}
const crewRar=c=>crewIsNft(c)?(RARITY[+c.id.slice(4)]||0):-1;
const crewKindName=c=>crewIsNft(c)?RAR[crewRar(c)]+' Founding Fisher':'Deckhand';
const crewO=(c,ti)=>({nft:crewIsNft(c),rar:Math.max(0,crewRar(c)),lvl:c.lvl,trip:ti});
const HAND_NAMES=['Salty Pete','Big Lou','Nan Ferris','Jonno','Mags','Tiny Rees','Old Wilf','Dee'];
function syncCrew(){S.crew=S.crew||[];for(const id of S.owned){if(!S.crew.find(c=>c.id==='nft:'+id))S.crew.push({id:'nft:'+id,lvl:1,xp:0,trip:null})}S.crew=S.crew.filter(c=>!c.id.startsWith('nft:')||S.owned.includes(+c.id.slice(4)))}
const crewIsNft=c=>c.id.startsWith('nft:');
const crewAv=c=>crewIsNft(c)?+c.id.slice(4):9000+(+c.id.slice(5))*37;
const crewName=c=>crewIsNft(c)?nftName(+c.id.slice(4)):HAND_NAMES[(+c.id.slice(5))%HAND_NAMES.length];
function hireHand(){const n=S.hired||0;if(n>=CFG.CREW.maxHired){toast('Your crew bunkhouse is full.');return}const cost=CFG.CREW.hireShells[n];if(!payShells(cost))return;S.hired=n+1;S.crew.push({id:'hand:'+n,lvl:1,xp:0,trip:null});markDirty();toast(`${HAND_NAMES[n]} signs on. Send them out from the Crew panel.`,'lvl');renderPanel()}
function crewZones(){return ZONE_ORDER.filter(z=>z!=='lake'&&ZONES[z].need<=Math.max(1,boatTier()))}
async function sendTrip(c,zone,ti){const T=CFG.CREW.trips[ti];if(c.trip){toast('Already out.');return}if(!S.licence){toast('Crew fish under your licence. Get one at the Harbourmaster.','warn');return}
  if(CHAIN.live){const r=await NET.req({t:'crew',crew:c.id,zone,trip:ti,lvl:c.lvl});if(!r.ok){toast(r.err,'warn');return}applyAcct(r.acct);c.trip={zone,trip:ti,start:r.start,end:r.end,server:1}}
  else{if(!payShells(T.fee))return;feeLog('crew',T.fee);S.mpool=S.mpool||{put:0,paid:0};S.mpool.cput=(S.mpool.cput||0)+Math.round(T.fee*CFG.CREW.split.pool);const now=Date.now();c.trip={zone,trip:ti,start:now,end:now+T.min*60000,seed:Math.floor(Math.random()*1e9)}}
  S.stats.trips++;markDirty();sfx('horn');toast(`${crewName(c)} heads out to the ${ZONES[zone].short} (${T.n.toLowerCase()}).`);bumpQuest('crew');renderPanel();updHUD()}
async function collectTrip(c){const t=c.trip;if(!t||Date.now()<t.end){toast('Not back yet.');return}if(t.server&&!CHAIN.live){t.server=0;t.seed=Math.abs(hashStr(c.id+':'+t.start))}let haul;
  if(CHAIN.live){const r=await NET.req({t:'crewin',crew:c.id});if(!r.ok){toast(r.err,'warn');return}c.trip=null;applyAcct(r.acct);haul=(r.haul||[]).filter(h=>CATI[h.id]);addShells(r.shells||0);if(r.lvl){if(r.lvl>c.lvl)toast(`${crewName(c)} is now level ${r.lvl}.`,'lvl');c.lvl=r.lvl;c.xp=r.xp||0}else crewXp(c,haul.length);markDirty();showHaul(c,haul,r.shells||0,r.pts||0,r.reel||0,r.m);return}
  haul=crewHaul({zone:t.zone,trip:t.trip,start:t.start,nft:crewIsNft(c),rar:Math.max(0,crewRar(c)),lvl:c.lvl},rng(t.seed));let shells=0,raw=0;for(const h of haul){const e=CATI[h.id];const v=Math.round(e.price*(.7+.8*sizeFrac(e,h.cm||0))*marketMul(e));shells+=v;raw+=catchPoints(e,h.cm,'')*CFG.CREW.ptsShare}
  const pts=S.coop?addPoints(raw):0;if(pts&&S.coop)reportCatch({id:'crew'},0,pts);addShells(shells);
  const ch={amt:0,m:0};
  crewXp(c,haul.length);c.trip=null;markDirty();showHaul(c,haul,shells,pts,ch.amt,ch.m)}
function crewXp(c,n){c.xp+=n;while(c.xp>=c.lvl*25){c.xp-=c.lvl*25;c.lvl++;toast(`${crewName(c)} is now level ${c.lvl}.`,'lvl')}}
// live mode: the server's list of trips is the truth (after a reload, or on another phone)
function crewFromServer(trips){if(!trips)return;syncCrew();for(const c of S.crew){const t=trips[c.id];if(t)c.trip={zone:t.zone,trip:t.trip,start:t.start,end:t.end,server:1};else if(c.trip&&c.trip.server)c.trip=null}}
function showHaul(c,haul,shells,pts,reel,m){sfx(m>=3?'fanfare2':'coin');const by={};for(const h of haul)by[h.id]=(by[h.id]||0)+1;const top=Object.entries(by).sort((a,b)=>CATI[b[0]].r-CATI[a[0]].r||b[1]-a[1]).slice(0,4).map(([id,n])=>`${n} ${CATI[id].n}`).join(', ');
  toast(`${crewName(c)} is back: ${haul.length} fish (${top||'nothing much'}). +${fmt(shells)} Shells${pts?`, +${pts} Cup points`:''}.`,'rare');if(m>=3)burst(player.x,player.y-20,['#ffd24d','#fff6c0','#7fdcc0'],18);renderPanel();updHUD()}
function crewReady(){return(S.crew||[]).filter(c=>c.trip&&Date.now()>=c.trip.end).length}
