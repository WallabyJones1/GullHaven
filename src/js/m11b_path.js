/* ================= tap-to-walk: A* pathfinding, tap targets, auto-act on arrival ================= */
const DIRS8=[[1,0,1],[-1,0,1],[0,1,1],[0,-1,1],[1,1,1.41],[1,-1,1.41],[-1,1,1.41],[-1,-1,1.41]];
function walkable(Sc,tx,ty){return tx>=0&&ty>=0&&tx<Sc.w&&ty<Sc.h&&!Sc.sol[ty*Sc.w+tx]}
// generic A* over a grid predicate
function findPathP(pass,W,H,sx,sy,gx,gy,maxN=14000){if(!pass(gx,gy))return null;const start=sy*W+sx,goal=gy*W+gx;if(start===goal)return[];
  const g=new Float32Array(W*H).fill(1e9),came=new Int32Array(W*H).fill(-1);g[start]=0;const heap=[[0,start]];
  const push=(f,n)=>{heap.push([f,n]);let i=heap.length-1;while(i>0){const p=(i-1)>>1;if(heap[p][0]<=heap[i][0])break;const t=heap[p];heap[p]=heap[i];heap[i]=t;i=p}};
  const pop=()=>{const top=heap[0];const last=heap.pop();if(heap.length){heap[0]=last;let i=0;for(;;){const l=i*2+1,r=l+1;let m=i;if(l<heap.length&&heap[l][0]<heap[m][0])m=l;if(r<heap.length&&heap[r][0]<heap[m][0])m=r;if(m===i)break;const t=heap[m];heap[m]=heap[i];heap[i]=t;i=m}}return top};
  const h=n=>{const dx=Math.abs(n%W-gx),dy=Math.abs((n/W|0)-gy);return Math.max(dx,dy)+.41*Math.min(dx,dy)};
  let n=0;while(heap.length&&n++<maxN){const[f,cur]=pop();if(cur===goal){const out=[];let c=goal;while(c!==start&&c>=0){out.push({tx:c%W,ty:c/W|0});c=came[c]}return out.reverse()}
    if(f-h(cur)>g[cur]+.01)continue;const cx=cur%W,cy=cur/W|0;
    for(const[dx,dy,cost]of DIRS8){const nx=cx+dx,ny=cy+dy;if(!pass(nx,ny))continue;if(dx&&dy&&(!pass(cx+dx,cy)||!pass(cx,cy+dy)))continue;const nn=ny*W+nx,ng=g[cur]+cost;if(ng<g[nn]){g[nn]=ng;came[nn]=cur;push(ng+h(nn),nn)}}}
  return null}
function findPath(Sc,sx,sy,gx,gy,maxN){return findPathP((x,y)=>walkable(Sc,x,y),Sc.w,Sc.h,sx,sy,gx,gy,maxN)}
function los(Sc,x0,y0,x1,y1){const d=Math.hypot(x1-x0,y1-y0);const n=Math.ceil(d/3);for(let i=1;i<=n;i++){const k=i/n;if(blocked(Sc,x0+(x1-x0)*k,y0+(y1-y0)*k))return false}return true}
function nearestWalkable(Sc,tx,ty,pref){if(walkable(Sc,tx,ty))return[tx,ty];const order=pref||[[0,1],[0,-1],[-1,0],[1,0],[-1,1],[1,1],[-1,-1],[1,-1]];for(let r=1;r<=3;r++)for(const[dx,dy]of order){const x=tx+dx*r,y=ty+dy*r;if(walkable(Sc,x,y))return[x,y]}
  for(let r=1;r<=5;r++)for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(Math.max(Math.abs(dx),Math.abs(dy))!==r)continue;if(walkable(Sc,tx+dx,ty+dy))return[tx+dx,ty+dy]}return null}
