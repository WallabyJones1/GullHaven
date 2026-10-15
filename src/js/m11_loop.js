/* ================= input + update loop ================= */
const keys=new Set();let joy=null,curAct=null,lastT=performance.now(),gameT=0,miniT=0,hudT=0,tapFx=null;
window.addEventListener('keydown',e=>{if(e.target.tagName==='INPUT'||e.target.tagName==='SELECT'||e.target.tagName==='TEXTAREA')return;const k=e.key.toLowerCase();
  if(['arrowup','arrowdown','arrowleft','arrowright','w','a','s','d'].includes(k)){keys.add(k);e.preventDefault();cancelPath()}
  if(k===' '||k==='enter'||k==='e'){e.preventDefault();if(!e.repeat)actDown()}if(k==='q'&&!e.repeat)btn2Press();
  if(k==='h')togglePanel('hold');if(k==='l')toggleBook();if(k==='m')togglePanel('map');if(k==='c')togglePanel('coop');if(k==='t'){e.preventDefault();toggleChat(true)}if(k==='escape')closeAll()});
window.addEventListener('keyup',e=>{const k=e.key.toLowerCase();keys.delete(k);if(k===' '||k==='enter'||k==='e')actUp()});
window.addEventListener('blur',()=>{keys.clear();actUp()});
cv.addEventListener('pointerdown',e=>{if(joy)return;cv.setPointerCapture(e.pointerId);joy={id:e.pointerId,x0:e.clientX,y0:e.clientY,x:e.clientX,y:e.clientY,t:performance.now(),moved:false}});
cv.addEventListener('pointermove',e=>{if(!joy||e.pointerId!==joy.id)return;joy.x=e.clientX;joy.y=e.clientY;const d=Math.hypot(joy.x-joy.x0,joy.y-joy.y0);if(d>10&&!joy.moved){joy.moved=true;cancelPath();if(player.boat)player.boat.tgt=null;const j=$('joy');j.hidden=false;j.style.left=joy.x0+'px';j.style.top=joy.y0+'px';$('joyBase').classList.add('hide')}if(joy.moved){const dx=clamp(joy.x-joy.x0,-38,38),dy=clamp(joy.y-joy.y0,-38,38);$('knob').style.transform=`translate(${dx}px,${dy}px)`}});
function endJoy(e){if(!joy||e.pointerId!==joy.id)return;if(!joy.moved&&performance.now()-joy.t<350){const wx=e.clientX/SCALE+camX,wy=e.clientY/SCALE+camY;tapWorld(wx,wy)}joy=null;$('joy').hidden=true;$('knob').style.transform='';$('joyBase').classList.remove('hide')}
cv.addEventListener('pointerup',endJoy);cv.addEventListener('pointercancel',endJoy);
document.addEventListener('gesturestart',e=>e.preventDefault());document.addEventListener('dblclick',e=>e.preventDefault());
function doorBump(){if(doorBump.t>performance.now())return;for(const a of scene.acts){if(a.icon!=='door'||a.exit)continue;if(Math.abs(a.x-player.x)<12&&a.y-player.y>-4&&a.y-player.y<14){doorBump.t=performance.now()+800;a.act();return}}}
function tapWorld(wx,wy){if(MG)return;
  if(player.boat){// tap the water to sail there; tap a pot, salvage site or the shore to go to it
    for(const p of S.pots)if(Math.hypot(p.x-wx,p.y-wy)<16){sailTo(p.x+6,p.y+10);return}
    for(const s of WORLD.salvage)if(!s.dead&&Math.hypot(s.x-wx,s.y-wy)<18){sailTo(s.x+12,s.y+10);return}
    if(isWaterPx(wx,wy)){if(Math.hypot(wx-player.boat.x,wy-player.boat.y)<18){const a=boatAct();if(a&&a.label==='Cast')a.act();return}sailTo(wx,wy);return}
    const tie=canTieUp();if(tie&&Math.hypot(tie.x-wx,tie.y-wy)<40){tieUp();return}toast('Tap the water to sail. Tie up next to a jetty or the beach.');return}
  const tg=tapTarget(wx,wy);if(tg){player.retried=0;walkTo(tg);tapFx={x:tg.x,y:tg.y,t:.5}}}
