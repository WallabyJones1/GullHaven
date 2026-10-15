/* ================= free licences, co-ops and daily Shells activities =================
   Each player's progress stays in their save; the server shares the harbour's public records. */
function feeLog(kind,amt){const d=envAt().day;if(!S.feeLog||S.feeLog.day!==d)S.feeLog={day:d,c:{}};S.feeLog.c[kind]=(S.feeLog.c[kind]||0)+amt;markDirty();if(NET.db)pushMyDoc();
  // on a play-mode server, the fees feed the shared play Cup (exchange, machine and derby fees are counted by the server itself)
  if(NET.mode==='ws'&&!CHAIN.live&&(kind==='licence'||kind==='crew'||kind==='cosmetic'||kind.startsWith('coop_')))wsSend({t:'fee',kind,amt})}
function myFees(day){return S.feeLog&&S.feeLog.day===day?S.feeLog.c:{}}
const carryCache=new Map();
function carryFor(day){if(carryCache.has(day))return carryCache.get(day);let c=0;for(let d=day-8;d<day;d++){c=(c+CSIM.inflow(d,1440,coopFees()).cup)*(1-CFG.CUP.payoutFrac)}carryCache.set(day,c);return c}
function coopFees(){const f={};for(const C of COOPS)f[C.id]=coopFee(C.id);return f}
function coopFee(id){return 0}
// today's pools: where the money came from
function cupPools(day,min){const E=envAt();day=day==null?E.day:day;min=min==null?(day===E.day?E.dmin:1440):min;
  if(NET.mode==='ws'&&NET.shared.co&&NET.shared.co.pools&&day===E.day)return NET.shared.co.pools;
  const inf=CSIM.inflow(day,min,coopFees());const fl=Object.assign({},inf.flows);const F=CFG.CUPFEED;
  const real=Object.assign({},NET.shared.fees||{});const mine=myFees(day);for(const k in mine)real[k]=(real[k]||0)+mine[k];
  fl.licence+=(real.licence||0)*CFG.LICENCE.split.cup;let coopIn=0;for(const C of COOPS)coopIn+=(real['coop_'+C.id]||0);fl.coop+=coopIn*CFG.COOP.split.cup;fl.crew+=(real.crew||0)*CFG.CREW.split.cup;fl.exchange+=(real.exchange||0)*F.exchange;fl.machine+=(real.machine||0)*F.machine;fl.derby+=(real.derby||0)*F.derby;fl.cosmetic+=(real.cosmetic||0)*F.cosmetic;
  const carry=carryFor(day);let cup=carry;for(const k in fl){fl[k]=Math.round(fl[k]);cup+=fl[k]}
  return{cup:Math.round(cup),carry:Math.round(carry),flows:fl,bounty:Math.round(inf.bounty+(real.licence||0)*CFG.LICENCE.split.bounty+carryFor(day)*.15)}}
function realPts(day){const E=envAt();const sh=day===E.day?NET.shared.coopPts:NET.shared.coopPtsY;const out=Object.assign({},sh||{});
  if(S.coop&&S.licence){if(day===E.day&&S.pts.day===day)out[S.coop]=(out[S.coop]||0)+S.pts.got;else if(S.ptsY&&S.ptsY.day===day)out[S.coop]=(out[S.coop]||0)+S.ptsY.got}return out}
function cupStandings(day,min){const E=envAt();day=day==null?E.day:day;min=min==null?(day===E.day?E.dmin:1440):min;return CSIM.standings(day,min,realPts(day))}
// the morning after: work out (play mode) what yesterday's Cup paid you
function rollPts(){const E=envAt();if(S.pts.day!==-1&&S.pts.day<E.day){if(S.pts.day===E.day-1)S.ptsY={day:S.pts.day,got:S.pts.got,coop:S.coop};S.pts={day:E.day,raw:0,got:0};markDirty()}}
function settleCup(){rollPts();if(CHAIN.live)return;const E=envAt();const y=E.day-1;if(S.cupPaid>=y)return;S.cupPaid=y;markDirty();const P=S.ptsY;if(!P||P.day!==y||!P.coop||!(P.got>0))return;
  const rows=cupStandings(y,1440);const pool=cupPools(y,1440).cup;const pay=CSIM.payout(pool,rows);const me=pay.find(p=>p.id===P.coop),row=rows.find(r=>r.id===P.coop);if(!me||!row)return;
  if(P.got<CFG.CUP.minPts)return;const realTot=Math.max(P.got,row.real);const sp=CSIM.split(P.coop,S.vote?[{split:S.vote,act:P.got}]:[]);
  const share=Math.floor((me.members+me.treasury*sp.dividends/100)*P.got/Math.max(1,realTot));if(share<=0)return;addShells(share);S.stats.won+=share;markDirty();
  S.lastCup={day:y,place:row.place,coop:P.coop,share,pool};setTimeout(()=>{toast(`Yesterday's Harbour Cup: ${COOPI[P.coop].s} came ${ord(row.place+1)}. Your share: ${fmt(share)} Shells`,'rare');sfx('fanfare2')},2500)}
