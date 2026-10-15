/* ================= mini-games: Fishing 2.0, digging, salvage and pot hauling =================
   One overlay, one canvas (200x84 pixels), one input: the big button, Space, or a tap on the canvas.
   Each game is an object with update(dt), draw(g,t), down() and up(). The world renderer reads MG.bx/by,
   MG.state, MG.e, MG.nib and MG.pow to draw the line and float in the harbour itself. */
const MGW=200,MGH=84;const mgcv=$('mgCv'),mgc=mgcv.getContext('2d');mgc.imageSmoothingEnabled=false;
function mgOpen(o){if(MG)closeMG(true);cancelPath();MG=Object.assign({t:0,t0:0,e:0,fx:[],pops:[],shake:0,ended:false},o);$('mg').hidden=false;$('mgTitle').textContent=o.title;mgText(o.hint||'');mgStat('');mgBtn(o.btn||'Tap',o.icon||'hand');$('btn2').hidden=true;drawMG()}
function mgBtn(label,icon){const b=$('btnAct');b.classList.remove('idle','bad','sea');b.classList.add('go');$('actLabel').textContent=label;if(icon)paintIcon($('actIcon'),uiIcon(icon))}
function closeMG(silent){if(!MG)return;const m=MG;MG=null;$('mg').hidden=true;curAct=null;setActButton(null);if(!m.ended&&m.onQuit&&!silent)m.onQuit()}
function mgEnd(delay,fn){const m=MG;if(!m||m.ended)return;m.ended=true;setTimeout(()=>{if(MG===m){MG=null;$('mg').hidden=true;curAct=null;setActButton(null)}fn&&fn()},delay*1000)}
function mgText(s){$('mgTxt').textContent=s}
function mgStat(s){$('mgStat').textContent=s}
function mgPop(text,col,x,y,big){if(!MG)return;if(!big)MG.pops=MG.pops.filter(p=>p.big);MG.pops.push({text:String(text),col,x,y,t:.9,big})}
function mgBurst(x,y,cols,n=8,sp=60){if(!MG)return;for(let i=0;i<n;i++){const a=Math.random()*6.283,s=sp*(.4+Math.random()*.8);MG.fx.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s-sp*.5,t:.35+Math.random()*.35,c:cols[i%cols.length]})}}
function mgTick(dt){const m=MG;m.t+=dt;m.e=m.t-m.t0;if(m.shake>0)m.shake=Math.max(0,m.shake-dt*3);for(let i=m.pops.length-1;i>=0;i--){m.pops[i].t-=dt;m.pops[i].y-=dt*10;if(m.pops[i].t<=0)m.pops.splice(i,1)}
  for(let i=m.fx.length-1;i>=0;i--){const p=m.fx[i];p.t-=dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.vy+=160*dt;if(p.t<=0)m.fx.splice(i,1)}}
function drawMG(){const m=MG;if(!m)return;const g=mgc;g.save();g.clearRect(0,0,MGW,MGH);if(m.shake>0)g.translate(Math.round((Math.random()-.5)*m.shake*6),Math.round((Math.random()-.5)*m.shake*3));
  m.draw(g,m.t);for(const p of m.fx){g.fillStyle=p.c;g.fillRect(Math.round(p.x),Math.round(p.y),2,2)}
  for(const p of m.pops){g.globalAlpha=Math.min(1,p.t*2);const w=textWM(p.text);if(p.big)bigText(g,p.text,Math.round(p.x-w),Math.round(p.y-4),p.col);else drawTextO(g,p.text,p.x-w/2,p.y-2,p.col)}g.globalAlpha=1;g.restore()}
