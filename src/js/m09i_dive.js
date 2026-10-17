/* ================= diving: drop over the side at a dive site and explore the sea floor on one breath of tank air =================
   Buy a dive kit at a boatyard. Every wreck and reef site has its own little underwater scene: chests to open, coral and
   shells to collect, fish all around and jellyfish to dodge. Chests refill after a while. */
const DIVECFG={kit:2000,tank:3500,air:[45,75],refillMs:30*60*1000};
const DIVE_THEME={
  reef:{n:'Coral garden',sand:['#efe0b0','#e2cf98','#d4bc84'],tint:'#3fb0c8',k:.18,rocks:5,kelp:4,coral:16,chests:3,jelly:1,wreck:0},
  shallows:{n:'Sandy flats',sand:['#f2e6c0','#e8d8a8','#dcc898'],tint:'#58c8d8',k:.14,rocks:4,kelp:3,coral:6,chests:2,jelly:1,wreck:0},
  kelp:{n:'Kelp forest',sand:['#c8bc98','#b8aa84','#a89870'],tint:'#2f7a78',k:.3,rocks:7,kelp:22,coral:5,chests:3,jelly:2,wreck:0},
  wreck:{n:'Shipwreck',sand:['#a89c80','#988c70','#887c62'],tint:'#24587a',k:.38,rocks:6,kelp:6,coral:6,chests:4,jelly:2,wreck:1},
  blue:{n:'Drop-off',sand:['#8a8a96','#7a7a88','#6a6a7a'],tint:'#1c3f7a',k:.45,rocks:8,kelp:2,coral:4,chests:3,jelly:4,wreck:1},
  deep:{n:'The trench',sand:['#5a5a6a','#4e4e5e','#424252'],tint:'#0c1838',k:.55,rocks:9,kelp:0,coral:5,chests:4,jelly:5,wreck:1}};
let DIVE=null;
function diveSites(){const out=[];for(let i=0;i<WORLD.salvage.length;i++){const s=WORLD.salvage[i];if(s.dead||!DIVE_THEME[s.zone])continue;out.push({key:'s'+i,x:s.x,y:s.y,zone:s.zone})}
  for(const d of WORLD.diveSites||[])out.push(d);return out}
function diveSiteNear(){const b=player.boat;if(!b)return null;for(const d of diveSites())if(Math.hypot(d.x-b.x,d.y-b.y)<34)return d;return null}
function diveAir(){return DIVECFG.air[S.diveTank?1:0]}
function startDive(site){if(!S.diveKit){toast('You need a dive kit. The Boatyard and Lantern Key sell them.','warn');return}if(MG)return;const b=player.boat;if(Math.abs(b.v)>6){toast('Stop the boat before you dive.');return}
  if(envAt().sky==='storm'){toast('Too rough to dive in a storm. Wait it out.','warn');return}
  const sc=genDive(site);DIVE={site,air:diveAir(),max:diveAir(),boat:b,sc,warned:0,bub:[],t:0};player.boat=null;b.v=0;
  const f=$('fade');f.hidden=false;f.textContent='Splash!';sfx('splash');setTimeout(()=>{f.hidden=true;setScene(sc,sc.spots.spawn.x,sc.spots.spawn.y,'down');S.stats.dives=(S.stats.dives||0)+1;markDirty();toast(`${DIVE_THEME[site.zone].n}. ${DIVE.max} seconds of air. Open the chests and get back to the rope!`)},500)}
