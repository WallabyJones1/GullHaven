"""Export Gullhaven's code-drawn pixel art and catalogue data for the Godot (HD-2D) project.
Usage: python3 tools/export_godot_assets.py
Writes PNGs into godot/art/ and JSON into godot/data/. Re-run after changing the web game's art or catalogue."""
import os, sys, glob, json, base64, re
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot')
MODS = [m for m in sorted(glob.glob(ROOT + '/src/js/m*.js')) if os.path.basename(m)[:3] in ('m00', 'm01', 'm02', 'm03', 'm04')]
SRC = "'use strict';\n" + '\n'.join(open(m).read() for m in MODS)

JS = r"""
const out={};const png=c=>c.toDataURL('image/png');
// a seamless 64x64 pixel texture from a per-pixel colour function (noise wraps at 64)
function tex(fn){const[c,x]=mk(64,64);const id=x.createImageData(64,64);for(let y=0;y<64;y++)for(let i=0;i<64;i++){const col=fn(i,y);const v=parseInt(col.slice(1),16);const o=(y*64+i)*4;id.data[o]=v>>16;id.data[o+1]=(v>>8)&255;id.data[o+2]=v&255;id.data[o+3]=255}x.putImageData(id,0,0);return c}
const wn=(x,y,s,seed)=>{// wrapped value noise, period 64
  const p=64/s;const fx=x/s,fy=y/s;const x0=Math.floor(fx),y0=Math.floor(fy);const tx=fx-x0,ty=fy-y0;const h=(a,b)=>hash2(((a%p)+p)%p,((b%p)+p)%p,seed);
  const sm=t=>t*t*(3-2*t);const a=h(x0,y0),b=h(x0+1,y0),c=h(x0,y0+1),d=h(x0+1,y0+1);return a+(b-a)*sm(tx)+(c-a)*sm(ty)+(a-b-c+d)*sm(tx)*sm(ty)};
const pick=(arr,t)=>arr[Math.max(0,Math.min(arr.length-1,Math.floor(t*arr.length)))];
out['art/tex/grass.png']=png(tex((x,y)=>{const n=wn(x,y,8,1)*.7+wn(x,y,4,2)*.3;let c=pick(['#4f8a4b','#5b9a52','#6aa85a','#79b85a'],n);const h=hash2(x,y,3);if(h<.05)c='#3f7a45';else if(h>.985)c='#a7d872';return c}));
out['art/tex/sand.png']=png(tex((x,y)=>{const rip=Math.sin((x+y*0.5)*0.39+wn(x,y,16,4)*3);let c=rip>.75?'#f8ebc4':rip<-.85?'#dcc48e':'#eedcaa';const h=hash2(x,y,5);if(h<.03)c='#c8ac78';else if(h>.99)c='#fff8ea';return c}));
out['art/tex/seabed.png']=png(tex((x,y)=>{const n=wn(x,y,8,6);let c=pick(['#b89c6a','#c8ac78','#d2b888'],n);if(hash2(x,y,7)<.02)c='#8a7a5a';return c}));
out['art/tex/planks.png']=png(tex((x,y)=>{const row=Math.floor(y/8);const off=(row%2)*24;const seam=(x+off)%48===0;let c=y%8===0?'#4a2e28':seam?'#5a3a2a':pick(['#8a5a3a','#9a6a46','#a8784e'],wn(x,row*8,8,8)*.6+hash2(x>>2,row,9)*.4);if(y%8===4&&(x+off)%48===4)c='#3a2418';return c}));
out['art/tex/cobble.png']=png(tex((x,y)=>{const cx=Math.floor((x+(Math.floor(y/8)%2)*4)/8),cy=Math.floor(y/8);const lx=(x+(cy%2)*4)%8,ly=y%8;if(lx===0||ly===0)return'#8f8aa0';const s=hash2(cx%8,cy,11);return pick(['#d6cab4','#e0d6c4','#cfc2aa','#e8e0d0'],s)}));
out['art/tex/path.png']=png(tex((x,y)=>{const n=wn(x,y,8,12);let c=pick(['#b8905f','#c39a6b','#cfa878'],n);if(hash2(x,y,13)<.04)c='#9a7448';return c}));
out['art/tex/roof_red.png']=png(tex((x,y)=>{const row=Math.floor(y/8),lx=(x+(row%2)*8)%16;if(y%8===7)return'#6a2420';if(lx===0)return'#8a3028';return pick(['#c8443a','#d25b4a','#b83a32'],hash2(Math.floor((x+(row%2)*8)/16),row,14))}));
out['art/tex/roof_blue.png']=png(tex((x,y)=>{const row=Math.floor(y/8),lx=(x+(row%2)*8)%16;if(y%8===7)return'#24305a';if(lx===0)return'#2a3a6a';return pick(['#3d5a9a','#4a6aaa','#34508a'],hash2(Math.floor((x+(row%2)*8)/16),row,15))}));
out['art/tex/roof_green.png']=png(tex((x,y)=>{const row=Math.floor(y/8),lx=(x+(row%2)*8)%16;if(y%8===7)return'#1f3a2a';if(lx===0)return'#2a4a34';return pick(['#3f7a55','#4a8a62','#356a48'],hash2(Math.floor((x+(row%2)*8)/16),row,16))}));
out['art/tex/plaster.png']=png(tex((x,y)=>{const n=wn(x,y,16,17);let c=pick(['#efe6d4','#f4ecdc','#e8dcc6'],n);if(hash2(x,y,18)<.01)c='#d8ccb4';return c}));
out['art/tex/stone.png']=png(tex((x,y)=>{const bw=16,bh=8;const row=Math.floor(y/bh),lx=(x+(row%2)*8)%bw,ly=y%bh;if(lx===0||ly===0)return'#3e3a52';return pick(['#7c7894','#8a86a0','#6e6a86'],hash2(Math.floor((x+(row%2)*8)/bw),row,19)*.7+wn(x,y,8,20)*.3)}));
out['art/tex/timber.png']=png(tex((x,y)=>{const col=Math.floor(x/16);if(x%16===0)return'#4a2e28';return pick(['#7d573d','#8a6448','#704c34'],wn(col*16,y,8,21)*.5+hash2(col,y>>3,22)*.5)}));
// people: the player's starting look and some townsfolk (3 frames x 4 rows: down, up, left, right; 16x26 each)
const looks={player:12};
[9037,9074,9111,9148,9185,9222,412,77].forEach((id,i)=>looks['folk'+i]=id);
for(const[k,id]of Object.entries(looks))out['art/chars/'+k+'.png']=png(sheet(id));
// everything that can be caught, hooked, snagged or combed: catalogue art (the Logbook pictures) and rules
const items=[];for(const e of CAT){if(e.how==='gift'||e.how==='oyster')continue;const im=catArt(e.id);if(!im)continue;out['art/fish/'+e.id+'.png']=png(im);
  items.push({id:e.id,n:e.n,cat:e.cat,z:e.z,r:e.r,c:e.c,cp:e.cp,sz:e.sz||null,price:e.price,how:e.how||'',art:String(e.art||'').split('|')[0],look:String(e.art||''),release:!!e.release,hint:e.hint||'',what:e.what||''})}
out['data/catalog.json']=JSON.stringify({zones:ZONES,order:ZONE_ORDER,rarity:RAR,rarw:RARW,bait:BAIT,bait_order:BAIT_ORDER,
  gear:{rod:GEAR.rod,reel:GEAR.reel,line:GEAR.line},epoch:T_EPOCH,items},null,1);
// scenery sprites for the diorama (billboards)
[0,1,2,3,4].forEach(v=>out['art/props/tree'+v+'.png']=png(artTree(v)));
out['art/props/bush.png']=png(artBush());out['art/props/bush_flower.png']=png(artBush('#f6bccb'));
out['art/props/reeds.png']=png(artReedsC());out['art/props/barrel.png']=png(artBarrelC());
[0,1,2].forEach(v=>out['art/props/crate'+v+'.png']=png(artFishCrate(v)));
[0,1].forEach(v=>out['art/props/palm'+v+'.png']=png(artPalmC(v)));
// the ten cats from Catoshi's Catch: 2 walk frames x 4 directions (20x20 each)
for(const cd of COATS){const[c,x]=mk(40,80);for(let d=0;d<4;d++)for(let f=0;f<2;f++)x.drawImage(catWalk(cd.k,d,f),f*20,d*20);out['art/cats/'+cd.k+'.png']=png(c)}
return JSON.stringify(out);
"""

