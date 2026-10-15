/* ================= the cats of Gullhaven =================
   Art ported as-is from Catoshi's Catch (the user's cat fishing game): ten coats, a sitting side view, a front
   portrait and little walking sprites. (Catoshi himself is not in Gullhaven, by request.)
   catSide(coat,frame) 30x28 sitting (frame 0/1 tail swish, 2 blink) · catFace(coat) 24x22 portrait
   catWalk(coat,dir,frame) 20x20, dir 0 down 1 left 2 right 3 up */
const COATS=[
  {k:'ginger',n:'Ginger',name:'Marmalade',base:'#e8873a',stripe:'#b85a22',eye:'#9ccf4a'},
  {k:'black',n:'Black',name:'Midnight',base:'#2e2b36',eye:'#e8c040'},
  {k:'grey',n:'Grey',name:'Smokey',base:'#8a93a3',eye:'#e8b040'},
  {k:'tabby',n:'Brown Tabby',name:'Tiger',base:'#a07a50',stripe:'#4f3a26',eye:'#8cc850'},
  {k:'tux',n:'Tuxedo',name:'Domino',base:'#2e2b36',white:'tux',eye:'#9ccf4a'},
  {k:'calico',n:'Calico',name:'Patches',base:'#f1ece2',patch:['#e0853a','#2e2b36'],eye:'#e8b040'},
  {k:'tortie',n:'Tortoiseshell',name:'Toffee',base:'#33292a',mottle:'#c8692e',eye:'#e8a030'},
  {k:'cream',n:'Cream',name:'Biscuit',base:'#ecd0a0',stripe:'#d4a870',eye:'#c8a040'},
  {k:'siamese',n:'Siamese',name:'Mochi',base:'#efe2cb',point:'#4b3a33',eye:'#5aa8e8'},
  {k:'bicolor',n:'Ginger and White',name:'Pumpkin',base:'#e8873a',stripe:'#c06a2a',white:'bi',eye:'#e8b040'}];
const COATI=Object.fromEntries(COATS.map(c=>[c.k,c]));
const PINK='#e89aa0';
const hn=(x,y,s)=>{const v=Math.sin(x*12.9898+y*78.233+s*37.719)*43758.5453;return v-Math.floor(v)};
function blotch(x,y,s){return Math.sin(x*.55+s)*Math.cos(y*.62+s*1.7)+.5*Math.sin((x+y)*.31+s*2.3)}
/* the coat colour of one pixel. region: head ear earIn muzzle chest body haunch leg paw tail ; u = tail position 0..1 */
function coatAt(cd,reg,x,y,u){
  if(reg==='earIn')return cd.k==='siamese'?shade(cd.point,.25):PINK;
  if(cd.point){ // siamese: dark points, soft body shading
    if(reg==='ear'||reg==='paw'||reg==='muzzle'||(reg==='tail'&&u>.25)||(reg==='leg'&&y>21))return cd.point;
    if(reg==='head'&&cd.face&&cd.face(x,y))return cd.point;
    return reg==='haunch'||reg==='body'?mix(cd.base,'#c8b090',.25):cd.base}
  if(cd.white==='tux'&&(reg==='chest'||reg==='paw'||reg==='muzzle'||(reg==='head'&&cd.blaze&&cd.blaze(x,y))))return '#f3f0ea';
  if(cd.white==='bi'&&(reg==='chest'||reg==='paw'||reg==='muzzle'||reg==='leg'||(reg==='haunch'&&y>21)||(reg==='tail'&&u>.85)))return '#f3f0ea';
  if(cd.patch){if(reg==='paw'||reg==='chest'||reg==='muzzle')return cd.base;const b=blotch(x,y,3.1);return b>.55?cd.patch[0]:b<-.65?cd.patch[1]:cd.base}
  if(cd.mottle){const b=blotch(x*1.3,y*1.3,1.7)+hn(x,y,2)*.6;return b>.55?cd.mottle:b>.35?shade(cd.mottle,-.25):cd.base}
  if(cd.stripe){
    if(reg==='tail')return (u*7)%1<.38?cd.stripe:cd.base;
    if(reg==='body'||reg==='haunch')return ((x+y*.45)%3.4)<1.05?cd.stripe:cd.base;
    if(reg==='head'&&cd.fore&&cd.fore(x,y))return cd.stripe;
    if(reg==='leg'&&y%3===0)return cd.stripe;
    if(reg==='chest'||reg==='muzzle')return mix(cd.base,'#fff3e0',.35);
    return cd.base}
  if(reg==='muzzle'&&cd.k!=='black'&&cd.k!=='tortie')return mix(cd.base,'#ffffff',.15);
  return cd.base}