mgcv.addEventListener('pointerdown',e=>{e.preventDefault();audioUnlock();if(MG&&MG.down&&!MG.ended){actHeld=true;MG.down()}});
mgcv.addEventListener('pointerup',e=>{e.preventDefault();if(MG&&MG.up&&!MG.ended){actHeld=false;MG.up()}});mgcv.addEventListener('pointercancel',()=>{if(MG&&MG.up)MG.up()});
$('mgX').addEventListener('click',()=>closeMG());
/* drawing helpers */
const frame=(g,x,y,w,h,bg)=>{R(g,x-1,y-1,w+2,h+2,OL);R(g,x,y,w,h,bg)};
function bigText(g,s,x,y,col,sc=2){const a=fmCanvas(s,OL),b=fmCanvas(s,col);const w=a.width,h=a.height;for(const[ox,oy]of[[-1,0],[1,0],[0,-1],[0,1],[1,1]])g.drawImage(a,0,0,w,h,x+ox*sc/2,y+oy*sc/2,w*sc,h*sc);g.drawImage(b,0,0,w,h,x,y,w*sc,h*sc)}
function pips(g,x,y,n,on,col){for(let i=0;i<n;i++){R(g,x+i*6,y,5,5,OL);R(g,x+i*6+1,y+1,3,3,i<on?col:'#22344e')}}
function shadeHex(hex,k){const n=parseInt(hex.slice(1),16);const f=v=>Math.max(0,Math.min(255,Math.round(v*k)));return'#'+((1<<24)+(f(n>>16)<<16)+(f(n>>8&255)<<8)+f(n&255)).toString(16).slice(1)}
// a side-on slice of sea: sky, surface and the water of this zone, getting darker with depth
function seaSide(g,t,zone,surf){const ph=dayPhase();const night=ph.a>.25;const E=envAt();const sky=night?['#141c3a','#1e2a4e']:ph.dusk>.08?['#f0a070','#f6c890']:E.sky==='storm'?['#4a5468','#5e687c']:E.sky==='rain'||E.sky==='fog'?['#8a98a8','#a8b4c0']:['#7fc8ec','#b4e2f4'];
  for(let y=0;y<surf;y++)R(g,0,y,MGW,1,y<surf*.5?sky[0]:sky[1]);if(night)for(let i=0;i<9;i++)P(g,(i*53+7)%MGW,(i*17+3)%Math.max(2,surf-4),'#e8ecff');
  const base=(ZONES[zone]||ZONES.harbour).col;for(let y=surf;y<MGH;y++){const k=1-(y-surf)/(MGH-surf)*.55;R(g,0,y,MGW,1,shadeHex(base,(night?.55:1)*k))}
  const amp=E.sky==='storm'?2:E.sky==='windy'?1.4:.7;for(let x=0;x<MGW;x+=2){const h=Math.round(Math.sin(x*.12+t*3)*amp+Math.sin(x*.05-t*1.7)*amp*.6);R(g,x,surf+h-1,2,2,'#e8fbff')}
  for(let i=0;i<10;i++){const x=Math.round((i*41+t*(6+i%3*3))%(MGW+20))-10,y=surf+6+(i*19)%(MGH-surf-8);R(g,x,y,4,1,shadeHex(base,1.25))}}