function surface(out){if(!DIVE)return;const b=DIVE.boat;DIVE=null;player.boat=b;setScene(WORLD,b.x,b.y,'down');splash(b.x,b.y+6,8);sfx('splash');updHullChip();if(out)toast('Out of air! You kicked for the surface just in time.','warn');else toast('Back aboard.')}
function diveRec(key){S.dives=S.dives||{};let r=S.dives[key];if(!r||Date.now()-r.t>DIVECFG.refillMs){r=S.dives[key]={t:Date.now(),open:[],took:[]}}return r}
/* ---------- the sea floor ---------- */
function genDive(site){const T=DIVE_THEME[site.zone];const W=22,H=32;const S2=newScene('dive:'+site.key,W,H);S2.kind='dive';S2.in='dive';S2.dive=site;S2.theme=T;const r=rng(hashStr(site.key)>>>0);const rec=diveRec(site.key);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;S2.g[i]='sb';if(x===0||x===W-1||y===0||y===H-1)S2.sol[i]=1}
  // the floor: rippled sand with darker patches, fading into the depth tint further from the boat
  const B=mkBuf(W*16,H*16);for(let py=0;py<H*16;py++)for(let px=0;px<W*16;px++){const rip=Math.sin(px*.38+Math.sin(py*.27)*1.6+py*.55);const n=NZ.at(px*.9+40,py*.9);let col=n>.66?T.sand[2]:rip>.7?T.sand[0]:T.sand[1];
    if(NZ.at(px*2.2+7,py*2.2)>.8)col=mix(col,'#5a6a5a',.3);if(hash2(px,py,91)<.006)col='#ffffff';if(px<8||px>=W*16-8||py>=H*16-8)col=mix(col,'#1a2a3a',.5);B.set(px,py,mix(col,T.tint,T.k+py/(H*16)*.25))}B.flush();S2.ground=B.c;S2.gx=B.x;
  const free=(x,y)=>x>1&&y>3&&x<W-2&&y<H-2&&!S2.sol[y*W+x]&&!S2.res[y*W+x];const spot=()=>{for(let k=0;k<80;k++){const x=1+Math.floor(r()*(W-2)),y=4+Math.floor(r()*(H-6));if(free(x,y))return[x,y]}return null};
  const put=(im,x,y,o={})=>addProp(S2,im,x*16+8-im.width/2,(y+1)*16-im.height,Object.assign({sy:(y+1)*16-1},o));
  // the rope down from your boat
  S2.spots.spawn={x:Math.floor(W/2)*16+8,y:3*16};S2.spots.rope={x:Math.floor(W/2)*16+8,y:2*16+8};S2.res[2*W+Math.floor(W/2)]=1;S2.res[3*W+Math.floor(W/2)]=1;
  act(S2,S2.spots.rope.x,S2.spots.rope.y+6,20,'Surface','dive',()=>surface(false));
  if(T.wreck){const im=artWreckHull();const wx=Math.floor(W/2)-4,wy=Math.floor(H*.55);addProp(S2,im,wx*16-12,wy*16-10,{sy:(wy+3)*16});solidRect(S2,wx-0,wy+1,wx+6,wy+2);reserve(S2,wx-1,wy-1,wx+7,wy+3);
    S2.wreckSpot={x:(wx+3)*16,y:(wy+4)*16}}
  for(let i=0;i<T.rocks;i++){const p=spot();if(!p)break;put(artSeaRock(i%2),p[0],p[1]);S2.sol[p[1]*W+p[0]]=1;S2.res[p[1]*W+p[0]]=1}
  for(let i=0;i<T.kelp;i++){const p=spot();if(!p)break;put(artKelp(i%2),p[0],p[1],{sway:1});S2.res[p[1]*W+p[0]]=1}
  // coral: decoration, and a few pieces worth taking home
  const corals=CAT.filter(e=>e.cat==='coral'&&(e.z===site.zone||(site.zone==='shallows'&&e.z==='reef')||(site.zone==='blue'&&e.z==='deep'))&&!e.cp.flags.includes('spawn')&&!e.cp.time);
  const pool=corals.length?corals:CAT.filter(e=>e.cat==='coral'&&e.r<=1);S2.corals=[];
  for(let i=0;i<T.coral;i++){const p=spot();if(!p)break;const e=pool[Math.floor(r()*pool.length)];const im=catArt(e.id);if(!im)continue;const k=Math.min(1,22/Math.max(im.width,im.height));const[c,x]=mk(Math.round(im.width*k),Math.round(im.height*k));x.imageSmoothingEnabled=false;x.drawImage(im,0,0,c.width,c.height);
    put(c,p[0],p[1]);S2.res[p[1]*W+p[0]]=1;if(i<3)S2.corals.push({i,id:e.id,x:p[0]*16+8,y:p[1]*16+12})}
  for(const c of S2.corals)act(S2,c.x,c.y,16,'Collect '+CATI[c.id].n,'hand',()=>{const rec2=diveRec(site.key);if(rec2.took.includes(c.i)){toast('You already took a piece from here.');return}rec2.took.push(c.i);markDirty();sfx('pin');onCatch({id:c.id,cm:0},'salvage')});
  // chests
  S2.chests=[];for(let i=0;i<T.chests;i++){let p=i===0&&S2.wreckSpot?[Math.floor(S2.wreckSpot.x/16),Math.floor(S2.wreckSpot.y/16)]:spot();if(!p||!free(p[0],p[1]))p=spot();if(!p)break;const ch={i,x:p[0]*16+8,y:p[1]*16+12};S2.chests.push(ch);
    put(artSeaChest(false),p[0],p[1],{anim:()=>artSeaChest(diveRec(site.key).open.includes(i))});S2.sol[p[1]*W+p[0]]=1;S2.res[p[1]*W+p[0]]=1;
    act(S2,ch.x,ch.y+4,20,'Open the chest','grapple',()=>openDiveChest(site,ch))}
  // sea life drifting about (drawn by the dive overlay)
  const fish=CAT.filter(e=>e.cat==='fish'&&(e.z===site.zone||(site.zone==='shallows'&&e.z==='reef'))&&e.r<=2&&!e.release);S2.swim=[];
  for(let i=0;i<9&&fish.length;i++){const e=fish[Math.floor(r()*fish.length)];S2.swim.push({id:e.id,x:r()*W*16,y:60+r()*(H*16-90),v:(8+r()*16)*(r()<.5?-1:1),ph:r()*6})}
  S2.jelly=[];for(let i=0;i<T.jelly;i++)S2.jelly.push({x:40+r()*(W*16-80),y:120+r()*(H*16-180),vx:(r()-.5)*10,vy:(r()-.5)*6,ph:r()*6,hit:0});
  return S2}
