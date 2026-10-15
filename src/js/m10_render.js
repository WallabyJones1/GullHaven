/* ================= rendering: the coast, the sea, boats, people, weather and light ================= */
const cv=$('cv');const ctx=cv.getContext('2d');let VW=320,VH=240,SCALE=2,camX=0,camY=0;
const lightCv=document.createElement('canvas');const lctx=lightCv.getContext('2d');
let ZOOM=0;try{ZOOM=+(localStorage.getItem('gullhaven.zoom')||0)}catch(e){}
function resize(){const w=window.innerWidth,h=window.innerHeight,dpr=Math.min(3,window.devicePixelRatio||1);const W=w*dpr,H=h*dpr;
  const target=(w>900?480:Math.min(w,h)<500?300:380)*(ZOOM?1.35:1);let DS=Math.max(2,Math.round(Math.min(W,H*1.15)/target));if(w>900)DS=Math.max(2,Math.round(W/target));
  SCALE=DS/dpr;VW=Math.ceil(W/DS);VH=Math.ceil(H/DS);cv.width=VW;cv.height=VH;cv.style.width=(VW*DS/dpr)+'px';cv.style.height=(VH*DS/dpr)+'px';ctx.imageSmoothingEnabled=false;lightCv.width=VW;lightCv.height=VH}
function setZoom(z){ZOOM=z?1:0;try{localStorage.setItem('gullhaven.zoom',ZOOM)}catch(e){}resize()}
window.addEventListener('resize',resize);
function drawChar(c,id,x,y,dir,f,extra,clipH){const s=sheet(id);if(!clipH)ell(c,Math.round(x),Math.round(y)+1,6,2,SHADOW);const h=clipH||SH;c.drawImage(s,f*SW,DIRROW[dir]*SH,SW,h,Math.round(x-8),Math.round(y-SH+2+(extra||0)),SW,h)}
function bubble(c,text,x,y,col){text=String(text).replace(/\s+/g,' ').trim();const words=text.split(' ');const lines=[];let cur='';const MAXW=86;
  for(const w of words){const t=cur?cur+' '+w:w;if(textWM(t)>MAXW&&cur){lines.push(cur);cur=w}else cur=t}if(cur)lines.push(cur);if(lines.length>4){lines.length=4;lines[3]=lines[3].replace(/.{0,2}$/,'..')}
  const bg=col||'#fbf1dc';const w=Math.max(...lines.map(textWM))+8,h=lines.length*10+3;const bx=Math.round(clamp(x-w/2,2,VW-w-2)),by=Math.round(y-h-2);
  R(c,bx+1,by,w-2,h,OL);R(c,bx,by+1,w,h-2,OL);R(c,bx+1,by+1,w-2,h-2,bg);const tx=Math.round(x);R(c,tx-2,by+h-1,5,1,bg);R(c,tx-1,by+h,3,1,bg);P(c,tx,by+h+1,bg);P(c,tx-3,by+h-1,OL);P(c,tx+3,by+h-1,OL);P(c,tx-2,by+h,OL);P(c,tx+2,by+h,OL);P(c,tx-1,by+h+1,OL);P(c,tx+1,by+h+1,OL);P(c,tx,by+h+2,OL);
  lines.forEach((l,i)=>drawTextM(c,l,bx+4,by+2+i*10,'#2b2130'))}
