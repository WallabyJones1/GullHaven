/* ================= art for the wilds, the lake, the town square and the sea floor =================
   Painted with the same PN pixel painter and ramps as the rest of Gullhaven. */
// a little cluster of wildflowers (flat ground decal)
function artFlowers(v){return cc('fl'+v,()=>{const N=PN(16,12);const cols=[['#ff7a6b','#fff6c0'],['#f6bccb','#ffffff'],['#9ab8ff','#fff6c0'],['#ffd24d','#e8604a']][v%4];const r=rng(v*71+5);
  for(let i=0;i<5;i++){const x=2+r()*12|0,y=3+r()*7|0;N.line(x,y+1,x,y+3,'#3f7a45',1,1);N.px(x-1,y,cols[0],2);N.px(x+1,y,cols[0],2);N.px(x,y-1,cols[0],2);N.px(x,y+1,cols[0],2);N.px(x,y,cols[1],3)}
  for(let i=0;i<4;i++){const x=1+r()*14|0,y=6+r()*5|0;N.px(x,y,'#579a4f',0);N.px(x,y-1,'#79b85a',0)}return N.canvas()})}
// toadstools for the old wood
function artToadstools(v){return cc('mush'+v,()=>{const N=PN(14,12);const cap=v?ramp5('#c8443a'):ramp5('#c89a5a');for(const[cx,cy,s]of[[4,6,3],[9,8,2.4]]){N.rect(cx-1,cy,2,4,'#f4ecd8',1);N.ell(cx,cy,s,s*.7,(nx,ny,l)=>(v&&((cx*7+nx*9|0)+(ny*5|0))%3===0&&ny<0)?'#fff6e8':rampPick(cap,l),2)}N.outline();return N.canvas()})}
// lily pads float on the lake (flat)
function artLily(v){return cc('lily'+v,()=>{const N=PN(14,10);const G=ramp5('#4f9a4a');N.ell(6,5,5.5,3.6,(nx,ny,l)=>(Math.abs(Math.atan2(ny,nx)-.3)<.35&&Math.hypot(nx,ny)>.2)?null:rampPick(G,l),1);if(v){N.ell(10,3,2,1.6,'#f6bccb',3);N.px(10,3,'#fff6c0',4)}N.outline('#2f5b3a');return N.canvas()})}
// a carved standing stone (holds a riddle)
function artRuneStone(){return cc('rune',()=>{const N=PN(16,24);const st=ramp5('#8a8aa0');N.poly([[3,23],[2,8],[5,2],[11,1],[14,7],[13,23]],(x,y)=>rampPick(st,.5-x/16-y/40),1);
  for(const[x,y]of[[6,6],[9,6],[7,10],[6,14],[10,13],[8,17]])N.px(x,y,'#3e3a52',2);N.line(6,8,10,8,'#5c5873',1,2);N.line(7,15,9,18,'#5c5873',1,2);N.px(4,20,'#579a4f',3);N.px(12,21,'#579a4f',3);N.px(5,21,'#79b85a',3);N.outline();
  const c=N.canvas();const[o,x]=mk(16,26);ell(x,8,24,7,2,SHADOW);x.drawImage(c,0,0);return o})}
// the old iron gate between two stone pillars, closed or open
function artLakeGate(open){return cc('gate'+open,()=>{const W=52,H=40;const N=PN(W,H);const st=ramp5('#7c7894');
  for(const px of[1,W-11]){N.rect(px,8,10,30,(i,j)=>(j%6===0||((i+(j/6|0)*3)%5===0))?st[1]:rampPick(st,.4-i/12),1);N.rect(px-1,5,12,4,st[3],2);N.rect(px,3,10,2,st[4],2);N.ell(px+5,2,2.5,2,BRASS,3)}
  const bar=IRON;if(!open){for(let i=0;i<7;i++){const x=13+i*4;N.line(x,12,x,37,bar[1],1,1);N.px(x,11,bar[3],2)}N.line(12,16,40,16,bar[2],1,2);N.line(12,30,40,30,bar[2],1,2);N.ell(26,23,3,3,BRASS,3);N.px(26,24,'#2a1e33',4)}
  else{for(let i=0;i<3;i++){N.line(12,14+i*2,12,37,bar[1],1,1);N.line(40-i,14+i*2,40-i,37,bar[1],1,1)}N.line(11,16,14,16,bar[2],1,2);N.line(38,16,41,16,bar[2],1,2)}
  for(let i=0;i<9;i++){const x=1+i*6;N.px(x,38,'#579a4f',0);N.px(x+1,37,'#79b85a',0)}N.outline();
  const c=N.canvas();const[o,x]=mk(W,H+2);ell(x,W/2,H-1,W/2,3,SHADOW);x.drawImage(c,0,0);return o})}