const rampC=new Map();
function rampOfC(hex){let r=rampC.get(hex);if(!r){r=ramp5(hex);rampC.set(hex,r)}return r}
const shadeC=(hex,lit)=>rampPick(rampOfC(hex),lit);
/* ---------- side view (facing right) ---------- */
function catSidePN(k,frame){const cd=Object.assign({},COATI[k]);const N=PN(30,28);
  cd.fore=(x,y)=>y<8&&x>15&&x<21&&(x%2===0);cd.blaze=(x,y)=>x>20&&y>8;cd.face=(x,y)=>x>19&&y>7;
  const F=(reg)=>(nx,ny,lit,x,y)=>shadeC(coatAt(cd,reg,x,y,0),lit);
  // tail: curls up behind the back
  const sw=frame===1?1.5:0;
  const tp=t=>{const a=t*Math.PI*.95;return[8-Math.sin(a)*6.5-sw*t*t,23-t*13+Math.cos(a)*1.5-sw*t*.4]};
  N.tube(tp,t=>2-t*.6,(t,side,lit)=>shadeC(coatAt(cd,'tail',0,0,t),lit+.1),70,-1);
  N.ell(11,19.5,6.8,6.2,F('haunch'),0);           // haunch
  N.ell(9.5,25,3.8,1.6,F('paw'),1);               // back foot
  N.ell(15,15.5,5,7.2,F('body'),1);               // body / back
  N.ell(17.4,16.5,3.2,5.4,F('chest'),2);          // chest
  N.rect(19,19,2,6,(i,j)=>shadeC(coatAt(cd,'leg',19+i,19+j),-.25),1);   // far leg
  N.rect(16.5,19,2.4,6,(i,j)=>shadeC(coatAt(cd,'leg',16+i,19+j),.15-i*.2),3); // near leg
  N.rect(16.5,24.5,3,1.5,(i,j)=>shadeC(coatAt(cd,'paw',0,0),.3),4);
  N.rect(19.2,24.5,2.6,1.5,(i,j)=>shadeC(coatAt(cd,'paw',0,0),0),2);
  // head
  N.poly([[15.2,7],[16.2,1],[19.6,5.4]],(x,y)=>shadeC(coatAt(cd,'ear',x,y),.4),5);
  N.poly([[16.4,5.6],[16.8,3],[18.4,5.4]],(x,y)=>coatAt(cd,'earIn',x,y),6);
  N.poly([[19,5],[21.6,.8],[22.6,6.2]],(x,y)=>shadeC(coatAt(cd,'ear',x,y),0),4);
  N.ell(19.4,9.6,5.6,4.9,F('head'),5);
  N.ell(23.2,11.2,2.4,1.9,F('muzzle'),6);
  N.px(25.3,10.3,PINK,7);
  // eye
  if(frame===2){N.px(21,9,shade(coatAt(cd,'head',21,9),-.45),7);N.px(22,9,shade(coatAt(cd,'head',22,9),-.45),7)}
  else{N.px(21,8,cd.eye,7);N.px(21,9,cd.eye,7);N.px(22,8,'#1a1418',7);N.px(22,9,'#1a1418',7);N.px(21,8,mix(cd.eye,'#ffffff',.5),8)}
  N.outline();return N}
const catSideCache=new Map();
function catSide(k,frame=0){const key=k+frame;let c=catSideCache.get(key);if(!c){c=catSidePN(k,frame).canvas();catSideCache.set(key,c)}return c}
/* ---------- front portrait ---------- */
function catFacePN(k){const cd=Object.assign({},COATI[k]);const N=PN(24,22);
  cd.fore=(x,y)=>y<9&&x>8&&x<16&&(x%2===1);cd.blaze=(x,y)=>Math.abs(x+.5-12)<2.2-((10-y)*.05)&&y>7;cd.face=(x,y)=>Math.hypot(x+.5-12,(y+.5-14)*1.2)<4.6;
  const F=(reg)=>(nx,ny,lit,x,y)=>shadeC(coatAt(cd,reg,x,y,0),lit);
  N.poly([[3,9],[4,1],[10,5]],(x,y)=>shadeC(coatAt(cd,'ear',x,y),.35),0);
  N.poly([[21,9],[20,1],[14,5]],(x,y)=>shadeC(coatAt(cd,'ear',x,y),-.1),0);
  N.poly([[5,7.5],[5.2,3.6],[8.4,5.6]],PINK,1);N.poly([[19,7.5],[18.8,3.6],[15.6,5.6]],PINK,1);
  if(cd.k==='siamese'){N.poly([[5,7.5],[5.2,3.6],[8.4,5.6]],shade(cd.point,.25),2);N.poly([[19,7.5],[18.8,3.6],[15.6,5.6]],shade(cd.point,.25),2)}
  N.ell(12,12.5,9.2,7.8,F('head'),3);
  N.ell(12,16,4.6,3,F('muzzle'),4);
  // eyes
  for(const ex of [7,15]){N.rect(ex,11,3,3,cd.eye,5);N.px(ex+1,11,'#1a1418',6);N.px(ex+1,12,'#1a1418',6);N.px(ex+1,13,'#1a1418',6);N.px(ex,11,mix(cd.eye,'#ffffff',.55),6)}
  N.rect(11,15,2,1,PINK,6);N.px(11.5,16,shade(PINK,-.3),6);
  const mc=shade(coatAt(cd,'muzzle',11,17),-.45);N.px(10,17,mc,6);N.px(13,17,mc,6);
  N.outline();return N}