function nameTag(c,text,x,y,col){text=String(text).slice(0,16);const w=textWM(text)+6;const bx=Math.round(x-w/2),by=Math.round(y);R(c,bx+1,by,w-2,11,'rgba(14,22,38,.8)');R(c,bx,by+1,w,9,'rgba(14,22,38,.8)');drawTextM(c,text,bx+3,by+1,col||'#fbf1dc')}
function arrow(x,y,col){x=Math.round(x);y=Math.round(y);R(ctx,x-4,y-6,9,5,OL);R(ctx,x-3,y-5,7,3,col);for(let i=0;i<4;i++){R(ctx,x-3+i,y-1+i,7-i*2,1,col);P(ctx,x-4+i,y-1+i,OL);P(ctx,x+4-i,y-1+i,OL)}P(ctx,x,y+3,OL)}
function swayAt(x,y,t){const E=envAt();const g=Math.sin(t*.31+1.3)*.5+.5;const a=.3+g*.9+E.wind*1.4;return Math.round(Math.sin(t*1.9-x*.011+y*.004)*a)}
function drawSway(img,x,y,dx,split){if(!dx){ctx.drawImage(img,x,y);return}const h=img.height,w=img.width;ctx.drawImage(img,0,split,w,h-split,x,y+split,w,h-split);ctx.drawImage(img,0,0,w,split,x+dx,y,w,split)}
function drawEmote(k,x,y,t){x=Math.round(x);y=Math.round(y-Math.abs(Math.sin(t*6))*2);R(ctx,x-6,y-6,13,12,OL);R(ctx,x-5,y-5,11,10,'#fbf1dc');if(k==='star'){R(ctx,x-1,y-4,2,5,'#e9675a');R(ctx,x-1,y+2,2,2,'#e9675a')}else drawIcon(ctx,k,x-3,y-4,k==='heart'?'#e9675a':'#2a4a6a')}
const WALK=[1,0,2,0];
function inView(x,y,w,h){return!(x-camX>VW||y-camY>VH||x+w-camX<0||y+h-camY<0)}
/* the sea */
function drawSea(t){const Sc=WORLD;const E=envAt();const x0=Math.max(0,Math.floor(camX/16)),y0=Math.max(0,Math.floor(camY/16)),x1=Math.min(Sc.w-1,Math.floor((camX+VW)/16)),y1=Math.min(Sc.h-1,Math.floor((camY+VH)/16));
  // high tide covers the wet sand; low tide uncovers it
  const tk=(E.tide+1)/2;if(tk>.05){ctx.globalAlpha=tk*.75;ctx.drawImage(Sc.tideC,camX,camY,VW,VH,0,0,VW,VH);ctx.globalAlpha=1}
  // lapping foam along the shore
  const f=(Math.sin(t*1.6)+1)/2;ctx.globalAlpha=.25+f*.55;ctx.drawImage(Sc.foam,camX+Math.round(f*1.5),camY+Math.round(f),VW,VH,0,0,VW,VH);ctx.globalAlpha=1;
  const caps=E.sky==='storm'?.5:E.sky==='windy'?.25:.06;
  for(let ty=y0;ty<=y1;ty++)for(let tx=x0;tx<=x1;tx++){const i=ty*Sc.w+tx;if(Sc.g[i]!=='o')continue;const x=tx*16-camX,y=ty*16-camY;const h=hash2(tx,ty,91);const ph=(t*.7+h*7)%7;const z=Sc.zone[i];const deep=z>=6;
    if(ph<1.2){const gx=x+2+(hash2(tx,ty,92)*9|0)+Math.round(Math.sin(t+h*6)*2),gy=y+3+(hash2(tx,ty,93)*10|0);const w=ph<.35||ph>.85?2:4;R(ctx,gx+(4-w)/2,gy,w,1,deep?'#5a7ac0':'#c8f0f8');if(w===4)R(ctx,gx+1,gy+1,2,1,deep?'#3a5aa0':'#8ad4ec')}
    if(h<caps){const k=(t*1.3+h*13)%3;if(k<1){const gx=x+(hash2(tx,ty,94)*12|0),gy=y+(hash2(tx,ty,95)*12|0);R(ctx,gx,gy,3+Math.round(k*2),1,'#ffffff');P(ctx,gx+1,gy-1,'#e8f8fb')}}}}
