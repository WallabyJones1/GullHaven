/* ================= HD-2D: the outdoor world in 3D =================
   Blender-modelled buildings (assets/hd2d/gullhaven_kit.glb, embedded as HD_GLB) wear the game's own pixel facades, roofs
   and signs. The coast is a heightfield painted with the same lazily painted 512px ground chunks the flat view uses.
   People, boats, cats, trees and props stay pixel sprites in the scene. Interiors, dives and every panel stay 2D.
   V (or the 2D/3D button) switches views; the choice is remembered. Needs WebGL2 + three.js (loaded as a module). */
const HD={on:false,ready:false,started:false,want:true,pass:false,rec:false,PITCH:46,FOV:26,VS:1.25,KZ:1,q:[],wy:0,cur:null,tgt:null,chunks:new Map()};
try{HD.want=localStorage.getItem('gullhaven.hd2d')!=='0'}catch(e){}
HD.on=HD.want;
// tag art as it is made, so the 3D layer knows which world props to replace with models
artBuilding=(f=>function(w,h,r,o){const c=f(w,h,r,o);c._k='bld';c._b={w,h,r,o};return c})(artBuilding);
artLighthouse=(f=>function(v){const c=f(v);c._k='lh';return c})(artLighthouse);
artSeaStack=(f=>function(v){const c=f(v);c._k='stack';c._v=v;return c})(artSeaStack);
artLamp=(f=>function(){const c=f();c._k='lamp';return c})(artLamp);
// while sprites are drawn for the 3D view: their painted ground shadows become blob shadows on the 3D ground, and speech
// bubbles, name tags and emotes go to the flat overlay so they stay crisp and on top
ell=(f=>function(c,cx,cy,rx,ry,col){if(HD.rec&&c===HD.rctx){if(col===SHADOW||col==='#12304a')HD.recSh={x:cx,y:cy,rx,ry,w:col!==SHADOW};return}
  if(HD.pass&&c===HD.actx&&(col===SHADOW||col==='#12304a'))return;return f(c,cx,cy,rx,ry,col)})(ell);
HD._bubble=bubble;HD._nameTag=nameTag;HD._emote=drawEmote;
HD.red=function(k,o){if(HD.rec)return true;if(HD.pass&&HD.cur){o.k=k;o.it=HD.cur;o.dx-=HD.cur.sx;o.dy-=HD.cur.sy;HD.q.push(o);return true}return false};
bubble=function(c,text,x,y,col){if((HD.rec||HD.pass)&&(c===HD.actx||c===HD.rctx)&&HD.red('b',{text,col,dx:x,dy:y}))return;return HD._bubble(c,text,x,y,col)};
nameTag=function(c,text,x,y,col){if((HD.rec||HD.pass)&&(c===HD.actx||c===HD.rctx)&&HD.red('n',{text,col,dx:x,dy:y}))return;return HD._nameTag(c,text,x,y,col)};
drawEmote=function(k,x,y,t){if((HD.rec||HD.pass)&&HD.red('e',{e:k,dx:x,dy:y}))return;return HD._emote(k,x,y,t)};
// boats are seen from above: mark them so they can lie on the water rather than stand up
boatDraw=(f=>function(list,k,x,y,h,...rest){const n=list.length;f(list,k,x,y,h,...rest);if(HD.collect&&list[n])list[n].boat={x,y,sz:boatImg(k,0,null,null).height}})(boatDraw);

HD.frame=function(t){if(!HD.started&&WORLD)HD.boot();
  if(HD.on&&HD.ready&&scene===WORLD){HD.show(true);try{HD.render(t);return}catch(e){console.warn('HD-2D frame',e);HD.on=false;HD.updBtn()}}
  HD.show(false);render(t)};
HD.show=function(v){if(!HD.gl||HD.vis===v)return;HD.vis=v;HD.gl.domElement.style.display=v?'block':'none';cv.style.opacity=v?'0':''};// in 3D the flat canvas only takes taps; its overlay is composited into the WebGL frame
HD.toggle=function(v){HD.on=v===undefined?!HD.on:!!v;try{localStorage.setItem('gullhaven.hd2d',HD.on?'1':'0')}catch(e){}HD.updBtn();if(HD.on&&!HD.started&&WORLD)HD.boot();
  toast(HD.on?(HD.ready?'HD-2D view on.':'Loading the 3D world...'):'Flat pixel view on.')};
HD.updBtn=function(){const b=$('hdBtn');if(b){b.textContent=HD.on?'2D':'3D';b.title=HD.on?'Switch to the flat pixel view (V)':'Switch to the HD-2D view (V)'}};
window.addEventListener('keydown',e=>{const tg=e.target&&e.target.tagName;if(tg==='INPUT'||tg==='TEXTAREA')return;if(e.key==='v'||e.key==='V')HD.toggle()});
HD.boot=function(){HD.started=true;HD.updBtn();if(!HD.on)return void(HD.started=false);
  const go=()=>HD.init().then(()=>{HD.ready=true}).catch(e=>{console.warn('HD-2D unavailable',e);HD.ready=false;HD.on=false;HD.updBtn();toast('The 3D view could not start here, so you are in the flat view.')});
  if(window.THREE&&window.GLTFLoader)go();else{window.addEventListener('three-ready',go,{once:true});setTimeout(()=>{if(!window.THREE&&HD.on){HD.on=false;HD.updBtn()}},20000)}};

/* ---------- heights: tile coordinates in, world px out ---------- */
HD.N=2;
HD.baseH=function(x,y){const L=landF(x,y);const k=shoreKind(x,y);const quay=k==='wall'&&y>43.4&&y<84.6&&x<58;
  if(L<0)return quay?-24:Math.max(-26,L*11)-1.2;
  if(quay)return 6;
  let h=k==='mud'?2.2*smooth(0,1,L)+3.8*smooth(1.5,5,L):6*smooth(0,1.4,L);
  if(k==='rock')h+=(NZ.at(x*7,y*7)-.35)*6*smooth(0,1,L)*(1-smooth(5,8,L));
  return h};
HD.prepHeights=function(){const S=WORLD,W=S.w,H=S.h;
  // hills rise only well away from anything built or paved
  const dist=new Uint8Array(W*H).fill(99),qx=[];const flat=new Uint8Array(W*H);
  for(let i=0;i<W*H;i++){const g=S.g[i];if(g!=='g'&&g!=='gb'&&g!=='o')flat[i]=1}
  for(const w of S.wins||[]){const x0=w.x/16|0,y0=w.y/16|0,x1=(w.x+w.w)/16|0,y1=(w.y+w.h)/16|0;for(let y=y0-1;y<=y1+1;y++)for(let x=x0-1;x<=x1+1;x++)if(x>=0&&y>=0&&x<W&&y<H)flat[y*W+x]=1}
  for(const a of S.acts||[]){const x=a.x/16|0,y=a.y/16|0;for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<W&&Y<H)flat[Y*W+X]=1}}
  for(let i=0;i<W*H;i++)if(flat[i]){dist[i]=0;qx.push(i)}
  for(let h=0;h<qx.length;h++){const i=qx[h],x=i%W,y=i/W|0,d=dist[i]+1;if(d>8)continue;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X<0||Y<0||X>=W||Y>=H)continue;const j=Y*W+X;if(dist[j]>d){dist[j]=d;qx.push(j)}}}
  HD.dgrid=dist;HD.nx=W*HD.N+1;HD.ny=H*HD.N+1;HD.hts=new Float32Array(HD.nx*HD.ny).fill(NaN)};
HD.hv=function(i,j){const nx=HD.nx;i=clamp(i,0,nx-1);j=clamp(j,0,HD.ny-1);const k=j*nx+i;let h=HD.hts[k];if(h===h)return h;
  const S=WORLD,x=i/HD.N,y=j/HD.N;h=HD.baseH(x,y);
  if(h>=5.9){const tx=Math.min(S.w-1,x|0),ty=Math.min(S.h-1,y|0);const f=smooth(1.5,5.5,HD.dgrid[ty*S.w+tx]);
    if(f>0){const L=landF(x,y);h+=f*smooth(3,10,L)*(4+26*NZ.at(x*1.6+11,y*1.6+3)+7*NZ.at(x*4+40,y*4))}}
  HD.hts[k]=h;return h};
HD.deckH={pr:5,bw:5.5};
HD.hAt=function(wx,wy){const tx=Math.floor(wx/16),ty=Math.floor(wy/16);const t=tileT(WORLD,tx,ty);if(t==='pr'||t==='bw')return HD.deckH[t];
  const fx=wx/16*HD.N,fy=wy/16*HD.N;const i=Math.floor(fx),j=Math.floor(fy),a=fx-i,b=fy-j;
  return(HD.hv(i,j)*(1-a)+HD.hv(i+1,j)*a)*(1-b)+(HD.hv(i,j+1)*(1-a)+HD.hv(i+1,j+1)*a)*b};