/* ================= 1. FISHING 2.0: cast, the wait, the bite, the fight and the landing ================= */
const BITE_STYLE={torp:'run',tuna:'run',mahi:'run',marlin:'run',sail:'run',flying:'run',shark:'slam',deep:'slam',grouper:'slam',angler:'slam',boar:'slam',hump:'slam',flathead:'soft',ray:'soft',guitar:'soft',eel:'soft',ribbon:'soft',crab:'soft',lobster:'soft',squid:'soft',cuttle:'soft',octo:'soft',seahorse:'soft',dragon:'soft'};
function biteStyle(e){if(e.cat==='legend')return'slam';if(e.cat!=='fish')return'soft';return BITE_STYLE[String(e.art).split('|')[0]]||(e.r>=2?'run':'nibble')}
// how hard a fish fights before your gear is counted
function fishPower(e,kg){if(e.cat!=='fish'&&e.cat!=='legend')return .3+e.r*.14;return Math.log10((kg||.2)+1)*.9+e.r*.22+(e.cat==='legend'?1.6:0)+.25}
const STYLE_TXT={nibble:'Little taps first, then it takes it.',run:'It hits and runs. The float shoots sideways.',slam:'No warning. The float just goes.',soft:'A slow, soft sink. Easy to miss.'};
function startFishing(w){if(MG)return;if(scene!==WORLD)return;
  if(S.baitSel!=='dough'&&baitCount(S.baitSel)<=0)S.baitSel='dough';
  const rod=GEAR.rod[S.gear.rod],reel=GEAR.reel[S.gear.reel],line=GEAR.line[S.gear.line];const boat=!!w.boat;const sx=boat?player.boat.x:player.x,sy=boat?player.boat.y:player.y;
  let dx=w.x-sx,dy=w.y-sy;const dl=Math.hypot(dx,dy)||1;dx/=dl;dy/=dl;if(!boat)player.dir=faceFrom(dx,dy,player.dir);
  const B=BAIT[S.baitSel];
  const G={type:'fish',title:(boat?'':'Shore · ')+(ZONES[w.zone]?ZONES[w.zone].n:'Gullhaven'),hint:'Hold to wind up the cast. Let go at the top for a long one.',btn:'Hold',icon:'rod_'+S.gear.rod,
    state:'aim',zone:w.zone,boat,sx,sy,dx,dy,rod,reel,line,pow:0,ht:0,hold:false,bx:null,by:null,nib:0,
    st(s){this.state=s;this.t0=this.t;this.e=0},
    // where the float lands: further with a better rod and a fuller swing, always on water
    land(){const reach=(boat?34:30)+this.pow*this.rod.cast*(boat?96:110);let x=this.sx,y=this.sy,ok=null;for(let d=12;d<=reach;d+=4){const px=this.sx+this.dx*d,py=this.sy+this.dy*d;if(isWaterPx(px,py)){ok=[px,py];x=px;y=py}else if(ok&&!boat)break}
      if(!ok){x=w.x;y=w.y}this.bx=x;this.by=y;this.cx=x;this.cy=y;const z=zoneAtPx(x,y)||w.zone;this.zone=z;if(MG===this)$('mgTitle').textContent=(boat?'':'Shore · ')+(ZONES[z]?ZONES[z].n:'Gullhaven')},
    roll(){const sh=shadowAt(this.bx,this.by,26);this.shadow=sh;const ctx={zone:this.zone,bait:S.baitSel,gear:gearCtx(),env:envAt(),near:nearFeatures(this.bx,this.by),shadowR:sh?sh.r:null};
      if(CHAIN.live){this.waitSrv=true;NET.req({t:'cast',zone:this.zone,bait:S.baitSel,shadow:ctx.shadowR,near:Object.keys(ctx.near),x:Math.round(this.bx),y:Math.round(this.by),gear:S.gear}).then(r=>{if(MG!==this||this.ended)return;this.waitSrv=false;if(!r||!r.ok){this.fail(r&&r.err||'The harbour server did not answer.');return}if(!r.id){this.hook=null;return}this.tok=r.tok;this.hook={e:CATI[r.id],cm:r.cm,v:r.v||'',kg:r.kg};this.prep()});return}
      this.hook=rollHook(ctx);if(this.hook)this.prep()},
    prep(){const h=this.hook,e=h.e;this.style=biteStyle(e);const P=fishPower(e,h.kg);this.F=P/this.rod.power;this.isFish=e.cat==='fish'||e.cat==='legend';
      let wait=2+Math.random()*4.5;if(this.shadow)wait=1+Math.random()*2;if(B.night&&isNightNow())wait*=.8;if(S.gear.lamp>=0&&isNightNow()&&boat)wait*=.85;if(e.cat==='legend')wait+=2;this.biteAt=Math.max(this.e+.8,wait);
      this.nibbles=this.style==='nibble'?1+Math.floor(Math.random()*3):0;this.nextNib=this.biteAt-(this.nibbles*.7)-.2;
      this.win=({nibble:.85,run:.62,slam:.5,soft:1.15})[this.style]*(e.r>=3?.85:1)},
    update(dt){if(this.ended)return;const e=this.e;if(this.nib>0)this.nib-=dt;
      if(this.state==='aim'){if(this.hold){this.ht+=dt;this.pow=.5-.5*Math.cos(this.ht*3.1)}mgStat(this.hold?Math.round(this.pow*100)+'%':'');return}
      if(this.state==='cast'){if(e>.5){this.st('wait');sfx('splash');splash(this.bx,this.by,5);this.roll();mgText(B.lure?`Working the ${B.n.toLowerCase()}... wait for a real bite.`:'Watch the float. Ignore the little nibbles.');mgBtn('Strike','hook')}return}
      if(this.state==='wait'){
        // fake nibbles keep you honest
        if(Math.random()<dt*.35&&!this.waitSrv&&(!this.hook||e<this.biteAt-1.2)){this.nib=.22;this.fake=.22;sfx('tick')}if(this.fake>0)this.fake-=dt;
        if(this.hook){if(this.nibbles>0&&e>=this.nextNib){this.nibbles--;this.nextNib=e+.55+Math.random()*.35;this.nib=.25;this.fake=0;sfx('tick');mgPop('nibble','#c9f5e6',60+Math.random()*60,26)}
          if(e>=this.biteAt){this.st('bite');sfx('bite');if(this.style==='slam')this.shake=.8;player.emote={k:'star',t:.9};mgText('!!  STRIKE  !!');mgBtn('STRIKE!','hook');$('btnAct').classList.add('bad')}}
        else if(!this.waitSrv&&e>9){this.fail('Nothing is biting here right now. Try another spot, bait or time of day.',true)}
        return}
      if(this.state==='bite'){if(this.style==='run'){this.bx+=this.dx*-12*dt+this.dy*24*dt;this.by+=this.dy*-12*dt-this.dx*24*dt}if(e>this.win){this.lose(this.isFish?'Too slow. It spat the hook.':'It slipped off the hook.',false)}return}
      if(this.state==='fight'){this.fight(dt);return}
      if(this.state==='land'){this.lp+=this.ld*dt*this.lspd;if(this.lp>1){this.lp=1;this.ld=-1}if(this.lp<0){this.lp=0;this.ld=1}if(e>6)this.lose('It shook free at the side of the boat.',false)}},
    fight(dt){const F=this.F,reel=this.reel,line=this.line;const tired=this.sta<.15;
      // the fish's runs: more often and longer when it is fresh and strong
      if(this.running>0){this.running-=dt;this.sta-=dt*.05/(.5+F*.4);if(this.running<=0){this.running=0;this.nextRun=(1.4+Math.random()*2.4)/(.5+Math.min(F,2.5)*.45)*(1.6-this.sta*.8);mgText(tired?'It is tiring. Reel it in!':'Reel while it rests.')}}
      else if(this.isFish&&!tired){this.nextRun-=dt;if(this.nextRun<=0){this.running=(.6+Math.random()*.9)*(.6+Math.min(F,2.5)*.35)*(.5+this.sta*.5);sfx('reel');this.shake=.4;mgText('It is running! Let go and let it take line.');mgPop('RUN!','#ff7a6b',60,18)}}
      const pull=F/reel.drag/(.55+.45*line.str);const hold=this.hold;const run=this.running>0;
      const target=hold?(run?.42+pull*1.25:.3+pull*.3):(run?pull*.35:0);this.T+=(target-this.T)*Math.min(1,dt*(target>this.T?3.2:2.4));if(run)this.T+=Math.sin(this.t*23)*.012;
      if(hold&&!run)this.dist-=dt*reel.speed*.13*(tired?1.6:1)/(.45+Math.min(F,3)*.3);else if(run)this.dist+=dt*(hold?.02*F:.075*F/reel.drag);
      if(hold)this.sta-=dt*(run?.04:.025)/(.5+F*.4);else this.sta-=dt*.008;this.sta=Math.max(0,this.sta);
      if(this.T>1){this.over+=dt;if(this.over>.3){this.snap();return}}else this.over=Math.max(0,this.over-dt);
      if(this.T<.08&&!run){this.slack+=dt;if(this.slack>1.7){this.lose(this.isFish?'Too much slack. It threw the hook.':'Too much slack. It dropped off.',false);return}}else this.slack=Math.max(0,this.slack-dt*2);
      if(this.dist>1.25){this.lose('Spooled! It took all your line. A stronger reel and line would hold it.',true);return}
      // the float follows the fish in the world
      const k=Math.max(.06,this.dist/this.dist0);const wob=run?4:1.5;this.bx=this.sx+(this.cx-this.sx)*k+Math.sin(this.t*5)*wob;this.by=this.sy+(this.cy-this.sy)*k+Math.cos(this.t*4)*wob*.6;
      mgStat(this.T>.85?'Line straining!':this.slack>.6?'Slack line!':run?'RUNNING':tired?'Tired':'');
      if(this.dist<=.04){const e=this.hook.e;if(!this.isFish||this.hook.kg<1.5){this.landed();return}this.st('land');this.lp=Math.random();this.ld=1;this.lspd=1.1+Math.min(F,2.5)*.35;this.lw=clamp(.3-Math.min(F,2.5)*.06,.12,.3);this.lc=.2+Math.random()*.6;this.gaff=this.hook.kg>8;mgText(this.gaff?'Alongside! Gaff it when the hook lines up.':'Alongside! Net it when the hoop lines up.');mgBtn(this.gaff?'Gaff':'Net','net');sfx('splash');this.shake=.3}},
    snap(){S.stats.lost++;loseLure();this.shake=1;sfx('snap');mgPop('SNAP!','#ff7a6b',100,14,1);this.lose(`The line snapped. ${this.line.str<2?'Heavier line holds bigger fish.':'Let go when it runs.'}`,true,true)},
    lose(msg,gearMsg,snapped){if(this.ended)return;if(!snapped){S.stats.lost++;sfx('error')}if(this.tok)wsSend({t:'lost',tok:this.tok});const e=this.hook&&this.hook.e;const hint=e&&this.isFish?` It felt like ${e.r>=3?'something huge':this.hook.kg>5?'a big one':'a decent fish'}.`:'';
      this.st('done');mgText(msg+hint);markDirty();mgEnd(1.6,()=>{})},
    fail(msg){if(this.ended)return;this.st('done');mgText(msg);mgEnd(1.6,()=>{})},
    async landed(){if(this.ended)return;this.st('done');const h=this.hook;sfx('catch');mgPop(h.e.cat==='legend'?'LEGEND!':'LANDED!','#ffd24d',100,14,1);mgBurst(150,40,['#fff6c0','#7fdcc0','#ffffff'],14,70);
      let pts=null;if(this.tok){const r=await NET.req({t:'land',tok:this.tok});if(!r||!r.ok){mgText((r&&r.err)||'The server did not count that one.');mgEnd(1.4,()=>{});return}if(r.acct)applyAcct(r.acct);pts=r.pts||0;if(r.bounty)setTimeout(()=>toast(`Legendary bounty: +${fmt(r.bounty)} Shells`,'rare'),2500)}
      mgEnd(.7,()=>onCatch(h,'rod',pts!=null?{serverPts:pts}:{}))},
    down(){if(this.ended)return;this.hold=true;const e=this.e;
      if(this.state==='aim'){this.ht=0;this.pow=0;mgText('Let go at the top of the swing for a long cast.');return}
      if(this.state==='wait'){if(this.nib>0||this.fake>0){this.lose(this.hook?'Too soon! That was a nibble and you pulled it away.':'Just a nibble. Wait for the real bite.',false)}else this.lose('Too early. Nothing had it yet.',false);return}
      if(this.state==='bite'){sfx('reel');this.st('fight');this.T=.35;this.dist=this.dist0=.45+this.pow*.55;this.sta=1;this.running=0;this.nextRun=.8+Math.random()*1.2;this.over=0;this.slack=0;
        if(this.style==='run'||this.style==='slam'){this.running=.8+Math.random()*.6}
        if(this.shadow){const i=SHADOWS.indexOf(this.shadow);if(i>=0)SHADOWS.splice(i,1)}
        mgText(this.isFish?'Hold to reel. When it runs, let go!':'Something heavy. Not a fish... reel it up steady.');mgBtn('Reel','reel');$('btnAct').classList.remove('bad');return}
      if(this.state==='land'){const d=Math.abs(this.lp-this.lc);if(d<this.lw/2){mgPop(d<this.lw/5?'Perfect!':'Got it!','#ffd24d',150,20);this.landed()}else{this.miss=(this.miss||0)+1;sfx('miss');this.shake=.5;if(this.miss>=3){this.lose('Three misses and it was gone.',false);return}mgPop('Missed!','#ff7a6b',150,20);this.st('fight');this.dist=.28;this.sta=Math.min(1,this.sta+.2);this.running=.7;this.T=.4;mgText('It made another run. Bring it back!');mgBtn('Reel','reel')}}},
    up(){this.hold=false;if(this.state==='aim'&&this.ht>.05){const p=this.pow;S.stats.casts++;if(!B.lure&&S.baitSel!=='dough')useBait(S.baitSel);this.land();this.st('cast');sfx('cast');mgPop(p>.92?'Perfect cast!':p>.6?'Nice cast':'Short cast',p>.92?'#ffd24d':'#c9f5e6',100,16);mgText('...');markDirty();updHUD()}},
    onQuit(){if(this.state==='fight'||this.state==='land'){S.stats.lost++;if(this.tok)wsSend({t:'lost',tok:this.tok})}},
    draw(g,t){const s=this.state,e=this.e,surf=26;seaSide(g,t,this.zone,surf);const tipX=186,tipY=8;
      // your rod tip on the right, bent by the fight
      const bend=s==='fight'?Math.min(10,this.T*10):s==='land'?6:0;g.strokeStyle=OL;g.lineWidth=2;g.beginPath();g.moveTo(199,26);g.quadraticCurveTo(194,14,tipX-bend*.6,tipY+bend);g.stroke();g.lineWidth=1;g.strokeStyle='#c8a070';g.beginPath();g.moveTo(199,26);g.quadraticCurveTo(194,14,tipX-bend*.6,tipY+bend);g.stroke();
      const tx=tipX-bend*.6,ty=tipY+bend;
      if(s==='aim'){frame(g,18,62,164,10,'#16233a');const w=Math.round(this.pow*164);R(g,18,62,w,10,this.pow>.92?'#ffd24d':this.pow>.6?'#8fffb0':'#7fdcc0');R(g,18+Math.round(164*.92),62,1,10,'#fff3b0');drawTextO(g,'POWER',18,51,'#fbf1dc');
        drawTextO(g,`${B.n}${B.lure?'':S.baitSel==='dough'?'':' ('+baitCount(S.baitSel)+')'}`,8,4,'#fbf1dc');g.drawImage(uiIcon('bait_'+S.baitSel),8+textWM(B.n)+(B.lure||S.baitSel==='dough'?6:24),2);bigText(g,this.hold?'LET GO!':'HOLD',this.hold?66:80,32,'#fbf1dc');return}
      const fx2=Math.round(tipX-30-this.pow*130);
      if(s==='cast'){const k=Math.min(1,e/.5);const x=tx+(fx2-tx)*k,y=ty+(surf-ty)*k-Math.sin(k*Math.PI)*18;g.strokeStyle='rgba(255,255,255,.8)';g.beginPath();g.moveTo(tx,ty);g.lineTo(x,y);g.stroke();stamp(g,['.k.','kRk','kWk','.k.'],{k:OL,R:'#e9675a',W:'#ffffff'},Math.round(x-1),Math.round(y-2));return}
      if(s==='wait'||s==='bite'){let fx=fx2,dip=this.nib>0?2:Math.round(Math.sin(t*3)*.6);let fy=surf-2+dip;if(s==='bite'){if(this.style==='run'){fx=fx2-Math.round(e*60)}else if(this.style==='soft'){fy=surf-2+Math.min(7,Math.round(e*8))}else fy=surf+3+Math.round(Math.sin(t*30))}
        g.strokeStyle='rgba(255,255,255,.75)';g.beginPath();g.moveTo(tx,ty);g.quadraticCurveTo((tx+fx)/2,surf-6,fx,fy);g.stroke();R(g,fx,fy+3,1,22,'rgba(255,255,255,.35)');P(g,fx,fy+25,'#ffd24d');
        // something circling the bait
        const sz=this.hook?Math.min(14,5+sizeClass(this.hook.e)*3):this.shadow?5+this.shadow.r*3:5;const cx=fx+Math.sin(t*1.2)*(s==='bite'?3:22),cy=surf+28+Math.cos(t*.9)*4;g.globalAlpha=.35;ell(g,cx,cy,sz,sz*.45,'#0a1424');g.globalAlpha=1;
        stamp(g,['.k.','kRk','kWk','.k.'],{k:OL,R:'#e9675a',W:'#ffffff'},Math.round(fx-1),Math.round(fy-2));
        if(s==='bite'){const f=Math.floor(t*12)%2;bigText(g,'!',fx-3,surf-24,f?'#ffd24d':'#ff7a6b',3);const left=1-e/this.win;R(g,fx-12,surf-30,24,3,OL);R(g,fx-11,surf-29,Math.max(0,Math.round(22*left)),1,'#ffd24d')}
        if(this.waitSrv)drawTextO(g,'...',8,4,'#fbf1dc');return}
      if(s==='fight'||s==='land'||(s==='done'&&this.dist!=null)){const h=this.hook,E2=h.e;const known=logged(E2.id);const run=this.running>0;
        // the fish on the line (a silhouette until it is in your Logbook)
        const sw=this.isFish?(known?swimArt(E2.id):null):null;const art=sw||catArt(E2.id,known?'':'s');const k=this.isFish?clamp(1-(this.dist||0)/1.25,0,1):1-(this.dist||0)/1.25;
        let px=s==='land'?150:14+k*150,py=s==='land'?surf+2+Math.round(Math.sin(t*6)*2):surf+22+Math.round(Math.sin(t*(run?14:4))*(run?4:2));
        const aw=Math.min(36,art.width),ah=Math.round(art.height*aw/art.width);g.strokeStyle=this.T>.85?'#ff9f8a':'rgba(255,255,255,.9)';g.beginPath();g.moveTo(tx,ty);g.lineTo(px+(sw?-aw/2+2:0),py);g.stroke();
        g.save();g.translate(Math.round(px),Math.round(py));if(sw&&!run)g.scale(-1,1);g.drawImage(art,Math.round(-aw/2),Math.round(-ah/2),aw,ah);g.restore();if(run&&Math.random()<.5)mgBurst(px-aw/2,py-2,['#e8fbff','#9adcf0'],2,30);
        drawTextO(g,known||!this.isFish?(known?E2.n:'Something heavy'):'???',6,4,known?'#fbf1dc':'#c9d8f0');const kgT=this.isFish?'about '+kgTxt(h.kg):'';if(kgT)drawTextO(g,kgT,6,14,'#c9f5e6');
        if(s==='land'){frame(g,110,64,80,10,'#16233a');const lx=110+Math.round((this.lc-this.lw/2)*80);R(g,lx,64,Math.round(this.lw*80),10,'#5fcf7a');R(g,110+Math.round((this.lc-this.lw/5)*80),64,Math.max(2,Math.round(this.lw*.4*80)),10,'#ffd24d');const mx=110+Math.round(this.lp*80);R(g,mx-1,61,3,16,OL);R(g,mx,62,1,14,'#ffffff');bigText(g,this.gaff?'GAFF!':'NET!',8,58,'#ffd24d');pips(g,150,4,3,3-(this.miss||0),'#8fffb0');return}
        // tension gauge: green is safe, red snaps the line
        const TX=8,TW=132,TY=70;frame(g,TX,TY,TW,8,'#16233a');R(g,TX+Math.round(TW*.85),TY,Math.round(TW*.15),8,'#5a2028');R(g,TX,TY,Math.round(TW*.08),8,'#2a3a58');const tw=Math.round(TW*clamp(this.T,0,1));R(g,TX,TY,tw,8,this.T>.85?'#ff5a4a':this.T>.6?'#ffd24d':'#5fcf7a');R(g,TX,TY,tw,2,'rgba(255,255,255,.35)');drawTextO(g,'TENSION',TX,TY-11,'#fbf1dc');
        if(this.T>.85&&Math.floor(t*8)%2)drawTextO(g,'LET GO!',TX+TW-40,TY-11,'#ff7a6b');else if(this.slack>.6&&Math.floor(t*6)%2)drawTextO(g,'SLACK!',TX+TW-36,TY-11,'#ffd24d');
        if(this.isFish){drawTextO(g,'FIGHT',150,TY-11,'#fbf1dc');frame(g,150,TY,44,8,'#16233a');R(g,150,TY,Math.round(44*this.sta),8,'#ff9f8a')}else{drawTextO(g,'DEPTH',150,TY-11,'#fbf1dc');frame(g,150,TY,44,8,'#16233a');R(g,150,TY,Math.round(44*clamp(this.dist/1.25,0,1)),8,'#7fdcc0')}
        if(run&&Math.floor(t*6)%2)bigText(g,'RUN!',72,2,'#ff7a6b')}}};
  mgOpen(G)}