function drawSeaLife(t){
  for(const s of SHADOWS){if(!inView(s.x-14,s.y-8,28,16))continue;const im=artFishShadow(s.r);const fl=s.vx<0;const a=Math.min(1,s.t*.8,(s.life-s.t)*.8);ctx.globalAlpha=a;ctx.save();ctx.translate(Math.round(s.x-camX),Math.round(s.y-camY+Math.sin(t*2+s.x)*1));if(!fl)ctx.scale(-1,1);ctx.drawImage(im,-im.width/2,-im.height/2);ctx.restore();ctx.globalAlpha=1;
    if(S.gear.sonar>=1&&player.boat&&Math.hypot(s.x-player.x,s.y-player.y)<120)drawTextO(ctx,['S','M','L','XL'][s.r],s.x-camX-3,s.y-camY-12,'#8fffb0')}
  for(const h of HOTS){if(!inView(h.x-30,h.y-30,60,60))continue;const x=Math.round(h.x-camX),y=Math.round(h.y-camY);if(h.kind==='birds'){const im=artBirds(Math.floor(t*6)%2);ctx.drawImage(im,x-12+Math.round(Math.sin(t*1.3)*6),y-28+Math.round(Math.cos(t)*3));if(Math.floor(t*2+h.x)%4===0){splashRing(x+Math.round(Math.sin(t*3)*10),y,t)}}
    else if(h.kind==='debris'){ctx.drawImage(artDebris(),x-13,y-7+Math.round(Math.sin(t*1.5)))}else{const im=artSchool(Math.floor(t*3)%3);ctx.globalAlpha=.8;ctx.drawImage(im,x-15,y-9);ctx.globalAlpha=1}}
  for(const j of JUMPS){const x=Math.round(j.x-camX),y=Math.round(j.y-camY);const p=j.t/.8;if(p<.6){const fy=y-Math.sin(p/.6*Math.PI)*9;R(ctx,x-2,Math.round(fy)-1,5,3,OL);R(ctx,x-1,Math.round(fy)-1,3,2,'#c8d4e0')}else splashRing(x,y,p)}
  for(const w of WAKE){if(!inView(w.x-4,w.y-4,8,8))continue;const a=w.t/1.2;ctx.fillStyle=`rgba(240,252,255,${a*.85})`;const r=Math.round((1-a)*5+1);ctx.fillRect(Math.round(w.x-camX)-r,Math.round(w.y-camY),r*2,1);if(a>.5)ctx.fillRect(Math.round(w.x-camX),Math.round(w.y-camY)-1,1,1)}
  for(const p of S.pots){if(!inView(p.x-8,p.y-8,16,16))continue;const ready=(Date.now()-p.at)/1000>=POTS.soakMin;ctx.drawImage(artPotFloat(S.coop?COOPI[S.coop].col:'#f0c040'),Math.round(p.x-camX)-5,Math.round(p.y-camY)-5+Math.round(Math.sin(t*2+p.x)));if(ready&&Math.floor(t*3)%2)P(ctx,Math.round(p.x-camX),Math.round(p.y-camY)-8,'#ffd24d')}
  for(const s of WORLD.salvage){if(s.dead||!inView(s.x-12,s.y-12,24,24))continue;const ready=salvageReady(s);ctx.globalAlpha=ready?1:.35;ctx.drawImage(artSalvageSpot(Math.floor(t*2)%3),Math.round(s.x-camX)-10,Math.round(s.y-camY)-7);ctx.globalAlpha=1}}
function splashRing(x,y,t){const r=(t*3)%1;ctx.strokeStyle=`rgba(232,248,251,${1-r})`;ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(Math.round(x)+.5,Math.round(y)+.5,2+r*7,1+r*3,0,0,6.283);ctx.stroke()}
function boatDraw(list,k,x,y,h,paint,flag,rider,t,opts={}){const hi=typeof h==='number'&&h<16&&Number.isInteger(h)?h:boatHeading(h);const im=boatImg(k,hi,paint,flag);const bob=Math.round(Math.sin(t*2.2+x*.01)*.6);
  list.push({sy:y+4,draw:()=>{const bx=Math.round(x-camX-im.width/2),by=Math.round(y-camY-im.height/2)+bob;ctx.globalAlpha=.35;ell(ctx,Math.round(x-camX),Math.round(y-camY)+4,im.width*.38,im.height*.22,'#12304a');ctx.globalAlpha=1;ctx.drawImage(im,bx,by);
    if(opts.decor&&opts.decor!=='none'&&BOAT_DECOR[opts.decor]){const d=BOAT_DECOR[opts.decor].art(),a=hi/16*Math.PI*2;const dx=Math.round(x-camX+Math.cos(a)*7),dy=Math.round(y-camY+Math.sin(a)*7-3+bob);if(opts.decor==='lifebuoy')ctx.drawImage(d,0,0,14,16,dx-3,dy-4,7,8);else{const w=opts.decor==='crates'?10:7,h2=opts.decor==='crates'?6:10;ctx.drawImage(d,dx-w/2|0,dy-h2|0,w,h2)}}
    if(rider){const ang=hi/16*Math.PI*2;const sp=BOAT_SPEC[k];const sx=x+Math.cos(ang)*(sp.seats?sp.seats[0]:-4)*.9,sy=y+Math.sin(ang)*(sp.seats?sp.seats[0]:-4)*.9;drawChar(ctx,rider.id,sx-camX,sy-camY+8+bob,rider.dir||faceFrom(Math.cos(ang),Math.sin(ang),'down'),rider.f||0,0,18)}
    if(opts.fishing){const a=hi/16*Math.PI*2+Math.PI/2;const sx=x-camX,sy=y-camY-8+bob,fx=sx+Math.cos(a)*25,fy=y-camY+Math.sin(a)*25;ctx.strokeStyle='#8a5a33';ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(sx+8,sy-10);ctx.stroke();ctx.strokeStyle='rgba(255,255,255,.7)';ctx.beginPath();ctx.moveTo(sx+8,sy-10);ctx.lineTo(fx,fy);ctx.stroke();R(ctx,Math.round(fx)-1,Math.round(fy+Math.sin(t*3)),3,2,'#e9675a')}
    if(opts.name)nameTag(ctx,opts.name,x-camX,y-camY+10,opts.col)}})}