HD.standH=function(wx,wy){return Math.max(HD.hAt(wx,wy),HD.wy)};

/* ---------- textures and atlases ---------- */
HD.tex=function(c,o={}){const T=THREE;const t=new T.CanvasTexture(c);t.colorSpace=T.SRGBColorSpace;t.flipY=!!o.flipY;t.magFilter=o.smooth?T.LinearFilter:T.NearestFilter;
  if(o.mip){t.minFilter=T.LinearMipmapLinearFilter;t.generateMipmaps=true;t.anisotropy=Math.min(4,HD.gl.capabilities.getMaxAnisotropy())}else{t.minFilter=o.smooth?T.LinearFilter:T.NearestFilter;t.generateMipmaps=false}return t};
HD.crop=function(img,x,y,w,h){const[c,g]=mk(Math.max(1,w),Math.max(1,h));g.drawImage(img,x,y,w,h,0,0,w,h);return c};
HD.pack=function(list,W,H){const[c,g]=mk(W,H);const out=new Map();let x=1,y=1,rh=0;const L=[...new Set(list)].sort((a,b)=>b.height-a.height);
  for(const im of L){if(x+im.width+1>W){x=1;y+=rh+2;rh=0}if(y+im.height+1>H){console.warn('HD-2D atlas full');break}g.drawImage(im,x,y);out.set(im,[x,y,im.width,im.height]);x+=im.width+2;rh=Math.max(rh,im.height)}
  return{c,map:out}};

/* ---------- sprite material: pixel billboards that stand up (people), face the camera, or lie flat (boats, flowers) ---------- */
HD.sprMat=function(tex,W,H){const T=THREE;return new T.ShaderMaterial({uniforms:{map:{value:tex},atW:{value:new T.Vector2(W,H)},time:{value:0},tint:{value:new T.Color(1,1,1)},bcs:{value:new T.Vector2(.7,.7)},
    fogC:{value:new T.Color('#9cc8dc')},fogN:{value:1e5},fogF:{value:2e5},lampP:{value:Array.from({length:8},()=>new T.Vector3(0,-1e5,0))},lampK:{value:0}},
  vertexShader:`attribute vec3 iPos;attribute vec4 iRect;attribute vec2 iSz;attribute float iSway;attribute float iFace;uniform float time;uniform vec2 atW;uniform vec2 bcs;varying vec2 vUv;varying vec3 vW;varying float vD;
void main(){vec2 q=position.xy;vec3 o;if(iFace<.5)o=vec3(q.x*iSz.x,q.y*iSz.y,0.);else if(iFace<1.5)o=vec3(q.x*iSz.x,q.y*iSz.y*bcs.x,-q.y*iSz.y*bcs.y);else{float g=iFace-2.;o=vec3(q.x*iSz.x,q.y*iSz.y*g,-q.y*iSz.y*sqrt(1.-g*g));}
vec3 p=iPos+o;p.x+=iSway*sin(time*1.9-iPos.x*.011+iPos.z*.004)*q.y*q.y*1.6;
vUv=vec2(iRect.x+(q.x+.5)*iRect.z,iRect.y+(1.-q.y)*iRect.w)/atW;vW=p;vec4 mv=modelViewMatrix*vec4(p,1.);vD=-mv.z;gl_Position=projectionMatrix*mv;}`,
  fragmentShader:`uniform sampler2D map;uniform vec3 tint;uniform vec3 fogC;uniform float fogN,fogF;uniform vec3 lampP[8];uniform float lampK;varying vec2 vUv;varying vec3 vW;varying float vD;
void main(){vec4 c=texture2D(map,vUv);if(c.a<.5)discard;vec3 l=tint;for(int i=0;i<8;i++){float d=distance(vW.xz,lampP[i].xz);l+=lampK*vec3(1.,.72,.42)*smoothstep(64.,6.,d);}
vec3 col=c.rgb*min(l,vec3(1.3));col=mix(col,fogC,smoothstep(fogN,fogF,vD));gl_FragColor=vec4(col,1.);
#include <colorspace_fragment>
}`})};
HD.sprGeo=function(n){const T=THREE;const g=new T.InstancedBufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute([-.5,0,0,.5,0,0,.5,1,0,-.5,1,0],3));g.setIndex([0,1,2,0,2,3]);
  const at=(k,s)=>{const a=new T.InstancedBufferAttribute(new Float32Array(n*s),s);a.setUsage(T.DynamicDrawUsage);g.setAttribute(k,a);return a};
  g.userData={iPos:at('iPos',3),iRect:at('iRect',4),iSz:at('iSz',2),iSway:at('iSway',1),iFace:at('iFace',1),n};g.instanceCount=0;return g};
HD.sprSet=function(g,i,x,y,z,r,w,h,sway,face){const u=g.userData;u.iPos.setXYZ(i,x,y,z);u.iRect.setXYZW(i,r[0],r[1],r[2],r[3]);u.iSz.setXY(i,w,h);u.iSway.setX(i,sway||0);u.iFace.setX(i,face||0)};
HD.sprDone=function(g,n){const u=g.userData;g.instanceCount=n;for(const k of['iPos','iRect','iSz','iSway','iFace'])u[k].needsUpdate=true};
HD.blobMat=function(){const T=THREE;return new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{k:{value:.3}},
  vertexShader:`attribute vec3 iPos;attribute vec2 iSz;varying vec2 q;void main(){q=position.xy;vec3 p=iPos+vec3(q.x*iSz.x,.35,(q.y-.5)*iSz.y);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.);}`,
  fragmentShader:`uniform float k;varying vec2 q;void main(){vec2 d=vec2(q.x*2.,(q.y-.5)*2.);float r=length(d);if(r>1.)discard;gl_FragColor=vec4(.11,.08,.16,(r<.7?k:k*.55));}`})};
// a stand-in context that only measures where a draw call would paint (to find each sprite's footprint)
HD.mkRec=function(){const B={x0:1e9,y0:1e9,x1:-1e9,y1:-1e9},st=[];let tx=0,ty=0;const add=(x,y,w,h)=>{x+=tx;y+=ty;if(x<B.x0)B.x0=x;if(y<B.y0)B.y0=y;if(x+w>B.x1)B.x1=x+w;if(y+h>B.y1)B.y1=y+h};
  const o={B,reset(){B.x0=B.y0=1e9;B.x1=B.y1=-1e9;tx=ty=0;st.length=0},drawImage(im,a,b,c,d,e,f,g,h){if(arguments.length>=9)add(e,f,g,h);else if(arguments.length>=5)add(a,b,c,d);else add(a,b,im.width||0,im.height||0)},
    fillRect(x,y,w,h){add(x,y,w,h)},strokeRect(x,y,w,h){add(x,y,w,h)},ellipse(x,y,rx,ry){add(x-rx,y-ry,rx*2,ry*2)},moveTo(x,y){add(x,y,1,1)},lineTo(x,y){add(x,y,1,1)},arc(x,y,r){add(x-r,y-r,r*2,r*2)},
    save(){st.push([tx,ty])},restore(){const s=st.pop();if(s){tx=s[0];ty=s[1]}},translate(x,y){tx+=x;ty+=y},createRadialGradient(){return{addColorStop(){}}},createLinearGradient(){return{addColorStop(){}}},measureText(){return{width:0}}};
  return new Proxy(o,{get:(t,k)=>k in t?t[k]:(typeof k==='string'?()=>{}:undefined),set:(t,k,v)=>{t[k]=v;return true}})};

