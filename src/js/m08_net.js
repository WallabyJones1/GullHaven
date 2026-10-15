/* ================= networking: Claude room/db, the self-hosted server, or solo =================
   room/db (published artifact): presence and chat through the room; each fisher's public record (name, co-op,
   today's Cup points, fees paid) is one db doc they own, so co-op totals are sums nobody can race. First-in-town
   credits, aquarium plaques and minted Founding Fishers use claim-once docs with a short lease.
   ws (server.js): the server keeps all of that, and in LIVE mode owns every $REEL balance.
   solo: everything runs on this device. */
const NET={mode:'solo',peers:new Map(),uid:null,room:null,db:null,user:null,ws:null,wsSeq:0,wsWait:new Map(),lastP:'',lastPT:0,
  shared:{firsts:{},aquarium:{},minted:new Set(),mpool:{put:0,paid:0},fishers:[],coopPts:{},coopPtsY:{},fees:{},feesY:{},co:null,trophies:{},clean:0,machine:null},myDoc:null};
function withTimeout(p,ms){return Promise.race([p,new Promise(r=>setTimeout(()=>r(null),ms))])}
async function initNet(){const C=window.claude;
  if(C&&typeof C.use==='function'){try{const[room,db,user]=await Promise.all([withTimeout(C.use('room'),10000),withTimeout(C.use('db'),10000),withTimeout(C.use('user'),10000)]);
      NET.user=user;if(user){try{NET.uid=await user.id()}catch(e){}}if(db&&NET.uid){NET.db=db;dbStart()}if(room){NET.room=room;NET.mode='room';roomStart()}else if(NET.db)NET.mode='db'}catch(e){console.warn(e)}updOnline();return}
  if(/^https?:/.test(location.protocol)){try{await wsStart();return}catch(e){}}
  updOnline()}
/* ---------- Claude artifact mode ---------- */
function dbStart(){const db=NET.db;const today=()=>envAt().day;
  db.doc('data/users/'+NET.uid+'/save').get().then(snap=>{if(snap.exists){const d=snap.data();if(d&&d.s){const r=migrate(JSON.parse(d.s));if(r&&(r.ts||0)>(S.ts||0)){S=r;refreshAll()}}}}).catch(e=>console.warn('save load',e));
  db.collection('fishers').onSnapshot(q=>{const list=[];const pts={},ptsY={},fees={},feesY={};const d=today();
    for(const doc of q.docs){const v=doc.data();if(!v||doc.id===NET.uid)continue;list.push(Object.assign({uid:doc.id},v));if(v.coop&&COOPI[v.coop]){if(v.day===d)pts[v.coop]=(pts[v.coop]||0)+Math.min(2500,+v.got||0);if(v.day===d-1)ptsY[v.coop]=(ptsY[v.coop]||0)+Math.min(2500,+v.got||0);else if(v.yday===d-1)ptsY[v.coop]=(ptsY[v.coop]||0)+Math.min(2500,+v.ygot||0)}
      if(v.feeDay===d)for(const[k,a]of Object.entries(v.fees||{}))fees[k]=(fees[k]||0)+Math.min(1e6,+a||0)}
    Object.assign(NET.shared,{fishers:list,coopPts:pts,coopPtsY:ptsY,fees});sharedChanged()},e=>console.warn('fishers',e));
  db.collection('firsts').onSnapshot(q=>{const f={};for(const doc of q.docs){const v=doc.data();if(v&&v.n)f[doc.id]=String(v.n).slice(0,16)}NET.shared.firsts=f;sharedChanged()},e=>console.warn('firsts',e));
  db.collection('aquarium').onSnapshot(q=>{const f={};for(const doc of q.docs){const v=doc.data();if(v&&v.n)f[doc.id]={n:String(v.n).slice(0,16),at:+v.at||0}}NET.shared.aquarium=f;sharedChanged()},e=>console.warn('aquarium',e));
  db.collection('mints').onSnapshot(q=>{const m=new Set();for(const doc of q.docs){const v=doc.data();if(v&&v.id)m.add(+v.id)}NET.shared.minted=m;syncMachine();sharedChanged()},e=>console.warn('mints',e));
  db.collection('machinep').onSnapshot(q=>{let put=0,paid=0,cput=0,cpaid=0;for(const doc of q.docs){if(doc.id===NET.uid)continue;const v=doc.data()||{};put+=Math.min(1e9,+v.put||0);paid+=Math.min(1e9,+v.paid||0);cput+=Math.min(1e9,+v.cput||0);cpaid+=Math.min(1e9,+v.cpaid||0)}NET.shared.mpool={put,paid,cput,cpaid};syncMachine();sharedChanged()},e=>console.warn('machinep',e))}
