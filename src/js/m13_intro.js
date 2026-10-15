/* ================= the title sequence: shadowy fish in deep water, and the town's name hooked off the bottom and reeled up =================
   Painted every frame at a low resolution and scaled up crisply. Tap to skip ahead. */
const INTRO={t:0,on:true,ready:false,W:0,H:0,k:2,fish:[],snow:[],bub:[],drip:[],kelp:[],sign:null,signFont:false,done:false};
const IT={drop:[0,1.5],bite:[1.5,2.1],reel:[2.1,4.4],card:4.5};
const iease=x=>x<0?0:x>1?1:x<.5?2*x*x:1-Math.pow(-2*x+2,2)/2;
function introSize(){const cv=$('introCv');const vw=innerWidth,vh=innerHeight;const k=Math.max(2,Math.floor(Math.min(vw/150,vh/280)));const W=Math.ceil(vw/k),H=Math.ceil(vh/k);
  if(W===INTRO.W&&H===INTRO.H)return;INTRO.W=W;INTRO.H=H;INTRO.k=k;cv.width=W;cv.height=H;
  const r=rng(2024);INTRO.fish=[];const n=Math.round(W*H/9000)+4;for(let i=0;i<n;i++){const big=i===0;INTRO.fish.push({x:r()*W,y:H*(.42+r()*.48),s:big?5.5:1+r()*2.4,v:(big?5:9+r()*14)*(r()<.5?-1:1),ph:r()*6,big,dark:.32+r()*.3})}
  INTRO.snow=[];for(let i=0;i<Math.round(W*H/900);i++)INTRO.snow.push({x:r()*W,y:r()*H,v:2+r()*4,s:r()});
  INTRO.kelp=[];for(let x=-4;x<W+8;x+=6+Math.floor(r()*14))INTRO.kelp.push({x,h:18+r()*46,ph:r()*6,w:r()<.3?2:1})}
function introSurface(){return Math.round(INTRO.H*.3)}
// the driftwood sign with the town's name in gold
function introSign(){if(INTRO.sign&&INTRO.signFont===!!INTRO.fontOK)return INTRO.sign;INTRO.signFont=!!INTRO.fontOK;
  const txt='GULLHAVEN';const fs=20;const[tc,tx]=mk(220,40);tx.font=(INTRO.fontOK?`${fs}px "Jersey 10"`:`bold ${fs-6}px sans-serif`);tx.textBaseline='top';tx.fillStyle='#fff';tx.fillText(txt,2,4);
  const id=tx.getImageData(0,0,220,40).data;let x0=999,x1=0,y0=999,y1=0;const on=(x,y)=>x>=0&&y>=0&&x<220&&y<40&&id[(y*220+x)*4+3]>110;
  for(let y=0;y<40;y++)for(let x=0;x<220;x++)if(on(x,y)){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
  const tw=x1-x0+1,th=y1-y0+1;const W=tw+14,H=th+9;const N=PN(W,H+8);
  // the plank, a little warped, with barnacles and weed
  N.poly([[1,8],[W-2,6],[W-1,H+5],[2,H+6]],(x,y)=>{const g=(y+Math.floor(x/23)*3)%7===0;return g?'#4a2e28':rampPick(WOOD,.55-(y-6)/(H+2)*1.1+(hash2(x>>2,y,7)-.5)*.25)},1);
  for(const[bx,by]of[[5,H+2],[9,H+3],[W-8,10],[W-12,H+2],[14,11]]){N.ell(bx,by,1.6,1.3,'#c8c0b0',2);N.px(bx,by,'#6a6050',3)}
  for(let i=0;i<5;i++){const wx=4+i*Math.floor((W-8)/4);N.line(wx,H+5,wx+(i%2?2:-2),H+8,'#3f7a45',1,2)}
  N.ell(W/2,3,3,3,(nx,ny)=>Math.hypot(nx,ny)>.5?BRASS[2]:null,3);
  // gold letters with a dark edge and a bright top
  const GOLDR=['#7a4a10','#b8741c','#e0aa30','#f6d060','#fff2b0'];
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){if(!on(x,y))continue;const lx=x-x0+7,ly=y-y0+9;const top=!on(x,y-1),bot=!on(x,y+1);N.px(lx,ly,top?GOLDR[4]:bot?GOLDR[1]:(ly-9)<th*.45?GOLDR[3]:GOLDR[2],5)}
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){if(!on(x,y))continue;const lx=x-x0+7,ly=y-y0+9;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1],[1,1]])if(!on(x+dx,y+dy))N.px(lx+dx,ly+dy,'#2a1406',4)}
  N.outline();INTRO.sign=N.canvas();return INTRO.sign}
