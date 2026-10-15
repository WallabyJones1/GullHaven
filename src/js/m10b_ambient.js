/* ================= time of day, weather and light ================= */
const AMB={dayMode:0,dark:0,flash:0,rain:[],fog:[],lastSky:''};
try{AMB.dayMode=+(localStorage.getItem('gullhaven.daymode')||0)}catch(e){}
const ghour=()=>envAt().hour;
function isNightNow(){const h=ghour();return h>=19||h<5.5}
function clockStr(){const E=envAt();const h=Math.floor(E.hour),m=Math.floor((E.hour-h)*60);return String(h).padStart(2,'0')+':'+String(m).padStart(2,'0')}
// darkness 0..1 for the light pass: day 7-17, dusk 17-20, night 20-5, dawn 5-7
function dayPhase(){if(AMB.dayMode===1)return{a:0,dusk:0};const h=ghour();
  if(h>=6.5&&h<17.5)return{a:0,dusk:0};if(h>=17.5&&h<20){const k=(h-17.5)/2.5;return{a:Math.max(0,(k-.4)/.6)*.42,dusk:Math.sin(k*Math.PI)*.24}}if(h>=4.5&&h<6.5){const k=(6.5-h)/2;return{a:k*.42,dusk:Math.sin(k*Math.PI)*.18}}return{a:.42,dusk:0}}
function updateAmbient(dt){const E=envAt();if(E.sky!==AMB.lastSky){if(AMB.lastSky)toast(E.sky==='storm'?'A storm is rolling in. Small boats: head for the harbour!':E.sky==='rain'?'Rain. Barramundi weather.':E.sky==='fog'?'Fog has come down over the water.':E.after?'The storm has passed. The beach will be full of things.':E.sky==='windy'?'The wind is picking up.':'The weather has cleared.');AMB.lastSky=E.sky}
  if(E.sky==='storm'&&Math.random()<dt*.08){AMB.flash=1;setTimeout(()=>sfx('rumble'),300+Math.random()*900)}AMB.flash=Math.max(0,AMB.flash-dt*2.5);
  const wantRain=E.sky==='storm'?110:E.sky==='rain'?60:0;while(AMB.rain.length<wantRain)AMB.rain.push({x:Math.random()*VW,y:Math.random()*VH,s:.7+Math.random()*.6});if(AMB.rain.length>wantRain)AMB.rain.length=wantRain;
  const wind=E.sky==='storm'?60:20;for(const r of AMB.rain){r.y+=230*r.s*dt;r.x-=wind*r.s*dt;if(r.y>VH){r.y=-6;r.x=Math.random()*(VW+40)}if(r.x<-10)r.x+=VW+20}
  if(E.sky==='fog'){while(AMB.fog.length<7)AMB.fog.push({x:Math.random()*VW*1.4,y:Math.random()*VH,r:60+Math.random()*80,v:4+Math.random()*6});for(const f of AMB.fog){f.x-=f.v*dt;if(f.x<-f.r)f.x=VW+f.r}}else AMB.fog.length=0;
  AMB.dark=dayPhase().a}
function drawWeather(t){const E=envAt();
  if(E.sky==='rain'||E.sky==='storm'){ctx.fillStyle=E.sky==='storm'?'rgba(20,30,50,.28)':'rgba(40,60,90,.14)';ctx.fillRect(0,0,VW,VH);ctx.strokeStyle='rgba(200,225,245,.55)';ctx.lineWidth=1;ctx.beginPath();for(const r of AMB.rain){ctx.moveTo(Math.round(r.x)+.5,Math.round(r.y));ctx.lineTo(Math.round(r.x-(E.sky==='storm'?3:1.5))+.5,Math.round(r.y+5))}ctx.stroke()}
  if(E.sky==='fog'){for(const f of AMB.fog){const g=ctx.createRadialGradient(f.x,f.y,4,f.x,f.y,f.r);g.addColorStop(0,'rgba(226,232,240,.38)');g.addColorStop(1,'rgba(226,232,240,0)');ctx.fillStyle=g;ctx.fillRect(f.x-f.r,f.y-f.r,f.r*2,f.r*2)}ctx.fillStyle='rgba(220,228,236,.16)';ctx.fillRect(0,0,VW,VH)}
  if(AMB.flash>0){ctx.fillStyle=`rgba(240,245,255,${AMB.flash*.55})`;ctx.fillRect(0,0,VW,VH)}}
function drawTimeOfDay(t){const ph=dayPhase();if(ph.dusk>0){ctx.fillStyle=`rgba(255,130,80,${ph.dusk})`;ctx.globalCompositeOperation='soft-light';ctx.fillRect(0,0,VW,VH);ctx.globalCompositeOperation='source-over'}
  if(ph.a<=0)return;const L=lctx;L.globalCompositeOperation='source-over';L.clearRect(0,0,VW,VH);L.fillStyle=`rgba(10,18,48,${ph.a})`;L.fillRect(0,0,VW,VH);L.globalCompositeOperation='destination-out';
  const hole=(x,y,r,s=1)=>{const g=L.createRadialGradient(x,y,r*.2,x,y,r);g.addColorStop(0,`rgba(0,0,0,${s})`);g.addColorStop(1,'rgba(0,0,0,0)');L.fillStyle=g;L.beginPath();L.arc(x,y,r,0,6.283);L.fill()};
  const lights=(WORLD.lights||[]).filter(l=>inView(l.x-50,l.y-50,100,100));for(const l of lights)hole(l.x-camX,l.y-camY,l.r||44);hole(player.x-camX,player.y-camY-8,40,.7);
  if(player.boat&&S.gear.lamp>=0)hole(player.boat.x-camX,player.boat.y-camY,70+S.gear.lamp*30,.9);
  for(const w of WORLD.wins||[])if(inView(w.x,w.y,w.w,w.h))for(const c of(w.o.win||[]))hole(w.x+c*16+8-camX,w.y+w.h-26-camY,18,.7);
  const lh=WORLD.lighthouse;if(lh)hole(lh.x-camX,lh.y-camY,30,1);
  ctx.drawImage(lightCv,0,0);ctx.globalCompositeOperation='lighter';for(const l of lights){const x=l.x-camX,y=l.y-camY;const g=ctx.createRadialGradient(x,y,1,x,y,26);g.addColorStop(0,`rgba(255,200,110,${ph.a*.5})`);g.addColorStop(1,'rgba(255,200,110,0)');ctx.fillStyle=g;ctx.fillRect(x-26,y-26,52,52)}
  if(lh&&inView(lh.x-260,lh.y-260,520,520)){const a=t*.9;const len=220;const x=lh.x-camX,y=lh.y-camY;const g=ctx.createRadialGradient(x,y,6,x,y,len);g.addColorStop(0,`rgba(255,246,190,${ph.a*.7})`);g.addColorStop(1,'rgba(255,246,190,0)');ctx.fillStyle=g;for(const off of[0,Math.PI]){ctx.beginPath();ctx.moveTo(x,y);ctx.arc(x,y,len,a+off-.13,a+off+.13);ctx.closePath();ctx.fill()}}
  ctx.globalCompositeOperation='source-over'}