/* ================= 2. BEACHCOMBING: dig in the sand, turn rocks in the pools ================= */
function startDig(c){if(MG)return;if(S.comb.dug.includes(c.i)){toast('Already dug here.');return}player.dir=faceFrom(c.x-player.x,c.y-player.y,player.dir);const rocks=c.where==='rocks';
  const G={type:'dig',title:rocks?'Rock pool':'Beachcombing',hint:rocks?'Tap when your hand is over the glint to turn the rock.':'Tap when the spade is over the glint. Three good digs finds it.',btn:rocks?'Lift':'Dig',icon:rocks?'hand':'shovel',
    pos:.1,dir:1,spd:.85+Math.random()*.3,hits:0,need:rocks?2:3,miss:0,maxMiss:4,cool:0,
    roll(){let c2=.12+Math.random()*.76;if(Math.abs(c2-this.pos)<.2)c2=c2>.5?c2-.35:c2+.35;this.tgt=clamp(c2,.1,.9);this.w=rocks?.16:.13},
    update(dt){if(this.ended)return;this.pos+=this.dir*this.spd*(1+this.hits*.18)*dt;if(this.pos>1){this.pos=1;this.dir=-1}if(this.pos<0){this.pos=0;this.dir=1}if(this.cool>0)this.cool-=dt;mgStat(`${this.hits}/${this.need}`)},
    down(){if(this.ended||this.cool>0)return;this.cool=.2;player.swing=.25;const x=20+this.pos*160;if(Math.abs(this.pos-this.tgt)<this.w/2){this.hits++;sfx(rocks?'clang':'thud');mgPop(rocks?'Lift!':'Dig!','#ffd24d',x,30);mgBurst(x,50,rocks?['#8a8478','#b8b0a0','#5a7a8a']:['#e8d29a','#c8b070','#fff4c8'],10,70);this.shake=.3;
        if(this.hits>=this.need){sfx('perfect');mgPop('FOUND IT!','#ffd24d',100,10,1);mgEnd(.7,()=>dugSpot(c));return}this.roll()}
      else{this.miss++;sfx('miss');mgPop('Miss','#c9c0d8',x,30);if(this.miss>=this.maxMiss){mgText(rocks?'The rock would not budge. The tide will bring more.':'The hole caved in. Nothing here.');S.comb.dug.push(c.i);markDirty();mgEnd(1.2,()=>{})}}},
    up(){},
    draw(g,t){if(rocks){R(g,0,0,MGW,MGH,'#5a6a6a');for(let i=0;i<40;i++){const x=(i*47)%MGW,y=(i*29)%MGH;ell(g,x,y,6+(i%4)*2,3+(i%3),i%2?'#4a5858':'#6a7a78')}R(g,10,30,180,40,'#2f6f86');for(let x=10;x<190;x+=6)P(g,x+((t*10|0)%6),34+(x%5),'#5fb0c8');ell(g,100,52,30,12,'#7a7468');ell(g,100,49,28,10,'#9a9284')}
      else{R(g,0,0,MGW,MGH,'#e8d29a');for(let y=40;y<MGH;y+=8)R(g,0,y,MGW,4,'#d8be84');for(let i=0;i<60;i++)P(g,(i*37)%MGW,(i*23)%MGH,i%3?'#c8ac70':'#fff4c8');const d=this.hits/this.need;ell(g,100,56,22+d*10,6+d*6,'#b8955c');ell(g,100,57,16+d*8,4+d*5,'#8a6a3a')}
      const X=20,W=160,Y=14;frame(g,X,Y,W,8,rocks?'#3a4a4a':'#b8955c');const gx=X+this.tgt*W;R(g,Math.round(gx-this.w*W/2),Y,Math.round(this.w*W),8,'rgba(255,240,160,.6)');if(Math.floor(t*6)%2){P(g,Math.round(gx),Y-3,'#ffffff');P(g,Math.round(gx)-3,Y+11,'#ffffff');P(g,Math.round(gx)+3,Y+10,'#fff4c8')}
      const px=X+this.pos*W;g.drawImage(uiIcon(rocks?'hand':'shovel'),Math.round(px-8),Y-14);R(g,Math.round(px),Y,1,8,'#ffffff');pips(g,6,74,this.need,this.hits,'#ffd24d');pips(g,MGW-6-this.maxMiss*6,74,this.maxMiss,this.maxMiss-this.miss,'#8fffb0')}};
  G.roll();mgOpen(G)}