function render(t){const Sc=scene;const ww=Sc.w*16,wh=Sc.h*16;const fx0=player.boat?player.boat.x:player.x,fy0=player.boat?player.boat.y:player.y-12;
  camX=ww<=VW?-(VW-ww)/2:clamp(fx0-VW/2,0,ww-VW);camY=wh<=VH?-(VH-wh)/2:clamp(fy0-VH/2,0,wh-VH);camX=Math.round(camX);camY=Math.round(camY);
  ctx.fillStyle=Sc===WORLD?'#2a74a8':'#0e1626';ctx.fillRect(0,0,VW,VH);
  const sx=Math.max(0,camX),sy=Math.max(0,camY),sw=Math.min(VW,ww-sx),sh=Math.min(VH,wh-sy);if(sw>0&&sh>0)ctx.drawImage(Sc.ground,sx,sy,sw,sh,sx-camX,sy-camY,sw,sh);
  const list=[];
  if(Sc===WORLD){drawSea(t);drawSeaLife(t);for(const c of combSpots()){if(!inView(c.x-6,c.y-6,12,12))continue;const k=Math.floor(t*4+c.i)%4;const x=Math.round(c.x-camX),y=Math.round(c.y-camY);P(ctx,x,y-k%2,'#ffffff');if(k<2){P(ctx,x-1,y,'#fff6c0');P(ctx,x+1,y,'#fff6c0')}P(ctx,x,y+2,'#c8ac78')}}
  for(const p of Sc.props){const img=p.anim?p.anim(t):p.img;if(!inView(p.x,p.y,img.width,img.height))continue;if(p.flat){ctx.drawImage(img,Math.round(p.x-camX),Math.round(p.y-camY));continue}if(p.sway){list.push({sy:p.sy,draw:()=>drawSway(img,Math.round(p.x-camX),Math.round(p.y-camY),swayAt(p.x,p.y,t),img.height-14)});continue}list.push({sy:p.sy,draw:()=>ctx.drawImage(img,Math.round(p.x-camX),Math.round(p.y-camY))})}
  if(Sc===WORLD){
    for(const b of AIBOATS){if(!inView(b.x-30,b.y-30,60,60))continue;boatDraw(list,b.k,b.x,b.y,b.h,COOPI[b.co].col,b.co,b.state!=='moored'?{id:3000+COOPS.indexOf(COOPI[b.co])*7}:null,t)}
    if(S.boat&&!player.boat){const sp=myBoatSpot();if(inView(sp.x-30,sp.y-30,60,60))boatDraw(list,S.boat,sp.x,sp.y,sp.h||0,S.paint[S.boat],S.coop,null,t,{name:S.boatName||null,col:'#bfe8f4',decor:boatDetail(S.boat)})}
    if(player.boat){const b=player.boat;boatDraw(list,b.k,b.x,b.y,b.h,S.paint[b.k],S.coop,{id:ACTIVE(),f:MG&&MG.type==='fish'?(Math.floor(t*6)%2?1:2):0},t,{name:S.boatName||null,col:'#bfe8f4',decor:boatDetail(b.k)})}
    for(const f of FOLK){if(!inView(f.x-10,f.y-30,20,34))continue;list.push({sy:f.y,draw:()=>{drawChar(ctx,f.id,f.x-camX,f.y-camY,f.dir,f.moving?WALK[f.f]:0);if(f.bubble)bubble(ctx,f.bubble.text,f.x-camX,f.y-camY-26)}})}
    for(const c of CRABS){if(!inView(c.x-6,c.y-6,12,12))continue;list.push({sy:c.y,draw:()=>ctx.drawImage(artCrabBeach(Math.floor(t*8)%2),Math.round(c.x-camX)-6,Math.round(c.y-camY)-5)})}}
  for(const kp of(Sc.keepers||[]))list.push({sy:kp.y,draw:()=>drawChar(ctx,kp.id,kp.x-camX,kp.y-camY,kp.dir||'down',Math.floor(t*1.5+kp.x)%7===0?1:0)});
  for(const[k,pe]of NET.peers){if(pe.sc!==Sc.name)continue;const col=pe.co?COOPI[pe.co].lt==='#ffffff'?'#bfe8f4':COOPI[pe.co].lt:'#7fdcc0';
    if(pe.b&&Sc===WORLD){boatDraw(list,pe.b.k,pe.x,pe.y,pe.b.h,pe.b.p,pe.co,{id:pe.id,f:pe.fish?(Math.floor(t*6)%2?1:2):0},t,{name:pe.b.n||pe.n,col,decor:pe.b.de,fishing:pe.fish});continue}
    list.push({sy:pe.y,draw:()=>{drawChar(ctx,pe.id,pe.x-camX,pe.y-camY,pe.dir,pe.moving?WALK[pe.f]:0);if(pe.co)drawBands(ctx,pe.x-camX,pe.y-camY,pe.dir,COOPI[pe.co].col,false);nameTag(ctx,pe.n,pe.x-camX,pe.y-camY+4,col);if(pe.bubble)bubble(ctx,pe.bubble.text,pe.x-camX,pe.y-camY-26);if(pe.emote)drawEmote(pe.emote.k,pe.x-camX,pe.y-camY-32,t)}})}
  if(!player.boat)list.push({sy:player.y,draw:()=>drawPlayer(t)});
  list.sort((a,b)=>a.sy-b.sy);for(const d of list)d.draw();
  if(player.boat){const b=player.boat;if(player.bubble)bubble(ctx,player.bubble.text,b.x-camX,b.y-camY-22);if(player.emote)drawEmote(player.emote.k,b.x-camX,b.y-camY-28,t)}
  if(Sc===WORLD){for(const g of GULLS){if(!inView(g.x-6,g.y-30,12,40))continue;const x=Math.round(g.x-camX),y=Math.round(g.y-camY-24);const up=Math.floor(t*5+g.ph)%2;ctx.fillStyle='rgba(18,48,74,.25)';ctx.fillRect(x-2,y+24,5,1);ctx.fillStyle='#fbfbff';ctx.fillRect(x-1,y,3,1);ctx.fillStyle=OL;if(up){P(ctx,x-3,y-2,OL);P(ctx,x-2,y-1,OL);P(ctx,x+2,y-1,OL);P(ctx,x+3,y-2,OL)}else{P(ctx,x-3,y+1,OL);P(ctx,x-2,y,OL);P(ctx,x+2,y,OL);P(ctx,x+3,y+1,OL)}}
    drawWeather(t);drawTimeOfDay(t)}
  else if(Sc.lights&&Sc.lights.length){ctx.globalCompositeOperation='lighter';for(const l of Sc.lights){const x=l.x-camX,y=l.y-camY;const g=ctx.createRadialGradient(x,y,1,x,y,l.r);g.addColorStop(0,'rgba(255,190,110,.18)');g.addColorStop(1,'rgba(255,190,110,0)');ctx.fillStyle=g;ctx.fillRect(x-l.r,y-l.r,l.r*2,l.r*2)}ctx.globalCompositeOperation='source-over'}
  // fishing line and float
  if(MG&&MG.type==='fish'&&MG.bx!=null&&MG.state!=='aim'){const sx0=player.boat?player.boat.x:player.x,sy0=player.boat?player.boat.y:player.y;const hx=sx0-camX+(player.dir==='left'?-7:player.dir==='right'?7:4),hy=sy0-camY-(player.boat?10:16);let bx=MG.bx-camX,by=MG.by-camY;
    if(MG.state==='cast'){const k=Math.min(1,MG.e/.5);bx=hx+(bx-hx)*k;by=hy+(by-hy)*k-Math.sin(k*Math.PI)*22}
    const tight=MG.state==='fight'||MG.state==='land';const dip=MG.state==='bite'?2+Math.round(Math.sin(t*30)):MG.nib>0?1:Math.round(Math.sin(t*3)*.6);
    ctx.strokeStyle=tight?'rgba(255,255,255,.95)':'rgba(255,255,255,.7)';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(hx+.5,hy+.5);if(tight)ctx.lineTo(bx+.5,by+.5);else ctx.quadraticCurveTo((hx+bx)/2,Math.max(hy,by)+8,bx+.5,by+dip+.5);ctx.stroke();
    if(MG.state!=='cast'&&!tight){const rr=(t*2)%1;ctx.strokeStyle=`rgba(214,242,248,${1-rr})`;ctx.beginPath();ctx.ellipse(bx,by+3,4+rr*8,2+rr*3,0,0,6.283);ctx.stroke()}
    if(tight){const fxp=bx+Math.sin(t*9)*3;for(let i=0;i<3;i++)P(ctx,Math.round(fxp+(Math.random()-.5)*8),Math.round(by+(Math.random()-.5)*4),'#e8fbff')}else stamp(ctx,['.k.','kRk','kWk','.k.'],{k:OL,R:'#e9675a',W:'#ffffff'},Math.round(bx-1),Math.round(by-2+dip))}
  // markers
  if(Sc===WORLD&&!MG){const qt=questTarget();if(qt){const qx=qt.x-camX,qy=qt.y-camY-30;if(qx>-4&&qx<VW+4&&qy>-4&&qy<VH+4)arrow(qx,qy+Math.round(Math.sin(t*5)*2),'#ffd24d');else edgeArrow(qx,qy,'#ffd24d')}
    if(S.boat&&!player.boat){const sp=myBoatSpot();const qx=sp.x-camX,qy=sp.y-camY;if(qx<-10||qx>VW+10||qy<-10||qy>VH+10)edgeArrow(qx,qy,'#7fdcc0')}}
  for(const p of fx){ctx.fillStyle=p.c;ctx.fillRect(Math.round(p.x-camX),Math.round(p.y-camY),2,2)}
  for(const f of floats){ctx.globalAlpha=Math.min(1,f.t*1.5);drawTextO(ctx,f.text,f.x-camX-textWM(f.text)/2,f.y-camY-4,f.col);ctx.globalAlpha=1}
  const g=player.boat?(player.boat.tgt&&player.boat.tgt[player.boat.tgt.length-1]):(player.path&&player.goal);if(g){const gx=Math.round(g.x-camX),gy=Math.round(g.y-camY),k=Math.floor(t*4)%2;R(ctx,gx-3-k,gy,2,1,'#fff6c0');R(ctx,gx+2+k,gy,2,1,'#fff6c0');R(ctx,gx,gy-2-k,1,1,'#fff6c0');R(ctx,gx,gy+2+k,1,1,'#fff6c0');P(ctx,gx,gy,'#ffd24d')}
  if(tapFx){const r=Math.round((.5-tapFx.t)*16);ctx.strokeStyle=`rgba(255,246,192,${tapFx.t*1.6})`;ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(Math.round(tapFx.x-camX)+.5,Math.round(tapFx.y-camY)+.5,3+r,1.5+r/2,0,0,6.283);ctx.stroke()}}