const faceCache=new Map();
function catFace(k){let c=faceCache.get(k);if(!c){c=catFacePN(k).canvas();faceCache.set(k,c)}return c}
/* ---------- world sprites: little cats walking the town (3/4 top-down), and Catoshi in miniature ----------
   catWalk(coat,dir,frame): dir 0 down, 1 left, 2 right, 3 up; frame 0 stand, 1/2 steps. 20x20, feet at y=18. */
function catWalkPN(k,dir,fr){const cd=Object.assign({},COATI[k]);cd.fore=(x,y)=>false;cd.blaze=(x,y)=>dir===0&&Math.abs(x+.5-10)<1.6&&y>7;cd.face=(x,y)=>dir===0&&Math.hypot(x+.5-10,y+.5-10)<3.2;
  const N=PN(20,20);const C=(reg,x,y,lit,u)=>shadeC(coatAt(cd,reg,x,y,u||0),lit);const st=fr===0?0:fr===1?1:-1;
  if(dir===0||dir===3){const up=dir===3;
    N.tube(t=>[14+t*3.5,15-t*7+Math.sin(t*3)*1],t=>1.4-t*.4,(t,s,lit)=>C('tail',0,0,lit+.1,t),40,-1);
    N.ell(10,14.6,4.6,3.6,(nx,ny,lit,x,y)=>C(up?'body':'chest',x,y,lit),1);
    for(const[px,s]of[[8,st],[12,-st]])N.ell(px,18-(s>0?1:0),1.6,1.1,(nx,ny,lit)=>C('paw',0,0,lit+.2),2);
    N.poly([[4.2,7],[4.8,1.2],[8.6,4.2]],(x,y)=>C('ear',x,y,.3),3);N.poly([[15.8,7],[15.2,1.2],[11.4,4.2]],(x,y)=>C('ear',x,y,0),3);
    if(!up){N.poly([[5.4,5.6],[5.7,2.9],[7.6,4.4]],PINK,4);N.poly([[14.6,5.6],[14.3,2.9],[12.4,4.4]],PINK,4)}
    N.ell(10,8.4,6.2,5.2,(nx,ny,lit,x,y)=>C('head',x,y,lit),5);
    if(!up){N.ell(10,10.6,2.6,1.6,(nx,ny,lit)=>C('muzzle',10,11,lit+.2),6);for(const ex of[6,13]){N.px(ex,8,cd.eye,7);N.px(ex+1,8,'#1a1418',7);N.px(ex,9,shade(cd.eye,-.2),7);N.px(ex+1,9,'#1a1418',7)}N.px(9,10,PINK,7);N.px(10,10,PINK,7)}}
  else{N.tube(t=>[5-t*3,12.5-t*6],t=>1.3-t*.4,(t,s,lit)=>C('tail',0,0,lit+.1,t),40,-1);
    for(const[lx,s,far]of[[5.5,st,1],[7.5,-st,0],[11.5,-st,1],[13.5,st,0]])N.rect(lx+s*.8,14.5,1.6,3,(i,j)=>C('leg',lx,15+j,far?-.35:.1),far?0:2);
    N.ell(9.5,13,5.5,3.4,(nx,ny,lit,x,y)=>C(ny>.35?'chest':'body',x,y,lit),1);
    N.poly([[11.4,6],[12,1],[14.4,4.4]],(x,y)=>C('ear',x,y,.2),3);N.poly([[14,4.4],[16.6,1.2],[17,6]],(x,y)=>C('ear',x,y,0),3);
    N.ell(14.4,8.4,4.6,4.2,(nx,ny,lit,x,y)=>C('head',x,y,lit),4);N.ell(17.6,9.8,1.8,1.4,(nx,ny,lit)=>C('muzzle',18,10,lit+.2),5);N.px(16,8,cd.eye,6);N.px(16,7,cd.eye,6);N.px(19,9,PINK,6)}
  N.outline();const c=N.canvas();if(dir===1){const[m,x]=mk(20,20);x.translate(20,0);x.scale(-1,1);x.drawImage(c,0,0);return m}return c}
const walkCache=new Map();
function catWalk(k,dir,fr){const key=k+dir+fr;let c=walkCache.get(key);if(!c){c=catWalkPN(k,dir,fr);walkCache.set(key,c)}return c}