/* ---------- build the scene ---------- */
HD.init=async function(){const T=THREE,S=WORLD;
  const gl=new T.WebGLRenderer({antialias:true,powerPreference:'high-performance'});HD.gl=gl;
  HD.touch=matchMedia('(pointer:coarse)').matches;HD.pr=Math.min(HD.touch?1.5:2,window.devicePixelRatio||1);gl.setPixelRatio(HD.pr);gl.outputColorSpace=T.SRGBColorSpace;gl.shadowMap.enabled=true;gl.shadowMap.type=T.PCFSoftShadowMap;
  const el=gl.domElement;el.id='gl3d';el.style.cssText='position:absolute;left:0;top:0;pointer-events:none;display:none';HD.vis=false;cv.parentNode.insertBefore(el,cv);
  const sc=new T.Scene();HD.sc=sc;sc.background=new T.Color('#2a74a8');sc.fog=new T.Fog('#a8d2e4',1e5,2e5);
  HD.cam=new T.PerspectiveCamera(HD.FOV,1,20,8000);HD.ray0=new T.Raycaster();
  HD.prepHeights();
  HD.groundMat=new T.MeshLambertMaterial({color:0xffffff});
  {const lo=tileMap(S,4);HD.loMap=lo;}
  const out=new T.Mesh(new T.PlaneGeometry(40000,40000).rotateX(-Math.PI/2),new T.MeshLambertMaterial({color:'#12204e'}));out.position.set(S.w*8,-30,S.h*8);sc.add(out);
  HD.chunkRoot=new T.Group();sc.add(HD.chunkRoot);
  // piers, jetties, bridges and breakwalls: decks that reuse the painted planks and stones
  {const W=S.w,H=S.h;const isD=(x,y)=>{const t=tileT(S,x,y);return t==='pr'||t==='bw'};const piles=[],rocks=[];const rr=rng(99);const byChunk=new Map();
    for(let ty=0;ty<H;ty++)for(let tx=0;tx<W;tx++){const t=S.g[ty*W+tx];if(t!=='pr'&&t!=='bw')continue;const k=(ty>>5)*1000+(tx>>5);let D=byChunk.get(k);if(!D){D={top:[],tuv:[],side:[],sc:[]};byChunk.set(k,D)}
      const h=HD.deckH[t],x0=tx*16,x1=x0+16,z0=ty*16,z1=z0+16;const ox=(tx>>5)*512,oy=(ty>>5)*512;
      D.top.push(x0,h,z0,x0,h,z1,x1,h,z0,x1,h,z0,x0,h,z1,x1,h,z1);const u0=(x0-ox)/512,u1=(x1-ox)/512,v0=(z0-oy)/512,v1=(z1-oy)/512;D.tuv.push(u0,v0,u0,v1,u1,v0,u1,v0,u0,v1,u1,v1);
      const low=t==='pr'?h-3:-14;const col=t==='pr'?[.35,.24,.17]:[.42,.4,.5];
      const face=(ax,az,bx,bz)=>{D.side.push(ax,h,az,ax,low,az,bx,h,bz,bx,h,bz,ax,low,az,bx,low,bz);for(let i=0;i<6;i++)D.sc.push(...col)};
      if(!isD(tx,ty+1))face(x0,z1,x1,z1);if(!isD(tx,ty-1))face(x1,z0,x0,z0);if(!isD(tx-1,ty))face(x0,z0,x0,z1);if(!isD(tx+1,ty))face(x1,z1,x1,z0);
      if(t==='pr'&&HD.baseH(tx+.5,ty+.5)<0){if(!isD(tx,ty+1)&&tx%2===0)piles.push([x0+2,h,z1-1.5]);if(!isD(tx,ty-1)&&tx%2===0)piles.push([x0+2,h,z0+1.5]);if(!isD(tx-1,ty)&&ty%2===0)piles.push([x0+1.5,h,z0+2]);if(!isD(tx+1,ty)&&ty%2===0)piles.push([x1-1.5,h,z0+2])}
      if(t==='bw'){for(const[dx,dy]of[[0,1],[0,-1],[1,0],[-1,0]]){if(isD(tx+dx,ty+dy))continue;for(let k2=0;k2<2;k2++)rocks.push([x0+8+dx*9+(dy?(rr()-.5)*14:0),z0+8+dy*9+(dx?(rr()-.5)*14:0),.8+rr()*.6,rr()*6.28,(rr()*3)|0])}}}
    HD.deckData=byChunk;HD.decks=[];
    for(const D of byChunk.values()){const g2=new T.BufferGeometry();g2.setAttribute('position',new T.Float32BufferAttribute(D.side,3));g2.setAttribute('color',new T.Float32BufferAttribute(D.sc,3));g2.computeVertexNormals();sc.add(new T.Mesh(g2,new T.MeshLambertMaterial({vertexColors:true,side:T.DoubleSide})))}
    HD._piles=piles;HD._rocks=rocks}
  // the Blender kit
  const kit=await new Promise((res,rej)=>{const bin=Uint8Array.from(atob(HD_GLB),c=>c.charCodeAt(0));new GLTFLoader().parse(bin.buffer,'',res,rej)});
  const part=n=>{const o=kit.scene.getObjectByName(n);if(!o)throw new Error('HD-2D kit is missing '+n);return o};HD.part=part;
  const lam=(m,o={})=>{const n=new T.MeshLambertMaterial({color:m.color?m.color.clone():new T.Color(1,1,1)});Object.assign(n,o);return n};HD.lam=lam;
  const inst=(name,list,fn)=>{if(!list.length)return[];const src=part(name);const parts=[];src.traverse(c=>{if(c.isMesh)parts.push(c)});const out=[];
    for(const p of parts){const glow=/glow|glass/.test(p.material.name||'');const im=new T.InstancedMesh(p.geometry,lam(p.material,glow?{emissive:new T.Color('#ffc86a'),emissiveIntensity:0}:{}),list.length);if(glow)HD.glow.push(im.material);
      const M=new T.Matrix4(),Q=new T.Quaternion(),P=new T.Vector3(),Sv=new T.Vector3();list.forEach((it,i)=>{fn(it,P,Q,Sv);M.compose(P,Q,Sv);im.setMatrixAt(i,M)});im.castShadow=true;im.receiveShadow=true;sc.add(im);out.push(im)}
    return out};
  HD.glow=[];HD.winMats=[];const up=new T.Vector3(0,1,0);
  inst('pile',HD._piles,(p,P,Q,Sv)=>{P.set(p[0],p[1],p[2]);Q.identity();Sv.set(16,16,16)});
  for(const k of[0,1,2])inst('rock_'+'abc'[k],HD._rocks.filter(r=>r[4]===k),(r,P,Q,Sv)=>{P.set(r[0],-1+r[2]*2,r[1]);Q.setFromAxisAngle(up,r[3]);Sv.setScalar(16*r[2])});
  {const L=[];for(let ty=43;ty<85;ty++)if(shoreKind(56,ty+.5)==='wall')L.push(ty);inst('quaywall',L,(ty,P,Q,Sv)=>{P.set(56*16,6,ty*16);Q.identity();Sv.set(16,16,16)})}
  // world props: buildings, lighthouses, sea stacks and lamps become models; everything else a billboard
  const stat=[],anim=[],stacks=[],lamps=[];
  for(const p of S.props){const k=p.img&&p.img._k;
    if(k==='bld'){try{HD.addBuilding(p)}catch(e){console.warn('HD-2D building',e);stat.push(p)}}
    else if(k==='lh'){const o=part('lighthouse').clone();o.traverse(c=>{if(!c.isMesh)return;const nm=c.material.name||'';c.material=lam(c.material);c.castShadow=c.receiveShadow=true;if(/glass/.test(nm)){c.material.emissive=new T.Color('#ffd27a');c.material.emissiveIntensity=0;HD.glow.push(c.material)}});
      const x=p.x+p.img.width/2,z=p.sy-10;o.position.set(x,HD.hAt(x,z)-1,z);o.scale.set(16,16*1.05,16);sc.add(o);if(!HD.lhObj)HD.lhObj=o}
    else if(k==='stack')stacks.push(p);else if(k==='lamp')lamps.push(p);else if(p.anim)anim.push(p);else stat.push(p)}
  for(const v of[0,1])inst(v?'stack_b':'stack_a',stacks.filter(p=>(p.img._v||0)%2===v),(p,P,Q,Sv)=>{const x=p.x+p.img.width/2,z=p.y+p.img.height-11;P.set(x,-1,z);Q.setFromAxisAngle(up,hash2(x,z,5)*6.28);Sv.set(16,16*(1.1+hash2(x,z,6)*.3),16)});
  HD.lampPos=lamps.map(p=>[p.x+p.img.width/2,p.y+p.img.height-1]);
  inst('lamp_post',HD.lampPos,(l,P,Q,Sv)=>{P.set(l[0],HD.hAt(l[0],l[1]),l[1]);Q.identity();Sv.set(15,15,15)});
  // one atlas for every still prop: upright ones stand, flat ones (flowers, towels, paths) lie on the ground
  {const pk=HD.pack(stat.map(p=>p.img),2048,2048);HD.statTex=HD.tex(pk.c);const g=HD.sprGeo(stat.length);let n=0;
    for(const p of stat){const r=pk.map.get(p.img);if(!r)continue;
      if(p.flat){const x=p.x+p.img.width/2,z=p.y+p.img.height;HD.sprSet(g,n++,x,HD.hAt(x,p.y+p.img.height/2)+.45,z,r,p.img.width,p.img.height,0,2)}
      else{const x=p.x+p.img.width/2,z=p.y+p.img.height-2;HD.sprSet(g,n++,x,HD.standH(x,z)-.5,z,r,p.img.width,p.img.height*HD.KZ0(),p.sway?1:0,0)}}
    HD.sprDone(g,n);HD.statMat=HD.sprMat(HD.statTex,2048,2048);const m=new T.Mesh(g,HD.statMat);m.frustumCulled=false;sc.add(m)}
  HD.animProps=anim;
  // moving sprites are redrawn every frame into one atlas
  {const[c,g]=mk(1024,1024);HD.acv=c;HD.actx=g;HD.dynTex=HD.tex(c);HD.dynGeo=HD.sprGeo(200);HD.dynMat=HD.sprMat(HD.dynTex,1024,1024);const m=new T.Mesh(HD.dynGeo,HD.dynMat);m.frustumCulled=false;sc.add(m)}
  HD.rctx=HD.mkRec();
  {const g=new T.InstancedBufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute([-.5,0,0,.5,0,0,.5,1,0,-.5,1,0],3));g.setIndex([0,1,2,0,2,3]);
    const a=new T.InstancedBufferAttribute(new Float32Array(200*3),3),b=new T.InstancedBufferAttribute(new Float32Array(200*2),2);a.setUsage(T.DynamicDrawUsage);b.setUsage(T.DynamicDrawUsage);g.setAttribute('iPos',a);g.setAttribute('iSz',b);g.instanceCount=0;
    HD.blobGeo=g;const m=new T.Mesh(g,HD.blobMat());m.frustumCulled=false;m.renderOrder=3;sc.add(m)}
  // water: a clear, glinting sheet that rises and falls with the tide; the sea's life rides on a decal that follows the view
  {HD.waterMat=new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{time:{value:0},night:{value:0},fogC:{value:new T.Color('#9cc8dc')},fogN:{value:1e5},fogF:{value:2e5}},
    vertexShader:`varying vec3 wp;varying float vD;void main(){vec4 w=modelMatrix*vec4(position,1.);wp=w.xyz;vec4 mv=viewMatrix*w;vD=-mv.z;gl_Position=projectionMatrix*mv;}`,
    fragmentShader:`uniform float time,night;uniform vec3 fogC;uniform float fogN,fogF;varying vec3 wp;varying float vD;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void main(){vec2 p=floor(wp.xz/2.)*2.;float n=sin(p.x*.045+time*1.1)*sin(p.y*.06-time*.8)+sin((p.x+p.y)*.021+time*.55)*.8;
vec3 col=mix(vec3(.10,.36,.56),vec3(.05,.10,.26),night);float a=.26+.06*n;
float g=step(.985,h(floor(p/4.)+floor(time*1.5)))*smoothstep(.6,1.4,n);col=mix(col,vec3(.92,.98,1.),g*.9);a=max(a,g*.8);
col=mix(col,fogC,smoothstep(fogN,fogF,vD));gl_FragColor=vec4(col,a);
#include <colorspace_fragment>
}`});const w=new T.Mesh(new T.PlaneGeometry(40000,40000).rotateX(-Math.PI/2),HD.waterMat);w.position.set(S.w*8,0,S.h*8);w.renderOrder=1;sc.add(w);HD.water=w;
    HD.foamMat=new T.MeshBasicMaterial({transparent:true,depthWrite:false,opacity:.5,color:0xffffff});
    const[c,g]=mk(1024,768);HD.scv=c;HD.sctx=g;HD.seaTex=HD.tex(c,{flipY:true});const d=new T.Mesh(new T.PlaneGeometry(1024,768).rotateX(-Math.PI/2),new T.MeshBasicMaterial({map:HD.seaTex,transparent:true,depthWrite:false}));d.renderOrder=2;sc.add(d);HD.seaDecal=d}
  // light: sun and sky, the nearest street lamps, a lantern on your boat and the lighthouse beam
  {HD.amb=new T.AmbientLight(0xffffff,1);sc.add(HD.amb);const sun=new T.DirectionalLight(0xffffff,1);sun.castShadow=true;const c2=sun.shadow.camera;c2.left=-520;c2.right=520;c2.top=520;c2.bottom=-520;c2.near=10;c2.far=3000;
    sun.shadow.mapSize.set(2048,2048);sun.shadow.bias=-.0004;sun.shadow.normalBias=.6;sc.add(sun);sc.add(sun.target);HD.sun=sun;
    HD.pl=[];for(let i=0;i<6;i++){const l=new T.PointLight(0xffb060,0,110,0);sc.add(l);HD.pl.push(l)}
    HD.boatLamp=new T.PointLight(0xfff0c0,0,160,0);sc.add(HD.boatLamp);
    const beam=new T.Group();const bm=new T.MeshBasicMaterial({color:0xfff2b0,transparent:true,opacity:0,blending:T.AdditiveBlending,depthWrite:false,side:T.DoubleSide});HD.beamMat=bm;
    for(const s of[1,-1]){const cg=new T.ConeGeometry(22,240,24,1,true);cg.translate(0,-120,0);cg.rotateZ(s*Math.PI/2);beam.add(new T.Mesh(cg,bm))}
    if(HD.lhObj)beam.position.copy(HD.lhObj.position).add(new T.Vector3(0,5.3*16*1.05,0));sc.add(beam);HD.beam=beam}
  // post: a tilt-shift focus band and a soft vignette
  {const rt=new T.WebGLRenderTarget(4,4,{samples:4,type:T.HalfFloatType});HD.rt=rt;
    HD.ovTex=HD.tex(cv);HD.post=new T.ShaderMaterial({uniforms:{tD:{value:rt.texture},tO:{value:HD.ovTex},res:{value:new T.Vector2(1,1)},amt:{value:5}},depthTest:false,depthWrite:false,
      vertexShader:`varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.,1.);}`,
      fragmentShader:`uniform sampler2D tD;uniform sampler2D tO;uniform vec2 res;uniform float amt;varying vec2 vUv;
void main(){float b=smoothstep(.2,.5,abs(vUv.y-.5))*amt;vec4 c=vec4(0.);for(int i=0;i<12;i++){float a=float(i)*2.39996;float r=sqrt(float(i)+.5)/3.5;c+=texture2D(tD,vUv+vec2(cos(a),sin(a))*r*b/res);}c/=12.;
float v=smoothstep(1.05,.4,length((vUv-.5)*vec2(1.1,1.)));c.rgb*=mix(.8,1.,v);vec4 o=texture2D(tO,vec2(vUv.x,1.-vUv.y));c.rgb=mix(c.rgb,o.rgb,o.a);gl_FragColor=vec4(c.rgb,1.);
#include <colorspace_fragment>
}`});HD.postScene=new T.Scene();HD.postCam=new T.OrthographicCamera(-1,1,1,-1,0,1);HD.postScene.add(new T.Mesh(new T.PlaneGeometry(2,2),HD.post))}
  HD.resize();window.addEventListener('resize',()=>setTimeout(HD.resize,0))};