function edgeArrow(qx,qy,col){const cx=VW/2,cy=VH/2,a=Math.atan2(qy-cy,qx-cx);const k=Math.min((VW/2-12)/Math.abs(Math.cos(a)||1e-3),(VH/2-50)/Math.abs(Math.sin(a)||1e-3));const px=cx+Math.cos(a)*k,py=cy+Math.sin(a)*k;ctx.save();ctx.translate(Math.round(px),Math.round(py));ctx.rotate(a);ctx.fillStyle=OL;ctx.beginPath();ctx.moveTo(7,0);ctx.lineTo(-5,-6);ctx.lineTo(-5,6);ctx.fill();ctx.fillStyle=col;ctx.beginPath();ctx.moveTo(5,0);ctx.lineTo(-4,-4);ctx.lineTo(-4,4);ctx.fill();ctx.restore()}
function drawPlayer(t){const p=player;const f=p.moving?WALK[p.f]:0;const fishing=MG&&MG.type==='fish';
  drawChar(ctx,ACTIVE(),p.x-camX,p.y-camY,p.dir,fishing&&MG.state==='fight'?(Math.floor(t*8)%2?1:2):f);if(S.coop)drawBands(ctx,p.x-camX,p.y-camY,p.dir,COOPI[S.coop].col,false);
  if(isNft(ACTIVE())&&traits(ACTIVE()).rar===3){for(let i=0;i<3;i++){const a=t*2+i*2.1;P(ctx,Math.round(p.x-camX+Math.cos(a)*9),Math.round(p.y-camY-12+Math.sin(a*1.3)*8),'#fff6c0')}}
  if(fishing||(MG&&(MG.type==='dig'||MG.type==='salvage'))){const ic=uiIcon(fishing?'rod_'+S.gear.rod:MG.type==='dig'?'shovel':'grapple');const side=p.dir==='left'?-1:1;ctx.save();ctx.translate(Math.round(p.x-camX+side*7),Math.round(p.y-camY-10));if(p.dir==='left')ctx.scale(-1,1);ctx.rotate(fishing&&MG.state==='aim'?-.4-MG.pow*.6:.2);ctx.drawImage(ic,-8,-12);ctx.restore()}
  if(p.bubble)bubble(ctx,p.bubble.text,p.x-camX,p.y-camY-26);if(p.emote)drawEmote(p.emote.k,p.x-camX,p.y-camY-32,t)}