html = '<html><body><script>' + SRC + '\nwindow.__EXPORT=()=>{' + JS + '};</script></body></html>'
tmp = '/tmp/claude-0/godot_export.html'
os.makedirs(os.path.dirname(tmp), exist_ok=True)
open(tmp, 'w').write(html)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + tmp)
    data = json.loads(pg.evaluate('window.__EXPORT()'))
    b.close()
if errs:
    print('page errors:', errs); sys.exit(1)
n = 0
for rel, val in data.items():
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if val.startswith('data:image/png;base64,'):
        open(path, 'wb').write(base64.b64decode(val.split(',', 1)[1]))
    else:
        open(path, 'w').write(val)
    n += 1
# the game's pixel fonts (embedded in fonts.css as woff2): regular and bold of each family
css = open(os.path.join(ROOT, 'src/fonts.css')).read()
for m in re.finditer(r"@font-face\{(.*?)\}", css, re.S):
    blk = m.group(1)
    fam = re.search(r"font-family:'([^']+)'", blk).group(1)
    wt = re.search(r"font-weight:\s*(\d+)", blk)
    wt = wt.group(1) if wt else '400'
    if wt not in ('400', '700') or 'unicode-range' in blk:
        continue
    b64 = re.search(r"base64,([A-Za-z0-9+/=]+)", blk).group(1)
    name = fam.lower().replace(' ', '_') + ('_bold' if wt == '700' else '') + '.woff2'
    path = os.path.join(OUT, 'art/fonts', name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(base64.b64decode(b64)); n += 1
print('wrote', n, 'files into', OUT)