let myDocBusy=false,myDocLast='';
async function pushMyDoc(force){if(!NET.db||!NET.uid||myDocBusy)return;const E=envAt();const rec={name:S.name||'',coop:S.coop||null,day:S.pts.day,got:S.pts.got,yday:S.ptsY?S.ptsY.day:-1,ygot:S.ptsY?S.ptsY.got:0,logN:logCount(),feeDay:S.feeLog&&S.feeLog.day,fees:S.feeLog?S.feeLog.c:{},av:ACTIVE(),ht:publicHomeKey(),home:homeProfile(S.home),trophies:topTrophies(),ts:Date.now()};const k=JSON.stringify(rec).replace(/"ts":\d+/,'');if(!force&&k===myDocLast)return;myDocLast=k;myDocBusy=true;
  try{await NET.db.doc('fishers/'+NET.uid).set(rec)}catch(e){}myDocBusy=false;
  if(S.mpool){const k2=JSON.stringify(S.mpool);if(k2!==pushMyDoc.mp){pushMyDoc.mp=k2;try{await NET.db.doc('machinep/'+NET.uid).set({put:S.mpool.put||0,paid:S.mpool.paid||0,cput:S.mpool.cput||0,cpaid:S.mpool.cpaid||0,ts:Date.now()})}catch(e){}}}}
async function claimOnce(path,body){if(NET.mode==='ws'){return true}if(!NET.db||!NET.uid)return true;try{const ref=NET.db.doc(path);const l=await ref.acquire({holder:NET.uid,ttlMs:4000});if(!l.acquired)return false;const snap=await ref.get();if(snap.exists&&snap.data()&&snap.data().n)return false;await ref.set(body);return true}catch(e){console.warn('claim',path,e);return false}}
async function remoteSave(){if(!NET.db||!NET.uid||remoteSave.busy)return;remoteSave.busy=true;try{await NET.db.doc('data/users/'+NET.uid+'/save').set({s:JSON.stringify(S),ts:S.ts})}catch(e){}remoteSave.busy=false}
function roomStart(){const room=NET.room;
  room.onPeers(ch=>{for(const p of ch.peers){if(p.sameTab||p.kind!=='viewer')continue;applyPeer(p.peer,p.presence)}for(const p of ch.left)NET.peers.delete(p.peer);updOnline()},e=>{NET.mode=NET.db?'db':'solo';updOnline()});
  room.on('chat',m=>{if(m.sameTab)return;const d=m.data||{};const txt=String(d.t||'').slice(0,90);if(!txt)return;const pe=NET.peers.get(m.peer);if(pe)pe.bubble={text:txt,t:5};chatLine(cleanName(d.n||(pe&&pe.n)),txt)});
  room.on('news',m=>{if(m.sameTab)return;const d=m.data||{};newsIn(cleanName(d.n),String(d.msg||'').slice(0,140),d.type)})}