HD.KZ0=function(){return 1/Math.cos(HD.PITCH*Math.PI/180)};
HD.q0={n:0,acc:0,t0:0,step:0};
HD.quality=function(now){const Q=HD.q0;if(!Q.last){Q.last=now;Q.t0=now;return}const d=now-Q.last;Q.last=now;if(d>250){Q.t0=now;Q.n=Q.acc=0;return}Q.n++;Q.acc+=d;
  if(now-Q.t0<3000)return;const avg=Q.acc/Q.n;Q.t0=now;Q.n=Q.acc=0;if(avg<26||Q.step>=3)return;Q.step++;
  if(Q.step===1){HD.pr=Math.max(1,HD.pr*.75);HD.gl.setPixelRatio(HD.pr);HD.resize()}
  else if(Q.step===2){HD.noShadow=true;HD.gl.shadowMap.enabled=false;HD.sun.castShadow=false}
  else{HD.pr=1;HD.gl.setPixelRatio(1);HD.post.uniforms.amt.value=0;HD.noBlur=true;HD.resize()}
  console.info('HD-2D quality step',Q.step,'avg frame',avg.toFixed(1)+'ms')};

/* ---------- ground chunks: 32x32 tiles, matching the flat view's painted 512px chunks ---------- */
HD.chunk=function(cx,cy){const k=cy*1000+cx;let C=HD.chunks.get(k);if(C){C.used=HD.fr;return C}
  const T=THREE,N=HD.N,TS=32,n=TS*N+1;const pos=new Float32Array(n*n*3),uv=new Float32Array(n*n*2);
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const q=j*n+i,I=cx*TS*N+i,J=cy*TS*N+j;pos[q*3]=I/N*16;pos[q*3+1]=HD.hv(I,J);pos[q*3+2]=J/N*16;uv[q*2]=i/(n-1);uv[q*2+1]=j/(n-1)}
  const idx=new Uint16Array((n-1)*(n-1)*6);let m=0;for(let j=0;j<n-1;j++)for(let i=0;i<n-1;i++){const a=j*n+i,b=a+1,c=a+n,d=c+1;idx[m++]=a;idx[m++]=c;idx[m++]=b;idx[m++]=b;idx[m++]=c;idx[m++]=d}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.BufferAttribute(pos,3));g.setAttribute('uv',new T.BufferAttribute(uv,2));g.setIndex(new T.BufferAttribute(idx,1));g.computeVertexNormals();
  // until the real pixels are painted, a soft colour map of the tiles stands in
  const lo=HD.crop(HD.loMap,cx*128,cy*128,128,128);const loT=HD.tex(lo,{smooth:true});const mat=new T.MeshLambertMaterial({map:loT});
  const mesh=new T.Mesh(g,mat);mesh.receiveShadow=true;HD.chunkRoot.add(mesh);
  C={k,cx,cy,mesh,mat,loT,painted:false,used:HD.fr,deck:null,foam:null};HD.chunks.set(k,C);return C};
