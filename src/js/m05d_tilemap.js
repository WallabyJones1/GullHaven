/* ================= the chart and minimap picture: one colour per tile (no need to paint the whole sea) =================
   Islands that are still locked stay hidden as open water until you open them. */
function hiddenAt(tx,ty){for(const I of(WORLD&&WORLD.islands)||[]){if(!I.lock||islandOpen(I.id))continue;if(Math.hypot(tx-I.x,(ty-I.y)*1.2)<I.r+12)return true}return false}
const TILE_COL={g:['#5b9a52','#6aa85a','#4f8a4b'],sa:['#e8d4a0','#dcc490'],mud:['#6e604a','#7a6a50'],rk:['#8a86a0','#7a7690'],w:['#c39a6b','#b8905f'],k:['#9c9ab0','#8f8da4'],p:['#e0d6c4','#d6cab4'],pr:['#b27b52','#9a6a46'],bw:['#86829a','#76728a'],sk:['#5a566a']};
function tileMap(S,k){const[c,x]=mk(S.w*k,S.h*k);const id=x.createImageData(S.w*k,S.h*k);const u=new Uint32Array(id.data.buffer);
  for(let ty=0;ty<S.h;ty++)for(let tx=0;tx<S.w;tx++){const i=ty*S.w+tx;let t=S.g[i];let col;const n=hash2(tx,ty,5);
    const hid=hiddenAt(tx+.5,ty+.5);if(t==='o'||hid){let z=ZONE_ORDER[S.zone[i]];if(hid||!z)z=tx>=188?'deep':tx>=152?'blue':'wreck';const P=SEA[z]||SEA.deep;const d=t==='o'?S.depth[i]:40;col=P[d<2?0:d<5?1:d<30?2:3];if(n>.85)col=mix(col,'#ffffff',.08)}
    else{const P=TILE_COL[t]||TILE_COL.g;col=P[Math.floor(n*P.length)]}
    const v=c32(col);for(let j=0;j<k;j++)for(let a=0;a<k;a++){const px=tx*k+a,py=ty*k+j;let vv=v;if(k>1&&(t==='o')&&hash2(px,py,9)<.06)vv=c32(mix(col,'#ffffff',.18));u[py*S.w*k+px]=vv}}
  x.putImageData(id,0,0);return c}