function openDiveChest(site,ch){const rec=diveRec(site.key);if(rec.open.includes(ch.i)){toast('Empty. It will have washed full again in a while.');return}rec.open.push(ch.i);markDirty();sfx('clang');
  const sh=Math.round([40,60,90,130,160,220][Object.keys(DIVE_THEME).indexOf(site.zone)]*(.7+Math.random()*.8));addShells(sh);floats.push({x:ch.x,y:ch.y-14,text:'+'+sh,col:'#ffd24d',t:1.4});
  let got=null;for(let k=0;k<6&&(!got||CATI[got.id].cat==='junk');k++)got=rollSalvage(site.zone,envAt());if(!got||CATI[got.id].cat==='junk'){const pool=CAT.filter(e=>e.how==='salvage'&&e.cat!=='junk'&&e.r<=2);got=pool.length?{id:pool[Math.floor(Math.random()*pool.length)].id}:null}
  if(got)setTimeout(()=>onCatch({id:got.id,cm:0},'salvage'),350);
  if(Math.random()<.18){const p=catOf('pearl').filter(e=>e.r<=2&&e.id!=='moon_pearl');setTimeout(()=>onCatch({id:p[Math.floor(Math.random()*p.length)].id,cm:0},'salvage'),900)}
  for(let i=0;i<10;i++)fx.push({x:ch.x,y:ch.y-6,vx:(Math.random()-.5)*40,vy:-30-Math.random()*30,t:.8,c:['#ffd24d','#fff6c0','#bfe8f4'][i%3]})}