// the still parts of the picture, painted once per screen size: dusk sky, the town on the horizon, the deep water, the seabed
function introBg(W,H,sy){const[c,g]=mk(W,H);
  for(let y=0;y<sy;y++){const k=y/sy;g.fillStyle=k<.35?'#1c2a52':k<.6?'#3a3c6a':k<.8?'#7a5a7a':k<.92?'#d8846a':'#f4b070';g.fillRect(0,y,W,1)}
  ell(g,W*.78,sy*.38,7,7,'#fde8b0');ell(g,W*.78-2,sy*.38-1,6,6,'#fff6d8');
  const hz=sy-1;g.fillStyle='#24203a';for(let x=0;x<W*.55;x++){const h=3+((x*7)%13<6?4:0)+((Math.floor(x/9)%3===0)?3:0);g.fillRect(x,hz-h,1,h)}
  for(let i=0;i<6;i++){const hx=6+i*14;if(hx>W*.5)break;g.fillRect(hx,hz-11,8,6);g.fillRect(hx+1,hz-13,6,2)}
  const lx=Math.round(W*.62);g.fillRect(lx-3,hz-26,6,26);g.fillRect(lx-4,hz-30,8,4);g.fillStyle='#ffe9a0';g.fillRect(lx-2,hz-29,4,2);
  const bands=['#2f6f9e','#285f8c','#22517c','#1c446c','#16385c','#112d4e','#0d2340','#0a1a32','#071226'];
  for(let y=sy;y<H;y++){const d=(y-sy)/(H-sy)*(bands.length-1);const i=Math.floor(d),f=d-i;g.fillStyle=bands[i];g.fillRect(0,y,W,1);if(f>.5&&i+1<bands.length){g.fillStyle=bands[i+1];for(let x=(y&1);x<W;x+=2)g.fillRect(x,y,1,1)}}
  const bed=H-14;g.fillStyle='#0a1426';for(let x=0;x<W;x++){const h=Math.round(3+Math.sin(x*.07)*2+Math.sin(x*.23)*1.2);g.fillRect(x,bed-h,1,H-bed+h)}
  g.fillStyle='#0e1a30';for(let i=0;i<W/18;i++){const rx=(i*37)%W,rw=6+(i*5)%9;g.fillRect(rx,bed-4-(i%3),rw,3+(i%3))}
  return c}
