window.AMB={dark:0};const t0=performance.now();const S=genWorld();const t1=performance.now();console.log('genWorld ms',Math.round(t1-t0));
const k=window.MAPK||4;const z=window.MAPZ||(window.MAPZS?JSON.parse(window.MAPZS):null);// z=[x0,y0,w,h] tiles at 1x
if(z){const[x0,y0,w,h]=z;const[c,x]=mk(w*16,h*16);for(let cy=Math.floor(y0*16/CH);cy<=Math.floor((y0+h)*16/CH);cy++)for(let cx=Math.floor(x0*16/CH);cx<=Math.floor((x0+w)*16/CH);cx++){const ch=paintGroundChunk(S,cx,cy);x.drawImage(ch.g,cx*CH-x0*16,cy*CH-y0*16);if(ch.f)x.drawImage(ch.f,cx*CH-x0*16,cy*CH-y0*16)}
  const list=S.props.filter(p=>p.x<(x0+w)*16&&p.x+p.img.width>x0*16&&p.y<(y0+h)*16&&p.y+p.img.height>y0*16).sort((a,b)=>a.sy-b.sy);for(const p of list){const im=p.anim?p.anim(0):p.img;if(p.flat)x.drawImage(im,p.x-x0*16,p.y-y0*16);else x.drawImage(im,p.x-x0*16,p.y-y0*16)}
  if(window.SHOWNAV){x.globalAlpha=.3;for(let ty=y0;ty<y0+h;ty++)for(let tx=x0;tx<x0+w;tx++){const i=ty*S.w+tx;if(S.sol[i]){x.fillStyle='#ff0000';x.fillRect((tx-x0)*16,(ty-y0)*16,16,16)}}x.globalAlpha=1}
  return c.toDataURL()}
const[c,x]=mk(S.w*16/k,S.h*16/k);x.imageSmoothingEnabled=true;for(let cy=0;cy<Math.ceil(S.h*16/CH);cy++)for(let cx=0;cx<Math.ceil(S.w*16/CH);cx++){const ch=paintGroundChunk(S,cx,cy);x.drawImage(ch.g,cx*CH/k,cy*CH/k,CH/k,CH/k)}
const list=S.props.slice().sort((a,b)=>a.sy-b.sy);for(const p of list){const im=p.anim?p.anim(0):p.img;x.drawImage(im,p.x/k,p.y/k,im.width/k,im.height/k)}
if(window.ZONES_ON){x.globalAlpha=.35;const zc=['#ff0000','#00ff00','#0000ff','#ffff00','#00ffff','#ff00ff','#ffffff','#000000'];for(let i=0;i<S.zone.length;i++){if(S.zone[i]===255)continue;x.fillStyle=zc[S.zone[i]];x.fillRect((i%S.w)*16/k,Math.floor(i/S.w)*16/k,16/k,16/k)}x.globalAlpha=1}
return c.toDataURL();