/* ================= 3. SALVAGE: drop the grapple onto the wreck and haul it up ================= */
function startSalvage(s){if(MG)return;if(!salvageReady(s)){const i=WORLD.salvage.indexOf(s);const left=SALV_COOL-(Date.now()-(S.salv[i]||0));toast(`You grappled here recently. Try again in ${Math.ceil(left/60000)} town hours.`);return}
  if(ZONES[s.zone]&&ZONES[s.zone].need>boatTier()){toast('This site is too far out for your boat.');return}
  const G={type:'salvage',title:'Salvage · '+(ZONES[s.zone]?ZONES[s.zone].short:'wreck'),hint:'Hold to lower the grapple. Let it rest on the glint until it bites.',btn:'Lower',icon:'grapple',
    state:'drop',d:0,band:.55+Math.random()*.25,bw:.12,rest:0,hold:false,slips:0,sw:0,load:.5,
    update(dt){if(this.ended)return;const t=this.t;
      if(this.state==='drop'){this.band+=Math.sin(t*.9)*dt*.05;if(this.hold){this.d=Math.min(1,this.d+dt*.32);if(this.d>=1){this.d=.92;sfx('clang');mgPop('Bottom','#c9c0d8',100,40)}}
        if(!this.hold&&Math.abs(this.d-this.band)<this.bw/2){this.rest+=dt;if(this.rest>.7){this.state='haul';sfx('clang');this.shake=.5;mgPop('HOOKED!','#ffd24d',100,14,1);mgText('Hold to haul. Ease off when the load swings red.');mgBtn('Haul','grapple')}}else this.rest=0;mgStat(Math.round(this.d*40)+' m')}
      else if(this.state==='haul'){this.sw=Math.sin(t*(2.2+this.slips*.4))*.5+.5;const red=this.sw>.78;if(this.hold){this.d-=dt*.2;if(red){this.strain=(this.strain||0)+dt*2.2;if(this.strain>1){this.strain=0;this.slips++;this.d=Math.min(1,this.d+.18);sfx('snap');this.shake=.7;mgPop('Slipped!','#ff7a6b',100,30);if(this.slips>=3){mgText('The grapple tore free. The site is still there for next time.');mgEnd(1.4,()=>{});return}}}}else this.strain=Math.max(0,(this.strain||0)-dt);
        if(this.d<=0){sfx('splash');mgPop('UP!','#ffd24d',100,14,1);mgEnd(.7,()=>salvageDone(s))}mgStat(Math.round(this.d*40)+' m')}},
    down(){this.hold=true},up(){this.hold=false},
    draw(g,t){seaSide(g,t,s.zone,10);R(g,0,74,MGW,10,'#3a3428');for(let x=0;x<MGW;x+=7)P(g,x,74+(x%3),'#5a5040');
      // the wreck on the bottom, the glint where a grapple can bite
      R(g,40,62,120,12,'#4a3a2a');R(g,44,58,40,4,'#5a4632');R(g,120,54,8,20,'#3a2e22');for(let i=0;i<6;i++)R(g,52+i*16,64,2,8,'#2a2018');
      const by=10+this.band*64;g.fillStyle='rgba(255,240,160,.18)';g.fillRect(70,Math.round(by-this.bw*32),60,Math.round(this.bw*64));if(Math.floor(t*5)%2)P(g,100,Math.round(by),'#ffffff');
      const gy=10+this.d*64;const swing=this.state==='haul'?(this.sw-.5)*10:Math.sin(t*2)*2;R(g,100,0,1,Math.round(gy),'#d8d0c0');g.drawImage(uiIcon('grapple'),Math.round(100+swing-8),Math.round(gy-4));
      if(this.state==='drop'&&this.rest>0){R(g,84,Math.round(gy)+14,Math.round(32*Math.min(1,this.rest/.7)),2,'#ffd24d')}
      if(this.state==='haul'){frame(g,8,20,8,50,'#16233a');const h=Math.round(50*this.sw);R(g,8,70-h,8,h,this.sw>.78?'#ff5a4a':'#5fcf7a');R(g,8,20,8,Math.round(50*.22),'rgba(255,90,74,.35)');drawTextO(g,'LOAD',4,8,'#fbf1dc');pips(g,170,4,3,3-this.slips,'#8fffb0')}}};
  mgOpen(G)}