HD.paintChunk=function(C,out){const T=THREE;const[bc,bx]=mk(512,512);bx.imageSmoothingEnabled=false;bx.drawImage(C.loT.image,0,0,512,512);bx.drawImage(out.g,0,0);C.loT.dispose();const t=HD.tex(bc,{mip:true});C.mat.map=t;C.mat.needsUpdate=true;C.tex=t;C.painted=true;
  const D=HD.deckData.get(C.k);if(D){const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(D.top,3));g.setAttribute('uv',new T.Float32BufferAttribute(D.tuv,2));g.computeVertexNormals();C.deck=new T.Mesh(g,new T.MeshLambertMaterial({map:t}));C.deck.receiveShadow=C.deck.castShadow=true;HD.chunkRoot.add(C.deck);HD.decks.push(C.deck)}
  if(out.f){const ft=HD.tex(out.f,{flipY:true});C.ftex=ft;const m=new T.Mesh(new T.PlaneGeometry(512,512).rotateX(-Math.PI/2),HD.foamMat.clone());m.material.map=ft;m.position.set(C.cx*512+256,HD.wy+.25,C.cy*512+256);m.renderOrder=2;C.foam=m;HD.chunkRoot.add(m)}};
HD.dropChunk=function(C){HD.chunkRoot.remove(C.mesh);C.mesh.geometry.dispose();C.mat.dispose();if(C.tex)C.tex.dispose();else C.loT.dispose();
  if(C.deck){HD.chunkRoot.remove(C.deck);C.deck.geometry.dispose();C.deck.material.dispose();HD.decks.splice(HD.decks.indexOf(C.deck),1)}if(C.foam){HD.chunkRoot.remove(C.foam);C.foam.material.dispose();C.ftex.dispose()}HD.chunks.delete(C.k)};
HD.chunkPass=function(){const S=WORLD,R=HD.reg;HD.fr=(HD.fr||0)+1;const ncx=Math.ceil(S.w/32),ncy=Math.ceil(S.h/32);
  const cx0=Math.max(0,Math.floor((R.x0-64)/512)),cx1=Math.min(ncx-1,Math.floor((R.x1+64)/512)),cy0=Math.max(0,Math.floor((R.z0-64)/512)),cy1=Math.min(ncy-1,Math.floor((R.z1+64)/512));
  let want=null,wd=1e9;
  for(let cy=cy0;cy<=cy1;cy++)for(let cx=cx0;cx<=cx1;cx++){const C=HD.chunk(cx,cy);if(C.painted)continue;const got=GCH.map.get(C.k);if(got){HD.paintChunk(C,got);continue}
    const d=Math.hypot(cx*512+256-HD.tgt.x,cy*512+256-HD.tgt.z);if(d<wd){wd=d;want=C}}
  if(want){const J=GCH.job;if(wd<560||!HD.warm){const out=groundChunk(S,want.cx,want.cy);HD.paintChunk(want,out)}else if(!J){GCH.job=chunkJob(S,want.cx,want.cy)}}
  HD.warm=true;for(const C of HD.chunks.values())if(C.foam){C.foam.position.y=HD.wy+.25;C.foam.material.opacity=HD.foamK}
  if(HD.chunks.size>40){const L=[...HD.chunks.values()].filter(C=>C.used<HD.fr-2).sort((a,b)=>a.used-b.used);for(const C of L.slice(0,HD.chunks.size-40))HD.dropChunk(C)}};

/* ---------- buildings: Blender shells wearing their pixel art ---------- */
HD.addBuilding=function(p){const T=THREE,img=p.img,b=img._b,o=b.o,w=b.w,h=b.h,r=b.r,W=w*16,H=(h+r)*16,RH=r*16+4,VS=HD.VS,part=HD.part;
  const tx=p.x/16,ty=p.y/16+r;let name=o.flat?'flat_6x3':o.barn?'barn_7x3':'gable_'+w+'x'+h,sx=16;
  if(!HD.sc.getObjectByName&&0)return;try{part(name)}catch(e){name=h<=2?'gable_4x2':'gable_'+clamp(w,5,8)+'x3';const bw=h<=2?4:clamp(w,5,8);sx=16*w/bw}
  const fac=HD.crop(img,0,RH-5,W,H-(RH-5));const roof=HD.crop(img,0,0,W,RH-5);const rg=roof.getContext('2d');
  let sign=null,lx=0,lw=0;if(o.label){lw=textW(o.label)+8;lx=(W-lw)/2|0;const ly=RH-15;sign=HD.crop(img,lx-2,ly,lw+4,11);if(!o.flat&&ly-16>=0)rg.drawImage(roof,lx-2,ly-16,lw+4,RH-5-ly,lx-2,ly,lw+4,RH-5-ly)}
  if(o.chimney&&!o.flat&&W>=40)rg.drawImage(roof,W-31,0,13,14,W-19,0,13,14);
  const[wc,wg]=mk(fac.width,fac.height);{const d=fac.getContext('2d').getImageData(0,0,fac.width,fac.height).data;const G=new Set(['214,242,248','168,220,238','134,196,224','236,250,253']);wg.fillStyle='#000';wg.fillRect(0,0,fac.width,fac.height);wg.fillStyle='#ffc870';
    for(let y=0;y<fac.height;y++)for(let x=0;x<fac.width;x++){const i=(y*fac.width+x)*4;if(G.has(d[i]+','+d[i+1]+','+d[i+2]))wg.fillRect(x,y,1,1)}}
  const facT=HD.tex(fac),roofT=HD.tex(roof),winT=HD.tex(wc);const wall=new T.Color(o.wall||'#e8e2d0');
  const g=part(name).clone();g.traverse(c=>{if(!c.isMesh)return;const n=(c.material.name||'').split('.')[0];let m;
    if(n==='facade'){m=new T.MeshLambertMaterial({map:facT,emissiveMap:winT,emissive:new T.Color(0,0,0)});HD.winMats.push(m)}else if(n==='roof')m=new T.MeshLambertMaterial({map:roofT});else if(n==='wall')m=new T.MeshLambertMaterial({color:wall});else m=HD.lam(c.material);
    c.material=m;c.castShadow=true;c.receiveShadow=true});
  const base=Math.min(HD.hAt(tx*16+W/2,(ty+h)*16),HD.hAt(tx*16+W/2,ty*16))-.2;g.position.set(tx*16,base,ty*16);g.scale.set(sx,16*VS,16);HD.sc.add(g);
  const front=(ty+h)*16,top=base+(h*16+1)*VS;const lamb=(o2,fn)=>{o2.traverse(c=>{if(c.isMesh){c.material=fn(c);c.castShadow=true}});return o2};
  if(sign){const st=HD.tex(sign);const s=lamb(part('part_sign').clone(),c=>(c.material.name||'').startsWith('sign')?new T.MeshLambertMaterial({map:st}):new T.MeshLambertMaterial({color:'#2a1e33'}));
    s.position.set(tx*16+lx-2+(lw+4)/2,top-5*VS,front+(o.flat?1.5:4.2));s.scale.set(lw+4,11*VS,16);HD.sc.add(s)}
  if(o.awning){const at=HD.tex(HD.crop(fac,0,6,W,10));const a=lamb(part('part_awning').clone(),()=>new T.MeshLambertMaterial({map:at,side:T.DoubleSide}));a.position.set(tx*16+2,top-6*VS,front+.4);a.scale.set(W-4,16*VS,16);HD.sc.add(a)}
  for(const cx of(o.columns||[])){const c=lamb(part('part_column').clone(),()=>new T.MeshLambertMaterial({color:'#ece8e0'}));c.position.set(tx*16+cx+3,base,front+4);c.scale.set(13,(top-base)/2.66,13);HD.sc.add(c)}
  if(o.chimney&&!o.flat){const rise=h*(o.barn?.55:.42)*16*VS;const c=lamb(part('part_chimney').clone(),c=>new T.MeshLambertMaterial({color:c.material.color}));c.position.set(tx*16+W-13,top,ty*16+h*16*.3);c.scale.set(16,(rise+9)/1.18,16);HD.sc.add(c)}};

