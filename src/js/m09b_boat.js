/* ================= boats: steering, fuel, grounds you can reach, tap-to-sail, wakes ================= */
let zoneWarnT=0;
function boatTier(){return S.boat?BOATI[S.boat].tier:0}
function navOK(x,y,quiet){if(x<4||y<4||x>WORLD.w*16-4||y>WORLD.h*16-4)return false;const tx=Math.floor(x/16),ty=Math.floor(y/16);const i=ty*WORLD.w+tx;if(!WORLD.nav[i])return false;
  const z=WORLD.zone[i];if(z!==255){const Z=ZONES[ZONE_ORDER[z]];if(Z.need>boatTier()){if(!quiet&&performance.now()>zoneWarnT){zoneWarnT=performance.now()+3500;const need=BOATS.find(b=>b.tier>=Z.need);toast(`The ${Z.n} needs a ${need?need.n.toLowerCase():'bigger boat'} or better.`,'warn');sfx('error')}return false}}return true}
function boatSpeedMax(){const B=BOATI[player.boat.k];const eng=GEAR.engine[S.gear.engine];const fuel=eng.burn===0||S.fuel>0;const E=envAt();
  let m=(fuel?eng.speed:1)*B.spd*(S.coop==='gullwing'?1.1:1)*(1+.03*myCoopFleetLvl());if(E.sky==='storm'&&B.storm<2)m*=.7;return 44*m}
function boatUpdate(dt,mx,my){const b=player.boat;if(!b)return;const maxV=boatSpeedMax();let thr=0;
  if(mx||my){const want=Math.atan2(my,mx);let d=((want-b.h+Math.PI*3)%(Math.PI*2))-Math.PI;b.h+=clamp(d,-2.8*dt,2.8*dt);thr=Math.min(1,Math.hypot(mx,my))*(Math.abs(d)>2.2?.35:1);b.tgt=null}
  else if(b.tgt&&b.tgt.length){const q=b.tgt[0];const dx=q.x-b.x,dy=q.y-b.y,dist=Math.hypot(dx,dy);if(dist<10){b.tgt.shift();if(!b.tgt.length){b.tgt=null;onSailArrive()}}else{const want=Math.atan2(dy,dx);let d=((want-b.h+Math.PI*3)%(Math.PI*2))-Math.PI;b.h+=clamp(d,-2.6*dt,2.6*dt);thr=(b.tgt.length===1?clamp(dist/50,.25,1):1)*(Math.abs(d)>1.6?.3:1)}}
  if(MG)thr=0;
  const accel=thr*maxV>b.v?1.1:2.2;b.v+=(thr*maxV-b.v)*Math.min(1,dt*accel);
  const E=envAt();const drift=E.wind*(E.sky==='storm'?7:2);
  const nx=b.x+Math.cos(b.h)*b.v*dt+Math.cos(E.t/9000)*drift*dt,ny=b.y+Math.sin(b.h)*b.v*dt+Math.sin(E.t/11000)*drift*dt*.6;
  const bow=[nx+Math.cos(b.h)*12,ny+Math.sin(b.h)*12];
  if(navOK(nx,ny,true)&&navOK(bow[0],bow[1],b.v<4)){b.x=nx;b.y=ny}else{navOK(bow[0],bow[1],false);if(Math.abs(b.v)>16){sfx('thud');splash(bow[0],bow[1],5)}b.v*=-.2;b.tgt=null}
  const eng=GEAR.engine[S.gear.engine];if(eng.burn>0&&thr>0&&S.fuel>0){S.fuel=Math.max(0,S.fuel-eng.burn*Math.abs(b.v)*dt/16/9);if(S.fuel===0)toast('Out of fuel! Rowing home.','warn');markDirty()}
  player.x=b.x;player.y=b.y;player.moving=Math.abs(b.v)>3;player.dir=faceFrom(Math.cos(b.h),Math.sin(b.h),player.dir);
  if(Math.abs(b.v)>12){b.wt=(b.wt||0)+dt;if(b.wt>.06){b.wt=0;const k=-14-Math.random()*4;WAKE.push({x:b.x+Math.cos(b.h)*k+(Math.random()-.5)*6,y:b.y+Math.sin(b.h)*k+(Math.random()-.5)*6,t:1.2,s:Math.abs(b.v)/60})}}
  b.zone=zoneAtPx(b.x,b.y);if(b.zone!==b.lastZone){b.lastZone=b.zone;if(b.zone){setLocation();if(!S.seenZone||!S.seenZone[b.zone]){(S.seenZone=S.seenZone||{})[b.zone]=1;toast(`${ZONES[b.zone].n}`,'lvl');markDirty()}bumpQuest('zone',b.zone)}}}
const WAKE=[];
function updWake(dt){for(let i=WAKE.length-1;i>=0;i--){WAKE[i].t-=dt;if(WAKE[i].t<=0)WAKE.splice(i,1)}}
function sailTo(wx,wy){const b=player.boat;const tx=Math.floor(wx/16),ty=Math.floor(wy/16);if(!navOK(wx,wy,false))return false;
  const pass=(x,y)=>{if(x<0||y<0||x>=WORLD.w||y>=WORLD.h)return false;const i=y*WORLD.w+x;if(!WORLD.nav[i])return false;const z=WORLD.zone[i];return z===255||ZONES[ZONE_ORDER[z]].need<=boatTier()};
  const path=findPathP(pass,WORLD.w,WORLD.h,Math.floor(b.x/16),Math.floor(b.y/16),tx,ty,20000);if(!path){toast("Can't find a way through.");return false}
  const pts=path.map(p=>({x:p.tx*16+8,y:p.ty*16+8}));const simp=[];let last={x:b.x,y:b.y};for(let i=0;i<pts.length;i++){if(i===pts.length-1||!losNav(last,pts[i+1])){simp.push(pts[i]);last=pts[i]}}if(!simp.length)simp.push({x:wx,y:wy});simp[simp.length-1]={x:wx,y:wy};b.tgt=simp;tapFx={x:wx,y:wy,t:.5};return true}
function losNav(a,b){const d=Math.hypot(b.x-a.x,b.y-a.y);const n=Math.ceil(d/6);for(let i=1;i<=n;i++){const k=i/n;if(!navOK(a.x+(b.x-a.x)*k,a.y+(b.y-a.y)*k,true))return false}return true}
function onSailArrive(){const a=boatAct();if(a)setActButton(a)}