/* minimap */
let miniBase=null;const mini=$('mini'),mctx=mini.getContext('2d');
function buildMiniBase(){const Sc=WORLD;const[c,x]=mk(Sc.w,Sc.h);x.imageSmoothingEnabled=true;x.drawImage(Sc.ground,0,0,Sc.w,Sc.h);for(const p of Sc.props)if(p.sy-p.y>40&&p.img.width>=60){x.fillStyle='#c45a4a';x.fillRect(p.x/16|0,(p.sy/16|0)-2,p.img.width/16|0,2)}miniBase=c}
function drawMini(){const w=mini.width,h=mini.height;mctx.imageSmoothingEnabled=false;mctx.fillStyle='#0e1626';mctx.fillRect(0,0,w,h);
  if(scene!==WORLD){const Sc=scene;if(!Sc.ground)return;const k=Math.min((w-6)/(Sc.w*16),(h-6)/(Sc.h*16));const dw=Sc.w*16*k,dh=Sc.h*16*k,ox=(w-dw)/2,oy=(h-dh)/2;mctx.imageSmoothingEnabled=true;mctx.drawImage(Sc.ground,ox,oy,dw,dh);const px=ox+player.x*k,py=oy+player.y*k;mctx.fillStyle='#2b2130';mctx.fillRect(px-3,py-3,6,6);mctx.fillStyle='#ff7a6b';mctx.fillRect(px-2,py-2,4,4);return}
  if(!miniBase)buildMiniBase();const z=player.boat?1.4:2,vw=w/z,vh=h/z;const fx0=player.x/16,fy0=player.y/16;const cx=clamp(fx0-vw/2,0,WORLD.w-vw),cy=clamp(fy0-vh/2,0,WORLD.h-vh);mctx.drawImage(miniBase,cx,cy,vw,vh,0,0,w,h);
  const dot=(tx,ty,c,s=3)=>{mctx.fillStyle=c;mctx.fillRect(Math.round((tx-cx)*z-s/2),Math.round((ty-cy)*z-s/2),s,s)};
  for(const pe of NET.peers.values())if(pe.sc==='world')dot(pe.x/16,pe.y/16,'#7fdcc0',3);for(const p of S.pots)dot(p.x/16,p.y/16,'#ffd24d',3);
  if(S.boat&&!player.boat){const sp=myBoatSpot();dot(sp.x/16,sp.y/16,'#bfe8f4',4)}for(const hs of HOTS)dot(hs.x/16,hs.y/16,'#ffffff',2);
  dot(fx0,fy0,'#ffffff',4);dot(fx0,fy0,'#e9675a',2)}
