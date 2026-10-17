/* ================= the wilds: Mirrorlake behind the old gate, the south wood, and a richer town and islands =================
   The lake is carved out of the same land field as the coast (landF), so its banks paint like every other shore. */
const LAKE={x:22,y:126,rx:9.5,ry:6.5,RX:16.5,RY:13};
const inLakeBox=(x,y)=>x>LAKE.x-LAKE.rx-3&&x<LAKE.x+LAKE.rx+3&&y>LAKE.y-LAKE.ry-3&&y<LAKE.y+LAKE.ry+3;
// signed distance-ish to the lake bank (tile units): negative inside the water
function lakeD(x,y){const dx=(x-LAKE.x)/LAKE.rx,dy=(y-LAKE.y)/LAKE.ry;const e=Math.sqrt(dx*dx+dy*dy);const wob=(NZ.at(x*4+90,y*4)-.5)*1.4+Math.sin(Math.atan2(dy,dx)*3+1)*.45;return(e-1)*Math.min(LAKE.rx,LAKE.ry)+wob}
// position on the wood ring around the lake (1 = inner edge of the trees)
const ringE=(x,y)=>Math.hypot((x-LAKE.x)/LAKE.RX,(y-LAKE.y)/LAKE.RY);
const STORY_CLUES=[
  {id:'lh',sym:'anchor',who:'An old carving at Lighthouse Point',text:'FIRST: I hold a ship still when the wind wants it gone.'},
  {id:'tideglass',sym:'moon',who:'Mara at Tideglass Cay',text:'SECOND: I pull the sea up the sand twice a day and never touch it.'},
  {id:'mossbank',sym:'shell',who:'Fern at Mossbank',text:'THIRD: a house that once walked the reef, washed up empty for you.'},
  {id:'lantern',sym:'lighthouse',who:'Old Ivo at Lantern Key',text:'FOURTH: I stand on the point and keep one eye open all night.'}];