const cleanName=n=>String(n||'Someone').replace(/[^\w@.\- ]/g,'').slice(0,16)||'Someone';
/* ---------- the self-hosted server ---------- */
function wsStart(){return new Promise((resolve,reject)=>{let ok=false;const url=(location.protocol==='https:'?'wss://':'ws://')+location.host+'/ws';let ws;try{ws=new WebSocket(url)}catch(e){reject(e);return}
  const to=setTimeout(()=>{if(!ok){try{ws.close()}catch(e){}reject(new Error('timeout'))}},4000);
  ws.onopen=()=>{ok=true;clearTimeout(to);NET.ws=ws;NET.mode='ws';let cid;try{cid=localStorage.getItem('gullhaven.cid');if(!cid){cid=Math.random().toString(36).slice(2)+Date.now().toString(36);localStorage.setItem('gullhaven.cid',cid)}}catch(e){cid='c'+Math.random()}let session=null;try{session=localStorage.getItem('gullhaven.session')}catch(e){}
    ws.send(JSON.stringify({t:'hello',cid,session,n:myName()}));updOnline();resolve()};
  ws.onmessage=ev=>{let m;try{m=JSON.parse(ev.data)}catch(e){return}
    if(m.t==='res'){const r=NET.wsWait.get(m.q);if(r){NET.wsWait.delete(m.q);r(m)}return}
    if(m.t==='welcome'){CHAIN.live=false;applyServerState(m.state);if(m.acct)applyAcct(m.acct);updHUD();return}
    if(m.t==='state'){applyServerState(m.state);return}
    if(m.t==='acct'){applyAcct(m.acct);return}
    if(m.t==='peers'){const seen=new Set();for(const[k,p]of Object.entries(m.peers||{})){if(k===m.you)continue;seen.add(k);applyPeer(k,p)}for(const k of[...NET.peers.keys()])if(!seen.has(k))NET.peers.delete(k);updOnline();return}
    if(m.t==='chat'){const pe=NET.peers.get(m.id);if(pe)pe.bubble={text:String(m.text).slice(0,90),t:5};chatLine(cleanName(m.n),String(m.text).slice(0,90));return}
    if(m.t==='news'){newsIn(cleanName(m.n),String(m.msg||'').slice(0,140),m.type);return}};
  ws.onclose=()=>{if(ok){NET.mode='solo';NET.ws=null;NET.peers.clear();updOnline();setTimeout(()=>wsStart().catch(()=>{}),3000)}else{clearTimeout(to);reject(new Error('closed'))}};ws.onerror=()=>{}})}
