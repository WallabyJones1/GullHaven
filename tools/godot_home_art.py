"""Gullhaven home catalogue art: every furniture piece in every colour, plus the wallpapers
and floors players decorate their homes with.

Usage: python3 tools/godot_home_art.py [--sheets DIR]

Reads godot/data/home_catalog.json (written by tools/godot_home_catalog.py) and draws
  godot/art/decor/home/<base>_<colour>.png          furniture sprites, RGBA
  godot/art/tex/home/wall_<pattern>_<colour>.png    64x64 tiling wallpapers
  godot/art/tex/home/floor_<kind>_<colour>.png      64x64 tiling floors
Same rules as tools/godot_interior_art.py: 32 px to the metre, front-facing 3/4 view,
light from the top left, hue-shifted ramps and a dark selective outline. Deterministic:
every bit of noise comes from seeded hashes, so reruns give identical files.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_art import OUT, hashmap, hx, ramp, shift  # noqa: E402
from godot_interior_art import BRASS, DARKWOOD, IRON, WOOD, Pix, floor_wood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, 'godot', 'data', 'home_catalog.json')
SPRITE_DIR = 'decor/home'
TEX_DIR = 'tex/home'
SHEETS = '/tmp/claude-0/-home-claude/838417ab-185c-588d-a125-9249c504fe92/scratchpad'

GRAD = ('#9945ff', '#14f195')  # the crypto colours: purple to mint
CHROME = '#b8c2cc'
PORC = '#f2f0ea'
GLASS = '#a8d4e0'
LEAF = '#4a8a3a'
CREAM = '#f0e4c8'
INK = '#2a2a34'

# ===================================================================== drawing helpers


def mix(a, b, t):
    a = hx(a) if isinstance(a, str) else a
    b = hx(b) if isinstance(b, str) else b
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def grid(p):
    yy, xx = np.mgrid[0:p.h, 0:p.w]
    return xx + 0.5, yy + 0.5


def emask(p, cx, cy, rx, ry):
    xx, yy = grid(p)
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0


def paint(p, m, c, shade=True):
    """Fill a mask as one lit part: highlight on edges facing the top left, shadow opposite."""
    if not m.any():
        return
    r = ramp(c)
    p.a[m, :3] = r[3]
    p.a[m, 3] = 255
    if shade:
        up = m & ~np.roll(m, 1, 0)
        lf = m & ~np.roll(m, 1, 1)
        dn = m & ~np.roll(m, -1, 0)
        rt = m & ~np.roll(m, -1, 1)
        p.a[rt, :3] = r[2]
        p.a[up | lf, :3] = r[4]
        p.a[dn, :3] = r[1]


def pell(p, cx, cy, rx, ry, c, shade=True):
    paint(p, emask(p, cx, cy, rx, ry), c, shade)


def rbox(p, x0, y0, x1, y1, c):
    """A lit box with its corners knocked off (cushions, rounded casings)."""
    r = ramp(c)
    p.rect(x0 + 1, y0, x1 - 1, y1, r[3])
    p.rect(x0, y0 + 1, x1, y1 - 1, r[3])
    p.rect(x0 + 1, y0, x1 - 1, y0, r[4])
    p.rect(x0, y0 + 1, x0, y1 - 1, r[4])
    p.rect(x1, y0 + 1, x1, y1 - 1, r[2])
    p.rect(x0 + 1, y1, x1 - 1, y1, r[1])
    p.px(x0 + 1, y0 + 1, r[5])


def topbox(p, x0, y0, x1, y1, c, top=3):
    """A block seen from the front with a sliver of its top showing."""
    r = ramp(c)
    p.box(x0, y0 + top, x1, y1, c)
    p.rect(x0, y0, x1, y0 + top - 1, r[4])
    p.rect(x0, y0, x1, y0, r[3])
    p.rect(x0, y0 + top - 1, x1, y0 + top - 1, r[5])


def trap(p, xc, y0, y1, w0, w1, c):
    """A trapezoid w0 wide at the top and w1 at the bottom, centred on xc (lamp shades)."""
    r = ramp(c)
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        hw = (w0 + (w1 - w0) * t) / 2
        xa, xb = int(round(xc - hw)), int(round(xc + hw)) - 1
        tone = r[4] if y == y0 else (r[1] if y == y1 else r[3])
        p.rect(xa, y, xb, y, tone)
        if y not in (y0, y1):
            p.px(xa, y, r[4])
            p.px(xb, y, r[2])
            p.px(xb - 1, y, r[2])


def thick(p, pts, c, w=2):
    """A polyline drawn with a square pen w pixels wide."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            x = int(round(x0 + (x1 - x0) * t - (w - 1) / 2))
            y = int(round(y0 + (y1 - y0) * t - (w - 1) / 2))
            p.rect(x, y, x + w - 1, y + w - 1, c)