/* ---------- each frame ---------- */
HD.resize=function(){if(!HD.gl)return;const w=VW*SCALE,h=VH*SCALE;HD.gl.setSize(w,h);const pr=HD.gl.getPixelRatio();HD.rt.setSize(Math.round(w*pr),Math.round(h*pr));HD.post.uniforms.res.value.set(w*pr,h*pr);HD.post.uniforms.amt.value=HD.noBlur?0:4.5*pr;HD.vw=VW;HD.vh=VH};
HD.proj=function(x,h,z){const v=HD._v||(HD._v=new THREE.Vector3());v.set(x,h,z).project(HD.cam);const sx=(v.x+1)/2*VW,sy=(1-v.y)/2*VH,sz=v.z;v.set(x,h+10*HD.KZ,z).project(HD.cam);const sy2=(1-v.y)/2*VH;return{x:sx,y:sy,k:Math.max(.2,(sy-sy2)/10),z:sz}};
HD.rayTo=function(sx,sy,objs){HD.ray0.setFromCamera(new THREE.Vector2(sx/VW*2-1,1-sy/VH*2),HD.cam);const hit=HD.ray0.intersectObjects(objs,false);return hit.length?hit[0].point:null};
HD.tap=function(cx,cy){const sx=cx/SCALE,sy=cy/SCALE;let best=null,bd=1e9;
  const pick=(x,y,h,r,wx,wy)=>{const P=HD.proj(x,h,y);const d=Math.hypot(P.x-sx,P.y-10*P.k-sy);if(d<r*P.k&&d<bd){bd=d;best=[wx,wy]}};
  if(!player.boat&&!MG){for(const a of WORLD.acts)pick(a.x,a.y,HD.hAt(a.x,a.y),Math.max(16,a.r||0),a.x,a.y-10);for(const f of FOLK)pick(f.x,f.y,HD.hAt(f.x,f.y),13,f.x,f.y-10);
    for(const c of combSpots())pick(c.x,c.y,HD.hAt(c.x,c.y),12,c.x,c.y);if(S.boat){const sp=myBoatSpot();pick(sp.x,sp.y,HD.wy,22,sp.x,sp.y)}}
  if(best){tapWorld(best[0],best[1]);return}
  const objs=[HD.water,...HD.decks];for(const C of HD.chunks.values())objs.push(C.mesh);const p=HD.rayTo(sx,sy,objs);if(p)tapWorld(p.x,p.z)};
HD.render=function(t){const T=THREE,E=envAt(),S0=WORLD;if(HD.vw!==VW||HD.vh!==VH)HD.resize();
  const dt=Math.min(.1,Math.max(0,t-(HD.lt===undefined?t:HD.lt)));HD.lt=t;HD.quality(performance.now());HD.KZ=HD.KZ0();const beta=HD.PITCH*Math.PI/180;
  HD.wy=(E.tide||0)*1.4-.3;HD.water.position.y=HD.wy;
  const onB=player.boat;const fx=onB?onB.x:player.x,fz=onB?onB.y:player.y;const fh=onB?HD.wy:HD.hAt(fx,fz);
  const D=VH/(2*Math.tan(HD.FOV*Math.PI/360))*(HD.dist||1);const ww=S0.w*16,wh=S0.h*16;
  const tx=clamp(fx,VW*.5,ww-VW*.5),tz=clamp(fz-6,VH*.62,wh-VH*.5);
  if(!HD.tgt||Math.hypot(tx-HD.tgt.x,tz-HD.tgt.z)>400)HD.tgt={x:tx,z:tz,h:fh};else{const k=1-Math.exp(-dt*9);HD.tgt.x+=(tx-HD.tgt.x)*k;HD.tgt.z+=(tz-HD.tgt.z)*k;HD.tgt.h+=(fh-HD.tgt.h)*Math.min(1,k*.6)}
  const cam=HD.cam;cam.aspect=VW/VH;cam.fov=HD.FOV;cam.near=D*.25;cam.far=D*6;cam.updateProjectionMatrix();
  cam.position.set(HD.tgt.x,HD.tgt.h+D*Math.sin(beta),HD.tgt.z+D*Math.cos(beta));cam.lookAt(HD.tgt.x,HD.tgt.h,HD.tgt.z);cam.updateMatrixWorld();
  camX=Math.round(HD.tgt.x-VW/2);camY=Math.round(HD.tgt.z-VH/2);
  {let x0=1e9,x1=-1e9,z0=1e9,z1=-1e9;for(const[a,b]of[[0,0],[VW,0],[0,VH],[VW,VH],[VW/2,0]]){const p=HD.rayTo(a,b,[HD.water]);if(p){x0=Math.min(x0,p.x);x1=Math.max(x1,p.x);z0=Math.min(z0,p.z);z1=Math.max(z1,p.z)}}
    if(x0>x1){x0=HD.tgt.x-VW;x1=HD.tgt.x+VW;z0=HD.tgt.z-VH;z1=HD.tgt.z+VH}HD.reg={x0:x0-40,x1:x1+40,z0:z0-90,z1:z1+30}}
  // time of day and weather
  const ph=dayPhase();const n=clamp(ph.a/.42,0,1),du=clamp(ph.dusk/.24,0,1);const PI=Math.PI;
  const storm=E.sky==='storm'?.6:E.sky==='rain'?.8:E.sky==='fog'?.85:1;
  HD.amb.color.setRGB(1,1,1).lerp(new T.Color(1,.85,.8),du*.6).lerp(new T.Color(.42,.5,.85),n);HD.amb.intensity=PI*(.62-n*.36);
  HD.sun.color.setRGB(1,1,1).lerp(new T.Color(1,.62,.38),du).lerp(new T.Color(.55,.62,.95),n);HD.sun.intensity=PI*(.5-n*.38)*storm;
  const sd=new T.Vector3(.5,1,.55).normalize();if(du>0&&n<.5)sd.set(.9,.55,.4).normalize();HD.sun.position.set(HD.tgt.x+sd.x*900,HD.tgt.h+sd.y*900,HD.tgt.z+sd.z*900);HD.sun.target.position.set(HD.tgt.x,HD.tgt.h,HD.tgt.z);HD.sun.target.updateMatrixWorld();
  HD.sun.castShadow=n<.85&&!HD.noShadow;
  const nightK=clamp((n-.25)/.75,0,1);for(const m of HD.winMats){m.emissive.setRGB(1,.8,.5);m.emissiveIntensity=nightK*1.2}for(const m of HD.glow)m.emissiveIntensity=.2+nightK*2.2;
  const lamps=HD.lampPos.map(l=>[l[0],l[1],Math.hypot(l[0]-HD.tgt.x,l[1]-HD.tgt.z)]).sort((a,b)=>a[2]-b[2]);
  HD.pl.forEach((l,i)=>{const L=lamps[i];if(!L){l.intensity=0;return}l.position.set(L[0],HD.hAt(L[0],L[1])+32,L[1]+1);l.intensity=nightK*PI*1.1});
  const tint=new T.Color(1,1,1).lerp(new T.Color(1,.88,.8),du*.5).lerp(new T.Color(.46,.52,.82),n).multiplyScalar(storm<1?.92:1);
  for(const m of[HD.statMat,HD.dynMat]){m.uniforms.bcs.value.set(Math.cos(beta),Math.sin(beta));m.uniforms.time.value=t;m.uniforms.tint.value.copy(tint);m.uniforms.lampK.value=nightK*.9;for(let i=0;i<8;i++){const L=lamps[i];m.uniforms.lampP.value[i].set(L?L[0]:0,L?0:-1e5,L?L[1]:0)}}
  if(onB&&S.gear&&S.gear.lamp>=0){HD.boatLamp.position.set(onB.x,HD.wy+30,onB.y);HD.boatLamp.intensity=nightK*PI*1.3;HD.boatLamp.distance=150+S.gear.lamp*40}else HD.boatLamp.intensity=0;
  HD.beamMat.opacity=nightK*.1;HD.beam.rotation.y=-t*.9;HD.beam.visible=nightK>.02;
  HD.waterMat.uniforms.time.value=t;HD.waterMat.uniforms.night.value=n*.8;
  const fogC=new T.Color('#a8d2e4').lerp(new T.Color('#1a2440'),n);const fogN=E.sky==='fog'?D*.95:D*1.25,fogF=E.sky==='fog'?D*2.3:D*3.2;
  for(const m of[HD.statMat,HD.dynMat,HD.waterMat]){m.uniforms.fogC.value.copy(fogC);m.uniforms.fogN.value=fogN;m.uniforms.fogF.value=fogF}
  HD.sc.fog.color.copy(fogC);HD.sc.fog.near=fogN;HD.sc.fog.far=fogF;HD.sc.background.copy(fogC);
  HD.foamK=.25+(Math.sin(t*1.6)+1)/2*.55;
  HD.chunkPass();HD.seaPass(t);HD.dynPass(t);
  const gl=HD.gl;gl.setRenderTarget(HD.rt);gl.render(HD.sc,cam);gl.setRenderTarget(null);
  HD.overlay(t);if(HD.ovTex.image.width!==cv.width||HD.ovTex.image.height!==cv.height){HD.ovTex.dispose();HD.ovTex=HD.tex(cv);HD.post.uniforms.tO.value=HD.ovTex}HD.ovTex.needsUpdate=true;gl.render(HD.postScene,HD.postCam)};