function introFrame(dt){if(!INTRO.on)return;introSize();if(INTRO.ready)INTRO.t+=dt;const t=INTRO.t,W=INTRO.W,H=INTRO.H,sy=introSurface();const g=$('introCv').getContext('2d');g.imageSmoothingEnabled=false;const now=performance.now()/1000;
  if(!INTRO.bg||INTRO.bg.width!==W||INTRO.bg.height!==H)INTRO.bg=introBg(W,H,sy);g.drawImage(INTRO.bg,0,0);
  // twinkles, the lighthouse beam and a few gulls
  g.fillStyle='#fff6c0';for(let i=0;i<14;i++){const x=(i*53)%W,y=(i*29)%Math.max(1,Math.round(sy*.4));if((Math.floor(now*2+i)%5))g.fillRect(x,y,1,1)}
  const hz=sy-1,lx=Math.round(W*.62);for(let i=0;i<6;i++){const hx=6+i*14;if(hx>W*.5)break;if((i+Math.floor(now/3))%3){g.fillStyle='#ffd27a';g.fillRect(hx+3,hz-9,2,2)}}
  const ba=now*.9;g.globalAlpha=.16;g.fillStyle='#fff2b0';g.beginPath();g.moveTo(lx,hz-28);g.lineTo(lx+Math.cos(ba)*W,hz-28+Math.sin(ba)*12-6);g.lineTo(lx+Math.cos(ba)*W,hz-28+Math.sin(ba)*12+6);g.fill();g.globalAlpha=1;
  for(let i=0;i<3;i++){const gx=Math.round((now*(10+i*4)+i*70)%(W+20))-10,gy=Math.round(sy*.3+i*7+Math.sin(now*2+i)*2),f=Math.floor(now*5+i)%2;g.fillStyle='#24203a';g.fillRect(gx-2,gy-f,2,1);g.fillRect(gx+1,gy-f,2,1);g.fillRect(gx,gy,1,1)}
  // light rays from the surface
  g.globalCompositeOperation='lighter';for(let i=0;i<5;i++){const x0=((i*47+now*6)%(W+60))-30;g.globalAlpha=.05+.03*Math.sin(now+i);g.fillStyle='#7fd0f0';g.beginPath();g.moveTo(x0,sy);g.lineTo(x0+10,sy);g.lineTo(x0+44,H*.85);g.lineTo(x0+20,H*.85);g.fill()}g.globalAlpha=1;g.globalCompositeOperation='source-over';
  // the surface line, a shimmer
  for(let x=0;x<W;x++){const w=Math.sin(x*.3+now*3)+Math.sin(x*.11-now*2);g.fillStyle=w>1.2?'#d6f2f8':w>0?'#8fd0ea':'#5ea9d8';g.fillRect(x,sy,1,1);if(w>1.5)g.fillRect(x,sy+1,1,1)}
  // marine snow
  g.fillStyle='rgba(200,230,255,.35)';for(const p of INTRO.snow){p.y+=p.v*dt*.3;p.x+=Math.sin(now+p.s*9)*dt*.6;if(p.y>H)p.y=sy+2;if(p.y>sy+2)g.fillRect(p.x|0,p.y|0,1,1)}
  // kelp silhouettes on the seabed
  const bed=H-14;
  g.fillStyle='#08101e';for(const k of INTRO.kelp){for(let j=0;j<k.h;j++){const sw=Math.sin(now*1.2+k.ph+j*.09)*(j/k.h)*4;g.fillRect(Math.round(k.x+sw),bed-j,k.w,1);if(j%7===3)g.fillRect(Math.round(k.x+sw)+(j%14<7?1:-2),bed-j,2,1)}}
  // the title: lies on the bottom, is hooked, then reeled up through the shadows and out of the water
  const sign=introSign();const kk=clamp(Math.min(Math.round(W*.84/sign.width),Math.floor((W-8)/sign.width)),1,3);const sw=sign.width*kk,sh=sign.height*kk;
  const restY=bed-sh+6,topY=Math.max(6,sy-sh-Math.round(H*.05));const cx=Math.round(W/2);
  let ly;if(t<IT.drop[1])ly=sy+(restY-sy)*iease(t/IT.drop[1]);else ly=restY;// hook depth (the sign's ring)
  let syg=restY,rot=0;
  if(t>=IT.bite[0]&&t<IT.bite[1]){const k=(t-IT.bite[0])/(IT.bite[1]-IT.bite[0]);syg=restY-Math.round(Math.sin(k*Math.PI*3)*3*(1-k));rot=Math.sin(k*20)*.04*(1-k)}
  if(t>=IT.reel[0]){const k=iease((t-IT.reel[0])/(IT.reel[1]-IT.reel[0]));syg=restY+(topY-restY)*k;const after=Math.max(0,t-IT.reel[1]);rot=Math.sin(t*3.2)*.07*(1-k*.6)*Math.exp(-after*.8);syg+=after>0?Math.sin(after*2.4)*1.5*Math.exp(-after*.5):0;ly=syg}
  if(t>=IT.bite[0]&&t<IT.reel[0])ly=syg;
  // shadowy fish (they scatter when the sign comes through)
  for(const f of INTRO.fish){const flee=t>IT.reel[0]&&t<IT.reel[1]+1&&Math.abs(f.y-(syg+sh/2))<30&&Math.abs(f.x-cx)<sw*.8;if(flee&&!f.fled){f.fled=1;f.v=Math.sign(f.x-cx||1)*Math.max(28,Math.abs(f.v)*3)}if(f.fled&&!flee)f.v*=Math.pow(.6,dt);if(f.fled&&Math.abs(f.v)<14)f.fled=0;
    f.x+=f.v*dt;const wrap=f.s*14+10;if(f.x>W+wrap)f.x=-wrap;if(f.x<-wrap)f.x=W+wrap;const y=f.y+Math.sin(now*.8+f.ph)*3;introFish(g,f.x,y,f.s,f.v<0,now+f.ph,f.big?.32:f.dark*(.6+.4*(f.y-sy)/(H-sy)))}
  // line and hook
  g.strokeStyle='rgba(230,240,255,.75)';g.lineWidth=1;g.beginPath();g.moveTo(cx+.5,0);g.lineTo(cx+.5,Math.round(ly)+(t<IT.bite[0]?3:-2));g.stroke();
  if(t<IT.bite[0]){const hy=Math.round(ly);g.fillStyle='#c8ccd8';g.fillRect(cx,hy,1,4);g.fillRect(cx-2,hy+4,3,1);g.fillRect(cx-2,hy+2,1,2);g.fillStyle='#e9675a';g.fillRect(cx-1,hy-6,3,3)}
  g.save();g.translate(cx,Math.round(syg));g.rotate(rot);g.drawImage(sign,-Math.round(sw/2),0,sw,sh);g.restore();
  // bubbles from the bite and the reel, a splash at the surface, then drips
  if(t>=IT.bite[0]&&t<IT.bite[0]+.1&&!INTRO.bitten){INTRO.bitten=1;for(let i=0;i<26;i++)INTRO.bub.push({x:cx+(Math.random()-.5)*sw,y:restY+sh*.5,v:12+Math.random()*30,r:Math.random()<.3?2:1})}
  if(t>IT.reel[0]&&syg>sy&&Math.random()<dt*30)INTRO.bub.push({x:cx+(Math.random()-.5)*sw*.8,y:syg+sh,v:20+Math.random()*30,r:Math.random()<.25?2:1});
  if(syg<sy&&!INTRO.splashed&&t>IT.reel[0]){INTRO.splashed=1;for(let i=0;i<40;i++)INTRO.drip.push({x:cx+(Math.random()-.5)*sw*1.1,y:sy,vx:(Math.random()-.5)*40,vy:-30-Math.random()*50,life:1.2})}
  if(INTRO.splashed&&t<IT.reel[1]+3&&Math.random()<dt*10)INTRO.drip.push({x:cx+(Math.random()-.5)*sw*.8,y:syg+sh-2,vx:0,vy:0,life:1.5});
  for(let i=INTRO.bub.length-1;i>=0;i--){const b=INTRO.bub[i];b.y-=b.v*dt;b.x+=Math.sin(b.y*.2)*dt*6;if(b.y<sy){INTRO.bub.splice(i,1);continue}g.fillStyle='#bfe8f4';if(b.r>1){g.fillRect(b.x|0,b.y|0,2,1);g.fillRect(b.x|0,(b.y|0)+2,2,1);g.fillRect((b.x|0)-1,(b.y|0)+1,1,1);g.fillRect((b.x|0)+2,(b.y|0)+1,1,1)}else g.fillRect(b.x|0,b.y|0,1,1)}
  for(let i=INTRO.drip.length-1;i>=0;i--){const d=INTRO.drip[i];d.life-=dt;d.vy+=140*dt;d.x+=d.vx*dt;d.y+=d.vy*dt;if(d.life<=0||d.y>sy+2){INTRO.drip.splice(i,1);continue}g.fillStyle='#d6f2f8';g.fillRect(d.x|0,d.y|0,1,2)}
  if(INTRO.splashed){const rr=Math.min(1,(t-IT.reel[1]+.3)/1.4);if(rr<1){g.strokeStyle=`rgba(214,242,248,${1-rr})`;g.beginPath();g.ellipse(cx+.5,sy+.5,sw*.4+rr*40,2+rr*3,0,0,6.283);g.stroke()}}
  // a vignette, and a hint while it plays
  const vg=g.createRadialGradient(W/2,H*.45,Math.min(W,H)*.3,W/2,H*.45,Math.max(W,H)*.75);vg.addColorStop(0,'rgba(0,0,0,0)');vg.addColorStop(1,'rgba(4,8,18,.55)');g.fillStyle=vg;g.fillRect(0,0,W,H);
  if(!INTRO.ready&&Math.floor(now*2)%2){g.fillStyle='#7fdcc0';g.fillRect(W/2-7,H-8,2,2);g.fillRect(W/2-1,H-8,2,2);g.fillRect(W/2+5,H-8,2,2)}
  if(t>=IT.card&&!INTRO.done){INTRO.done=true;$('intro').classList.add('show')}}