/* ---------- air, jellyfish and the underwater look ---------- */
function diveTick(dt){if(!DIVE||scene!==DIVE.sc)return;const Sc=scene;DIVE.t+=dt;if(!MG&&$('panel').hidden)DIVE.air-=dt;
  if(DIVE.air<10&&!DIVE.warned){DIVE.warned=1;toast('Ten seconds of air left! Back to the rope.','warn');sfx('error')}if(DIVE.air<=0){surface(true);return}
  for(const f of Sc.swim){f.x+=f.v*dt;f.y+=Math.sin(DIVE.t*.9+f.ph)*dt*4;if(f.x<-30)f.x=Sc.w*16+20;if(f.x>Sc.w*16+30)f.x=-20;if(Math.hypot(f.x-player.x,f.y-player.y)<26&&Math.random()<dt*3)f.v=Math.sign(f.x-player.x||1)*Math.max(30,Math.abs(f.v))}
  for(const j of Sc.jelly){j.ph+=dt;j.x+=j.vx*dt;j.y+=(j.vy+Math.sin(j.ph*1.5)*6)*dt;if(j.x<20||j.x>Sc.w*16-20)j.vx*=-1;if(j.y<70||j.y>Sc.h*16-30)j.vy*=-1;j.hit=Math.max(0,j.hit-dt);
    if(!j.hit&&Math.hypot(j.x-player.x,j.y-(player.y-10))<12){j.hit=2;DIVE.air-=8;sfx('crack2');toast('Zap! A jellyfish stung you. -8 seconds of air.','warn');for(let i=0;i<8;i++)fx.push({x:player.x,y:player.y-12,vx:(Math.random()-.5)*50,vy:-20-Math.random()*30,t:.5,c:'#e8a0ff'})}}
  if(Math.random()<dt*2.5)DIVE.bub.push({x:player.x+(player.dir==='left'?-4:4),y:player.y-20,v:22+Math.random()*12,t:0});for(let i=DIVE.bub.length-1;i>=0;i--){const b=DIVE.bub[i];b.t+=dt;b.y-=b.v*dt;b.x+=Math.sin(b.t*6)*.3;if(b.t>3)DIVE.bub.splice(i,1)}}
function artJelly(f){return cc('jelly'+f,()=>{const N=PN(14,18);N.ell(7,5,5.5,4.5,(nx,ny,l)=>ny>.55?null:l>.2?'#f8d0ff':'#d898f0',2);N.px(5,3,'#ffffff',3);for(let i=0;i<4;i++){const x=3+i*2.6;for(let y=8;y<17;y++)N.px(x+Math.round(Math.sin(y*.7+f*1.6+i)*1),y,y%3?'#c890e8':'#e8b8ff',1)}return N.canvas()})}
function drawDive(t,Sc){if(!Sc.dive)return;const T=Sc.theme;
  for(const f of Sc.swim){const im=swimArt(f.id);if(!im||!inView(f.x-20,f.y-20,40,40))continue;ctx.save();ctx.globalAlpha=.9;const x=Math.round(f.x-camX),y=Math.round(f.y-camY);if(f.v>0){ctx.translate(x+im.width/2,y-im.height/2);ctx.scale(-1,1);ctx.drawImage(im,0,0)}else ctx.drawImage(im,x-im.width/2,y-im.height/2);ctx.restore()}
  for(const j of Sc.jelly){const im=artJelly(Math.floor(t*4)%4);ctx.globalAlpha=j.hit?.5:.85;ctx.drawImage(im,Math.round(j.x-camX)-7,Math.round(j.y-camY)-9);ctx.globalAlpha=1}
  // the rope up to the boat
  const rx=Sc.spots.rope.x-camX;ctx.fillStyle='#d8c8a0';ctx.fillRect(Math.round(rx),Math.round(-camY),1,Math.round(Sc.spots.rope.y-camY+4));ctx.fillStyle='#8a6a40';ctx.fillRect(Math.round(rx)-2,Math.round(Sc.spots.rope.y-camY+3),5,3);
  if(DIVE)for(const b of DIVE.bub){ctx.fillStyle='#d6f2f8';ctx.fillRect(Math.round(b.x-camX),Math.round(b.y-camY),1,1);if(b.t>.6)ctx.fillRect(Math.round(b.x-camX)+1,Math.round(b.y-camY)-1,1,1)}
  // light from above, a blue cast and drifting specks
  ctx.globalCompositeOperation='lighter';for(let i=0;i<4;i++){const x0=((i*97+t*7)%(VW+80))-40;ctx.globalAlpha=.05+.03*Math.sin(t+i);ctx.fillStyle='#8fe0ff';ctx.beginPath();ctx.moveTo(x0,0);ctx.lineTo(x0+14,0);ctx.lineTo(x0+60,VH);ctx.lineTo(x0+30,VH);ctx.fill()}ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';
  ctx.fillStyle=T.tint;ctx.globalAlpha=.16+T.k*.2;ctx.fillRect(0,0,VW,VH);ctx.globalAlpha=1;
  ctx.fillStyle='rgba(220,240,255,.35)';for(let i=0;i<30;i++){const x=(i*53+t*4*(1+i%3))%VW,y=(i*37+t*9)%VH;ctx.fillRect(x|0,y|0,1,1)}}