/* what did the tap land on? where to stand, which way to face, and whether to act on arrival */
function tapTarget(wx,wy){const Sc=scene;let best=null,bd=1e9;const cand=(x,y,r,info)=>{const d=Math.hypot(x-wx,y-wy);if(d<r&&d<bd){bd=d;best=info}};
  for(const a of Sc.acts)cand(a.x,a.y-10,Math.max(22,a.r+6),{x:a.x,y:a.y,auto:true,face:'up'});
  if(Sc===WORLD){for(const f of FOLK)cand(f.x,f.y-10,13,{x:f.x+(player.x<f.x?-12:12),y:f.y+2,auto:true,folk:f});
    if(S.boat){const sp=myBoatSpot();cand(sp.x,sp.y,24,{boat:true,x:sp.x,y:sp.y})}
    for(const c of combSpots())cand(c.x,c.y,14,{x:c.x,y:c.y+6,auto:true,comb:c})}
  if(best&&best.boat){const nw=nearestWalkable(Sc,Math.floor(best.x/16),Math.floor(best.y/16));if(!nw)return null;return{x:nw[0]*16+8,y:nw[1]*16+10,auto:true,face:faceFrom(best.x-nw[0]*16-8,best.y-nw[1]*16-10,'up')}}
  if(!best){const tx=Math.floor(wx/16),ty=Math.floor(wy/16);const t=tileT(Sc,tx,ty);
    if(t==='o'){// walk to the shore facing this water and cast there
      let pick=null;for(let r=1;r<=6&&!pick;r++)for(let dy=-r;dy<=r&&!pick;dy++)for(let dx=-r;dx<=r&&!pick;dx++){if(Math.max(Math.abs(dx),Math.abs(dy))!==r)continue;const x=tx+dx,y=ty+dy;if(!walkable(Sc,x,y))continue;
        for(const[fx2,fy2,f]of[[0,-1,'up'],[0,1,'down'],[-1,0,'left'],[1,0,'right']]){if(tileT(Sc,x+fx2,y+fy2)==='o'){pick={x:x*16+8,y:y*16+10,face:f,auto:true,fish:{x:wx,y:wy}};break}}}best=pick}
    else{const nw=nearestWalkable(Sc,tx,ty);if(nw)best={x:Math.abs(nw[0]-tx)+Math.abs(nw[1]-ty)?nw[0]*16+8:wx,y:Math.abs(nw[0]-tx)+Math.abs(nw[1]-ty)?nw[1]*16+10:wy,auto:false}}}
  return best}
function walkTo(tg,silent){if(!tg)return false;const Sc=scene;const sx=Math.floor(player.x/16),sy=Math.floor(player.y/16),gx=Math.floor(tg.x/16),gy=Math.floor(tg.y/16);if(MG)closeMG();
  if(Math.hypot(tg.x-player.x,tg.y-player.y)<3){player.path=null;arrive(tg);return true}
  const path=findPath(Sc,sx,sy,gx,gy);if(!path){if(!silent)toast("Can't find a way there.");return false}
  const pts=path.map(p=>({x:p.tx*16+8,y:p.ty*16+10}));if(pts.length)pts[pts.length-1]={x:tg.x,y:tg.y};else pts.push({x:tg.x,y:tg.y});player.path=pts;player.goal=tg;player.stuck=0;return true}
function arrive(tg){if(tg.face)player.dir=tg.face;if(!tg.auto)return;if(tg.folk){if(Math.hypot(tg.folk.x-player.x,tg.folk.y-player.y)<34)talkFolk(tg.folk);return}
  if(tg.comb){startDig(tg.comb);return}
  if(tg.fish){const w=waterAhead();if(w){const z=zoneAtPx(tg.fish.x,tg.fish.y)||w.zone;startFishing({x:tg.fish.x,y:tg.fish.y,zone:z,shore:true});return}}
  const a=nearestAct();if(a&&a.act){curAct=a;setActButton(a);a.act()}}
function followPath(dt){const P=player.path;if(!P)return[0,0,0];while(P.length>1&&los(scene,player.x,player.y,P[1].x,P[1].y))P.shift();
  const q=P[0];const dx=q.x-player.x,dy=q.y-player.y,d=Math.hypot(dx,dy);if(d<1.5){P.shift();if(!P.length){const tg=player.goal;player.path=null;player.goal=null;if(!blocked(scene,q.x,q.y)){player.x=q.x;player.y=q.y}arrive(tg)}return[0,0,0]}
  return[dx/d,dy/d,d]}
function cancelPath(){player.path=null;player.goal=null}