HD.withCam=function(x,y,w,h,c,fn){const oc=ctx,ovw=VW,ovh=VH,ocx=camX,ocy=camY;if(c)ctx=c;VW=w;VH=h;camX=x;camY=y;try{return fn()}finally{ctx=oc;VW=ovw;VH=ovh;camX=ocx;camY=ocy}};
HD.seaPass=function(t){const ox=Math.round((HD.reg.x0+HD.reg.x1)/2-512),oy=Math.round((HD.reg.z0+HD.reg.z1)/2-400);
  HD.withCam(ox,oy,1024,768,HD.sctx,()=>{ctx.clearRect(0,0,1024,768);const Sc=WORLD,E=envAt();const x0=Math.max(0,Math.floor(camX/16)),y0=Math.max(0,Math.floor(camY/16)),x1=Math.min(Sc.w-1,Math.floor((camX+VW)/16)),y1=Math.min(Sc.h-1,Math.floor((camY+VH)/16));
    const caps=E.sky==='storm'?.5:E.sky==='windy'?.25:.06;
    for(let ty=y0;ty<=y1;ty++)for(let tx=x0;tx<=x1;tx++){const i=ty*Sc.w+tx;if(Sc.g[i]!=='o')continue;const x=tx*16-camX,y=ty*16-camY;const h=hash2(tx,ty,91);const ph=(t*.7+h*7)%7;const deep=Sc.zone[i]>=6;
      if(ph<1.2){const gx=x+2+(hash2(tx,ty,92)*9|0)+Math.round(Math.sin(t+h*6)*2),gy=y+3+(hash2(tx,ty,93)*10|0);const w=ph<.35||ph>.85?2:4;R(ctx,gx+(4-w)/2,gy,w,1,deep?'#5a7ac0':'#c8f0f8');if(w===4)R(ctx,gx+1,gy+1,2,1,deep?'#3a5aa0':'#8ad4ec')}
      if(h<caps){const k=(t*1.3+h*13)%3;if(k<1){const gx=x+(hash2(tx,ty,94)*12|0),gy=y+(hash2(tx,ty,95)*12|0);R(ctx,gx,gy,3+Math.round(k*2),1,'#ffffff');P(ctx,gx+1,gy-1,'#e8f8fb')}}}
    drawSeaLife(t);try{drawLocks(t)}catch(e){}});
  HD.seaTex.needsUpdate=true;HD.seaDecal.position.set(ox+512,HD.wy+.35,oy+384)};
HD.dynPass=function(t){const Sc=WORLD,R0=HD.reg;const cx0=Math.round(R0.x0),cy0=Math.round(R0.z0),cw=Math.round(R0.x1-R0.x0),ch=Math.round(R0.z1-R0.z0);const list=[];
  // collect exactly what the flat renderer would draw, using the visible ground as the 'screen'
  HD.withCam(cx0,cy0,cw,ch,null,()=>{HD.collect=true;try{
    for(const p of HD.animProps){if(!inView(p.x,p.y,80,120))continue;const img=p.anim(t);list.push({ax:p.x+img.width/2,ay:p.y+img.height,w:img.width+2,h:img.height+1,draw:()=>ctx.drawImage(img,Math.round(p.x-camX),Math.round(p.y-camY))})}
    for(const b of AIBOATS){if(!inView(b.x-30,b.y-30,60,60))continue;boatDraw(list,b.k,b.x,b.y,b.h,COOPI[b.co].col,b.co,b.state!=='moored'?{id:3000+COOPS.indexOf(COOPI[b.co])*7}:null,t)}
    if(S.boat&&!player.boat){const sp=myBoatSpot();if(inView(sp.x-30,sp.y-30,60,60))boatDraw(list,S.boat,sp.x,sp.y,sp.h||0,S.paint[S.boat],S.coop,null,t,{name:S.boatName||null,col:'#bfe8f4',decor:boatDetail(S.boat)})}
    if(player.boat){const b=player.boat;boatDraw(list,b.k,b.x,b.y,b.h,S.paint[b.k],S.coop,{id:ACTIVE(),f:MG&&MG.type==='fish'?(Math.floor(t*6)%2?1:2):0},t,{name:S.boatName||null,col:'#bfe8f4',decor:boatDetail(b.k)})}
    for(const f of FOLK){if(!inView(f.x-10,f.y-30,20,34))continue;list.push({sy:f.y,draw:()=>{drawChar(ctx,f.id,f.x-camX,f.y-camY,f.dir,f.moving?WALK[f.f]:0);if(f.bubble)bubble(ctx,f.bubble.text,f.x-camX,f.y-camY-26)}})}
    for(const c of CRABS){if(!inView(c.x-6,c.y-6,12,12))continue;list.push({sy:c.y,draw:()=>ctx.drawImage(artCrabBeach(Math.floor(t*8)%2),Math.round(c.x-camX)-6,Math.round(c.y-camY)-5)})}
    drawCats(list,t,Sc);drawRiders(list,t,Sc);drawDiveFlags(list,t);
    for(const kp of(Sc.keepers||[])){if(!inView(kp.x-10,kp.y-30,20,34))continue;list.push({sy:kp.y,draw:()=>drawChar(ctx,kp.id,kp.x-camX,kp.y-camY,kp.dir||'down',Math.floor(t*1.5+kp.x)%7===0?1:0)})}
    for(const[k,pe]of NET.peers){if(pe.sc!==Sc.name||pe.r||!inView(pe.x-30,pe.y-40,60,60))continue;const col=pe.co?COOPI[pe.co].lt==='#ffffff'?'#bfe8f4':COOPI[pe.co].lt:'#7fdcc0';
      if(pe.b){boatDraw(list,pe.b.k,pe.x,pe.y,pe.b.h,pe.b.p,pe.co,{id:pe.id,f:pe.fish?(Math.floor(t*6)%2?1:2):0},t,{name:pe.b.n||pe.n,col,decor:pe.b.de,fishing:pe.fish});continue}
      list.push({sy:pe.y,draw:()=>{drawChar(ctx,pe.id,pe.x-camX,pe.y-camY,pe.dir,pe.moving?WALK[pe.f]:0);if(pe.co)drawBands(ctx,pe.x-camX,pe.y-camY,pe.dir,COOPI[pe.co].col,false);nameTag(ctx,pe.n,pe.x-camX,pe.y-camY+4,col);if(pe.bubble)bubble(ctx,pe.bubble.text,pe.x-camX,pe.y-camY-26);if(pe.emote)drawEmote(pe.emote.k,pe.x-camX,pe.y-camY-32,t)}})}
    if(!player.boat&&!player.ride)list.push({sy:player.y,draw:()=>drawPlayer(t)});
    for(const g of GULLS){if(!inView(g.x-6,g.y-30,12,40))continue;list.push({ax:g.x,ay:g.y-14,w:12,h:16,fly:g,draw:()=>{const x=Math.round(g.x-camX),y=Math.round(g.y-camY-24);const up=Math.floor(t*5+g.ph)%2;ctx.fillStyle='#fbfbff';ctx.fillRect(x-1,y,3,1);
      if(up){P(ctx,x-3,y-2,OL);P(ctx,x-2,y-1,OL);P(ctx,x+2,y-1,OL);P(ctx,x+3,y-2,OL)}else{P(ctx,x-3,y+1,OL);P(ctx,x-2,y,OL);P(ctx,x+2,y,OL);P(ctx,x+3,y+1,OL)}}})}
    // measure each sprite's footprint once (its anchor is the bottom-centre of what it paints)
    const oc=ctx;ctx=HD.rctx;HD.rec=true;
    for(const it of list){if(it.ax!==undefined)continue;HD.rctx.reset();HD.recSh=null;try{it.draw()}catch(e){}const B=HD.rctx.B;if(B.x1<B.x0){it.skip=1;continue}
      it.ax=Math.round((B.x0+B.x1)/2+camX);it.ay=Math.round(B.y1+camY);it.w=Math.min(160,Math.ceil(B.x1-B.x0)+4);it.h=Math.min(150,Math.ceil(B.y1-B.y0)+3);
      if(HD.recSh)it.sh={x:HD.recSh.x+camX,y:HD.recSh.y+camY,rx:HD.recSh.rx,ry:HD.recSh.ry,w:HD.recSh.w}}
    HD.rec=false;ctx=oc;
  }finally{HD.collect=false;HD.rec=false}});
  // draw them all into the atlas, each moved into its own cell by the canvas transform
  const a=HD.actx;a.setTransform(1,0,0,1,0,0);a.clearRect(0,0,1024,1024);HD.q.length=0;let x=1,y=1,rh=0,n=0,nb=0;const g=HD.dynGeo,bg=HD.blobGeo,bp=bg.getAttribute('iPos'),bs=bg.getAttribute('iSz');
  HD.withCam(cx0,cy0,cw,ch,a,()=>{HD.pass=true;try{for(const it of list){if(it.skip)continue;if(n>=g.userData.n)break;if(x+it.w+1>1024){x=1;y+=rh+2;rh=0}if(y+it.h+1>1024)break;
      const cx=x+(it.w>>1),cy=y+it.h;it.sx=it.ax-camX;it.sy=it.ay-camY;HD.cur=it;
      a.save();a.beginPath();a.rect(x,y,it.w,it.h);a.clip();a.translate(cx-it.sx,cy-it.sy);try{it.draw()}catch(e){}a.restore();
      const boat=it.boat,wet=!!boat||(it.sh&&it.sh.w);const gh=it.fly?HD.standH(it.ax,it.fly.y)+14*HD.KZ:wet?HD.wy:HD.standH(it.ax,it.ay-2);it.gh=gh;
      // boats lie on the water tilted a little towards you; people and props stand up
      if(boat)HD.sprSet(g,n++,it.ax+(it.w/2-(cx-x)),gh+.6,it.ay,[x,y,it.w,it.h],it.w,it.h,0,2.42);
      else HD.sprSet(g,n++,it.ax+(it.w/2-(cx-x)),gh-.4,it.ay,[x,y,it.w,it.h],it.w,it.h*HD.KZ,0,0);
      const sh=it.sh||(it.fly?{x:it.fly.x,y:it.fly.y,rx:2.5,ry:1}:null);if(sh&&nb<bp.count){const wy2=sh.w||boat?HD.wy:HD.standH(sh.x,sh.y);bp.setXYZ(nb,sh.x,wy2,sh.y);bs.setXY(nb,sh.rx*2+2,sh.ry*2+2);nb++}
      x+=it.w+2;rh=Math.max(rh,it.h)}}finally{HD.pass=false}});
  HD.sprDone(g,n);bg.instanceCount=nb;bp.needsUpdate=true;bs.needsUpdate=true;HD.dynTex.needsUpdate=true};
