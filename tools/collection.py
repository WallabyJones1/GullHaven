"""Render the 500 Founding Fishers: images (512x512 PNG, nearest-neighbour from the 64x64 pixel portrait) and Metaplex
metadata JSON, plus the collection image and a preview sheet. Usage: python3 tools/collection.py [outdir]"""
import sys, os, json, base64, io, glob
from playwright.sync_api import sync_playwright
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'collection')
os.makedirs(os.path.join(OUT, 'images'), exist_ok=True); os.makedirs(os.path.join(OUT, 'metadata'), exist_ok=True)
MODS = [m for m in sorted(glob.glob(ROOT + '/src/js/m*.js')) if os.path.basename(m)[:3] in ('m00', 'm01', 'm02')]
src = "'use strict';\n" + '\n'.join(open(m).read() for m in MODS)
dump = """
window.__dump=(a,b)=>{const out=[];for(let id=a;id<=b;id++){const t=traits(id);out.push({id,png:cardArt(id).toDataURL(),t:{rar:t.rar,skin:SKINS.indexOf(t.skin),hs:t.hs,hair:t.hair,eyes:EYES[t.eyes],mouth:MOUTH[t.mouth],shirt:t.shirt,pants:t.pants,pat:PATTERN[t.pat],acc:ACC[t.acc],acc2:t.acc2?ACC[t.acc2]:null,pers:t.pers}})}return out};
"""
html = '<html><body><script>' + src + dump + '</script></body></html>'
tmp = os.path.join(OUT, '_render.html'); open(tmp, 'w').write(html)
SKIN = ['Porcelain', 'Fair', 'Sand', 'Tan', 'Brown', 'Deep']
HAIRSTYLE = ['Tousled', 'Bob', 'Spiky', 'Long', 'Top bun', 'Curly']
def colour_name(hexc):
    names = {'#3d3048': 'Ink', '#5a3a2a': 'Chestnut', '#8a5a33': 'Auburn', '#c9894a': 'Ginger', '#e8c87a': 'Blonde', '#3d3f5c': 'Slate',
             '#d25b5b': 'Coral', '#5b8fd2': 'Sky', '#9a6ad8': 'Violet', '#e9e6ef': 'Silver', '#58c9a8': 'Seafoam', '#f08bbf': 'Pink', '#ff9b3d': 'Sunset', 'prism': 'Prism',
             '#e9675a': 'Red', '#f2a541': 'Orange', '#f6d65a': 'Yellow', '#7cc36b': 'Green', '#4fae9c': 'Teal', '#5b9be0': 'Blue', '#7a6fe0': 'Indigo', '#c76fd1': 'Purple',
             '#f28cb1': 'Rose', '#f4efe4': 'White', '#3d4a63': 'Navy', '#9c6b4a': 'Brown', '#3d4a78': 'Denim', '#2f3346': 'Black', '#6b5a4a': 'Khaki', '#4f6b4a': 'Olive', '#8a3f4a': 'Maroon', '#d8d2c4': 'Cream'}
    return names.get(hexc, hexc)
RAR = ['Common', 'Uncommon', 'Rare', 'Legendary']
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + tmp)
    rows = []
    for a in range(1, 501, 50):
        rows += pg.evaluate(f'window.__dump({a},{a+49})')
    b.close()
if errs: print('ERRORS', errs); sys.exit(1)
counts = [0, 0, 0, 0]
for r in rows:
    i = r['id']; t = r['t']; tag = f'{i:03d}'; counts[t['rar']] += 1
    im = Image.open(io.BytesIO(base64.b64decode(r['png'].split(',')[1]))).convert('RGBA').resize((512, 512), Image.NEAREST)
    im.save(os.path.join(OUT, 'images', tag + '.png'))
    attrs = [{'trait_type': 'Rarity', 'value': RAR[t['rar']]}, {'trait_type': 'Skin', 'value': SKIN[t['skin']] if 0 <= t['skin'] < 6 else 'Unknown'},
             {'trait_type': 'Hair', 'value': HAIRSTYLE[t['hs']] + ' ' + colour_name(t['hair'])}, {'trait_type': 'Eyes', 'value': t['eyes']}, {'trait_type': 'Mouth', 'value': t['mouth']},
             {'trait_type': 'Top', 'value': colour_name(t['shirt']) + ' ' + t['pat']}, {'trait_type': 'Trousers', 'value': colour_name(t['pants'])},
             {'trait_type': 'Accessory', 'value': t['acc']}, {'trait_type': 'Personality', 'value': t['pers']}]
    if t['acc2']: attrs.append({'trait_type': 'Second accessory', 'value': t['acc2']})
    meta = {'name': f'Founding Fisher #{tag}', 'symbol': 'FISHER',
            'description': f'Founding Fisher #{tag}, one of the 500 original fishers of Gullhaven, a pixel fishing town. Wear their look in game and send them out on crew trips; Founding Fishers bring back 20% more than hired hands.',
            'image': f'{tag}.png', 'attributes': attrs, 'properties': {'files': [{'uri': f'{tag}.png', 'type': 'image/png'}], 'category': 'image'}}
    json.dump(meta, open(os.path.join(OUT, 'metadata', tag + '.json'), 'w'), indent=1)
# the collection: image is a 4x4 mosaic of legendaries, plus a preview sheet of the first 100 in drop order
leg = [r for r in rows if r['t']['rar'] == 3][:16]
col = Image.new('RGBA', (512, 512))
for k, r in enumerate(leg):
    im = Image.open(os.path.join(OUT, 'images', f"{r['id']:03d}.png")).resize((128, 128), Image.NEAREST); col.paste(im, ((k % 4) * 128, (k // 4) * 128))
col.save(os.path.join(OUT, 'collection.png'))
json.dump({'name': 'Founding Fishers', 'symbol': 'FISHER', 'description': 'The 500 Founding Fishers of Gullhaven. Released in five drops of 100 from the vending machine on the town square.',
           'image': 'collection.png', 'properties': {'files': [{'uri': 'collection.png', 'type': 'image/png'}], 'category': 'image'}}, open(os.path.join(OUT, 'collection.json'), 'w'), indent=1)
prev = Image.new('RGBA', (10 * 128, 10 * 128))
for k, r in enumerate(rows[:100]):
    im = Image.open(os.path.join(OUT, 'images', f"{r['id']:03d}.png")).resize((128, 128), Image.NEAREST); prev.paste(im, ((k % 10) * 128, (k // 10) * 128))
prev.save(os.path.join(OUT, 'preview_001-100.png'))
os.remove(tmp)
print('rendered', len(rows), 'Founding Fishers; rarity counts', dict(zip(RAR, counts)))