function diveChip(){const c=$('hullChip');if(!c||!DIVE||scene!==DIVE.sc)return false;c.hidden=false;$('hullTxt').textContent='Air '+Math.max(0,Math.ceil(DIVE.air))+'s';$('hullSub').textContent=DIVE.air<10?'Back to the rope!':'Tap Surface at the rope';paintIcon($('hullIc'),uiIcon('dive'));return true}
function diveShopRows(){const l=el('div','list');
  l.append(itemRow(uiIcon('dive'),'Dive kit',S.diveKit?'Mask, fins and a 45-second tank. Dive at wreck flags from your boat.':'Mask, fins and a 45-second tank. Dive at the flags by wrecks and reefs.',S.diveKit?el('b',null,'Owned'):btn(fmt(DIVECFG.kit),()=>{if(!payShells(DIVECFG.kit))return;S.diveKit=1;markDirty();sfx('buy');toast('Dive kit ready. Stop your boat by a dive flag and tap Dive.','lvl');renderPanel()},'sm gold')));
  if(S.diveKit)l.append(itemRow(uiIcon('dive'),'Twin tanks',S.diveTank?'75 seconds of air on every dive.':'75 seconds of air instead of 45.',S.diveTank?el('b',null,'Owned'):btn(fmt(DIVECFG.tank),()=>{if(!payShells(DIVECFG.tank))return;S.diveTank=1;markDirty();sfx('buy');renderPanel()},'sm gold')));return l}
function artDiveFlag(f){return cc('dflag'+f,()=>{const N=PN(12,16);N.rect(5,8,2,7,'#e8e2d0',1);N.ell(6,15,4,1.5,'#c8443a',0);for(let y=1;y<8;y++)for(let x=6;x<12;x++){const w=Math.round(Math.sin(y*.8+f*1.5)*.6);N.px(x,y+w,Math.abs((x-6)-(y-1))<1.2?'#ffffff':'#e83a2a',2)}N.rect(5,1,1,8,'#e8e2d0',2);N.outline();return N.canvas()})}
function drawDiveFlags(list,t){for(const d of diveSites()){if(!inView(d.x-20,d.y-30,40,40))continue;const im=artDiveFlag(Math.floor(t*3)%3);const x=Math.round(d.x+12-camX),y=Math.round(d.y-14-camY+Math.sin(t*2+d.x)*1);list.push({sy:d.y,draw:()=>ctx.drawImage(im,x-6,y)})}}
