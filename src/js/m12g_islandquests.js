/* Small, personal island errands. Shared sea, individual progression. */
function islandQuest(I){const day=envAt().day,key=day+':'+I.id;let q=S.islandBounties[key];if(q)return q;
  const pool=CAT.filter(e=>e.cat==='fish'&&e.how==='fish'&&e.z===I.zone&&e.r<=1&&!e.release&&!e.cp.where&&!e.cp.moon&&!e.cp.season);
  const e=pool[Math.floor(hsh(day,hashStr(I.id),17)*pool.length)]||CATI.bream;
  q={id:e.id,n:2,pay:Math.round(e.price*4+120),done:false};S.islandBounties[key]=q;
  for(const k of Object.keys(S.islandBounties))if(+k.split(':')[0]<day-7)delete S.islandBounties[k];markDirty();return q}
function atIslandBoard(I){return scene===WORLD&&!player.boat&&Math.hypot(player.x-I.bounty.x,player.y-I.bounty.y)<72}
function panelIsland(body,H){tabs(null);const I=(WORLD.islands||[]).find(i=>i.id===panelTab||i.id===panelCtx);if(!I){head('Island bounties','Help a little town',uiIcon('map'));H('p','Sail to an island and read its bounty board.');return}
  head(I.n,'Island bounty board',uiIcon('map'));H('p',I.desc);const here=atIslandBoard(I);
  if(here&&!S.visitedIslands.includes(I.id)){S.visitedIslands.push(I.id);addShells(100);bumpQuest('island');toast('Discovered '+I.n+' · +100 Shells','lvl');markDirty()}
  const q=islandQuest(I),e=CATI[q.id],have=S.hold.filter(c=>c.id===q.id).length;
  const row=itemRow(catArt(e.id),I.n+' needs '+q.n+' × '+e.n,q.done?'Delivered. Thank you!':ZONES[e.z].n+' · in your hold '+have+'/'+q.n+' · reward '+fmt(q.pay)+' Shells');body.append(row);
  H('p','One personal bounty per island each real day. Deliver your fish here at the board. Your progress is your own.');
  if(!q.done){const b=btn('Deliver · '+fmt(q.pay)+' Shells',()=>{if(q.done||!atIslandBoard(I))return;if(S.hold.filter(c=>c.id===q.id).length<q.n){toast('Bring '+q.n+' '+e.n+' in your hold.');return}let left=q.n;S.hold=S.hold.filter(c=>{if(c.id===q.id&&left){left--;return false}return true});q.done=true;S.story=S.story||{};S.story.bounties=(S.story.bounties||0)+1;addShells(q.pay);bumpQuest('bounty');markDirty();sfx('lvl');toast('Bounty complete · +'+fmt(q.pay)+' Shells','lvl');renderPanel()},'gold');b.disabled=!here||have<q.n;body.append(b)}
  if(!here)H('p','Tie up and walk to this island’s board to discover the settlement and deliver its bounty.');
  const r=el('div','row');r.style.marginTop='12px';r.append(btn('Sea chart',()=>openPanel('map'),'alt'));if(here)r.append(btn(I.shopLabel,()=>openPanel(I.shopKind==='home'?'home':'shop',I.shopKind==='home'?null:I.shopKind),'sea'));body.append(r)}