const actBtn=$('btnAct');
actBtn.addEventListener('pointerdown',e=>{e.preventDefault();actBtn.setPointerCapture(e.pointerId);actDown()});
actBtn.addEventListener('pointerup',e=>{e.preventDefault();actUp()});actBtn.addEventListener('pointercancel',()=>actUp());
$('btn2').addEventListener('click',e=>{e.preventDefault();btn2Press()});
let actHeld=false;
function actDown(){if(gachaOpen||!$('panel').hidden||!$('book').hidden)return;actHeld=true;if(MG){if(!MG.ended&&MG.down)MG.down();return}const a=curAct;if(a)a.act();else toast(player.boat?'Tap the water to sail. Stop to cast.':'Walk up to something to use it. Face the water to fish.')}
function actUp(){if(!actHeld)return;actHeld=false;if(MG&&MG.up&&!MG.ended)MG.up()}
function btn2Press(){if(MG||gachaOpen)return;const a=secondAct();if(a)a.act()}
function update(dt){gameT+=dt;
  let mx=0,my=0;if(keys.has('arrowleft')||keys.has('a'))mx-=1;if(keys.has('arrowright')||keys.has('d'))mx+=1;if(keys.has('arrowup')||keys.has('w'))my-=1;if(keys.has('arrowdown')||keys.has('s'))my+=1;
  if(joy&&joy.moved){const dx=joy.x-joy.x0,dy=joy.y-joy.y0;const d=Math.hypot(dx,dy);if(d>8){mx=dx/Math.max(d,38);my=dy/Math.max(d,38)}}
  const p=player;
  if(p.boat){boatUpdate(dt,MG?0:mx,MG?0:my)}
  else{let pathD=0;if(!mx&&!my&&p.path){const f=followPath(dt);mx=f[0];my=f[1];pathD=f[2]}if(MG)mx=my=0;const len=Math.hypot(mx,my);if(len>1){mx/=len;my/=len}
    if(mx||my){const sp=pathD?Math.min(78*dt,pathD):78*dt;const moved=moveEnt(p,mx*sp,my*sp,scene);if(!moved&&my<-.5&&!p.path)doorBump();p.dir=faceFrom(mx,my,p.dir);p.moving=moved;if(p.path){if(!moved){p.stuck=(p.stuck||0)+dt;if(p.stuck>.35){const g=p.goal;cancelPath();if(g&&!p.retried){p.retried=1;walkTo(g,true)}else p.retried=0}}else p.stuck=0}p.ft+=dt;if(p.ft>.11){p.ft=0;p.f=(p.f+1)%4}}else{p.moving=false;p.f=0}
    if(scene&&scene.exitFn&&p.y>(scene.h-1)*16+2&&!MG){const f=scene.exitFn;cancelPath();f();return}}
  if(tapFx){tapFx.t-=dt;if(tapFx.t<=0)tapFx=null}
  if(MG){MG.update(dt);if(MG){mgTick(dt);drawMG()}}
  lifeUpdate(dt);updWake(dt);updateAmbient(dt);
  for(const pe of NET.peers.values()){const k=Math.min(1,dt*10);pe.x+=(pe.tx-pe.x)*k;pe.y+=(pe.ty-pe.y)*k;pe.ft+=dt;if(pe.ft>.12){pe.ft=0;pe.f=(pe.f+1)%4}if(pe.bubble){pe.bubble.t-=dt;if(pe.bubble.t<=0)pe.bubble=null}if(pe.emote){pe.emote.t-=dt;if(pe.emote.t<=0)pe.emote=null}}
  if(p.bubble){p.bubble.t-=dt;if(p.bubble.t<=0)p.bubble=null}if(p.emote){p.emote.t-=dt;if(p.emote.t<=0)p.emote=null}
  for(let i=floats.length-1;i>=0;i--){floats[i].t-=dt;floats[i].y-=dt*14;if(floats[i].t<=0)floats.splice(i,1)}
  for(let i=fx.length-1;i>=0;i--){const q=fx[i];q.t-=dt;q.x+=q.vx*dt;q.y+=q.vy*dt;q.vy+=120*dt;if(q.t<=0)fx.splice(i,1)}
  const a=scene?nearestAct():null;if(!MG&&(a!==curAct||(a&&a.label!==$('actLabel').textContent))){curAct=a;setActButton(a)}
  sendPresence(false);miniT+=dt;if(miniT>.25){miniT=0;drawMini()}hudT+=dt;if(hudT>1){hudT=0;updEnvHUD();upd2Button();updChips();if(NET.db)pushMyDoc()}
  if(dirty&&performance.now()-lastSave>5000){lastSave=performance.now();dirty=false;saveLocal();if(NET.db)remoteSave();if(NET.mode==='ws'&&CHAIN.live)wsSend({t:'save',s:JSON.stringify(S)})}}
function loop(now){const dt=Math.min(.05,(now-lastT)/1000);lastT=now;if(scene&&WORLD){update(dt);if(!gachaOpen&&$('book').hidden)render(gameT)}if(gachaOpen)gachaFrame(dt);requestAnimationFrame(loop)}