/* ================= 4. POTS: winch the pot up between the swells ================= */
function startPotHaul(p,cb){if(MG)return;
  const G={type:'pot',title:'Haul pot · '+(ZONES[p.zone]?ZONES[p.zone].short:''),hint:'Hold to winch. Ease off when a swell lifts the boat.',btn:'Winch',icon:'pot',prog:0,hold:false,strain:0,ph:Math.random()*6,per:1.4+Math.random()*.6,
    update(dt){if(this.ended)return;const sw=Math.sin(this.t*6.283/this.per+this.ph);this.surge=sw>.55;if(this.hold){if(this.surge){this.strain+=dt*2.4;if(this.strain>1){this.strain=0;this.prog=Math.max(0,this.prog-.25);sfx('snap');this.shake=.6;mgPop('Slipped!','#ff7a6b',100,30)}}else{this.prog+=dt*.42;if(Math.random()<dt*8)sfx('crank')}}else this.strain=Math.max(0,this.strain-dt*1.5);
      if(this.prog>=1){sfx('splash');mgPop('UP!','#ffd24d',100,14,1);mgEnd(.6,cb)}mgStat(Math.round(this.prog*100)+'%')},
    down(){this.hold=true},up(){this.hold=false},
    draw(g,t){const lift=Math.sin(t*6.283/this.per+this.ph);seaSide(g,t,p.zone,22+Math.round(lift*3));const py=78-this.prog*52;R(g,100,0,1,Math.round(py),'#e8d8b0');const pot=artCrabPot();g.drawImage(pot,Math.round(100-pot.width/2),Math.round(py-pot.height/2));
      if(this.surge&&Math.floor(t*8)%2)bigText(g,'SWELL!',60,4,'#ff7a6b');frame(g,8,74,120,6,'#16233a');R(g,8,74,Math.round(120*this.prog),6,'#ffd24d');frame(g,140,74,52,6,'#16233a');R(g,140,74,Math.round(52*this.strain),6,'#ff5a4a')}};
  mgOpen(G)}