// a fish-shaped shadow: body, tail and fins, gently swimming
function introFish(g,x,y,s,left,ph,a){g.save();g.globalAlpha=Math.min(.95,a);g.fillStyle='#030a18';g.translate(Math.round(x),Math.round(y));if(left)g.scale(-1,1);
  const L=Math.round(10*s),Hh=Math.max(2,Math.round(3*s)),tw=Math.sin(ph*7)*Math.max(1,s);
  for(let i=-L;i<=L;i++){const k=i/L;const h=Math.round(Hh*Math.sqrt(Math.max(0,1-k*k))*(k<0?1:.9));g.fillRect(i,-h,1,h*2+1)}
  g.beginPath();g.moveTo(-L+1,0);g.lineTo(-L-Math.round(5*s),-Math.round(3*s)+tw);g.lineTo(-L-Math.round(4*s),tw*.3);g.lineTo(-L-Math.round(5*s),Math.round(3*s)+tw);g.fill();
  g.beginPath();g.moveTo(-Math.round(2*s),-Hh);g.lineTo(Math.round(2*s),-Hh-Math.round(2.5*s));g.lineTo(Math.round(4*s),-Hh+1);g.fill();
  if(s>3){g.fillRect(-Math.round(L*.2),Hh-1,Math.round(5*s),Math.round(1.5*s))}g.restore()}
function introSkip(e){if(!INTRO.ready||INTRO.done)return;if(e&&e.target&&e.target.closest&&e.target.closest('.box'))return;INTRO.t=Math.max(INTRO.t,IT.reel[1]-.25)}
if(document.fonts&&document.fonts.load)document.fonts.load('26px "Jersey 10"').then(f=>{INTRO.fontOK=f&&f.length>0;INTRO.sign=null}).catch(()=>{});