const LOCK_SYMS=['anchor','moon','shell','lighthouse','sun','fish','boat','storm'];
function clearTiles(W,x0,y0,x1,y1){W.props=W.props.filter(p=>{const im=p.img;if(!im||im.height>60)return true;const ax=Math.floor((p.x+im.width/2)/16),ay=Math.floor((p.sy-1)/16);if(ax<x0||ax>x1||ay<y0||ay>y1)return true;W.sol[ay*W.w+ax]=0;return false})}
function freeG(W,x,y){const i=y*W.w+x;return x>=0&&y>=0&&x<W.w&&y<W.h&&W.g[i]==='g'&&!W.sol[i]&&!W.res[i]}
function addWilds(W,set,pier){const idx=(x,y)=>y*W.w+x;const r=rng(9091);const L=LAKE;
  const deco=(im,tx,ty,o={})=>addProp(W,im,tx*16+8-im.width/2,(ty+1)*16-im.height+(o.dy||0),Object.assign({sy:(ty+1)*16-1},o));
  const solidDeco=(im,tx,ty,o)=>{if(!freeG(W,tx,ty))return false;deco(im,tx,ty,o);W.sol[idx(tx,ty)]=1;W.res[idx(tx,ty)]=1;return true};
  const flat=(im,tx,ty)=>{addProp(W,im,tx*16+8-im.width/2,ty*16+2,{flat:1,sy:ty*16});W.res[idx(tx,ty)]=1};
  /* ---- the road south to the old gate ---- */
  const road=(x0,y0,x1,y1)=>{clearTiles(W,x0,y0,x1,y1);set('w',x0,y0,x1,y1);for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++)W.sol[idx(x,y)]=0};
  const GX=L.x-1;road(30,93,31,106);road(GX,105,31,106);
  /* ---- the wood ring around Mirrorlake, with a gate in its north side ---- */
  const gateTiles=[];let gateTop=999;
  for(let ty=Math.floor(L.y-L.RY*1.3);ty<=Math.ceil(L.y+L.RY*1.3);ty++)for(let tx=Math.floor(L.x-L.RX*1.3);tx<=Math.ceil(L.x+L.RX*1.3);tx++){if(tx<0||ty<0||tx>=W.w||ty>=W.h)continue;const e=ringE(tx+.5,ty+.5);if(e<1||e>1.26)continue;const i=idx(tx,ty);if(W.g[i]==='o')continue;
    if((tx===GX||tx===GX+1)&&ty<L.y){clearTiles(W,tx,ty,tx,ty);W.g[i]='w';W.sol[i]=1;W.res[i]=1;gateTiles.push(i);gateTop=Math.min(gateTop,ty);continue}
    clearTiles(W,tx,ty,tx,ty);W.sol[i]=1;W.res[i]=1;W.g[i]='g';const k=r();if(k<.62)treeAt(W,tx,ty,k<.3?3:k<.48?0:k<.56?2:4);else if(k<.8)deco(artBush(k<.7?null:'#f6bccb'),tx,ty);}
  road(GX,107,GX+1,gateTop-1);
  const gateRows=[...new Set(gateTiles.map(i=>Math.floor(i/W.w)))].sort((a,b)=>a-b);const gy=gateRows[0];
  addProp(W,artLakeGate(false),(GX+1)*16-26,(gy+1)*16-41,{sy:(gy+1)*16-1,anim:()=>artLakeGate(lakeOpen())});
  W.lakeGate={tiles:gateTiles,x:(GX+1)*16,y:(gy+1)*16+10};
  // the clearing path from the gate down to the lake
  for(let ty=gateRows[gateRows.length-1]+1;ty<L.y;ty++){let wet=false;for(const tx of[GX,GX+1]){const i=idx(tx,ty);if(W.g[i]==='o'){wet=true;W.g[i]='pr';W.sol[i]=0;W.nav[i]=0;W.res[i]=1}else{clearTiles(W,tx,ty,tx,ty);W.g[i]='w';W.res[i]=1;W.sol[i]=0}}if(wet){for(let k=1;k<=2;k++)for(const tx of[GX,GX+1]){const i=idx(tx,ty+k);if(W.g[i]==='o'){W.g[i]='pr';W.sol[i]=0;W.nav[i]=0;W.res[i]=1}}break}}
  /* ---- the lakeside: reeds, lilies, a warden's hut, a bench and a name sign ---- */
  for(let ty=Math.floor(L.y-L.RY);ty<=Math.ceil(L.y+L.RY);ty++)for(let tx=Math.floor(L.x-L.RX);tx<=Math.ceil(L.x+L.RX);tx++){if(tx<0||ty<0)continue;const i=idx(tx,ty);const d=lakeD(tx+.5,ty+.5);if(ringE(tx+.5,ty+.5)>=1)continue;
    if(W.g[i]==='o'){if(d<-.6&&d>-2.6&&r()<.16)flat(artLily(r()<.3?1:0),tx,ty);continue}
    if(W.g[i]!=='g'||W.sol[i]||W.res[i])continue;
    if(d<1.4&&r()<.18){deco(artReedsC(),tx,ty,{dy:2});continue}
    if(d>2.5&&r()<.12)flat(artFlowers(Math.floor(r()*4)),tx,ty);else if(d>2.5&&r()<.06)solidDeco(artToadstools(r()<.5?1:0),tx,ty)}
  {const hx=14,hy=117;let ok=true;for(let y=hy-2;y<=hy+2;y++)for(let x=hx;x<hx+4;x++){const i=idx(x,y);if(W.g[i]!=='g'||W.sol[i]||ringE(x+.5,y+.5)>=1||lakeD(x+.5,y+.5)<.5)ok=false}
    if(ok){clearTiles(W,hx,hy-2,hx+3,hy+2);const h=placeBuilding(W,hx,hy,4,2,2,{wall:'#d8d0b8',mat:'logs',roof:'#4f6b4a',door:1,win:[3],chimney:1,doorC:'#5a4a3a',flowers:1});W.spots.warden=h.door}}
  {const sx=GX+3,sy=Math.floor(L.y-L.ry-2);solidDeco(artSignpost(),sx,sy);W.spots.lakeSign={x:sx*16+8,y:sy*16+20};solidDeco(artBench(),GX-3,Math.floor(L.y-L.ry-1))}
  /* ---- the south wood: trees, toadstools and wildflowers ---- */
  for(let ty=96;ty<W.h-1;ty++)for(let tx=0;tx<106;tx++){if(!freeG(W,tx,ty))continue;const e=ringE(tx+.5,ty+.5);if(e<1.26)continue;const Lf=landF(tx+.5,ty+.5);if(Lf<3)continue;
    let nearRoad=false;for(let dy=-1;dy<=1&&!nearRoad;dy++)for(let dx=-1;dx<=1;dx++)if(W.g[idx(tx+dx,ty+dy)]==='w'){nearRoad=true;break}if(nearRoad)continue;
    const n=NZ.at(tx*5+3,ty*5+7);const dens=(e<1.5?.3:.02+.2*n)*(tx<60?1:.5);const k=r();
    if(k<dens){const v=r();treeAt(W,tx,ty,v<.5?3:v<.88?0:v<.95?2:4)}else if(k<dens+.02)solidDeco(artToadstools(r()<.4?1:0),tx,ty);else if(k<dens+.05)flat(artFlowers(Math.floor(r()*4)),tx,ty)}
  /* ---- the carving at Lighthouse Point ---- */
  {let best=null;for(let rr=0;rr<5&&!best;rr++)for(let dy=-rr;dy<=rr&&!best;dy++)for(let dx=-rr;dx<=rr;dx++){const x=63+dx,y=40+dy,i=idx(x,y);if(x<0||y<0)continue;if(W.sol[i]||W.g[i]==='o'||W.g[i]==='pr'||W.g[i]==='bw')continue;if(Math.abs(x-60)<2&&y<41)continue;best=[x,y];break}
    if(best){deco(artRuneStone(),best[0],best[1]);W.sol[idx(best[0],best[1])]=1;W.spots.carving={x:best[0]*16+8,y:best[1]*16+22}}}
  /* ---- town: a new lane with the Cat Café, a bakery and a cottage, a little farm, the square fountain ---- */
  clearTiles(W,4,67,29,78);road(4,71,29,72);
  const cafe=placeBuilding(W,5,69,6,2,2,{wall:'#f8e4d4',mat:'plaster',roof:'#c86a8a',door:3,win:[1,4],awning:['#e88aa8','#fbf6ea'],label:'CAT CAFE',labelBg:'#fff4e0',doorC:'#c86a8a',lamp:1,curtain:'#f6bccb',flowers:1});W.spots.cafe=cafe.door;
  const bakery=placeBuilding(W,13,69,5,2,2,{wall:'#f4e4b8',mat:'siding',roof:'#8a5a3a',door:2,win:[0,4],awning:['#e8c040','#fbf6ea'],label:'BAKERY',labelBg:'#fff4e0',doorC:'#8a5a3a',chimney:1});W.spots.bakery=bakery.door;
  const cot=placeBuilding(W,21,69,4,2,2,{wall:'#e4d8f0',mat:'planks',roof:'#5a4a7a',door:1,win:[3],flowers:1,chimney:1,doorC:'#f0c040'});(W.houses=W.houses||[]).push(cot.door);
  for(const[x,y]of[[12,71],[26,71]]){const i=idx(x,y-1);if(!W.sol[i]){const lamp=artLamp();addProp(W,lamp,x*16+2,(y-1)*16+14-33);W.sol[i]=1;W.lights.push({x:x*16+8,y:(y-1)*16-12,r:40,c:'rgba(255,200,120,'})}}
  for(const[x,y,v]of[[6,74,0],[9,74,1],[12,74,0],[6,76,1],[9,76,0],[12,76,1]]){addProp(W,artVeg(v),x*16,y*16-1,{flat:1,sy:y*16});reserve(W,x,y,x+1,y)}
  solidDeco(artSignpost(),15,74);
  {const fx=40,fy=57;const fr=[0,1,2,3].map(artTownFountain);addProp(W,fr[0],fx*16-22,(fy+1)*16-37,{sy:(fy+1)*16-1,anim:t=>fr[Math.floor(t*5)%4]});solidRect(W,fx-1,fy-1,fx+1,fy);W.spots.fountain={x:fx*16,y:(fy+1)*16+8}}
  for(const h of W.houses||[]){const tx=Math.floor(h.x/16),ty=Math.floor(h.y/16)-1;if(tx>58)continue;for(const dx of[-2,2])if(freeG(W,tx+dx,ty)&&r()<.7)flat(artFlowers(Math.floor(r()*4)),tx+dx,ty)}
  for(let ty=0;ty<96;ty++)for(let tx=0;tx<56;tx++){if(!freeG(W,tx,ty))continue;if(r()<.025)flat(artFlowers(Math.floor(r()*4)),tx,ty)}
  for(const[x,y]of[[35,64],[44,64]])if(freeG(W,x,y)||W.g[idx(x,y)]==='p'){if(!W.sol[idx(x,y)]){deco(artFlowerBox((x+y)%4),x,y);W.sol[idx(x,y)]=1}}
  /* ---- islands: each settlement gets its own character and a local who knows a riddle ---- */
  const NPC={tideglass:['Mara',4211],mossbank:['Fern',4277],lantern:['Old Ivo',4355]};W.npcs=[];
  for(const I of W.islands||[]){const x=I.x,y=I.y;const near=[];for(let dy=-I.r;dy<=I.r;dy++)for(let dx=-I.r;dx<=I.r;dx++){const tx=x+dx,ty=y+dy;if(tx<0||ty<0||tx>=W.w||ty>=W.h)continue;const i=idx(tx,ty);if(W.sol[i]||W.res[i])continue;near.push([tx,ty,W.g[i]])}
    const sand=near.filter(p=>p[2]==='sa'),grass=near.filter(p=>p[2]==='g');const pickT=a=>a.length?a.splice(Math.floor(r()*a.length),1)[0]:null;
    if(I.id==='tideglass'){for(let k=0;k<4;k++){const p=pickT(sand);if(!p)break;const col=['#e8604a','#3f86bd','#f0c040','#5aa070'][k];addProp(W,artUmbrella(col),p[0]*16-8,p[1]*16-26,{sy:p[1]*16+14});W.sol[idx(p[0],p[1])]=1;W.res[idx(p[0],p[1])]=1}
      for(let k=0;k<3;k++){const p=pickT(sand);if(p)solidDeco(artDeckChair(['#3f86bd','#e8604a','#f0c040'][k]),p[0],p[1])}}
    if(I.id==='mossbank'){for(let k=0;k<10;k++){const p=pickT(grass);if(p)flat(artFlowers(k%4),p[0],p[1])}for(let k=0;k<3;k++){const p=pickT(grass);if(p&&freeG(W,p[0],p[1]))treeAt(W,p[0],p[1],1)}for(let k=0;k<2;k++){const p=pickT(grass);if(p)solidDeco(artFlowerBox(k),p[0],p[1])}}
    if(I.id==='lantern'){for(let k=0;k<5;k++){const p=pickT(grass)||pickT(sand);if(p)solidDeco(artRock(false,3),p[0],p[1])}for(let k=0;k<3;k++){const p=pickT(grass);if(p&&freeG(W,p[0],p[1]))treeAt(W,p[0],p[1],3)}}
    const n=NPC[I.id];if(n){const nx=(x-3)*16+8,ny=(y+2)*16+12;W.keepers.push({id:n[1],x:nx,y:ny,dir:'down'});W.npcs.push({island:I.id,n:n[0],x:nx,y:ny})}}
  // the three locked islands: a ring of water boats cannot cross until the island is opened, plus a look of their own
  W.locks={};for(const I of W.islands||[]){if(!I.lock)continue;const t=[];for(let ty=Math.floor(I.y-(I.r+11)/1.2);ty<=Math.ceil(I.y+(I.r+11)/1.2);ty++)for(let tx=I.x-I.r-11;tx<=I.x+I.r+11;tx++){if(tx<0||ty<0||tx>=W.w||ty>=W.h)continue;const d=Math.hypot(tx+.5-I.x,(ty+.5-I.y)*1.2);if(d<I.r+7.5||d>I.r+10)continue;const i=idx(tx,ty);if(W.g[i]==='o'&&W.nav[i])t.push(i)}W.locks[I.id]=t;
    const fr=[],grass=[];for(let dy=-I.r;dy<=I.r;dy++)for(let dx=-I.r;dx<=I.r;dx++){const tx=I.x+dx,ty=I.y+dy,i=idx(tx,ty);if(W.sol[i]||W.res[i])continue;if(W.g[i]==='g')grass.push([tx,ty]);else if(W.g[i]==='sa'||W.g[i]==='rk')fr.push([tx,ty])}
    const pk=a=>a.length?a.splice(Math.floor(r()*a.length),1)[0]:null;
    if(I.id==='kelpwood'){for(let k=0;k<6;k++){const p=pk(grass);if(p&&freeG(W,p[0],p[1])){deco(artMangrove(k%3),p[0],p[1],{sway:1});W.sol[idx(p[0],p[1])]=1;W.res[idx(p[0],p[1])]=1}}for(let k=0;k<6;k++){const p=pk(fr)||pk(grass);if(p)deco(artReedsC(),p[0],p[1],{dy:2})}}
    if(I.id==='cove'){let p=null;const cs=[];for(let oy=-I.r;oy<=I.r;oy++)for(let ox=-I.r;ox<=I.r;ox++)cs.push([ox,oy]);cs.sort((a1,a2)=>Math.hypot(a1[0]+6,a1[1]-5)-Math.hypot(a2[0]+6,a2[1]-5));for(const[ox,oy]of cs){if(p)break;const tx=I.x+ox,ty=I.y+oy;let ok=true;for(let x=tx-1;x<=tx+3;x++)for(let y=ty-1;y<=ty;y++){const i=idx(x,y);if(W.sol[i]||W.res[i]&&W.g[i]==='g'||W.g[i]==='o'||W.g[i]==='pr'||W.g[i]==='w'||W.g[i]==='p')ok=false}if(ok){p=[tx,ty];break}}if(p){const wh=cc('whs',()=>{const src=artWreckHull();const[c2,x2]=mk(78,38);x2.imageSmoothingEnabled=false;x2.drawImage(src,0,0,78,38);return c2});addProp(W,wh,p[0]*16-14,(p[1]+1)*16-36,{sy:(p[1]+1)*16-1});solidRect(W,p[0]-1,p[1],p[0]+3,p[1]);reserve(W,p[0]-1,p[1]-1,p[0]+3,p[1])}for(let k=0;k<4;k++){const q=pk(grass)||pk(fr);if(q)solidDeco(k%2?artBarrelC():artFishCrate(k%3),q[0],q[1])}}
    if(I.id==='ember'){let vx=0,vy=0,ok=false;const cand=[];for(let oy=-I.r;oy<=I.r;oy++)for(let ox=-I.r;ox<=I.r;ox++)cand.push([ox,oy]);cand.sort((p1,p2)=>Math.abs(Math.hypot(p1[0],p1[1])-6)-Math.abs(Math.hypot(p2[0],p2[1])-6));for(const[ox,oy]of cand){vx=I.x+ox;vy=I.y+oy;ok=true;for(let y=vy-1;y<=vy;y++)for(let x=vx-1;x<=vx+2;x++)if(!freeG(W,x,y))ok=false;if(ok)break}if(ok){const fr2=[0,1,2,3].map(artVolcano);addProp(W,fr2[0],vx*16+8-32,(vy+1)*16-60,{sy:(vy+1)*16-1,anim:t=>fr2[Math.floor(t*3)%4]});solidRect(W,vx-1,vy-1,vx+2,vy);reserve(W,vx-1,vy-3,vx+2,vy)}
      const sp=pk(grass);if(sp){const fs=[0,1,2].map(artHotSpring);addProp(W,fs[0],sp[0]*16+8-15,sp[1]*16,{flat:1,sy:sp[1]*16,anim:t=>fs[Math.floor(t*2)%3]});W.res[idx(sp[0],sp[1])]=1;W.spots.spring={x:sp[0]*16+8,y:sp[1]*16+12}}
      for(let k=0;k<5;k++){const q=pk(grass)||pk(fr);if(q)solidDeco(artRock(false,3),q[0],q[1])}}}
  // a few palms on the coral atoll's sand ring
  for(let k=0;k<7;k++){const an=-1.2+k*.62;if(Math.abs(an-1.57)<.6)continue;const tx=Math.round(ATOLL.x+Math.cos(an)*ATOLL.R),ty=Math.round(ATOLL.y+Math.sin(an)*ATOLL.R);const i=idx(tx,ty);if(W.g[i]!=='sa'||W.sol[i])continue;const im=artPalmC(k%2);addProp(W,im,tx*16+8-18,ty*16+16-48,{sy:ty*16+14,sway:1});W.sol[i]=1}
  // a dive flag off each island's reef
  W.diveSites=[];for(const I of W.islands||[]){let got=null;for(let rr=I.r+3;rr<=I.r+7&&!got;rr++)for(let a=0;a<16&&!got;a++){const an=2.4+a/16*6.283;const tx=Math.round(I.x+Math.cos(an)*rr),ty=Math.round(I.y+Math.sin(an)*rr/1.2);const i=idx(tx,ty);if(W.g[i]!=='o'||!W.nav[i])continue;const z=ZONE_ORDER[W.zone[i]];if(['shallows','reef','kelp','wreck','blue'].includes(z))got={key:'i'+I.id,x:tx*16+8,y:ty*16+8,zone:z}}if(got)W.diveSites.push(got)}
  W.lakeCenter={x:L.x*16,y:L.y*16}}
function lakeOpen(){return!!(typeof S!=='undefined'&&S&&S.story&&S.story.lake)}
