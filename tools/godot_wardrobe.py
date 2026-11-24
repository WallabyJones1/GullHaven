"""Gullhaven HD-2D: the layered character art for the character creator and clothes shop.
Usage: python3 tools/godot_wardrobe.py [--preview]

The townsfolk painter in godot_art.py draws a whole person at once. For a player you can
dress, it draws each layer on its own (hair behind, body and clothes, glasses, beard, hair
in front, hat) using stand-in "key" colours. Every pixel is then written down as which
colour slot it belongs to (skin, hair, shirt...), how much darker that bit was drawn, and
which tone of the colour ramp it is; anything else (eyes, buttons, the visor) is kept as
it is. character.gd puts the layers back together in the game with the colours you pick,
running the same ramp, and adds the outline last.

Writes godot/art/wardrobe/layers.json (what's where) and layers.bin (gzip, RGBA rows):
  index pixel: R = slot, G = darkening step, B = ramp tone, A = 254
  plain pixel: R, G, B as drawn, A = 255
  empty:       A = 0"""
import gzip
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import godot_art  # noqa: E402
from godot_art import DIRS, FH, FW, POSES, PREVIEW, draw_person, hx, ramp, shift  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'art', 'wardrobe')

SLOTS = ['', 'skin', 'hair', 'shirt', 'pants', 'shoes', 'garment', 'hat', 'pattern', 'floral']
KEYS = {'skin': '#d0805a', 'hair': '#5a3a9a', 'shirt': '#b83030', 'pants': '#3a5ac8', 'shoes': '#8a8a2a',
        'garment': '#2aa860', 'hat': '#c83aa8', 'pattern': '#e8c83a', 'floral': '#3ac8c8'}
DVS = [0.0, -0.05, -0.08, -0.1, -0.12, -0.15, -0.18, -0.2, -0.25]

HAIR = ['short', 'bob', 'long', 'ponytail', 'bun', 'spiky', 'bald']
BEARDS = ['stubble', 'mustache', 'short', 'full']
HATS = ['beanie', 'cap', 'bucket', 'captain', 'straw', 'ranger', 'bandana']
TOPS = ['tee', 'coat', 'vest', 'overalls', 'apron']
PATTERNS = ['none', 'stripes', 'checks', 'floral']
LEGS = ['trousers', 'dress']


def key_look(**kw):
    godot_art.SKIN['key'] = KEYS['skin']
    look = dict(skin='key', hair=KEYS['hair'], style='bald', shirt=KEYS['shirt'], pants=KEYS['pants'], shoes=KEYS['shoes'],
                top='tee', inner='#f4efe2', apron=KEYS['garment'], overall=KEYS['garment'], vest=KEYS['garment'],
                hatc=KEYS['hat'], stripes=KEYS['pattern'], floral=KEYS['floral'])
    look.update(kw)
    return look


def candidates():
    table = {}
    for si, name in enumerate(SLOTS):
        if not name:
            continue
        for di, dv in enumerate(DVS):
            # the painter passes some colours straight through and some via shift(), which
            # rounds a little even with no change; both count as the same thing
            bases = [hx(KEYS[name]), shift(hx(KEYS[name]), 0.0)] if dv == 0.0 else [shift(hx(KEYS[name]), dv)]
            for base in bases:
                for t, rgb in enumerate(ramp(base)):
                    key = tuple(int(v) for v in rgb)
                    if key in table and table[key][0] != si:
                        raise SystemExit('colour clash between %s and %s at %s' % (SLOTS[table[key][0]], name, key))
                    table.setdefault(key, (si, di, t))
    return table


def sheet(look, layer):
    out = np.zeros((FH * 4, FW * 5, 4), np.uint8)
    for r, d in enumerate(DIRS):
        for c, p in enumerate(POSES):
            if d == 'right':
                img = draw_person(look, 'left', p, only={layer}, outline=False)[:, ::-1]
            else:
                img = draw_person(look, d, p, only={layer}, outline=False)
            out[r * FH:(r + 1) * FH, c * FW:(c + 1) * FW] = img
    return out


def encode(img, table, stats):
    enc = np.zeros_like(img)
    h, w = img.shape[:2]
    for y in range(h):
        for x in range(w):
            if img[y, x, 3] == 0:
                continue
            rgb = tuple(int(v) for v in img[y, x, :3])
            hit = table.get(rgb)
            if hit:
                enc[y, x] = (hit[0], hit[1], hit[2], 254)
                stats['index'] += 1
            else:
                enc[y, x] = (rgb[0], rgb[1], rgb[2], 255)
                stats['plain'][rgb] = stats['plain'].get(rgb, 0) + 1
    return enc


def main():
    preview = '--preview' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    table = candidates()
    layers = []  # (name, look, layer)
    for st in HAIR:
        layers.append(('hair_back/%s' % st, key_look(style=st), 'hair_back'))
        layers.append(('hair_front/%s' % st, key_look(style=st), 'hair_front'))
    for legs in LEGS:
        for top in TOPS:
            for pat in PATTERNS:
                kw = dict(top=top, dress=legs == 'dress')
                if pat == 'stripes':
                    kw['stripes'] = KEYS['pattern']
                elif pat == 'checks':
                    kw['checks'] = True
                elif pat == 'floral':
                    kw['floral'] = KEYS['floral']
                look = key_look(**kw)
                if pat != 'stripes' and pat != 'checks':
                    look.pop('stripes', None)
                if pat != 'floral':
                    look.pop('floral', None)
                if pat == 'checks':
                    look['stripes'] = KEYS['pattern']
                layers.append(('body/%s/%s/%s' % (legs, top, pat), look, 'body'))
    layers.append(('glasses', key_look(glasses=True), 'glasses'))
    for b in BEARDS:
        layers.append(('beard/%s' % b, key_look(beard=b), 'beard'))
    for hat in HATS:
        layers.append(('hat/%s' % hat, key_look(hat=hat), 'hat'))

    stats = {'index': 0, 'plain': {}}
    blob = bytearray()
    index = {}
    previews = []
    for name, look, layer in layers:
        img = sheet(look, layer)
        enc = encode(img, table, stats)
        index[name] = len(blob)
        blob += enc.tobytes()
        if preview and (name.startswith('body/trousers') or name.startswith('hat/') or name.startswith('hair_front/')):
            previews.append(img)
    w, h = FW * 5, FH * 4
    meta = {'frame': [FW, FH], 'size': [w, h], 'cols': 5, 'rows': 4, 'slots': SLOTS, 'dvs': DVS,
            'hair': HAIR, 'beards': BEARDS, 'hats': HATS, 'tops': TOPS, 'patterns': PATTERNS, 'legs': LEGS,
            'layers': index, 'bytes': len(blob)}
    json.dump(meta, open(os.path.join(OUT, 'layers.json'), 'w'), indent=1)
    with open(os.path.join(OUT, 'layers.bin'), 'wb') as f:
        f.write(gzip.compress(bytes(blob), 9))
    plain = sorted(stats['plain'].items(), key=lambda kv: -kv[1])
    print('wardrobe: %d layers, %d index pixels, %d plain colours: %s' % (
        len(layers), stats['index'], len(plain), ', '.join('#%02x%02x%02x x%d' % (k[0], k[1], k[2], v) for k, v in plain[:16])))
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        big = np.concatenate(previews[:8], 1)
        Image.fromarray(big, 'RGBA').resize((big.shape[1] * 2, big.shape[0] * 2), Image.NEAREST).save(
            os.path.join(PREVIEW, 'wardrobe.png'))


if __name__ == '__main__':
    main()