// the town fountain (animated)
function artTownFountain(f){return cc('fount'+f,()=>{const W=44,H=36;const N=PN(W,H);const st=ramp5('#c1bfd2');
  N.ell(22,26,20,8,(nx,ny,l)=>Math.hypot(nx,ny)>.82?rampPick(st,l+.2):null,1);N.ell(22,25,16.5,6,(nx,ny)=>{const w=Math.sin(nx*9+f*1.7+ny*4);return w>.6?'#bfe8f4':w<-.6?'#3f86bd':'#5ea9d8'},2);
  N.rect(19,10,6,15,(i,j)=>rampPick(st,.4-i/6),3);N.ell(22,11,7,3,(nx,ny,l)=>Math.hypot(nx,ny)>.6?rampPick(st,l):'#8fd0ea',4);
  for(let i=0;i<6;i++){const a=i/6*Math.PI*2+f*.5;const x=22+Math.cos(a)*(5+f%2),y=8-Math.abs(Math.sin(a))*2;N.px(x,y,'#e8fbff',5);N.px(22+Math.cos(a)*(9+f%3),15+(i+f)%3,'#d6f2f8',5)}N.px(22,4+f%2,'#ffffff',5);N.px(22,5,'#bfe8f4',5);
  N.outline();const c=N.canvas();const[o,x]=mk(W,H+3);ell(x,22,H-3,21,4,SHADOW);x.drawImage(c,0,0);return o})}
// a garden planter box with flowers
function artFlowerBox(v){return cc('plant'+v,()=>{const N=PN(30,16);N.rect(1,8,28,7,(i,j)=>rampPick(WOOD,j<1?.6:.1-j/10),1);const cols=['#ff7a6b','#f6bccb','#ffd24d','#9ab8ff'];
  for(let i=0;i<7;i++){const x=3+i*3.8;N.ell(x,6,2.4,2.2,ramp5('#579a4f'),2);N.ell(x+.5,4.5,1.3,1.3,ramp5(cols[(i+v)%4]),3)}N.outline();return N.canvas()})}
// a wooden signpost
function artSignpost(){return cc('signpost',()=>{const N=PN(22,26);N.rect(10,6,3,19,WOOD,1);N.poly([[1,5],[17,5],[21,8],[17,11],[1,11]],(x,y)=>rampPick(WOOD,.6-y/14),2);N.poly([[4,13],[20,13],[20,18],[4,18],[1,15.5]],(x,y)=>rampPick(WOOD,.5-y/22),2);N.line(4,8,15,8,'#4a2e28',1,3);N.line(6,15,17,15,'#4a2e28',1,3);N.outline();return N.canvas()})}
// a hay bale and a garden plot for the farm edge
function artVeg(v){return cc('veg'+v,()=>{const N=PN(32,18);N.rect(1,3,30,14,(i,j)=>j%4===0?'#5a3d2c':j%4===1?'#7d573d':'#a3774f',1);
  for(let r=0;r<3;r++)for(let i=0;i<6;i++){const x=4+i*5,y=5+r*4;if(v===0){N.ell(x,y,1.8,1.5,ramp5('#79b85a'),2);N.px(x,y-1,'#a7d872',3)}else{N.ell(x,y+1,1.6,1.3,ramp5('#e8873a'),2);N.line(x,y-1,x,y-2,'#579a4f',1,3)}}N.outline();return N.canvas()})}