const ord=n=>n+(n===1?'st':n===2?'nd':n===3?'rd':'th');
/* licences and co-ops */
async function buyLicence(){if(S.licence){toast('You already hold a licence.');return}
  S.licence={no:1000+(Math.abs(hashStr(S.cid||S.name||'Fisher'))%9000),at:Date.now()};markDirty();sfx('lvl');
  toast('Your free fishing licence is ready. Join any co-op at the Harbourmaster.','lvl');bumpQuest('licence');renderPanel();updHUD()}
function canSwitchCoop(){const wk=envAt().wk;return!S.coop||S.coopSwitch.wk!==wk||S.coopSwitch.n<CFG.COOP.switchPerSeason}
async function joinCoop(id){if(!S.licence){toast('Get a licence from the Harbourmaster first.','warn');return}if(S.coop===id)return;if(!canSwitchCoop()){toast('One co-op switch per season (a real week).','warn');return}
  if(CHAIN.live){const r=await NET.req({t:'join',co:id});if(r.ok){applyAcct(r.acct);afterJoin(id)}else toast(r.err,'warn');return}
  const fee=coopFee(id);if(!payShells(fee))return;const wk=envAt().wk;if(S.coop){S.coopSwitch={wk,n:S.coopSwitch.wk===wk?S.coopSwitch.n+1:1}}S.coop=id;S.vote=null;S.coopAt=Date.now();feeLog('coop_'+id,fee);afterJoin(id)}
function afterJoin(id){const C=COOPI[id];sfx('fanfare1');burst(player.x,player.y-20,[C.col,C.lt,'#ffd24d'],18);toast(`Welcome to ${C.n}. ${C.captain}: "${C.motto}"`,'lvl');bumpQuest('coop');sendPresence(true);updHUD();renderPanel();if(NET.db)pushMyDoc(true)}
function castVote(split,fee){S.vote=split;if(fee!=null)S.voteFee=fee;markDirty();if(NET.mode==='ws')wsSend({t:'vote',co:S.coop,v:split,fee});toast('Vote cast. The captain counts votes at the end of the day.')}
// fleet upgrades bought with the co-op's fleet bucket: bigger holds and faster hulls for every member
const fleetCache={};
function myCoopFleetLvl(){if(!S.coop)return 0;if(NET.mode==='ws'&&NET.shared.co&&NET.shared.co.fleet)return CSIM.fleetLevel(NET.shared.co.fleet[S.coop]||0);const E=envAt();const k=S.coop+E.day;if(fleetCache[k]!=null)return fleetCache[k];
  let f=0;for(let d=E.day-14;d<E.day;d++){const inf=CSIM.inflow(d,1440,coopFees());const rows=CSIM.standings(d,1440,{});const pay=CSIM.payout(carryFor(d)+inf.cup,rows).find(p=>p.id===S.coop);const sp=CSIM.split(S.coop,[]);f+=((inf.treasury[S.coop]||0)+(pay?pay.treasury:0))*sp.fleet/100}
  return fleetCache[k]=CSIM.fleetLevel(f)}
function coopToday(id){const E=envAt();const inf=CSIM.inflow(E.day,E.dmin,coopFees());return{joins:inf.joins[id],treasuryIn:Math.round(inf.treasury[id]+(myFees(E.day)['coop_'+id]||0)*CFG.COOP.split.treasury),crew:CSIM.crew(id,E.day)}}
/* the daily Big Fish Derby */
async function enterDerby(){const E=envAt();if(S.derby.day===E.day&&S.derby.in){toast('You are already entered today.');return}if(!S.licence){toast('Licence holders only.','warn');return}
  if(NET.mode==='ws'){const r=await NET.req({t:'derby'});if(!r||!r.ok){toast(r&&r.err||'The derby book is closed.','warn');return}if(r.acct)applyAcct(r.acct);if(CHAIN.live){S.derby={day:E.day,in:true,best:0,id:derbySpecies(E.day).id};markDirty();toast('Entered! Your longest one counts.','lvl');renderPanel();return}}
  if(!payShells(CFG.DERBY.entry))return;if(NET.mode!=='ws')feeLog('derby',CFG.DERBY.entry);S.derby={day:E.day,in:true,best:0,id:derbySpecies(E.day).id};markDirty();sfx('buy');toast(`Entered the ${derbySpecies(E.day).n} derby. Only fish you land from now on count.`,'lvl');renderPanel()}
function derbyReport(cm){if(NET.mode==='ws')wsSend({t:'derbybest',cm})}
function settleDerby(){const E=envAt();const D=S.derby;if(CHAIN.live||!D.in||D.day>=E.day||D.settled)return;D.settled=true;markDirty();const field=CSIM.derbyField(D.day);const n=field.length+1;const pot=CFG.DERBY.reward;
  if(D.best>field[0]){addShells(pot);S.stats.won+=pot;setTimeout(()=>toast(`You won yesterday's derby with a ${D.best} cm ${CATI[D.id].n}! +${fmt(pot)} Shells`,'rare'),4000)}else if(D.best>0)setTimeout(()=>toast(`Derby result: your ${D.best} cm was beaten by a ${field[0]} cm fish.`),4000)}