HD.overlay=function(t){ctx.clearRect(0,0,VW,VH);
  for(const q of HD.q){const it=q.it;const P0=HD.proj(it.ax,it.gh,it.ay);const k=it.boat?1:P0.k;const x=P0.x+q.dx*k,y=P0.y+q.dy*k;if(q.k==='b')HD._bubble(ctx,q.text,x,y,q.col);else if(q.k==='n')HD._nameTag(ctx,q.text,x,y,q.col);else HD._emote(q.e,x,y,t)}
  for(const c of combSpots()){const Q=HD.proj(c.x,HD.hAt(c.x,c.y),c.y);if(Q.x<-6||Q.x>VW+6||Q.y<-6||Q.y>VH+6)continue;const k=Math.floor(t*4+c.i)%4;const x=Math.round(Q.x),y=Math.round(Q.y);P(ctx,x,y-k%2,'#ffffff');if(k<2){P(ctx,x-1,y,'#fff6c0');P(ctx,x+1,y,'#fff6c0')}P(ctx,x,y+2,'#c8ac78')}
  if(player.boat){const b=player.boat;const Q=HD.proj(b.x,HD.wy,b.y);if(player.bubble)HD._bubble(ctx,player.bubble.text,Q.x,Q.y-22*Q.k,null);if(player.emote)HD._emote(player.emote.k,Q.x,Q.y-28*Q.k,t)}
  if(MG&&MG.type==='fish'&&MG.bx!=null&&MG.state!=='aim'){const onB=!!player.boat;const px=onB?player.boat.x:player.x,py=onB?player.boat.y:player.y;const Q=HD.proj(px,onB?HD.wy:HD.hAt(px,py+3),py+(onB?0:3));
    const hx=Q.x+(player.dir==='left'?-7:player.dir==='right'?7:4)*Q.k,hy=Q.y-(onB?14:19)*Q.k;const B=HD.proj(MG.bx,HD.wy,MG.by);let bx=B.x,by=B.y;
    if(MG.state==='cast'){const k=Math.min(1,MG.e/.5);bx=hx+(bx-hx)*k;by=hy+(by-hy)*k-Math.sin(k*Math.PI)*22}
    const tight=MG.state==='fight'||MG.state==='land';const dip=MG.state==='bite'?2+Math.round(Math.sin(t*30)):MG.nib>0?1:Math.round(Math.sin(t*3)*.6);
    ctx.strokeStyle=tight?'rgba(255,255,255,.95)':'rgba(255,255,255,.7)';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(hx+.5,hy+.5);if(tight)ctx.lineTo(bx+.5,by+.5);else ctx.quadraticCurveTo((hx+bx)/2,Math.max(hy,by)+8,bx+.5,by+dip+.5);ctx.stroke();
    if(MG.state!=='cast'&&!tight){const rr=(t*2)%1;ctx.strokeStyle=`rgba(214,242,248,${1-rr})`;ctx.beginPath();ctx.ellipse(bx,by+3,4+rr*8,2+rr*3,0,0,6.283);ctx.stroke()}
    if(tight){const fxp=bx+Math.sin(t*9)*3;for(let i=0;i<3;i++)P(ctx,Math.round(fxp+(Math.random()-.5)*8),Math.round(by+(Math.random()-.5)*4),'#e8fbff')}else stamp(ctx,['.k.','kRk','kWk','.k.'],{k:OL,R:'#e9675a',W:'#ffffff'},Math.round(bx-1),Math.round(by-2+dip))}
  if(!MG){const qt=questTarget();if(qt){const Q=HD.proj(qt.x,HD.standH(qt.x,qt.y),qt.y);const qx=Q.x,qy=Q.y-30*Q.k;if(qx>-4&&qx<VW+4&&qy>-4&&qy<VH+4&&Q.z<1)arrow(qx,qy+Math.round(Math.sin(t*5)*2),'#ffd24d');else edgeArrow(qx,Q.z<1?qy:VH*2,'#ffd24d')}
    if(S.boat&&!player.boat){const sp=myBoatSpot();const Q=HD.proj(sp.x,HD.wy,sp.y);if(Q.x<-10||Q.x>VW+10||Q.y<-10||Q.y>VH+10)edgeArrow(Q.x,Q.y,'#7fdcc0')}}
  for(const p of fx){const Q=HD.proj(p.x,HD.standH(p.x,p.y),p.y);ctx.fillStyle=p.c;ctx.fillRect(Math.round(Q.x),Math.round(Q.y),2,2)}
  for(const f of floats){const Q=HD.proj(f.x,HD.standH(f.x,f.y),f.y);ctx.globalAlpha=Math.min(1,f.t*1.5);drawTextO(ctx,f.text,Q.x-textWM(f.text)/2,Q.y-4*Q.k,f.col);ctx.globalAlpha=1}
  const g=player.boat?(player.boat.tgt&&player.boat.tgt[player.boat.tgt.length-1]):(player.path&&player.goal);if(g){const Q=HD.proj(g.x,player.boat?HD.wy:HD.standH(g.x,g.y),g.y);const gx=Math.round(Q.x),gy=Math.round(Q.y),k=Math.floor(t*4)%2;R(ctx,gx-3-k,gy,2,1,'#fff6c0');R(ctx,gx+2+k,gy,2,1,'#fff6c0');R(ctx,gx,gy-2-k,1,1,'#fff6c0');R(ctx,gx,gy+2+k,1,1,'#fff6c0');P(ctx,gx,gy,'#ffd24d')}
  if(tapFx){const Q=HD.proj(tapFx.x,HD.standH(tapFx.x,tapFx.y),tapFx.y);const r=Math.round((.5-tapFx.t)*16);ctx.strokeStyle=`rgba(255,246,192,${tapFx.t*1.6})`;ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(Math.round(Q.x)+.5,Math.round(Q.y)+.5,(3+r)*Q.k,(1.5+r/2)*Q.k,0,0,6.283);ctx.stroke()}
  drawWeather(t);const ph=dayPhase();if(ph.dusk>0){ctx.fillStyle=`rgba(255,130,80,${ph.dusk*.6})`;ctx.globalCompositeOperation='soft-light';ctx.fillRect(0,0,VW,VH);ctx.globalCompositeOperation='source-over'}};