def blur(m, passes):
    m = m.astype(float)
    for _ in range(passes):
        q = np.pad(m, 1)
        m = sum(q[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    return m


def glow(p, mask, c, passes=3, strength=1.8, alpha=150):
    """A soft halo in colour c around mask, only on empty pixels."""
    g = np.clip(blur(mask, passes) * strength, 0, 1)
    empty = p.a[..., 3] == 0
    a = (g * alpha).astype(np.uint8)
    m = empty & (a > 6)
    p.a[m, :3] = hx(c) if isinstance(c, str) else c
    p.a[m, 3] = a[m]


def lit_glow(p, mask, c, amount=0.35):
    """Brighten already-drawn pixels near mask (light spilling onto the sprite)."""
    g = np.clip(blur(mask, 2) * 1.5, 0, 1) * amount
    full = p.a[..., 3] > 0
    col = np.array(hx(c) if isinstance(c, str) else c, float)
    rgb = p.a[..., :3].astype(float)
    rgb = rgb + (col - rgb) * g[..., None] * full[..., None]
    p.a[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)


def neon(c):
    c = hx(c) if isinstance(c, str) else c
    return shift(c, 0.25, 0.2)


def metal_shine(p, m, c):
    """Metallic finish: a bright streak and specular dots on top of a painted mask."""
    r = ramp(c)
    ys, xs = np.nonzero(m)
    if len(ys) == 0:
        return
    y0, y1 = ys.min(), ys.max()
    band = m & (np.mgrid[0:p.h, 0:p.w][0] == y0 + max(1, (y1 - y0) // 4))
    p.a[band, :3] = r[5]
    lo = m & (np.mgrid[0:p.h, 0:p.w][0] == y0 + (y1 - y0) * 3 // 4)
    p.a[lo, :3] = r[2]


FONT = {  # 3x5 pixel letters
    'G': ['111', '100', '101', '101', '111'], 'U': ['101', '101', '101', '101', '111'],
    'L': ['100', '100', '100', '100', '111'], 'P': ['111', '101', '111', '100', '100'],
}


def text(p, x, y, s, c):
    for ch in s:
        for j, row in enumerate(FONT[ch]):
            for i, b in enumerate(row):
                if b == '1':
                    p.px(x + i, y + j, c)
        x += 4


def accent(key):
    """A contrast colour for trims on fabric pieces."""
    return '#6a5040' if key in ('cream', 'yellow', 'white') else CREAM


def tint(c, t=0.45):
    return mix(c, '#f6efe0', t)


# ===================================================================== living room

def sofa(c, key):
    p = Pix(64, 30)
    cd = shift(hx(c), -0.12)
    for x in (5, 56):
        p.rect(x, 26, x + 2, 28, DARKWOOD)
    rbox(p, 4, 3, 59, 18, cd)  # back frame
    for x0 in (7, 24, 41):  # back cushions
        rbox(p, x0, 5, x0 + 15, 16, c)
        p.px(x0 + 7, 10, ramp(c)[2])
    p.box(3, 19, 60, 26, cd)  # seat base
    for x0 in (8, 32):  # seat cushions, top and front
        rbox(p, x0, 15, x0 + 23, 22, shift(hx(c), 0.06))
        p.rect(x0 + 1, 18, x0 + 22, 18, ramp(c)[4])
    for x0 in (1, 55):  # arms
        rbox(p, x0, 10, x0 + 7, 26, c)
        p.rect(x0 + 1, 11, x0 + 6, 12, ramp(c)[4])
    return p.outline()


def armchair(c, key):
    p = Pix(32, 30)
    cd = shift(hx(c), -0.12)
    for x in (5, 25):
        p.rect(x, 26, x + 1, 28, DARKWOOD)
    rbox(p, 4, 1, 27, 18, cd)
    rbox(p, 7, 3, 24, 16, c)
    p.rect(11, 3, 20, 3, ramp(c)[5])
    p.box(3, 19, 28, 26, cd)
    rbox(p, 8, 15, 23, 22, shift(hx(c), 0.06))
    p.rect(9, 18, 22, 18, ramp(c)[4])
    for x0 in (1, 23):
        rbox(p, x0, 9, x0 + 7, 26, c)
        p.rect(x0 + 1, 10, x0 + 6, 11, ramp(c)[4])
    return p.outline()


def beanbag(c, key):
    p = Pix(30, 24)
    r = ramp(c)
    m = emask(p, 15, 16, 13.5, 6.5) | emask(p, 14, 10, 9, 8)  # a slumped pear
    paint(p, m, c)
    pell(p, 15, 18.5, 12, 3.5, r[2], shade=False)  # shadowed belly
    pell(p, 11.5, 7, 5, 3.5, r[4], shade=False)  # the lit top
    pell(p, 16, 13, 5, 2, r[2], shade=False)  # dimple where you sit
    pell(p, 15.5, 12.5, 4, 1.2, r[1], shade=False)
    p.px(9, 5, r[5])
    p.px(10, 5, r[5])
    p.px(9, 6, r[5])
    for k in range(6):  # seams
        p.px(7 + k, 14 - k // 2, r[2])
        p.px(22 - k, 15 - k // 2, r[2])
    p.a[m & ~np.roll(m, -1, 0), :3] = r[1]
    return p.outline()


def coffee_table(c, key):
    p = Pix(48, 18)
    r = ramp(c)
    for x in (3, 42):
        p.box(x, 7, x + 2, 16, c)
    p.rect(9, 7, 10, 13, r[1])  # back legs
    p.rect(37, 7, 38, 13, r[1])
    p.box(5, 12, 42, 13, c)  # lower shelf
    p.box(14, 10, 22, 11, '#3a6aa8')  # a book on the shelf
    topbox(p, 1, 3, 46, 7, c, top=3)
    p.box(31, 0, 34, 4, '#e8e0d0', edge=False)  # a mug
    p.px(35, 2, '#c8c0b0')
    p.rect(9, 3, 18, 4, '#f0e8d0')  # a tide table
    p.rect(10, 4, 17, 4, '#a8a090')
    return p.outline()


def side_table(c, key):
    p = Pix(16, 18)
    r = ramp(c)
    for x in (2, 12):
        p.box(x, 10, x + 1, 16, c, edge=False)
    topbox(p, 1, 2, 14, 5, c, top=2)
    p.box(2, 6, 13, 10, c)
    p.rect(3, 7, 12, 9, r[2])
    p.rect(3, 7, 12, 7, r[3])
    p.px(7, 8, BRASS)
    p.px(8, 8, BRASS)
    return p.outline()


def tv_retro(c, key):
    p = Pix(32, 34)
    p.line(14, 7, 9, 1, IRON)  # rabbit ears
    p.line(18, 7, 23, 0, IRON)
    p.px(9, 1, '#d8d8e0')
    p.px(23, 0, '#d8d8e0')
    p.line(8, 24, 5, 32, DARKWOOD)
    p.line(23, 24, 26, 32, DARKWOOD)
    p.line(9, 24, 6, 32, DARKWOOD)
    p.line(22, 24, 25, 32, DARKWOOD)
    rbox(p, 2, 6, 29, 25, c)
    p.rect(3, 7, 28, 7, ramp(c)[5])
    rbox(p, 4, 8, 21, 23, '#2a2e36')  # screen bezel
    p.rect(5, 9, 20, 22, '#4a7a8a')  # the weather channel
    p.rect(5, 18, 20, 22, '#3a6070')
    pell(p, 15, 12.5, 2.5, 2.5, '#f0d060', shade=False)
    pell(p, 10, 14, 3.5, 2, '#e8f0f0', shade=False)
    pell(p, 12.5, 13, 2.5, 2, '#e8f0f0', shade=False)
    p.px(6, 10, '#ffffff')
    p.px(7, 10, '#ffffff')
    p.px(6, 11, '#ffffff')
    for y in (11, 16):  # knobs
        pell(p, 25.5, y, 2, 2, BRASS)
    for y in range(19, 24, 2):  # speaker slots
        p.rect(23, y, 27, y, ramp(c)[1])
    return p.outline()


def radio(c, key):
    p = Pix(16, 24)
    r = ramp(c)
    for x in (3, 12):
        p.rect(x, 19, x, 22, DARKWOOD)
    pell(p, 8, 7.5, 6.5, 6.5, c)
    p.box(1, 8, 14, 19, c)
    p.rect(2, 8, 2, 18, r[4])
    pell(p, 8, 7.5, 4.5, 4.5, '#d8c8a0', shade=False)  # grille cloth
    p.rect(4, 8, 11, 11, '#d8c8a0')
    for x in range(5, 12, 2):
        p.rect(x, 4 if x in (7, 9) else 5, x, 11, '#a8987a')
    p.rect(3, 13, 12, 14, '#f0e0a0')  # dial
    p.rect(7, 13, 7, 14, '#c83a2a')
    p.px(4, 13, '#b89a50')
    p.px(11, 13, '#b89a50')
    pell(p, 4.5, 17, 1.5, 1.5, BRASS, shade=False)
    pell(p, 11.5, 17, 1.5, 1.5, BRASS, shade=False)
    p.px(4, 16, '#fff0b0')
    p.px(11, 16, '#fff0b0')
    return p.outline()


def bookcase_tall(c, key):
    p = Pix(48, 64)
    r = ramp(c)
    p.box(1, 2, 46, 62, c)
    p.box(0, 0, 47, 2, c)  # cornice
    p.rect(4, 4, 43, 59, r[1])
    cols = ['#b84a3a', '#3a6aa8', '#4a8a4a', '#d8b050', '#7a4a8a', '#e8e0c8', '#3a8a8a', '#a85a2a', '#2e3f6e']
    n = hashmap(48, 64, 17, 1)
    for s, y in enumerate((4, 18, 32, 46)):
        x = 5
        k = s * 5
        while x < 42:
            if s == 1 and 30 <= x < 38:  # a little plant on the second shelf
                p.box(31, y + 9, 36, y + 13, '#c86a48')
                pell(p, 33.5, y + 7, 4, 3, '#4a8a3a')
                p.px(32, y + 5, '#7ac85a')
                x = 38
                continue
            if s == 2 and 8 <= x < 18:  # a shell and a jar
                pell(p, 11, y + 11, 3, 2.5, '#f0c8b0')
                p.px(10, y + 10, '#ffffff')
                p.box(14, y + 6, 18, y + 13, GLASS)
                p.rect(15, y + 10, 17, y + 12, '#e8d8a0')
                x = 19
                continue
            w = 2 + int(n[y, x] * 3)
            h = 9 + int(n[y + 1, x] * 4)
            col = cols[(k * 5 + x) % len(cols)]
            p.box(x, y + 13 - h, min(42, x + w - 1), y + 13, col, edge=False)
            p.px(x + w // 2, y + 15 - h, shift(hx(col), 0.35))
            x += w
            k += 1
        p.box(3, y + 13, 44, y + 14, c)
    p.rect(4, 60, 43, 61, r[2])
    return p.outline()


def rug_round(c, key):
    w, h = 64, 40
    p = Pix(w, h)
    a = accent(key)
    r = ramp(c)
    pell(p, 32, 20, 31.5, 19.5, a, shade=False)
    pell(p, 32, 20, 29.5, 17.5, c, shade=False)
    pell(p, 32, 20, 24, 14, a, shade=False)
    pell(p, 32, 20, 23, 13, shift(hx(c), 0.12), shade=False)
    pell(p, 32, 20, 14, 8, r[2], shade=False)
    pell(p, 32, 20, 12, 6.8, c, shade=False)
    pell(p, 32, 20, 5, 3, a, shade=False)
    for k in range(12):  # little diamonds round the inner ring
        an = k * np.pi / 6
        x, y = 32 + np.cos(an) * 18.5, 20 + np.sin(an) * 10.8
        p.px(int(x), int(y), a)
        p.px(int(x) + 1, int(y), a)
    m = p.a[..., 3] > 0
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    ys, xs = np.nonzero(edge)
    for y, x in zip(ys, xs):  # tufted edge
        if (x + y) % 2 == 0:
            p.a[y, x, :3] = ramp(a)[2]
    return p


def rug_stripe(c, key):
    w, h = 80, 30
    p = Pix(w, h)
    a = accent(key)
    r = ramp(c)
    p.rect(2, 0, w - 3, h - 1, c)
    bands = [(4, 6, a), (8, 9, r[1]), (14, 17, tint(c, 0.35)), (22, 23, a), (28, 31, r[2])]
    for x0, x1, col in bands:
        for xs in ((x0, x1), (w - 1 - x1, w - 1 - x0)):
            p.rect(xs[0], 1, xs[1], h - 2, col)
    p.rect(36, 1, 43, h - 2, a)
    p.rect(38, 1, 41, h - 2, shift(hx(c), 0.12))
    for y in range(1, h - 1, 2):  # a faint weave in the main colour
        for x in range(2 + (y // 2) % 2 * 2, w - 2, 4):
            if tuple(p.a[y, x, :3]) == hx(c):
                p.px(x, y, shift(hx(c), -0.06))
    p.rect(2, 0, w - 3, 0, r[4])
    p.rect(2, h - 1, w - 3, h - 1, r[1])
    for y in range(1, h - 1, 2):  # fringe on the short ends
        p.rect(0, y, 1, y, CREAM)
        p.rect(w - 2, y, w - 1, y, CREAM)
    return p


# ===================================================================== bedroom

def double_bed(c, key):
    p = Pix(64, 40)
    for x in (3, 58):
        p.rect(x, 36, x + 2, 39, DARKWOOD)
    p.box(4, 2, 59, 16, WOOD)  # headboard
    for x in range(10, 56, 8):
        p.rect(x, 4, x + 4, 14, ramp(WOOD)[2])
        p.rect(x, 4, x + 4, 4, ramp(WOOD)[1])
    for x in (1, 59):
        p.box(x, 0, x + 3, 22, DARKWOOD)
        p.rect(x, 0, x + 3, 0, ramp(DARKWOOD)[4])
    p.rect(5, 10, 58, 31, '#f4f0e8')  # sheet
    rbox(p, 8, 8, 30, 15, '#f4f0e8')  # pillows
    rbox(p, 33, 8, 55, 15, '#f4f0e8')
    p.rect(12, 12, 26, 12, '#d8d4cc')
    p.rect(37, 12, 51, 12, '#d8d4cc')
    light = tint(c, 0.55)
    for ty in range(3):  # patchwork quilt on top
        for tx in range(7):
            col = c if (tx + ty) % 2 == 0 else light
            x0, y0 = 5 + tx * 8, 19 + ty * 4
            p.rect(x0, y0, min(58, x0 + 7), y0 + 3, col)
            p.px(x0 + 3, y0 + 1, shift(hx(col) if isinstance(col, str) else col, -0.22))
    p.rect(5, 17, 58, 18, '#f4f0e8')  # turned-down sheet
    p.rect(5, 18, 58, 18, '#d8d4cc')
    r = ramp(c)
    p.rect(4, 31, 59, 35, r[2])  # quilt hanging over the front
    for x in range(5, 59, 8):
        p.rect(x + 4, 31, x + 7, 35, ramp(light)[2])
    p.rect(4, 31, 59, 31, r[4])
    p.box(2, 35, 61, 37, DARKWOOD)
    return p.outline()


def bunk_bed(c, key):
    p = Pix(32, 58)
    r = ramp(c)
    for y0, blanket in ((10, '#4a6ac8'), (36, '#c84a4a')):
        rbox(p, 4, y0, 27, y0 + 6, '#f4f0e8')  # mattress
        rbox(p, 4, y0 + 1, 9, y0 + 4, '#ffffff')  # pillow
        p.rect(10, y0 + 1, 27, y0 + 6, blanket)
        p.rect(10, y0 + 1, 27, y0 + 1, ramp(blanket)[4])
        p.rect(10, y0 + 6, 27, y0 + 6, ramp(blanket)[1])
        p.box(1, y0 + 6, 30, y0 + 9, c)  # side rail
    p.box(1, 4, 30, 6, c)  # top guard rail
    for x in (21, 26):  # ladder
        p.rect(x, 19, x, 42, r[2])
    for y in range(22, 42, 5):
        p.rect(21, y, 26, y, r[4])
    for x in (1, 28):  # posts
        p.box(x, 1, x + 2, 57, c)
    return p.outline()


def wardrobe(c, key):
    p = Pix(48, 62)
    r = ramp(c)
    for x in (3, 42):
        p.rect(x, 57, x + 2, 61, r[1])
    p.box(1, 3, 46, 57, c)
    p.box(0, 0, 47, 3, c)
    p.rect(0, 3, 47, 3, r[1])
    for x0 in (4, 25):  # doors with raised panels
        p.box(x0, 6, x0 + 18, 54, c)
        p.rect(x0 + 3, 9, x0 + 15, 27, r[2])
        p.rect(x0 + 4, 10, x0 + 15, 27, r[3])
        p.rect(x0 + 3, 31, x0 + 15, 51, r[2])
        p.rect(x0 + 4, 32, x0 + 15, 51, r[3])
    p.rect(23, 6, 24, 54, r[1])
    for x in (21, 26):
        p.rect(x, 27, x, 32, BRASS)
        p.px(x, 27, ramp(BRASS)[5])
    return p.outline()


def dresser(c, key):
    p = Pix(48, 30)
    r = ramp(c)
    for x in (3, 42):
        p.rect(x, 26, x + 2, 29, r[1])
    topbox(p, 1, 5, 46, 8, c, top=2)
    p.box(1, 9, 46, 26, c)
    for y in (10, 16, 21):  # drawers
        p.box(3, y, 44, y + 4, c)
        for x in (12, 34):
            p.rect(x, y + 2, x + 2, y + 2, BRASS)
    p.box(7, 0, 11, 5, '#e8e0f0')  # a jewellery box and a photo
    p.rect(7, 2, 11, 2, '#b89adf')
    p.box(36, 0, 41, 5, '#c8983a')
    p.rect(37, 1, 40, 4, '#a8d0e8')
    p.px(38, 3, '#e8b890')
    return p.outline()


def nightstand(c, key):
    p = Pix(16, 24)
    r = ramp(c)
    for x in (2, 12):
        p.rect(x, 19, x + 1, 23, r[2])
    p.box(3, 2, 8, 7, '#c84a3a')  # alarm clock
    p.rect(4, 3, 7, 6, '#f4ecd8')
    p.px(5, 4, INK)
    p.px(6, 5, INK)
    p.px(3, 1, BRASS)
    p.px(8, 1, BRASS)
    p.rect(10, 3, 12, 7, '#c8e4f0')  # glass of water
    p.rect(10, 5, 12, 7, '#8ac0e0')
    topbox(p, 1, 7, 14, 10, c, top=2)
    p.box(2, 11, 13, 19, c)
    p.rect(3, 12, 12, 15, r[2])
    p.rect(3, 12, 12, 12, r[4])
    p.px(7, 14, BRASS)
    p.px(8, 14, BRASS)
    return p.outline()


# ===================================================================== kitchen and dining

def _counter(p, y, c, doors=2):
    r = ramp(c)
    p.box(1, y + 5, 30, y + 26, c)
    p.rect(2, y + 27, 29, y + 28, '#3a3a42')  # plinth
    p.box(2, y + 6, 29, y + 9, c)  # drawer
    p.rect(13, y + 8, 18, y + 8, CHROME)
    for x0, x1 in ((2, 15), (16, 29)):
        p.box(x0, y + 11, x1, y + 25, c)
        p.rect(x0 + 2, y + 13, x1 - 2, y + 23, r[2])
        p.rect(x0 + 3, y + 14, x1 - 2, y + 23, r[3])
    p.rect(14, y + 15, 14, y + 19, CHROME)
    p.rect(17, y + 15, 17, y + 19, CHROME)
    topbox(p, 0, y, 31, y + 4, '#c8a070', top=3)  # butcher-block worktop


def kitchen_counter(c, key):
    p = Pix(32, 36)
    _counter(p, 7, c)
    p.box(4, 0, 9, 7, '#e8e4dc')  # canisters
    p.rect(4, 3, 9, 4, '#3a6aa8')
    p.box(11, 2, 15, 7, '#e8e4dc')
    p.rect(11, 4, 15, 4, '#3a6aa8')
    p.box(21, 3, 28, 8, '#a87a48')  # bread board
    p.rect(22, 2, 27, 3, '#d89040')
    return p.outline()


def kitchen_sink(c, key):
    p = Pix(32, 38)
    _counter(p, 9, c)
    p.rect(7, 10, 24, 11, '#6a7480')  # basin in the worktop
    p.rect(8, 10, 23, 10, '#4a5460')
    p.rect(15, 2, 16, 9, CHROME)  # tap
    p.rect(15, 1, 21, 2, CHROME)
    p.rect(21, 3, 21, 4, CHROME)
    p.px(15, 1, '#ffffff')
    p.rect(12, 7, 13, 8, '#e8e8f0')
    p.rect(18, 7, 19, 8, '#e8e8f0')
    p.px(21, 6, '#a8d8f0')  # a drip
    return p.outline()


def fridge(c, key):
    p = Pix(32, 58)
    r = ramp(c)
    p.rect(4, 55, 6, 57, INK)
    p.rect(25, 55, 27, 57, INK)
    pell(p, 7, 6, 5.5, 5.5, c, shade=False)
    pell(p, 24, 6, 5.5, 5.5, c, shade=False)
    p.rect(7, 1, 24, 10, c)
    p.rect(2, 6, 29, 55, c)
    m = p.a[..., 3] > 0
    paint(p, m, c)
    p.rect(4, 6, 4, 52, r[4])  # a long highlight down the rounded front
    p.rect(3, 18, 28, 18, r[1])  # freezer door
    p.rect(3, 19, 28, 19, r[4])
    for y0, y1 in ((9, 15), (23, 34)):
        p.rect(25, y0, 26, y1, CHROME)
        p.px(25, y0, '#ffffff')
        p.rect(27, y0 + 1, 27, y1, ramp(CHROME)[1])
    p.rect(12, 4, 19, 5, CHROME)  # badge
    p.px(12, 4, '#ffffff')
    p.box(8, 26, 12, 30, '#f4f0e0')  # a note under a magnet
    p.px(10, 26, '#e84a3a')
    return p.outline()


def oven_retro(c, key):
    p = Pix(32, 36)
    r = ramp(c)
    p.rect(3, 33, 5, 35, INK)
    p.rect(26, 33, 28, 35, INK)
    rbox(p, 2, 0, 29, 7, c)  # control backsplash
    for x in (6, 11, 20, 25):
        pell(p, x + 0.5, 3.5, 1.6, 1.6, CHROME, shade=False)
        p.px(x, 2, '#ffffff')
    p.rect(14, 2, 17, 4, '#2a2e36')  # clock
    p.px(15, 3, '#ffb040')
    p.rect(1, 8, 30, 10, '#3a3a42')  # hob
    for x in (4, 11, 19, 25):
        p.rect(x, 8, x + 3, 9, '#1a1a20')
        p.rect(x + 1, 9, x + 2, 9, '#5a5a66')
    p.box(1, 11, 30, 33, c)
    p.rect(5, 13, 26, 13, CHROME)  # handle
    p.px(5, 13, '#ffffff')
    p.box(5, 16, 26, 29, '#2a2a32')  # oven window
    p.rect(7, 18, 24, 27, '#4a2a22')
    p.rect(8, 23, 23, 27, '#c8602a')
    p.rect(10, 25, 21, 26, '#ffb040')
    p.px(7, 18, '#8a8a9a')
    p.px(8, 18, '#8a8a9a')
    p.rect(2, 31, 29, 31, r[2])
    return p.outline()


def dining_table(c, key):
    p = Pix(64, 26)
    r = ramp(c)
    for x in (11, 51):  # back legs
        p.rect(x, 10, x + 1, 21, r[1])
    for x in (4, 57):
        p.box(x, 10, x + 3, 24, c)
    p.box(4, 10, 59, 12, c)  # apron
    p.rect(8, 12, 55, 12, r[1])
    topbox(p, 1, 1, 62, 10, c, top=6)
    p.rect(14, 2, 49, 5, '#f0ece0')  # a table runner
    p.rect(14, 2, 49, 2, '#ffffff')
    pell(p, 31.5, 3, 3, 1.5, '#e8e0d0', shade=False)  # a bowl of fruit
    p.px(30, 2, '#e84a3a')
    p.px(32, 2, '#f0a030')
    p.px(31, 1, '#6aa040')
    return p.outline()


def dining_chair(c, key):
    p = Pix(16, 30)
    r = ramp(c)
    for x in (2, 12):
        p.box(x, 0, x + 1, 29, c, edge=False)
    p.box(2, 0, 13, 3, c)
    for y in (6, 10):
        p.box(3, y, 12, y + 1, c, edge=False)
    topbox(p, 1, 14, 14, 18, c, top=2)
    p.rect(3, 22, 12, 22, r[2])  # stretcher
    return p.outline()


def round_table(c, key):
    p = Pix(48, 28)
    r = ramp(c)
    pell(p, 24, 25, 11, 2.5, r[2], shade=False)
    p.box(21, 12, 26, 24, c)
    p.rect(20, 13, 27, 14, r[1])
    pell(p, 24, 9, 23, 6, r[2], shade=False)  # edge thickness
    pell(p, 24, 7.5, 23, 6, c, shade=False)
    pell(p, 22, 6.5, 19, 4.2, r[4], shade=False)
    pell(p, 18, 5.5, 8, 2, r[5], shade=False)
    m = emask(p, 24, 9, 23, 6) & ~emask(p, 24, 7.5, 23, 6)
    p.a[m & ~np.roll(m, -1, 0), :3] = r[1]
    p.rect(29, 3, 31, 6, '#f4f0e8')  # a cup
    p.px(32, 4, '#d8d4cc')
    p.rect(14, 6, 21, 8, '#e8e0c8')  # playing cards
    p.px(15, 7, '#c83a3a')
    p.px(19, 7, INK)
    return p.outline()


def bar_stool(c, key):
    p = Pix(16, 26)
    pell(p, 8, 24, 6, 1.6, CHROME)
    p.rect(7, 8, 8, 23, CHROME)
    p.rect(7, 8, 7, 23, '#e8eef4')
    p.rect(3, 17, 12, 18, CHROME)
    p.rect(3, 17, 12, 17, '#e8eef4')
    p.box(1, 4, 14, 8, c)
    pell(p, 8, 4, 7, 2.6, c)
    pell(p, 7, 3.5, 4, 1.2, ramp(c)[4], shade=False)
    p.rect(2, 8, 13, 8, ramp(c)[1])
    return p.outline()


# ===================================================================== bathroom

def bathtub(c, key):
    p = Pix(64, 28)
    r = ramp(c)
    for x in (8, 53):  # claw feet
        p.rect(x, 22, x + 2, 26, BRASS)
        p.rect(x - 1, 26, x + 3, 26, ramp(BRASS)[2])
    m = emask(p, 32, 13, 29, 11) & (np.mgrid[0:28, 0:64][0] >= 5)
    paint(p, m, c)
    p.rect(6, 7, 6, 18, r[4])
    p.rect(9, 8, 54, 8, r[4])
    topbox(p, 1, 2, 62, 6, PORC, top=3)
    p.rect(4, 3, 59, 4, '#8ac8e0')  # water
    p.rect(4, 3, 59, 3, '#6aa8cc')
    for x in (14, 31, 44):
        p.rect(x, 4, x + 3, 4, '#c8ecf8')
    pell(p, 52, 3, 4, 1.6, '#ffffff', shade=False)  # bubbles
    p.px(48, 2, '#ffffff')
    p.rect(3, 0, 4, 3, BRASS)  # tap
    p.rect(3, 0, 7, 0, BRASS)
    p.px(7, 1, BRASS)
    return p.outline()


def toilet(c, key):
    p = Pix(16, 28)
    r = ramp(c)
    p.box(5, 19, 10, 26, PORC)
    p.rect(4, 26, 11, 27, ramp(PORC)[2])
    pell(p, 8, 17, 6.5, 4, PORC)
    p.box(2, 1, 13, 10, c)  # cistern
    p.rect(2, 1, 13, 1, r[5])
    p.rect(7, 2, 8, 2, CHROME)
    pell(p, 8, 13.5, 6.5, 2.5, c)  # seat lid seen from above
    p.rect(3, 11, 12, 11, r[2])
    return p.outline()


def shower(c, key):
    p = Pix(32, 68)
    r = ramp(c)
    p.rect(2, 2, 29, 59, c)  # tiled back wall
    for y in range(2, 60, 6):
        p.rect(2, y, 29, y, r[4])
    for y in range(2, 60, 6):
        for x in range(2 + (y // 6 % 2) * 3, 30, 6):
            p.rect(x, y, x, y + 5, r[2])
    p.rect(14, 4, 15, 13, CHROME)  # pipe and head
    p.rect(14, 4, 19, 5, CHROME)
    pell(p, 18.5, 7, 3.5, 1.8, CHROME)
    p.px(17, 9, '#a8d8f0')
    p.px(19, 11, '#a8d8f0')
    p.px(18, 14, '#a8d8f0')
    p.rect(13, 28, 16, 30, CHROME)  # mixer
    # glass door over the right two thirds
    g = np.zeros((68, 32), bool)
    g[2:60, 11:30] = True
    rgb = p.a[..., :3].astype(float)
    rgb[g] = rgb[g] * 0.7 + np.array(hx('#e0f4fa')) * 0.3
    p.a[..., :3] = rgb.astype(np.uint8)
    for x0, y0, ln in ((15, 50, 12), (18, 52, 7)):  # glare on the glass
        p.line(x0, y0, x0 + ln // 2, y0 - ln, mix(p.a[y0, x0, :3], '#ffffff', 0.6))
    p.rect(11, 2, 11, 59, CHROME)
    p.rect(13, 32, 13, 38, CHROME)  # door handle
    for x in (1, 30):  # frame
        p.rect(x, 0, x, 59, CHROME)
    p.rect(1, 0, 30, 1, CHROME)
    p.rect(1, 0, 30, 0, '#e8eef4')
    topbox(p, 0, 59, 31, 65, PORC, top=2)
    return p.outline()


def basin(c, key):
    p = Pix(16, 30)
    r = ramp(c)
    p.box(5, 15, 10, 27, c)
    p.rect(4, 27, 11, 28, r[2])
    m = (emask(p, 8, 10, 7, 5) & (np.mgrid[0:30, 0:16][0] >= 7))
    paint(p, m, c)
    pell(p, 8, 8, 6.5, 1.8, r[4], shade=False)  # rim
    pell(p, 8, 8.3, 5, 1.2, '#dce8ec', shade=False)  # the bowl inside
    p.rect(7, 2, 8, 7, CHROME)  # tap
    p.rect(7, 2, 10, 3, CHROME)
    p.px(7, 2, '#ffffff')
    p.px(5, 6, '#e84a3a')
    p.px(10, 6, '#3a7ab8')
    return p.outline()


# ===================================================================== lights

def floor_lamp(c, key):
    p = Pix(14, 52)
    p.rect(6, 13, 7, 48, BRASS)
    p.rect(6, 13, 6, 48, ramp(BRASS)[4])
    pell(p, 7, 49.5, 5, 1.6, BRASS)
    trap(p, 7, 1, 13, 7, 12, c)
    p.rect(2, 13, 11, 13, '#fff4c0')  # light spilling from under the shade
    p.rect(4, 2, 4, 11, ramp(c)[5])
    p.outline()
    glow(p, (np.mgrid[0:52, 0:14][0] == 14) & (np.mgrid[0:52, 0:14][1] > 2) & (np.mgrid[0:52, 0:14][1] < 11),
         '#fff0b0', passes=2, strength=1.4, alpha=110)
    return p


def table_lamp(c, key):
    p = Pix(14, 22)
    pell(p, 7, 20, 4.5, 1.4, BRASS)
    p.rect(6, 15, 7, 19, BRASS)
    pell(p, 7, 14, 3.5, 3.5, '#f0ece0')  # ceramic base
    trap(p, 7, 1, 9, 6, 12, c)
    p.rect(3, 9, 10, 9, '#fff4c0')
    p.rect(4, 2, 4, 8, ramp(c)[5])
    return p.outline()


def lava_lamp(c, key):
    p = Pix(12, 26)
    metal = '#8a8e98'
    trap(p, 6, 17, 24, 4, 10, metal)  # base cone
    trap(p, 6, 1, 4, 3, 4, metal)  # cap
    liquid = shift(hx(c), -0.45, -0.2)
    trap(p, 6, 5, 16, 4, 8, liquid)  # glass
    r = ramp(c)
    for cx, cy, rx, ry in ((6, 8, 1.4, 1.8), (5.5, 12, 2, 2), (6.5, 15.5, 2.6, 1.2)):
        pell(p, cx, cy, rx, ry, neon(c), shade=False)
    p.px(5, 11, r[5])
    p.px(6, 7, r[5])
    p.rect(3, 6, 3, 14, mix(liquid, '#ffffff', 0.4))
    p.rect(4, 18, 4, 22, ramp(metal)[5])
    p.outline()
    gm = np.zeros((26, 12), bool)
    gm[5:17, 3:9] = True
    glow(p, gm, neon(c), passes=2, strength=1.2, alpha=90)
    return p


def string_lights(c, key):
    p = Pix(64, 12)
    wire = '#3a3a44'
    ys = [2 + 3 * np.sin(np.pi * (x % 16) / 16) for x in range(64)]
    for x in range(64):
        p.px(x, int(round(ys[x])), wire)
    bulbs = np.zeros((12, 64), bool)
    for k in range(8):
        x = 4 + k * 8
        y = int(round(ys[x])) + 1
        p.rect(x - 1, y, x, y, wire)
        col = neon(c)
        p.rect(x - 1, y + 1, x, y + 3, col)
        p.px(x - 1, y + 1, shift(col, 0.4, -0.6))
        p.px(x, y + 3, ramp(col)[2])
        bulbs[y + 1:y + 4, x - 1:x + 1] = True
    glow(p, bulbs, neon(c), passes=2, strength=1.6, alpha=120)
    return p


def _neon_sign(p, strokes, c, dots=()):
    col = neon(c)
    core = shift(col, 0.45, -0.6)
    for pts in strokes:
        thick(p, pts, col, 2)
    for x, y in dots:
        p.rect(x, y, x + 1, y + 1, col)
    m = p.a[..., 3] > 0
    for pts in strokes:  # a white-hot core down the middle of the tube
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(n + 1):
                t = i / n
                x, y = int(round(x0 + (x1 - x0) * t - 0.5)), int(round(y0 + (y1 - y0) * t - 0.5))
                if m[y, x]:
                    p.px(x, y, core)
    for x, y in dots:
        p.px(x, y, core)
    glow(p, m, col, passes=3, strength=2.2, alpha=140)
    return p


def arc(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + np.cos(a) * rx, cy + np.sin(a) * ry) for a in np.linspace(a0, a1, n)]


def neon_gm(c, key):
    p = Pix(36, 24)
    g = arc(11, 12, 6.5, 7, np.radians(-45), np.radians(-45 - 300), 30)  # the G, drawn anticlockwise
    bar = [(13, 13.5), (17.5, 13.5)]
    m = [(20.5, 19), (20.5, 5), (25.5, 13), (30.5, 5), (30.5, 19)]
    return _neon_sign(p, [g, bar, [g[-1], (17.5, 15)], m], c)


def neon_fish(c, key):
    p = Pix(36, 24)
    top = arc(15, 12, 11, 7, np.radians(205), np.radians(335), 24)
    bot = arc(15, 12, 11, 7, np.radians(155), np.radians(25), 24)
    tail = [top[-1], (33, 5), (31, 12), (33, 19), bot[-1]]
    nose = [top[0], (3.5, 12), bot[0]]
    fin = [(13, 6.5), (17, 2.5), (21, 6)]
    return _neon_sign(p, [top, bot, tail, nose, fin], c, dots=[(8, 9)])


def neon_heart(c, key):
    p = Pix(30, 26)
    t = np.linspace(0, 2 * np.pi, 60)
    xs = 15 + 0.7 * 16 * np.sin(t) ** 3
    ys = 12 - 0.62 * (13 * np.cos(t) - 5 * np.cos(2 * t) - 2 * np.cos(3 * t) - np.cos(4 * t))
    return _neon_sign(p, [list(zip(xs, ys))], c)


# ===================================================================== fun

def jukebox(c, key):
    p = Pix(32, 48)
    r = ramp(c)
    m = emask(p, 16, 16, 14.5, 15) | ((np.mgrid[0:48, 0:32][0] >= 16) & (np.mgrid[0:48, 0:32][0] <= 45)
                                       & (np.mgrid[0:48, 0:32][1] >= 1) & (np.mgrid[0:48, 0:32][1] <= 30))
    paint(p, m, c)
    p.rect(2, 16, 2, 44, r[4])
    # the glowing arch: three bands of light round the top and down the sides
    yy, xx = np.mgrid[0:48, 0:32]
    d = np.hypot(xx + 0.5 - 16, (yy + 0.5 - 16) * 14.5 / 15)
    for r0, r1, col in ((12.6, 14.0, '#ff5a8a'), (11.4, 12.6, '#ffb040'), (10.2, 11.4, '#fff07a')):
        band = (d >= r0) & (d < r1) & (yy < 16)
        side = (yy >= 16) & (yy <= 38) & (((xx + 0.5 - 16) >= r0) & ((xx + 0.5 - 16) < r1)
                                          | ((16 - xx - 0.5) >= r0) & ((16 - xx - 0.5) < r1))
        p.a[band | side, :3] = hx(col)
    p.a[(d < 10.2) & (yy < 16), :3] = hx('#2a2236')  # window onto the records
    p.rect(6, 16, 25, 22, '#2a2236')
    for k, x in enumerate((9, 16, 23)):
        pell(p, x, 15, 3, 1.4, '#14141c', shade=False)
        p.px(x, 15, ['#e84a3a', '#f0c040', '#3ab8e8'][k])
    p.rect(8, 9, 23, 9, '#3a3248')
    p.px(9, 7, '#ffffff')
    p.px(10, 6, '#ffffff')
    p.box(6, 24, 25, 27, CHROME)  # song buttons
    for x in range(8, 24, 3):
        p.px(x, 25, '#ff5a8a' if x % 2 else '#fff07a')
    p.box(6, 29, 25, 40, ramp(c)[1])  # speaker grille
    for y in range(30, 40, 2):
        p.rect(7, y, 24, y, CHROME)
    p.box(0, 42, 31, 46, c)
    p.rect(0, 42, 31, 42, r[5])
    arch = np.isin(p.a[..., 0], [hx('#ff5a8a')[0], hx('#ffb040')[0], hx('#fff07a')[0]]) & (p.a[..., 3] > 0)
    p.outline()
    glow(p, arch & (yy < 12), '#ffb040', passes=2, strength=1.0, alpha=90)
    return p


def arcade(c, key):
    p = Pix(32, 58)
    r = ramp(c)
    p.box(1, 0, 30, 57, c)  # side panels show round the front
    p.rect(2, 1, 2, 56, r[4])
    p.rect(4, 2, 27, 9, '#ffe680')  # lit marquee
    p.rect(4, 2, 27, 2, '#fff8c0')
    text(p, 8, 4, 'GULL', '#c83a3a')
    p.box(4, 11, 27, 31, '#1a1a22')  # screen bezel
    p.rect(6, 13, 25, 29, '#1a2a5a')
    n = hashmap(32, 58, 91, 1)
    for y in range(13, 30):
        for x in range(6, 26):
            if n[y, x] > 0.96:
                p.px(x, y, '#ffffff')
    for x in range(8, 24, 4):  # a row of crabs coming down
        p.rect(x, 15, x + 2, 16, '#ff5a6a')
        p.px(x, 17, '#ff5a6a')
        p.px(x + 2, 17, '#ff5a6a')
    for x in range(10, 22, 4):
        p.rect(x, 19, x + 2, 20, '#5ae8ff')
    p.rect(15, 23, 15, 24, '#fff07a')  # a shot
    p.rect(14, 26, 16, 27, '#5aff8a')  # the player's gull
    p.px(15, 25, '#5aff8a')
    p.rect(6, 13, 25, 13, '#3a4a8a')
    topbox(p, 0, 32, 31, 37, '#2a2a34', top=3)  # control panel
    p.rect(8, 29, 8, 33, '#3a3a44')
    pell(p, 8.5, 29.5, 2, 2, '#e83a3a')
    p.px(8, 28, '#ffb0b0')
    for x, col in ((17, '#3ab8e8'), (21, '#f0c040'), (25, '#5ae84a')):
        p.rect(x, 33, x + 1, 34, col)
    p.box(11, 41, 20, 52, '#2a2a34')  # coin door
    p.rect(13, 43, 14, 47, '#ff8a3a')
    p.rect(17, 43, 18, 47, '#ff8a3a')
    p.rect(1, 55, 30, 57, r[1])
    p.outline()
    scr = np.zeros((58, 32), bool)
    scr[13:30, 6:26] = True
    lit_glow(p, scr, '#5a8aff', 0.18)
    return p


def piano(c, key):
    p = Pix(48, 40)
    r = ramp(c)
    for x in (3, 42):
        p.box(x, 28, x + 2, 38, c)
    p.box(4, 0, 43, 26, c)
    topbox(p, 2, 0, 45, 3, c, top=2)
    p.rect(8, 6, 39, 18, r[2])  # front panel
    p.rect(9, 7, 39, 18, r[3])
    p.box(17, 8, 30, 16, '#f4f0e8')  # sheet music
    for y in range(10, 16, 2):
        p.rect(19, y, 28, y, '#8a8a9a')
        p.px(20 + (y * 3) % 7, y - 1, INK)
    for x in (6, 41):  # candle sconces
        p.rect(x, 7, x + 1, 9, BRASS)
        p.px(x, 6, '#fff0a0')
    p.box(2, 21, 45, 23, c)  # key bed
    p.rect(4, 23, 43, 26, '#f4f0e8')  # keys
    for x in range(4, 44, 3):
        p.rect(x, 23, x, 26, '#c8c4bc')
    for x in range(5, 43):
        if (x - 5) % 21 in (1, 4, 10, 13, 16):
            p.rect(x, 23, x + 1, 24, '#1a1a20')
    p.box(2, 27, 45, 28, c)
    p.box(6, 29, 41, 36, c)
    p.rect(8, 30, 39, 35, r[2])
    for x in (20, 23, 26):  # pedals
        p.rect(x, 37, x + 1, 38, BRASS)
    return p.outline()


def guitar_stand(c, key):
    p = Pix(16, 38)
    stand = '#2a2a30'
    p.line(8, 28, 3, 36, stand)
    p.line(8, 28, 13, 36, stand)
    p.rect(2, 36, 5, 36, stand)
    p.rect(11, 36, 14, 36, stand)
    p.rect(7, 4, 8, 17, '#6a4428')  # neck
    for y in range(6, 17, 3):
        p.rect(7, y, 8, y, '#c8c0b0')
    p.box(6, 0, 9, 4, '#4a3020')  # headstock
    p.px(5, 1, CHROME)
    p.px(10, 1, CHROME)
    p.px(5, 3, CHROME)
    p.px(10, 3, CHROME)
    m = emask(p, 8, 28, 6.5, 6.5) | emask(p, 8, 20.5, 5, 5)
    p.a[m, :3] = hx(CREAM if key != 'cream' else '#6a4428')  # binding
    p.a[m, 3] = 255
    m2 = emask(p, 8, 28, 5.5, 5.5) | emask(p, 8, 20.5, 4, 4)
    paint(p, m2, c)
    pell(p, 6, 26, 2.5, 3, ramp(c)[4], shade=False)
    pell(p, 8, 23, 1.8, 1.8, '#1a1410', shade=False)  # sound hole
    p.rect(6, 30, 10, 30, '#3a2418')  # bridge
    p.rect(8, 4, 8, 29, '#e8e4dc')  # strings
    return p.outline()


def pool_table(c, key):
    p = Pix(80, 30)
    wood = '#6e4426'
    for x in (4, 37, 71):
        p.box(x, 20, x + 4, 28, wood)
    p.rect(3, 28, 9, 29, ramp(wood)[1])
    p.rect(70, 28, 76, 29, ramp(wood)[1])
    p.box(0, 0, 79, 15, wood)  # rails
    p.box(1, 15, 78, 21, wood)
    p.rect(1, 15, 78, 15, ramp(wood)[5])
    for x in range(10, 72, 10):  # diamond markers on the apron
        p.px(x, 18, '#f0e0b0')
    r = ramp(c)
    p.rect(4, 3, 75, 12, c)  # felt
    p.rect(4, 3, 75, 3, r[1])
    p.rect(4, 3, 4, 12, r[2])
    p.rect(5, 12, 75, 12, r[4])
    p.rect(20, 4, 20, 11, r[4])  # baulk line
    for x, y in ((2, 1), (38, 1), (76, 1), (2, 12), (38, 13), (76, 12)):  # pockets
        p.rect(x, y, x + 1, y + 1, '#141414')
    balls = [(13, 8, '#f8f8f0'), (52, 7, '#f0c030'), (55, 6, '#3a6ae8'), (55, 8, '#e83a3a'),
             (58, 5, '#7a3ab8'), (58, 7, '#1a1a1a'), (58, 9, '#f08a30'), (61, 6, '#2a8a4a'),
             (61, 8, '#8a2a2a'), (35, 6, '#f0c030')]
    for x, y, col in balls:
        p.rect(x, y, x + 1, y + 1, col)
        p.px(x, y, shift(hx(col), 0.4, -0.5))
    p.line(16, 9, 30, 11, '#e8c890')  # the cue
    p.px(16, 9, '#f8f8f0')
    return p.outline()


def fish_bowl(c, key):
    p = Pix(16, 30)
    r = ramp(c)
    p.box(3, 27, 12, 29, c)  # stand
    p.box(6, 21, 9, 27, c)
    topbox(p, 2, 17, 13, 21, c, top=2)
    pell(p, 8, 10, 7, 7.5, '#d8eef4')  # bowl
    m = emask(p, 8, 10, 6, 6.5)
    yy = np.mgrid[0:30, 0:16][0]
    paint(p, m & (yy >= 7), '#6ab8d8', shade=False)
    p.a[m & (yy == 7), :3] = hx('#b8e4f4')
    paint(p, m & (yy >= 14), tint(c, 0.25), shade=False)  # gravel
    for x in range(3, 13, 2):
        p.px(x, 15 + x % 2, r[2])
    p.line(11, 14, 11, 9, LEAF)  # weed
    p.px(12, 11, '#6ac85a')
    p.rect(5, 10, 7, 11, '#f08a30')  # Admiral
    p.px(4, 10, '#f8b060')
    p.px(8, 9, '#f08a30')
    p.px(8, 12, '#f08a30')
    p.px(6, 10, INK)
    p.rect(2, 2, 13, 3, '#e8f4f8')  # rim
    p.px(4, 6, '#ffffff')
    p.px(3, 7, '#ffffff')
    return p.outline()


def cat_bed(c, key):
    p = Pix(30, 16)
    r = ramp(c)
    pell(p, 15, 9.5, 14, 5.8, r[2], shade=False)
    pell(p, 15, 7.5, 14, 5.5, c, shade=False)
    pell(p, 13, 6, 10, 3, r[4], shade=False)
    inner = '#f4ecd8' if key != 'cream' else '#c8b89a'
    pell(p, 15, 8, 9.5, 3.2, inner)
    for x, y in ((12, 8), (17, 7)):  # a paw-print pattern
        p.px(x, y, ramp(inner)[2])
    m = p.a[..., 3] > 0
    p.a[m & ~np.roll(m, -1, 0), :3] = r[1]
    return p.outline()


def gaming_desk(c, key):
    p = Pix(48, 40)
    r = ramp(c)
    for x0 in (2, 42):
        p.box(x0, 21, x0 + 3, 38, c)
    p.box(32, 21, 41, 34, c)  # drawer unit
    p.rect(33, 24, 40, 24, r[1])
    p.rect(33, 29, 40, 29, r[1])
    p.rect(35, 22, 38, 22, CHROME)
    topbox(p, 0, 16, 47, 21, c, top=3)
    rgb = ['#ff3a8a', '#ffb03a', '#3ae8a0', '#3a9aff']
    for x in range(1, 47):  # an LED strip under the desk edge
        p.px(x, 21, rgb[(x // 6) % 4])
    for x0, x1, kind in ((3, 21, 'chart'), (25, 44, 'game')):  # two monitors
        p.box(x0, 1, x1, 13, '#1a1a22')
        p.rect((x0 + x1) // 2 - 1, 14, (x0 + x1) // 2 + 1, 16, '#2a2a34')
        p.rect((x0 + x1) // 2 - 3, 16, (x0 + x1) // 2 + 3, 16, '#2a2a34')
        if kind == 'chart':
            p.rect(x0 + 2, 3, x1 - 2, 11, '#0e1620')
            for k, x in enumerate(range(x0 + 3, x1 - 2, 2)):
                top = 10 - k * 0.9
                up = k != 3
                col = '#2ee88a' if up else '#ff4a5a'
                y0 = int(top) - 1
                p.rect(x, max(3, y0), x, min(11, y0 + 2), col)
                p.px(x, max(3, y0 - 1), shift(hx(col), -0.3))
        else:
            p.rect(x0 + 2, 3, x1 - 2, 11, '#5ab8f0')
            p.rect(x0 + 2, 9, x1 - 2, 11, '#4ab83a')
            p.rect(x0 + 2, 9, x1 - 2, 9, '#8ae86a')
            p.rect(x0 + 6, 7, x0 + 7, 8, '#ffffff')  # a gull hopping
            p.px(x0 + 8, 7, '#f0a030')
            p.rect(x1 - 6, 6, x1 - 4, 8, '#c86a48')
            pell(p, x1 - 4.5, 4.5, 1.5, 1.5, '#fff07a', shade=False)
    p.rect(14, 17, 29, 18, '#d8dce4')  # keyboard and mouse
    for x in range(15, 29, 2):
        p.px(x, 17, '#8a8e98')
    p.rect(32, 17, 33, 18, '#d8dce4')
    p.box(39, 13, 42, 17, '#f4f0e8')  # a mug
    p.outline()
    scr = np.zeros((40, 48), bool)
    scr[3:12, 5:20] = True
    scr[3:12, 27:43] = True
    glow(p, scr, '#9ad8ff', passes=2, strength=0.5, alpha=70)
    return p


# ===================================================================== plants

def _pot(p, x0, y0, x1, y1, c):
    p.box(x0 + 1, y0 + 2, x1 - 1, y1, c)
    p.rect(x0 + 2, y1, x1 - 2, y1, ramp(c)[1])
    p.box(x0, y0, x1, y0 + 2, c)
    p.rect(x0, y0, x1, y0, ramp(c)[5])


def potted_palm(c, key):
    p = Pix(20, 42)
    cy = 12
    for y in range(cy, 33):  # trunk, leaning a little
        x = 9 + (1 if y > 24 else 0)
        p.rect(x, y, x + 1, y, '#8a6a42' if y % 3 else '#6a4a2a')
        p.px(x, y, '#a88a5a')
    # fronds rise out of the crown and arch over, with leaflets hanging from each one:
    # (side, span, lift, drop)
    fronds = [(-1, 9, 3, 9), (1, 9, 3, 9), (-1, 7, 5, 4), (1, 7, 5, 4), (-1, 3, 7, 0), (1, 3, 7, 0)]
    for k, (side, span, lift, drop) in enumerate(fronds):
        pts = []
        for i in range(25):
            t = i / 24
            pts.append((9.5 + side * span * t, cy - lift * 2 * t + (lift * 2 + drop) * t * t))
        for i, (x, y) in enumerate(pts[3::2]):
            ln = 4 if i < 4 else (3 if i < 8 else 2)
            col = '#5aa04a' if (i + k) % 2 else '#3e8a3a'
            p.line(x, y, x + side * 0.7, y + ln, col)
        for x, y in pts:
            p.px(int(round(x - 0.5)), int(round(y)), '#2e6a30')
    for x, y in ((9, cy), (10, cy), (9, cy + 1), (10, cy + 1)):  # coconuts
        p.px(x, y, '#7a5a2a')
    _pot(p, 4, 31, 15, 41, c)
    return p.outline()


def cactus(c, key):
    p = Pix(14, 26)
    g = '#4a9a4a'
    rbox(p, 1, 9, 3, 14, g)
    p.rect(3, 13, 5, 14, g)
    rbox(p, 10, 6, 12, 12, g)
    p.rect(8, 11, 10, 12, g)
    rbox(p, 5, 3, 8, 19, g)
    p.rect(6, 4, 6, 18, '#7ac86a')
    for x, y in ((5, 7), (8, 10), (5, 13), (8, 16), (1, 11), (12, 8)):
        p.px(x, y, '#e8f0c8')
    p.px(6, 2, '#ff6aa0')
    p.px(7, 2, '#ff6aa0')
    _pot(p, 2, 18, 11, 25, c)
    return p.outline()


def flower_vase(c, key):
    p = Pix(14, 24)
    for x0, x1 in ((7, 3), (7, 7), (7, 11), (6, 5), (8, 9)):
        p.line(x0, 15, x1, 6, '#3a7a3a')
    p.px(4, 11, '#5aa04a')
    p.px(10, 10, '#5aa04a')
    centre = '#f0c040' if key not in ('yellow',) else '#a8602a'
    for x, y in ((3, 5), (7, 3), (11, 5), (5, 8), (9, 8)):
        p.rect(x - 1, y, x + 1, y, c)
        p.rect(x, y - 1, x, y + 1, c)
        p.px(x - 1, y - 1, ramp(c)[4])
        p.px(x + 1, y + 1, ramp(c)[2])
        p.px(x, y, centre)
    pell(p, 7, 18.5, 4.5, 4.5, GLASS)  # glass vase
    p.rect(5, 12, 8, 15, GLASS)
    p.rect(5, 12, 8, 12, '#e0f4fa')
    p.rect(4, 18, 9, 21, '#7ab8d0')
    p.px(4, 16, '#ffffff')
    p.px(5, 14, '#ffffff')
    return p.outline()


def bonsai(c, key):
    p = Pix(20, 20)
    bark = '#6a4a32'
    p.line(10, 15, 9, 11, bark)
    p.line(11, 15, 10, 11, bark)
    p.line(9, 11, 12, 7, bark)
    p.line(10, 11, 13, 7, bark)
    p.line(10, 10, 6, 8, bark)
    p.line(12, 8, 9, 4, bark)
    for cx, cy, rx, ry in ((5.5, 7, 4, 2.2), (14, 6, 4.5, 2.4), (9.5, 3.5, 3.5, 2)):
        pell(p, cx, cy, rx, ry, '#4a8a3a')
        pell(p, cx - 1, cy - 0.8, rx * 0.6, ry * 0.5, '#6aaa4a', shade=False)
    _pot(p, 3, 15, 16, 19, c)
    p.rect(5, 15, 14, 15, '#5a7a3a')  # moss
    return p.outline()


def monstera(c, key):
    p = Pix(32, 40)
    xx, yy = grid(p)
    # big split leaves, back to front; a = which way the leaf points (0 = right)
    leaves = [(16, 8, 8, 6, -1.75), (7, 15, 7.5, 5.5, 3.6), (25, 14, 7.5, 5.5, -0.45),
              (9, 25, 6, 4.2, 2.9), (23, 25, 6, 4.2, 0.25)]
    for cx, cy, rx, ry, a in leaves:  # stems first
        p.line(15.5, 30, cx - np.cos(a) * rx * 0.8, cy - np.sin(a) * ry * 0.8, '#3a7a3a')
    for i, (cx, cy, rx, ry, a) in enumerate(leaves):
        dx, dy = xx - cx, yy - cy
        u = (dx * np.cos(a) + dy * np.sin(a)) / rx
        v = (-dx * np.sin(a) + dy * np.cos(a)) / ry
        m = (u ** 2 + v ** 2 <= 1) & ~((u < -0.75) & (np.abs(v) < 0.18))  # notch at the stem
        slit = (np.abs(v) > 0.3) & (((u * 2.6 - np.abs(v) * 1.3 + 10) % 1.0) < 0.2) & (u > -0.7)
        m &= ~slit
        col = '#3f8a3a' if i % 2 else '#4a9a40'
        paint(p, m, col)
        edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        p.a[edge, :3] = hx('#235a2a')
        rib = m & ~edge & (np.abs(v) < 0.1) & (u > -0.75)
        p.a[rib, :3] = hx('#7ac85a')
        hl = m & ~edge & (v < -0.35) & (v > -0.6) & (np.abs(u) < 0.45)
        p.a[hl, :3] = hx('#62b050')
    _pot(p, 9, 29, 22, 39, c)
    return p.outline()


# ===================================================================== wall decor

def curtains(c, key):
    p = Pix(44, 60)
    r = ramp(c)
    for side in (0, 1):
        for y in range(8, 58):
            # gathered at the tieback, flaring above and below
            if y < 36:
                w = 12 - int((y - 8) / 28 * 5)
            else:
                w = 7 + int((y - 36) / 21 * 5)
            for i in range(w):
                x = 1 + i if side == 0 else 42 - i
                fold = (i * 4 // max(1, w)) % 2
                tone = r[3] if fold == 0 else r[2]
                if i == 0:
                    tone = r[4] if side == 0 else r[2]
                if i == w - 1:
                    tone = r[1] if side == 0 else r[4]
                p.px(x, y, tone)
        p.rect(1 if side == 0 else 34, 57, 9 if side == 0 else 42, 57, r[1])
    for x0 in (1, 37):  # tiebacks
        p.rect(x0, 35, x0 + 6, 37, BRASS)
        p.rect(x0, 35, x0 + 6, 35, ramp(BRASS)[5])
    p.box(0, 0, 43, 7, c)  # pelmet with a scalloped edge
    p.rect(0, 1, 43, 1, r[5])
    for x in range(0, 44):  # four swags along the bottom
        dip = int(round(2.5 * np.sin(np.pi * (x % 11 + 0.5) / 11)))
        p.rect(x, 7, x, 7 + dip, r[2])
        p.px(x, 8 + dip, r[1])
    for x0 in (11, 22, 33):  # pleats where the swags meet
        p.rect(x0, 3, x0, 8, r[2])
    return p.outline()


def _poster(c, key, draw):
    p = Pix(24, 32)
    p.box(1, 1, 22, 30, '#f4f0e8')  # paper
    p.rect(3, 3, 20, 25, c)
    draw(p, c, key)
    for x in range(5, 19):  # caption
        if x % 4 != 3:
            p.px(x, 27, '#4a4a58')
    p.rect(8, 28, 15, 28, '#8a8a9a')
    p.px(11, 1, '#c83a3a')  # pin
    p.px(12, 1, '#e86a5a')
    return p.outline()


def poster_wave(c, key):
    def draw(p, c, key):
        p.rect(3, 3, 20, 25, tint(c, 0.35))
        pell(p, 17.5, 6.5, 2.2, 2.2, '#fff4c0', shade=False)
        xx, yy = grid(p)
        inside = (xx >= 3) & (xx < 21) & (yy >= 3) & (yy < 26)
        cx, cy = 11.5, 13
        d = np.hypot(xx - cx, yy - cy)
        ang = np.degrees(np.arctan2(yy - cy, xx - cx))  # 0 right, -90 up, 180 left
        ring = (d <= 8) & (d >= 3.6) & ~((ang > 70) & (ang < 165))  # the curl, open at the bottom left
        face = (xx >= cx) & (yy >= cy) & (xx < 21)  # the wave face down to the sea
        sea = yy >= 21
        tube = (d < 3.6) & ~((ang > 70) & (ang < 165))
        p.a[inside & (ring | face | sea), :3] = hx('#2a5aa8')
        p.a[inside & ring & (d < 6.6), :3] = hx('#1e3a78')
        p.a[inside & (tube | ((d < 3.6) & (yy > cy))), :3] = hx('#142a5a')  # the shadowed tube
        p.a[inside & face & (xx > cx + 5), :3] = hx('#3a72c0')
        foam = ring & (d > 6.6) & (ang < -15) & (ang > -175)
        p.a[inside & foam, :3] = hx('#ffffff')
        p.a[inside & ring & (ang >= 150) & (d > 5.5), :3] = hx('#e8f4ff')  # the falling lip
        for x, y in ((4, 15), (5, 17), (3, 13), (6, 19)):  # spray
            p.px(x, y, '#ffffff')
        for x in range(3, 21):  # foam along the base
            p.px(x, 21 + (x % 3 == 0), '#e8f4ff')
        p.rect(14, 23, 18, 23, '#5a8ad8')
        p.rect(4, 24, 7, 24, '#5a8ad8')
    return _poster(c, key, draw)


def poster_gull(c, key):
    def draw(p, c, key):
        p.rect(3, 3, 20, 25, tint(c, 0.3))
        pell(p, 11.5, 11, 6, 6, tint(c, 0.6), shade=False)  # sun behind
        p.box(9, 19, 13, 25, '#8a6a42')  # a post
        pell(p, 11, 15, 5, 3.2, '#f4f4f0')  # body
        p.rect(7, 13, 13, 15, '#a8b0bc')  # folded wing
        p.rect(7, 15, 12, 15, '#5a6070')
        pell(p, 15, 10, 2.5, 2.4, '#f4f4f0')  # head
        p.px(16, 9, INK)
        p.rect(17, 10, 19, 10, '#f0a030')
        p.px(18, 11, '#e85a3a')
        p.line(5, 15, 7, 16, '#5a6070')  # tail
        p.rect(10, 18, 10, 19, '#f0a030')
        p.rect(12, 18, 12, 19, '#f0a030')
    return _poster(c, key, draw)


def poster_moon(c, key):
    def draw(p, c, key):
        p.rect(3, 3, 20, 25, shift(hx(c), -0.35))
        for x, y in ((5, 5), (9, 19), (13, 4), (19, 15), (6, 13), (17, 23)):
            p.px(x, y, '#fff8d8')
        pell(p, 16, 8, 4.5, 4.5, '#f4ecc8')  # the moon
        p.px(15, 7, '#d8ccA0')
        p.px(17, 10, '#d8cca0')
        p.px(18, 6, '#d8cca0')
        # the rocket climbing to the top right
        xx, yy = grid(p)
        u = ((xx - 8) - (yy - 19)) / np.sqrt(2)  # along the flight path
        v = ((xx - 8) + (yy - 19)) / np.sqrt(2)  # across it
        body = (u >= -1) & (u <= 8) & (np.abs(v) <= 1.9 - np.clip(u - 5.5, 0, 9) * 0.6)
        fins = (u >= -1.5) & (u <= 1.2) & (np.abs(v) <= 3.4) & (np.abs(v) > 1.5)
        flame = (u < -1) & (u > -5) & (np.abs(v) <= 1.6 + u * 0.3)
        p.a[flame, :3] = hx('#ffb040')
        p.a[flame & (u > -2.6) & (np.abs(v) < 0.8), :3] = hx('#fff07a')
        p.a[flame, 3] = 255
        paint(p, fins, '#5a5a6a')
        paint(p, body, '#f4f4f0')
        p.a[body & (u > 6), :3] = hx('#e84a3a')  # nose cone
        p.a[(np.hypot(u - 3.2, v) < 1.1), :3] = hx('#5ab8f0')  # porthole
    return _poster(c, key, draw)


def poster_candles(c, key):
    def draw(p, c, key):
        p.rect(5, 6, 18, 23, '#0e1620')  # chart panel on the poster colour
        p.rect(5, 6, 18, 6, '#26303e')
        for y in (10, 14, 18):
            for x in range(6, 18, 2):
                p.px(x, y, '#1e2a38')
        for k, x in enumerate(range(6, 18, 2)):
            red = k == 2
            bot = 21 - k * 2 + (2 if red else 0)
            top = bot - (3 if not red else 2)
            col = '#ff4a5a' if red else '#2ee88a'
            p.rect(x, max(7, top - 1), x, bot + 1, shift(hx(col), -0.35))
            p.rect(x, max(7, top), x, bot, col)
        p.px(18, 7, '#2ee88a')
        p.px(17, 8, '#2ee88a')
        p.px(18, 8, '#2ee88a')
    return _poster(c, key, draw)


def wall_shelf(c, key):
    p = Pix(40, 18)
    r = ramp(c)
    for x in (5, 33):  # brackets
        p.rect(x, 13, x + 1, 16, IRON)
        p.line(x, 16, x + 3, 13, IRON)
    pell(p, 6, 9, 3.5, 2.6, '#f0c8b0')  # a scallop shell
    for k in range(-2, 3):
        p.line(6, 11, 6 + k * 1.4, 7, '#d8a090')
    p.box(11, 3, 15, 11, GLASS)  # a jar of sand
    p.rect(12, 7, 14, 10, '#e8d8a0')
    p.rect(11, 2, 15, 2, '#c8a060')
    p.box(19, 7, 23, 11, '#c86a48')  # a tiny plant
    pell(p, 21, 5, 3, 2.5, '#4a8a3a')
    p.px(20, 4, '#7ac85a')
    p.box(26, 2, 28, 11, '#3a6aa8')  # books
    p.box(29, 3, 31, 11, '#b84a3a')
    for i in range(9):
        p.rect(32 + i // 3, 11 - i, 34 + i // 3, 11 - i, '#d8b050')
    topbox(p, 0, 11, 39, 14, c, top=2)
    return p.outline()


def wall_clock(c, key):
    p = Pix(16, 16)
    pell(p, 8, 8, 7.5, 7.5, c)
    face = '#fbfaf2' if key != 'cream' else '#fffdf8'
    pell(p, 8, 8, 5.5, 5.5, face, shade=False)
    for x, y in ((7, 3), (8, 3), (12, 7), (12, 8), (7, 12), (8, 12), (3, 7), (3, 8)):
        p.px(x, y, '#6a6a78')
    p.rect(7, 5, 7, 8, INK)  # hands
    p.rect(7, 8, 10, 8, INK)
    p.px(8, 9, '#c83a3a')
    p.px(9, 10, '#c83a3a')
    if key in ('brass',):
        metal_shine(p, emask(p, 8, 8, 7.5, 7.5) & ~emask(p, 8, 8, 5.5, 5.5), c)
    p.px(4, 2, ramp(c)[5])
    p.px(3, 3, ramp(c)[5])
    return p.outline()


def surfboard(c, key):
    p = Pix(16, 72)
    xx, yy = grid(p)
    t = (yy - 36) / 35
    hw = 6.6 * np.sqrt(np.clip(1 - np.abs(t) ** 2.2, 0, 1)) * np.where(t < 0, 1 - 0.25 * (-t) ** 3, 1)
    m = np.abs(xx - 8) <= hw
    paint(p, m, c)
    r = ramp(c)
    p.a[m & (np.abs(xx - 8) < 0.6), :3] = r[2]  # stringer
    band = m & (yy > 44) & (yy < 50)
    p.a[band, :3] = hx('#f8f6ee')
    p.a[m & (yy > 46) & (yy < 48), :3] = hx(INK) if key != 'gradient' else hx('#f8f6ee')
    p.a[m & (yy > 18) & (yy < 22) & (np.abs(xx - 8) < 2.5), :3] = r[4]
    hl = m & (xx < 8 - hw + 2.2) & (xx > 8 - hw + 1) & (yy > 8) & (yy < 60)
    p.a[hl, :3] = r[5]
    p.outline()
    for y in (22, 54):  # wall pegs
        p.rect(1, y, 2, y + 1, DARKWOOD)
        p.rect(13, y, 14, y + 1, DARKWOOD)
    return p


def trophy_fish(c, key):
    p = Pix(36, 18)
    wood = '#6e4426'
    pell(p, 18, 9, 17, 8, wood)
    pell(p, 18, 9, 15, 6.5, ramp(wood)[2], shade=False)
    pell(p, 17, 8, 14, 5.5, wood, shade=False)
    # the fish, leaping left to right
    body = emask(p, 15, 8.5, 10, 4)
    xx, yy = grid(p)
    tail = (xx > 24) & (xx < 31) & (np.abs(yy - 8.5) < (xx - 23) * 0.9)
    fin = (xx > 12) & (xx < 19) & (yy > 3) & (yy < 5.5) & (yy > 5.5 - (xx - 12) * 0.5)
    paint(p, body | tail | fin, c)
    r = ramp(c)
    p.a[body & (yy > 9.5) & (yy < 11), :3] = r[2]
    for x in range(9, 23, 3):
        p.px(x, 7 + (x % 2), r[2])
    p.rect(9, 6, 21, 6, r[5])
    p.px(10, 5, '#ffffff')
    p.px(16, 6, '#ffffff')
    p.px(8, 7, INK)  # eye
    p.px(6, 9, r[1])  # mouth
    p.px(5, 9, r[1])
    p.box(14, 13, 21, 15, BRASS)  # name plate
    return p.outline()


def mirror_round(c, key):
    p = Pix(20, 24)
    pell(p, 10, 12, 9.5, 11.5, c)
    if key == 'brass':
        metal_shine(p, emask(p, 10, 12, 9.5, 11.5), c)
    pell(p, 10, 12, 7, 9, '#b8d8e4', shade=False)
    xx, yy = grid(p)
    gl = emask(p, 10, 12, 7, 9)
    p.a[gl & (yy > 15), :3] = hx('#98bccc')
    for off, w in ((0, 1.2), (5, 0.7)):
        band = gl & (np.abs((xx + yy) - (16 + off)) < w)
        p.a[band, :3] = hx('#eef8fc')
    p.px(10, 0, IRON)
    return p.outline()


ITEMS = {
    'sofa': sofa, 'armchair': armchair, 'beanbag': beanbag, 'coffee_table': coffee_table, 'side_table': side_table,
    'tv_retro': tv_retro, 'radio': radio, 'bookcase_tall': bookcase_tall, 'rug_round': rug_round,
    'rug_stripe': rug_stripe, 'double_bed': double_bed, 'bunk_bed': bunk_bed, 'wardrobe': wardrobe,
    'dresser': dresser, 'nightstand': nightstand, 'kitchen_counter': kitchen_counter, 'kitchen_sink': kitchen_sink,
    'fridge': fridge, 'oven_retro': oven_retro, 'dining_table': dining_table, 'dining_chair': dining_chair,
    'round_table': round_table, 'bar_stool': bar_stool, 'bathtub': bathtub, 'toilet': toilet, 'shower': shower,
    'basin': basin, 'floor_lamp': floor_lamp, 'table_lamp': table_lamp, 'lava_lamp': lava_lamp,
    'string_lights': string_lights, 'neon_fish': neon_fish, 'neon_gm': neon_gm, 'neon_heart': neon_heart,
    'jukebox': jukebox, 'arcade': arcade, 'piano': piano, 'guitar_stand': guitar_stand, 'pool_table': pool_table,
    'fish_bowl': fish_bowl, 'cat_bed': cat_bed, 'gaming_desk': gaming_desk, 'potted_palm': potted_palm,
    'cactus': cactus, 'flower_vase': flower_vase, 'bonsai': bonsai, 'monstera': monstera, 'curtains': curtains,
    'poster_wave': poster_wave, 'poster_gull': poster_gull, 'poster_moon': poster_moon,
    'poster_candles': poster_candles, 'wall_shelf': wall_shelf, 'wall_clock': wall_clock, 'surfboard': surfboard,
    'trophy_fish': trophy_fish, 'mirror_round': mirror_round,
}


def render(base, key, colours):
    """Draw one sprite. Gradient pieces are drawn twice, in purple and in mint, and blended
    diagonally, so only the parts painted in the piece's colour pick up the gradient."""
    fn = ITEMS[base]
    if key != 'gradient':
        return fn(colours[key], key).a
    a = fn(GRAD[0], key).a.astype(float)
    b = fn(GRAD[1], key).a.astype(float)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    t = (xx / max(1, w - 1)) * 0.55 + (yy / max(1, h - 1)) * 0.45
    t = np.round(t * 5) / 5
    out = a + (b - a) * t[..., None]
    return np.clip(np.round(out), 0, 255).astype(np.uint8)


# ===================================================================== tiling textures

S = 64


def wrect(p, x0, y0, x1, y1, c):
    """A rectangle that wraps round the tile edges."""
    if x1 < x0 or y1 < y0:
        return
    ys = np.arange(y0, y1 + 1) % S
    xs = np.arange(x0, x1 + 1) % S
    p.a[np.ix_(ys, xs, [0, 1, 2])] = np.array(hx(c) if isinstance(c, str) else c, np.uint8)
    p.a[np.ix_(ys, xs, [3])] = 255


def wbox(p, x0, y0, x1, y1, c):
    r = ramp(c)
    wrect(p, x0, y0, x1, y1, r[3])
    wrect(p, x0, y0, x1, y0, r[4])
    wrect(p, x0, y0, x0, y1, r[4])
    wrect(p, x0, y1, x1, y1, r[1])
    wrect(p, x1, y0, x1, y1, r[2])


def wpx(p, x, y, c):
    p.px(int(x) % S, int(y) % S, c)


def pnoise(seed, cells=8):
    """Smooth value noise that tiles over the 64 px texture."""
    g = hashmap(cells, cells, seed, 1)
    t = np.arange(S) / S * cells
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    fx, fy = f[None, :], f[:, None]
    a = g[np.ix_(i0, i0)]
    b = g[np.ix_(i0, i1)]
    c = g[np.ix_(i1, i0)]
    d = g[np.ix_(i1, i1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(seed):
    return pnoise(seed, 4) * 0.5 + pnoise(seed + 1, 8) * 0.3 + pnoise(seed + 2, 16) * 0.2


def tone_map(p, base, v, amount):
    """Fill with base, brightened or darkened by v in [-1, 1] * amount (HSV value)."""
    b = np.array(hx(base) if isinstance(base, str) else base, float)
    out = b[None, None, :] * (1 + v[..., None] * amount)
    p.a[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
    p.a[..., 3] = 255


def wall_base(key, colours):
    c = hx(colours[key])
    if key == 'cream':
        return c
    if key == 'charcoal':
        return mix(c, '#e8dcc0', 0.12)
    return mix(c, '#efe4cc', 0.32)


def wall_tex(pattern, key, colours):
    base = wall_base(key, colours)
    p = Pix(S, S)
    lo = shift(base, -0.06)
    lo2 = shift(base, -0.11)
    hi = shift(base, 0.07, -0.12) if key != 'charcoal' else shift(base, 0.22, -0.1)
    seed = 100 + sum(map(ord, pattern + key))
    tone_map(p, base, (fbm(seed) - 0.5), 0.05)
    n = hashmap(S, S, seed, 1)
    if pattern == 'plain':
        for y in range(S):
            for x in range(S):
                if n[y, x] > 0.93:
                    p.px(x, y, lo)
                elif n[y, x] < 0.04:
                    p.px(x, y, hi)
    elif pattern == 'stripes':
        for x0 in range(0, S, 16):
            wrect(p, x0 + 4, 0, x0 + 9, S - 1, lo)
            wrect(p, x0 + 13, 0, x0 + 13, S - 1, hi)
    elif pattern == 'flowers':
        petal = hi
        mid = mix(base, '#f0c050', 0.5)
        leaf = mix(lo2, '#5a8a4a', 0.35)
        for gy in range(0, S, 16):
            for gx in range(0, S, 16):
                cx = gx + 8 + (8 if (gy // 16) % 2 else 0)
                cy = gy + 8
                for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                    wpx(p, cx + dx, cy + dy, petal)
                wpx(p, cx, cy, mid)
                wpx(p, cx + 3, cy + 3, leaf)
                wpx(p, cx + 4, cy + 3, leaf)
                wpx(p, cx - 3, cy + 4, leaf)
    elif pattern == 'checks':
        for k in range(0, S, 16):
            wrect(p, k, 0, k + 7, S - 1, lo)
            wrect(p, 0, k, S - 1, k + 7, lo)
        for ky in range(0, S, 16):
            for kx in range(0, S, 16):
                wrect(p, kx, ky, kx + 7, ky + 7, lo2)
        for k in range(0, S, 4):  # woven texture
            for j in range(0, S, 2):
                x = k + (j // 2) % 2
                wpx(p, x, j, shift(tuple(p.a[j % S, x % S, :3]), -0.025))
    elif pattern == 'dots':
        for gy in range(0, S, 16):
            for gx in range(0, S, 16):
                for cx, cy in ((gx + 4, gy + 4), (gx + 12, gy + 12)):
                    wrect(p, cx - 1, cy - 2, cx + 1, cy + 2, hi)
                    wrect(p, cx - 2, cy - 1, cx + 2, cy + 1, hi)
                    wpx(p, cx + 2, cy + 1, lo)
                    wpx(p, cx + 1, cy + 2, lo)
    elif pattern == 'waves':
        for y0 in range(0, S, 16):
            for x in range(S):
                y = y0 + 8 + 3 * np.sin(2 * np.pi * x / 32)
                wpx(p, x, round(y), hi)
                wpx(p, x, round(y) + 1, lo)
                y2 = y0 + 8 + 3 * np.sin(2 * np.pi * (x + 16) / 32) + 8
                if x % 4 == 0:
                    wpx(p, x, round(y2), lo)
    elif pattern == 'brick':
        brick = shift(base, -0.04, 0.1)
        mortar = mix(base, '#f4ecdc', 0.55) if key != 'charcoal' else mix(base, '#9a9890', 0.5)
        p.rect(0, 0, S - 1, S - 1, mortar)
        for row in range(8):
            off = 8 if row % 2 else 0
            for bx in range(0, S, 16):
                v = (hashmap(8, 8, seed + 3, 1)[row, bx // 16] - 0.5) * 0.14
                wbox(p, bx + off, row * 8, bx + off + 14, row * 8 + 6, shift(brick, v))
        for y in range(S):
            for x in range(S):
                if n[y, x] > 0.95 and tuple(p.a[y, x, :3]) != hx('#000000'):
                    p.px(x, y, shift(tuple(p.a[y, x, :3]), -0.08))
    elif pattern == 'panels':
        wood = shift(base, -0.02, 0.05)
        r = ramp(wood)
        for col in range(8):
            x0 = col * 8
            tone = r[3] if col % 2 else shift(wood, 0.03)
            wrect(p, x0, 0, x0 + 7, S - 1, tone)
            wrect(p, x0, 0, x0, S - 1, r[4])
            wrect(p, x0 + 7, 0, x0 + 7, S - 1, r[1])
            for y in range(S):
                if n[y, x0 + 3] > 0.87:
                    wpx(p, x0 + 3, y, r[2])
                if n[y, x0 + 5] > 0.93:
                    wpx(p, x0 + 5, y, r[2])
    return p


def floor_tex(kind, key, colours):
    c = hx(colours[key])
    seed = 300 + sum(map(ord, kind + key))
    if kind == 'planks':
        return floor_wood(colours[key], seed)
    p = Pix(S, S)
    n = hashmap(S, S, seed, 1)
    if kind == 'tiles':
        grout = '#d8d4cc' if key not in ('cream',) else '#a8a090'
        if key == 'charcoal':
            grout = '#6a6a70'
        p.rect(0, 0, S - 1, S - 1, grout)
        tv = hashmap(4, 4, seed + 1, 1)
        for ty in range(4):
            for tx in range(4):
                col = shift(c, (tv[ty, tx] - 0.5) * 0.08)
                r = ramp(col)
                x0, y0 = tx * 16, ty * 16
                p.box(x0, y0, x0 + 14, y0 + 14, col, edge=False)
                p.px(x0 + 2, y0 + 2, r[5])
                p.px(x0 + 3, y0 + 2, r[4])
                p.px(x0 + 2, y0 + 3, r[4])
    elif kind == 'carpet':
        v = (fbm(seed) - 0.5) * 1.2 + (n - 0.5) * 0.5
        tone_map(p, c, v, 0.12)
        r = ramp(c)
        for y in range(S):
            for x in range(S):
                if n[y, x] > 0.94:
                    p.px(x, y, r[4])
                elif n[y, x] < 0.05:
                    p.px(x, y, r[2])
    elif kind == 'stone':
        r = ramp(c)
        p.rect(0, 0, S - 1, S - 1, r[1])
        # big flagstones in three courses of different heights, corners rounded off
        rows = [(0, 21, 5, [24, 18, 22]), (22, 41, 17, [20, 26, 18]), (42, 63, 30, [16, 28, 20])]
        tv = hashmap(4, 3, seed + 5, 1)
        for i, (y0, y1, x, widths) in enumerate(rows):
            for j, w in enumerate(widths):
                col = shift(c, (tv[i, j] - 0.5) * 0.2)
                wbox(p, x + 1, y0 + 1, x + w - 1, y1, col)
                for cx, cy in ((x + 1, y0 + 1), (x + w - 1, y0 + 1), (x + 1, y1), (x + w - 1, y1)):
                    wpx(p, cx, cy, r[1])
                x += w
        for y in range(S):
            for x in range(S):
                if n[y, x] > 0.9 and p.a[y, x, 0] != r[1][0]:
                    p.px(x, y, shift(tuple(p.a[y, x, :3]), -0.08))
                elif n[y, x] < 0.04 and p.a[y, x, 0] != r[1][0]:
                    p.px(x, y, shift(tuple(p.a[y, x, :3]), 0.08))
    elif kind == 'marble':
        f = fbm(seed)
        warp = pnoise(seed + 3, 4) * 0.7 + pnoise(seed + 4, 8) * 0.3
        warp2 = pnoise(seed + 8, 4) * 0.7 + pnoise(seed + 9, 8) * 0.3
        yy, xx = np.mgrid[0:S, 0:S]
        s = np.abs(np.sin(2 * np.pi * (xx + yy * 2) / S + warp * 4.5))
        s2 = np.abs(np.sin(2 * np.pi * (2 * xx - yy) / S + warp2 * 4))
        v = (f - 0.5) * 0.6
        tone_map(p, c, v, 0.08)
        vein = shift(c, -0.3) if key != 'black' else shift(mix(c, '#e8e4dc', 0.5), 0)
        vein2 = shift(c, -0.15) if key != 'black' else mix(c, '#c8c4bc', 0.25)
        if key == 'pink':
            vein = shift(c, -0.25, 0.1)
        p.a[s2 < 0.1, :3] = vein2
        p.a[s < 0.09, :3] = vein
        r = ramp(c)
        wrect(p, 0, 0, S - 1, 0, r[2])  # slab seams every 32 px
        wrect(p, 0, 32, S - 1, 32, r[2])
        wrect(p, 0, 0, 0, S - 1, r[2])
        wrect(p, 32, 0, 32, S - 1, r[2])
        for k in (1, 33):
            wrect(p, k, 1, k + 30, 1, r[4])
    elif kind == 'chequer':
        cream = '#ece0c4'
        for ty in range(4):
            for tx in range(4):
                col = c if (tx + ty) % 2 == 0 else hx(cream)
                r = ramp(col)
                x0, y0 = tx * 16, ty * 16
                p.rect(x0, y0, x0 + 15, y0 + 15, r[3])
                p.rect(x0, y0, x0 + 15, y0, r[4])
                p.rect(x0, y0, x0, y0 + 15, r[4])
                p.rect(x0 + 3, y0 + 2, x0 + 5, y0 + 2, r[5])  # polish
                p.px(x0 + 2, y0 + 3, r[5])
    return p


# ===================================================================== contact sheets

def sprite_sheet(cat, sprites, path):
    font_w = 150
    rows = []
    for it in cat['items']:
        ims = [sprites[(it['base'], k)] for k in it['colours']]
        rows.append((it['base'], ims))
    width = max(font_w + sum(im.shape[1] * 2 + 8 for im in ims) for _, ims in rows) + 8
    height = sum(max(im.shape[0] for im in ims) * 2 + 12 for _, ims in rows) + 8
    sheet = Image.new('RGBA', (width, height), (128, 128, 128, 255))
    d = ImageDraw.Draw(sheet)
    y = 6
    for base, ims in rows:
        h = max(im.shape[0] for im in ims) * 2
        d.text((6, y + 2), base, fill=(20, 20, 30, 255))
        x = font_w
        for im in ims:
            img = Image.fromarray(im, 'RGBA')
            img = img.resize((im.shape[1] * 2, im.shape[0] * 2), Image.NEAREST)
            sheet.alpha_composite(img, (x, y + h - img.height))
            x += img.width + 8
        y += h + 12
    sheet.save(path)


def texture_sheet(textures, path):
    cols = 10
    cell = 128 + 6
    keys = list(textures)
    rows = (len(keys) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cell + 6, rows * (cell + 12) + 6), (128, 128, 128, 255))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(keys):
        img = Image.fromarray(textures[k], 'RGBA')
        tile = Image.new('RGBA', (128, 128))
        for oy in (0, 64):
            for ox in (0, 64):
                tile.paste(img, (ox, oy))
        x, y = 6 + (i % cols) * cell, 6 + (i // cols) * (cell + 12)
        sheet.alpha_composite(tile, (x, y + 12))
        d.text((x, y), k.replace('wall_', 'w_').replace('floor_', 'f_'), fill=(20, 20, 30, 255))
    sheet.save(path)


# ===================================================================== main

def main():
    sheets = SHEETS
    if '--sheets' in sys.argv:
        sheets = sys.argv[sys.argv.index('--sheets') + 1]
    with open(CATALOG) as f:
        cat = json.load(f)
    colours = cat['colours']
    sprites = {}
    for it in cat['items']:
        base = it['base']
        if base not in ITEMS:
            raise SystemExit('no drawing for %s' % base)
        for key in it['colours']:
            a = render(base, key, colours)
            path = os.path.join(OUT, SPRITE_DIR, '%s_%s.png' % (base, key))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            Image.fromarray(a, 'RGBA').save(path)
            sprites[(base, key)] = a
    textures = {}
    for w in cat['walls']:
        for key in w['colours']:
            name = 'wall_%s_%s' % (w['pattern'], key)
            textures[name] = wall_tex(w['pattern'], key, colours).save('%s/%s.png' % (TEX_DIR, name))
    for fl in cat['floors']:
        for key in fl['colours']:
            name = 'floor_%s_%s' % (fl['kind'], key)
            textures[name] = floor_tex(fl['kind'], key, colours).save('%s/%s.png' % (TEX_DIR, name))

    # check that everything the catalogue implies exists
    want_s = ['%s/%s/%s_%s.png' % (OUT, SPRITE_DIR, it['base'], k) for it in cat['items'] for k in it['colours']]
    want_t = ['%s/%s/wall_%s_%s.png' % (OUT, TEX_DIR, w['pattern'], k) for w in cat['walls'] for k in w['colours']]
    want_t += ['%s/%s/floor_%s_%s.png' % (OUT, TEX_DIR, fl['kind'], k) for fl in cat['floors'] for k in fl['colours']]
    miss = [p for p in want_s + want_t if not os.path.exists(p)]
    bad = [p for p in want_t if os.path.exists(p) and Image.open(p).size != (64, 64)]
    print('home art: %d/%d sprites, %d/%d textures, %d missing, %d wrong size'
          % (sum(os.path.exists(p) for p in want_s), len(want_s), sum(os.path.exists(p) for p in want_t),
             len(want_t), len(miss), len(bad)))
    for m in miss + bad:
        print('  problem:', m)
    if os.path.isdir(sheets):
        sprite_sheet(cat, sprites, os.path.join(sheets, 'home_sprites.png'))
        texture_sheet(textures, os.path.join(sheets, 'home_textures.png'))
        print('contact sheets in', sheets)
    if miss or bad:
        sys.exit(1)


if __name__ == '__main__':
    main()