NET.req=function(o){return new Promise(res=>{if(!NET.ws||NET.ws.readyState!==1){res({err:'Not connected to the harbour server.'});return}const q=++NET.wsSeq;NET.wsWait.set(q,res);NET.ws.send(JSON.stringify(Object.assign({q},o)));setTimeout(()=>{if(NET.wsWait.has(q)){NET.wsWait.delete(q);res({err:'The server took too long to answer.'})}},20000)})};
function wsSend(o){if(NET.ws&&NET.ws.readyState===1)NET.ws.send(JSON.stringify(o))}
function applyServerState(st){if(!st)return;const sh=NET.shared;sh.firsts=st.firsts||{};sh.aquarium=st.aquarium||{};sh.minted=new Set(st.minted||[]);sh.machine=st.machine||null;sh.coopPts=st.coopPts||{};sh.coopPtsY=st.coopPtsY||{};sh.co=st.co||null;sh.crewFund=st.crewFund!=null?+st.crewFund:null;sh.trophies=st.trophies||{};sh.clean=st.clean||0;sh.derby=st.derby||null;syncMachine();sharedChanged()}
/* ---------- presence, chat, news ---------- */
function applyPeer(key,pr){if(!pr||typeof pr.x!=='number')return;let pe=NET.peers.get(key);if(!pe){pe={x:pr.x,y:pr.y,dir:'down',f:0,ft:0,moving:false};NET.peers.set(key,pe)}
  pe.tx=pr.x;pe.ty=pr.y;pe.dir=['down','up','left','right'].includes(pr.d)?pr.d:'down';pe.moving=!!pr.m;pe.id=registerLook(pr.look)||Number(pr.id)||1000;pe.n=cleanName(pr.n);pe.sc=String(pr.sc||'world').slice(0,48);pe.co=COOPI[pr.co]?pr.co:null;pe.ht=cleanHomeKey(pr.ht);pe.home=homeProfile(pr.home);
  pe.b=pr.b&&typeof pr.b==='object'&&BOATI[pr.b.k]?{k:pr.b.k,h:(pr.b.h|0)&15,p:/^#[0-9a-f]{6}$/i.test(pr.b.p)?pr.b.p:null,de:hasRpg(BOAT_DECOR,pr.b.de)?pr.b.de:'none',n:String(pr.b.n||'').replace(/[^\w '\-.]/g,'').trim().slice(0,16)}:null;if(pr.e&&pr.et!==pe.et){pe.et=pr.et;pe.emote={k:pr.e,t:2.5}}pe.fish=!!pr.f;
  if(scene&&scene.homeGuest&&scene.homeOwner===pe.ht&&scene.homeDesign!==JSON.stringify(pe.home)){const exit=scene.exitFn;let x=player.x,y=player.y;const next=makeHomeInterior(pe.home,pe.ht,pe.n,false);setExit(next,exit);if(blocked(next,x,y)){x=next.spots.spawn.x;y=next.spots.spawn.y}setScene(next,x,y,player.dir)}}
function sendPresence(force){const p=player;if(!scene)return;const b=p.boat?{k:p.boat.k,h:boatHeading(p.boat.h),p:S.paint[p.boat.k]||null,de:boatDetail(p.boat.k),n:S.boatName||''}:null;
  const o={x:Math.round(p.boat?p.boat.x:p.x),y:Math.round(p.boat?p.boat.y:p.y),d:p.dir,m:p.moving?1:0,id:ACTIVE(),look:publicLook(),ht:publicHomeKey(),home:homeProfile(S.home),n:myName(),sc:scene.name,co:S.coop||null,b,e:p.emoteK||null,et:p.emoteT||0,f:MG&&MG.type==='fish'?1:0};
  const k=JSON.stringify(o);const now=performance.now();if(!force&&(k===NET.lastP||now-NET.lastPT<100))return;NET.lastP=k;NET.lastPT=now;
  if(NET.mode==='room'&&NET.room)NET.room.presence(o).catch(()=>{});if(NET.mode==='ws')wsSend({t:'p',p:o})}
function sendChat(txt){if(NET.mode==='room'&&NET.room)return NET.room.emit('chat',{t:txt,n:myName()}).then(()=>true,e=>{toast(e&&e.code==='not_permitted'?'Chat needs Contributor access to this page.':'Chat could not send.');return false});if(NET.mode==='ws'){wsSend({t:'chat',text:txt});return Promise.resolve(true)}return Promise.resolve(true)}
function announce(msg,type){if(NET.mode==='room'&&NET.room)NET.room.emit('news',{n:myName(),msg,type}).catch(()=>{});if(NET.mode==='ws')wsSend({t:'news',msg,type})}
function newsIn(n,msg,type){if(type==='legend'){toast(`${n} ${msg}`,'rare');sfx('fanfare1')}else toast(`${n} ${msg}`)}
function updOnline(){const el=$('online');const n=NET.peers.size+1;if(NET.mode==='room'||NET.mode==='ws'){el.classList.add('live');$('onlineTxt').textContent=n+' online'+(CHAIN.live?' · LIVE':'')}else{el.classList.remove('live');$('onlineTxt').textContent=NET.mode==='db'?'Synced':'Solo'}}
/* ---------- shared registries ---------- */
async function creditFirst(id){if(NET.shared.firsts[id])return false;if(NET.mode==='ws'){if(!CHAIN.live)wsSend({t:'first',id});NET.shared.firsts[id]=myName();return true}
  if(NET.db){const ok=await claimOnce('firsts/'+id,{n:myName(),at:Date.now()});if(ok)NET.shared.firsts[id]=myName();return ok}NET.shared.firsts[id]=myName();(S.firstsLocal=S.firstsLocal||{})[id]=1;return true}
async function donate(id){if(NET.shared.aquarium[id]){toast('Someone already donated one. The tank has a plaque with their name.');return false}
  if(NET.mode==='ws'){wsSend({t:'donate',id});NET.shared.aquarium[id]={n:myName(),at:Date.now()};return true}
  if(NET.db){const ok=await claimOnce('aquarium/'+id,{n:myName(),at:Date.now()});if(!ok){toast('Someone beat you to it by a moment.');return false}NET.shared.aquarium[id]={n:myName(),at:Date.now()};return true}
  NET.shared.aquarium[id]={n:myName(),at:Date.now()};(S.aqLocal=S.aqLocal||{})[id]=Date.now();return true}
function reportCatch(e,cm,pts){if(NET.mode==='ws'&&!CHAIN.live)wsSend({t:'catch',id:e.id,cm,pts,co:S.coop});if(NET.db)pushMyDoc()}
function topTrophies(){const out=[];for(const e of CAT){if(e.cat!=='fish'&&e.cat!=='legend')continue;const L=S.log[e.id];if(L&&L.best&&e.r>=2&&isTrophy(e,L.best))out.push([e.id,L.best])}return out.slice(-12)}
let sharedT=0;function sharedChanged(){if(performance.now()-sharedT<400){clearTimeout(sharedChanged.t);sharedChanged.t=setTimeout(sharedChanged,450);return}sharedT=performance.now();if(!$('panel').hidden)renderPanel();if(gachaOpen)updMachineUI()}