/* ---------- under the sea ---------- */
function artKelp(v){return cc('kelp'+v,()=>{const H=40+v*8;const N=PN(18,H);const G=ramp5(v%2?'#4a7a3a':'#5a8a4a');for(let s=0;s<3;s++){const ox=4+s*5;N.tube(t=>[ox+Math.sin(t*7+s)*2,H-1-t*(H-6-s*5)],t=>1.4-t*.6,(t,side,l)=>rampPick(G,l),40,1+s);
  for(let k=0;k<5;k++){const t=.2+k*.15;const y=H-1-t*(H-6-s*5),x=ox+Math.sin(t*7+s)*2;N.ell(x+(k%2?2:-2),y,2.2,1.2,G,4)}}N.outline();return N.canvas()})}
function artSeaRock(v){return cc('srock'+v,()=>{const W=v?30:22,H=v?20:16;const N=PN(W,H);const R5=ramp5('#4a5a72');N.ell(W/2,H/2+1,W/2-1,H/2-1,(nx,ny,l)=>rampPick(R5,l+(hash2(nx*9|0,ny*9|0,3)-.5)*.5),1);
  for(let i=0;i<4;i++)N.ell(3+i*(W-6)/3,H-4,2,1.4,['#e88aa8','#f0c880','#7fdcc0','#c39bff'][(i+v)%4],2);N.outline();return N.canvas()})}
function artSeaChest(open){return cc('schest'+open,()=>{const N=PN(22,18);N.rect(2,7,18,10,(i,j)=>i%6===0?IRON[2]:rampPick(WOOD,.3-j/12),1);if(open){N.rect(2,1,18,4,(i,j)=>rampPick(WOOD,.5),2);N.rect(4,6,14,3,'#ffd24d',2);N.px(7,6,'#fff6c0',3);N.px(13,7,'#fff6c0',3)}else{N.ell(11,7,9,4,(nx,ny,l)=>ny<0?rampPick(WOOD,l):null,2);N.rect(10,8,2,3,BRASS[2],3)}
  N.px(4,15,'#7fdcc0',4);N.px(17,14,'#e88aa8',4);N.outline();return N.canvas()})}
function artWreckHull(){return cc('whull',()=>{const W=120,H=58;const N=PN(W,H);const T=ramp5('#5a4632');
  N.poly([[4,40],[18,18],[96,12],[116,20],[110,44],[60,54],[16,50]],(x,y)=>{const plank=(y+((x/14)|0)*2)%5===0;return plank?T[0]:rampPick(T,.4-y/60+(hash2(x>>2,y,5)-.5)*.3)},1);
  N.poly([[22,24],[92,18],[104,24],[98,36],[30,40]],(x,y)=>rampPick(ramp5('#2a2018'),-.2+(hash2(x>>3,y>>2,8)-.5)*.3),2);
  for(let i=0;i<6;i++)N.line(30+i*13,20,32+i*13,38,T[3],2,3);N.line(66,2,64,30,T[2],3,4);N.line(56,8,78,6,T[1],2,4);
  for(let i=0;i<14;i++)N.px(10+i*7,44+(i%3),'#7fdcc0',5);for(let i=0;i<5;i++)N.ell(20+i*20,48,3,1.5,'#e88aa8',5);N.outline();return N.canvas()})}
function artBubble(){return cc('bubble',()=>{const N=PN(5,5);N.ell(2.5,2.5,2.2,2.2,(nx,ny)=>Math.hypot(nx,ny)>.6?'#d6f2f8':ny<-.1&&nx<0?'#ffffff':null,1);return N.canvas()})}
// a small heart for petting
function artHeart(){return cc('heart',()=>{const[c,x]=mk(7,6);stamp(x,['.kk.kk.','kRWkRRk','kRRRRRk','.kRRRk.','..kRk..','...k...'],{k:'#6a1a2a',R:'#ff7a8a',W:'#ffd0d8'},0,0);return c})}
