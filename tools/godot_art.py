"""Gullhaven HD-2D art: higher-resolution pixel sprites for the Godot build.
Usage: python3 tools/godot_art.py [characters|cats|plants|fish|all] [--preview]

Everything is drawn in code, in the same spirit as the web game's art, but at roughly
twice the detail: 32x48 people with five poses in four directions, 32x32 cats, big
layered trees and plants, and a 72x48 portrait of every fish in the catalogue (built from
the catalogue's own shape, colour and pattern data). Shading uses hue-shifted ramps,
selective outlines and ordered dithering so it reads as hand-made pixel art.
Writes into godot/art/ (chars2, cats2, plants, fish2). --preview also writes contact
sheets into the scratchpad for checking."""
import colorsys
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'art')
PREVIEW = os.environ.get('ART_PREVIEW', '/tmp/claude-0/art_preview')
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


# --------------------------------------------------------------------------- colour

def hx(c):
    c = c.lstrip('#')
    if len(c) == 3:
        c = ''.join(ch * 2 for ch in c)
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def shift(rgb, dv=0.0, ds=0.0, dh=0.0):
    r, g, b = [v / 255 for v in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h + dh) % 1.0
    s = min(1.0, max(0.0, s * (1 + ds)))
    v = min(1.0, max(0.0, v * (1 + dv)))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def hue_toward(rgb, target_h, amount):
    r, g, b = [v / 255 for v in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    d = ((target_h - h + 0.5) % 1.0) - 0.5
    h = (h + d * amount) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def ramp(base):
    """outline, dark, mid, base, light, highlight: shadows lean blue, lights lean warm."""
    b = hx(base) if isinstance(base, str) else base
    dark = hue_toward(shift(b, -0.3, 0.15), 0.68, 0.12)
    mid = hue_toward(shift(b, -0.14, 0.06), 0.68, 0.06)
    light = hue_toward(shift(b, 0.14, -0.12), 0.12, 0.06)
    hi = hue_toward(shift(b, 0.3, -0.3), 0.12, 0.1)
    out = hue_toward(shift(b, -0.6, 0.25), 0.72, 0.2)
    return [out, dark, mid, b, light, hi]


# --------------------------------------------------------------------------- canvas

class Canvas:
    """Parts are painted back to front into a colour image plus a part-index map, so the
    outline and contact-shadow passes know which part every pixel belongs to."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.uint8)
        self.part = np.full((h, w), -1, np.int32)
        self.ramps = []
        self.flags = []

    def mask(self):
        return np.zeros((self.h, self.w), bool)

    def paint(self, m, color, shade=True, line=False, light=(-1, -1), soft=False):
        """Paint mask m as one part. shade adds rim light and shadow, line darkens the
        part's own edge where it overlaps other parts."""
        m = m & np.ones_like(m)
        if not m.any():
            return
        r = ramp(color)
        idx = len(self.ramps)
        self.ramps.append(r)
        self.flags.append(line)
        tone = np.full(m.shape, 3, np.int32)
        if shade:
            lx, ly = light
            def out(dx, dy):
                sh = np.roll(np.roll(m, dy, 0), dx, 1)
                return m & ~sh
            # edges facing the light get a highlight, the far side a shadow band
            lit = out(-lx, -ly)
            far1 = out(lx, ly)
            far2 = m & ~np.roll(np.roll(m, ly * 2, 0), lx * 2, 1)
            tone[far2] = 2
            tone[far1] = 1 if not soft else 2
            tone[lit & ~far1] = 4
        self.rgb[m] = np.array([r[t] for t in range(6)])[tone[m]]
        self.part[m] = idx
        if line:
            # where this part sits on top of an earlier part, darken its rim
            below = self.part.copy()
            edge = np.zeros_like(m)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = np.roll(np.roll(m, dy, 0), dx, 1)
                edge |= m & ~nb
            self.rgb[edge] = r[1]
        return idx

    def dots(self, pts, color):
        for x, y in pts:
            if 0 <= x < self.w and 0 <= y < self.h:
                self.rgb[y, x] = hx(color) if isinstance(color, str) else color
                if self.part[y, x] < 0:
                    self.part[y, x] = len(self.ramps) - 1 if self.ramps else 0

    def finish(self, outline=True):
        img = np.zeros((self.h, self.w, 4), np.uint8)
        filled = self.part >= 0
        img[..., :3] = self.rgb
        img[..., 3] = np.where(filled, 255, 0)
        if outline:
            # selective outline: each empty pixel touching the sprite takes the darkest
            # tone of the part it touches
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                src = np.roll(np.roll(self.part, dy, 0), dx, 1)
                ok = (~filled) & (src >= 0) & (img[..., 3] == 0)
                if dy == 1:
                    ok[0, :] = False
                if dy == -1:
                    ok[-1, :] = False
                if dx == 1:
                    ok[:, 0] = False
                if dx == -1:
                    ok[:, -1] = False
                ys, xs = np.nonzero(ok)
                for y, x in zip(ys, xs):
                    img[y, x, :3] = self.ramps[src[y, x]][0]
                    img[y, x, 3] = 255
        return img


def ellipse(w, h, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def rect(w, h, x0, y0, x1, y1):
    m = np.zeros((h, w), bool)
    x0, x1 = max(0, int(x0)), min(w - 1, int(x1))
    y0, y1 = max(0, int(y0)), min(h - 1, int(y1))
    if x1 >= x0 and y1 >= y0:
        m[y0:y1 + 1, x0:x1 + 1] = True
    return m


def poly(w, h, pts):
    im = Image.new('1', (w, h), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=1)
    return np.array(im, bool)


def line_mask(w, h, pts, width=1):
    im = Image.new('1', (w, h), 0)
    ImageDraw.Draw(im).line([(float(x), float(y)) for x, y in pts], fill=1, width=max(1, int(round(width))))
    return np.array(im, bool)


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(img, 'RGBA').save(path)


# ====================================================================== characters

FW, FH = 32, 48
SKIN = {'fair': '#f6d2b4', 'rose': '#f0bea0', 'tan': '#d9a07a', 'brown': '#a8714e', 'deep': '#7a4e36'}

LOOKS = {
    # the fisher: knit beanie, mustard rain jacket, navy trousers
    'player': dict(skin='rose', hair='#6a4028', style='short', hat='beanie', hatc='#2f8a8a', shirt='#e8b23a',
                   top='coat', inner='#f4efe2', pants='#2e3f6e', shoes='#5a3a26'),
    'hale': dict(skin='fair', hair='#c8c4bc', style='bald', beard='full', shirt='#5f8f5a', top='apron', apron='#3f6a44',
                 pants='#4a4a5a', shoes='#3a2a22', glasses=True),
    'marlo': dict(skin='tan', hair='#ece8e0', style='short', beard='full', hat='captain', hatc='#24305a', shirt='#2a3a6a',
                  top='coat', inner='#e8e4d8', pants='#3a3a48', shoes='#2a2020'),
    'pip': dict(skin='fair', hair='#d8782a', style='short', hat='cap', hatc='#d8443a', shirt='#f4f0e8', stripes='#3f6aaa',
                pants='#5a7aa8', shoes='#e8e8e8', kid=True, freckles=True),
    'juniper': dict(skin='brown', hair='#2a1a14', style='bun', shirt='#e88aa0', top='apron', apron='#f8f4ec',
                    pants='#e88aa0', shoes='#6a3a2a', dress=True),
    'fishmonger': dict(skin='tan', hair='#3a2a20', style='short', hat='cap', hatc='#3f6a8a', shirt='#d8d4cc', top='apron',
                       apron='#4a8aa0', pants='#3a3a48', shoes='#2a3a3a', beard='stubble'),
    'boatwright': dict(skin='deep', hair='#1a1414', style='short', hat='beanie', hatc='#c8443a', shirt='#e8dcc0',
                       top='overalls', overall='#4a6a9a', pants='#4a6a9a', shoes='#4a3020'),
    'carpenter': dict(skin='rose', hair='#a8642a', style='bob', hat='straw', hatc='#e0c070', shirt='#c84a3a', stripes='#8a2a2a',
                      pants='#6a5a3a', shoes='#4a3020', checks=True),
    'keeper': dict(skin='fair', hair='#8a3a2a', style='long', shirt='#4a3a6a', top='apron', apron='#e8dcc8',
                   pants='#3a2a3a', shoes='#3a2020', dress=True),
    'curator': dict(skin='brown', hair='#e8e4dc', style='short', shirt='#f0ece0', top='vest', vest='#6a3a4a',
                    pants='#3a3a4a', shoes='#2a2020', glasses=True, beard='mustache'),
    'ranger': dict(skin='tan', hair='#5a3a20', style='ponytail', hat='ranger', hatc='#8a6a3a', shirt='#5a7a4a', top='vest',
                   vest='#3f5a3a', pants='#5a5a3a', shoes='#4a3020'),
    'islander': dict(skin='deep', hair='#1a1414', style='long', shirt='#f0a040', floral='#e85a7a', pants='#e8dcc0',
                     shoes='#c89a5a', dress=True),
    'salvager': dict(skin='tan', hair='#2a2020', style='short', hat='bandana', hatc='#3a3a4a', shirt='#6a6a5a', top='coat',
                     inner='#a89a7a', pants='#3a3a30', shoes='#2a2020', beard='short'),
    'villager_a': dict(skin='fair', hair='#e8c070', style='long', shirt='#7aa0d8', pants='#7aa0d8', shoes='#5a3a2a', dress=True),
    'villager_b': dict(skin='brown', hair='#2a1a14', style='short', shirt='#a8c86a', pants='#5a4a3a', shoes='#3a2a20',
                       beard='short'),
    'villager_c': dict(skin='rose', hair='#5a2a1a', style='ponytail', hat='straw', hatc='#e8d080', shirt='#f4f0e8',
                       stripes='#d85a5a', pants='#3a5a8a', shoes='#e8e8e8'),
    'villager_d': dict(skin='deep', hair='#b8b4ac', style='bun', shirt='#c87ac8', top='vest', vest='#6a4a8a', pants='#4a3a5a',
                       shoes='#2a2020', glasses=True),
    'kid_b': dict(skin='tan', hair='#2a1a14', style='bun', shirt='#f0d050', pants='#d8604a', shoes='#f0f0f0', kid=True,
                  dress=True),
}


def draw_person(look, direction, pose):
    """direction: down, up, left. pose: stand, walk_a, walk_b, cast, cheer."""
    L = dict(look)
    c = Canvas(FW, FH)
    kid = L.get('kid', False)
    skin = SKIN[L['skin']]
    walk = pose in ('walk_a', 'walk_b')
    bob = -1 if walk else 0
    # kids are shorter: a lower head, a shorter body and shorter legs
    head_cy = 15.5 + bob + (6 if kid else 0)
    torso_y0, torso_y1 = (31 + bob, 38 + bob) if kid else (25 + bob, 35 + bob)
    leg_y0 = torso_y1
    ground = 45
    shirt = L['shirt']
    pants = L['pants']
    top = L.get('top', 'tee')
    side = direction == 'left'
    back = direction == 'up'

    def legs():
        if side:
            hip_x = 15
            if pose == 'walk_a':
                fronts, backs = (10, 13), (18, 21)
            elif pose == 'walk_b':
                fronts, backs = (18, 21), (10, 13)
            else:
                fronts, backs = (13, 16), (14, 17)
            for (fx0, fx1), shade in ((backs, -0.18), (fronts, 0.0)):
                col = shift(hx(pants), shade)
                m = poly(FW, FH, [(hip_x - 2, leg_y0), (hip_x + 2, leg_y0), (fx1 + 0.5, ground - 1), (fx0 - 0.5, ground - 1)])
                c.paint(m, col, line=True)
                c.paint(rect(FW, FH, fx0 - 2, ground - 1, fx1, ground), shift(hx(L['shoes']), shade), soft=True)
            return
        lift_l = 2 if pose == 'walk_b' else 0
        lift_r = 2 if pose == 'walk_a' else 0
        for x0, lift in ((11, lift_l), (17, lift_r)):
            m = rect(FW, FH, x0, leg_y0, x0 + 3, ground - 2 - lift)
            if L.get('dress'):
                m = rect(FW, FH, x0 + 1, leg_y0 + 3, x0 + 2, ground - 2 - lift)
                c.paint(m, skin, shade=False)
            else:
                c.paint(m, pants)
            c.paint(rect(FW, FH, x0 - 1, ground - 1 - lift, x0 + 4, ground - lift), L['shoes'], soft=True)

    def torso():
        if side:
            x0, x1 = 12, 19
        else:
            x0, x1 = 10, 21
        bottom = torso_y1 + (4 if L.get('dress') else 0) + (3 if top == 'coat' and not side else 0)
        m = rect(FW, FH, x0, torso_y0 + 1, x1, bottom) | rect(FW, FH, x0 + 1, torso_y0, x1 - 1, torso_y0)
        if L.get('dress') and not side:
            m |= poly(FW, FH, [(x0, torso_y1 - 2), (x1 + 1, torso_y1 - 2), (x1 + 3, bottom + 1), (x0 - 2, bottom + 1)])
        elif L.get('dress') and side:
            m |= poly(FW, FH, [(x0, torso_y1 - 2), (x1 + 1, torso_y1 - 2), (x1 + 2, bottom + 1), (x0 - 2, bottom + 1)])
        base = shirt if top != 'coat' else shirt
        c.paint(m, base, line=False)
        # patterns
        if L.get('stripes') and top not in ('coat',):
            ys = range(torso_y0 + 2, bottom + 1, 3)
            for y in ys:
                row = m & rect(FW, FH, 0, y, FW, y)
                c.rgb[row] = ramp(L['stripes'])[3]
        if L.get('checks'):
            yy, xx = np.mgrid[0:FH, 0:FW]
            chk = m & (((xx // 2) + (yy // 2)) % 2 == 0)
            c.rgb[chk] = ramp(L['stripes'])[2]
        if L.get('floral'):
            for (fx, fy) in ((12, 28), (18, 30), (14, 33), (20, 35), (11, 36)):
                if not side or 12 <= fx <= 19:
                    c.dots([(fx, fy + bob), (fx + 1, fy + bob), (fx, fy + 1 + bob)], ramp(L['floral'])[3])
        if top == 'coat' and not back:
            inner = rect(FW, FH, 14, torso_y0 + 1, 17, bottom) if not side else rect(FW, FH, 12, torso_y0 + 1, 13, bottom)
            c.paint(inner & m, L.get('inner', '#eeeeee'), shade=False)
            c.dots([(15 if not side else 14, torso_y0 + 4), (15 if not side else 14, torso_y0 + 7)], ramp(shirt)[1])
        if top == 'apron' and not back:
            ax0, ax1 = (11, 20) if not side else (11, 15)
            am = rect(FW, FH, ax0, torso_y0 + 3, ax1, torso_y1 + 4)
            c.paint(am, L['apron'], line=True)
            c.paint(rect(FW, FH, ax0 + 1, torso_y0, ax0 + 1, torso_y0 + 3) | (rect(FW, FH, ax1 - 1, torso_y0, ax1 - 1, torso_y0 + 3) if not side else c.mask()),
                    L['apron'], shade=False)
        if top == 'apron' and back:
            c.paint(rect(FW, FH, 11, torso_y0 + 5, 20, torso_y0 + 5) | rect(FW, FH, 15, torso_y0 + 5, 16, torso_y0 + 7), L['apron'], shade=False)
        if top == 'overalls':
            ox0, ox1 = (12, 19) if not side else (13, 17)
            om = rect(FW, FH, ox0, torso_y0 + 4, ox1, torso_y1)
            c.paint(om, L['overall'], line=True)
            for sx in ((13, 18) if not side else (15,)):
                c.paint(rect(FW, FH, sx, torso_y0, sx, torso_y0 + 4), L['overall'], shade=False)
            if not back:
                c.dots([(13, torso_y0 + 4), (18, torso_y0 + 4)] if not side else [(15, torso_y0 + 4)], '#e8d070')
        if top == 'vest':
            if not back:
                vm = (rect(FW, FH, 10, torso_y0, 13, torso_y1) | rect(FW, FH, 18, torso_y0, 21, torso_y1)) if not side else rect(FW, FH, 15, torso_y0, 19, torso_y1)
            else:
                vm = rect(FW, FH, 10, torso_y0, 21, torso_y1)
            c.paint(vm & m, L['vest'], line=True)
        if not back and not side and top in ('tee', 'vest'):
            c.dots([(15, torso_y0), (16, torso_y0)], ramp(skin)[2])  # collar gap

    def arm(x_sh, y_sh, hx_, hy_, near=True):
        sleeve = shirt if top != 'vest' else shirt
        col = sleeve if near else shift(hx(sleeve), -0.15)
        long_sleeve = top in ('coat',) or L.get('dress') and False
        m = line_mask(FW, FH, [(x_sh, y_sh), (hx_, hy_)], width=3)
        c.paint(m, col, line=True)
        if not long_sleeve:
            # forearm skin on the lower half
            mx, my = (x_sh + hx_) / 2, (y_sh + hy_) / 2
            fm = line_mask(FW, FH, [(mx, my), (hx_, hy_)], width=3)
            c.paint(fm & m, skin if near else shift(hx(skin), -0.15), shade=False)
        hand = ellipse(FW, FH, hx_ + 0.5, hy_ + 0.5, 1.7, 1.7)
        c.paint(hand, skin if near else shift(hx(skin), -0.15), soft=True)

    def arms(front):
        sy = torso_y0 + 2
        if side:
            if pose == 'cast':
                arm(15, sy, 8, sy + 1)
            elif pose == 'cheer':
                arm(15, sy, 14, sy - 12)
            else:
                hxp = {'walk_a': 11, 'walk_b': 19}.get(pose, 15)
                arm(15, sy, hxp, torso_y1 - 2)
            return
        if not front:
            return
        if pose == 'cast':
            arm(9, sy, 13, sy + 2)
            arm(22, sy, 18, sy + 2)
        elif pose == 'cheer':
            arm(9, sy, 6, sy - 12)
            arm(22, sy, 25, sy - 12)
        else:
            sw_l = {'walk_a': -1, 'walk_b': 1}.get(pose, 0)
            arm(8, sy, 8, torso_y1 - 1 + sw_l)
            arm(23, sy, 23, torso_y1 - 1 - sw_l)

    def head():
        if side:
            hm = ellipse(FW, FH, 15.5, head_cy, 7.2, 7.8)
            hm |= rect(FW, FH, 9, int(head_cy) + 2, 13, int(head_cy) + 5)  # jaw toward the face
        else:
            hm = ellipse(FW, FH, 16, head_cy, 7.6, 7.8)
        c.paint(hm, skin, soft=True)
        if not back:
            if side:
                c.paint(ellipse(FW, FH, 18, head_cy + 1.5, 1.4, 1.8), shift(hx(skin), -0.08), shade=False)
            else:
                c.paint(ellipse(FW, FH, 8.2, head_cy + 1.5, 1.2, 1.6) | ellipse(FW, FH, 23.8, head_cy + 1.5, 1.2, 1.6), skin, shade=False)
        return hm

    def face():
        ey = int(head_cy + 1)
        eye = '#2a2234'
        if side:
            c.dots([(10, ey), (10, ey + 1), (11, ey), (11, ey + 1)], eye)
            c.dots([(10, ey)], '#ffffff')
            c.dots([(8, ey + 2)], ramp(skin)[2])
            c.dots([(10, ey + 4)], ramp(skin)[1])
            if L.get('freckles'):
                c.dots([(12, ey + 2), (13, ey + 3)], ramp(skin)[1])
            else:
                c.dots([(12, ey + 2)], '#f0a0a0')
            if L.get('glasses'):
                c.dots([(9, ey - 1), (10, ey - 1), (11, ey - 1), (12, ey - 1), (12, ey), (13, ey), (14, ey), (15, ey), (16, ey)], '#8a6a5a')
            return
        for ex in (12, 19):
            c.dots([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1), (ex, ey + 2), (ex + 1, ey + 2)], eye)
            c.dots([(ex, ey)], '#ffffff')
        c.dots([(15, ey + 5), (16, ey + 5)], ramp(skin)[1])
        if L.get('freckles'):
            c.dots([(11, ey + 3), (13, ey + 4), (19, ey + 4), (21, ey + 3)], ramp(skin)[1])
        else:
            c.dots([(11, ey + 3), (21, ey + 3)], '#f2a2a2')
        if L.get('glasses'):
            for ex in (11, 18):
                c.dots([(ex + i, ey - 1) for i in range(4)] + [(ex, ey + j) for j in range(3)] + [(ex + 3, ey + j) for j in range(3)], '#8a6a5a')
            c.dots([(15, ey), (16, ey)], '#8a6a5a')

    def beard():
        b = L.get('beard')
        if not b or back:
            return
        hc = L['hair']
        ey = int(head_cy + 1)
        if side:
            if b in ('full', 'short'):
                m = ellipse(FW, FH, 13, head_cy + 5.5, 5 if b == 'full' else 4, 3.5 if b == 'full' else 2.5) & ~rect(FW, FH, 0, 0, FW, ey + 2)
                c.paint(m, hc, line=True)
            elif b == 'mustache':
                c.dots([(9, ey + 3), (10, ey + 3), (11, ey + 3)], ramp(hc)[2])
            elif b == 'stubble':
                c.dots([(10, ey + 5), (12, ey + 5), (11, ey + 6), (13, ey + 6)], ramp(skin)[1])
            return
        if b == 'full':
            m = ellipse(FW, FH, 16, head_cy + 5, 7, 4.5) & ~rect(FW, FH, 0, 0, FW, ey + 2)
            m &= ~rect(FW, FH, 14, ey + 4, 17, ey + 5)
            c.paint(m, hc, line=True)
            c.dots([(15, ey + 5), (16, ey + 5)], ramp(skin)[1])
        elif b == 'short':
            m = ellipse(FW, FH, 16, head_cy + 6, 5.5, 3) & ~rect(FW, FH, 0, 0, FW, ey + 3)
            c.paint(m, hc, line=True)
        elif b == 'mustache':
            c.paint(rect(FW, FH, 13, ey + 4, 18, ey + 4) | rect(FW, FH, 12, ey + 5, 13, ey + 5) | rect(FW, FH, 18, ey + 5, 19, ey + 5), hc, shade=False)
        elif b == 'stubble':
            c.dots([(12, ey + 6), (14, ey + 7), (16, ey + 7), (18, ey + 6), (20, ey + 5), (11, ey + 5)], ramp(skin)[1])

    def hair(front_layer):
        style = L.get('style', 'short')
        hc = L['hair']
        top_y = head_cy - 8
        if style == 'bald':
            if front_layer and not back:
                m = (rect(FW, FH, 8, int(head_cy) - 1, 9, int(head_cy) + 2) | rect(FW, FH, 22, int(head_cy) - 1, 23, int(head_cy) + 2)) if not side else rect(FW, FH, 18, int(head_cy) - 2, 21, int(head_cy) + 1)
                c.paint(m, hc, shade=False)
            elif front_layer and back:
                c.paint(rect(FW, FH, 9, int(head_cy) - 1, 22, int(head_cy) + 3), hc, shade=False)
            return
        if not front_layer:
            # long hair falls behind the shoulders
            if style == 'long':
                if side:
                    c.paint(poly(FW, FH, [(14, head_cy - 2), (23, head_cy - 2), (22, head_cy + 13), (15, head_cy + 13)]), hc, line=True)
                else:
                    c.paint(rect(FW, FH, 7, int(head_cy) - 2, 24, int(head_cy) + 12), hc, line=True)
            if style == 'ponytail' and (back or side):
                if side:
                    c.paint(ellipse(FW, FH, 23, head_cy + 3, 2.2, 5), hc, line=True)
                else:
                    c.paint(ellipse(FW, FH, 16, head_cy + 6, 2.3, 5), hc, line=True)
            return
        cap = ellipse(FW, FH, 16 if not side else 15.5, head_cy - 1.5, 8.2, 7.2)
        if back:
            m = cap | rect(FW, FH, 8, int(head_cy) - 2, 23, int(head_cy) + 4)
            if style in ('bob', 'long'):
                m |= rect(FW, FH, 7, int(head_cy), 24, int(head_cy) + (12 if style == 'long' else 6))
            c.paint(m, hc, line=True)
            if style == 'bun':
                c.paint(ellipse(FW, FH, 16, top_y - 0.5, 3.3, 3), hc, line=True)
            # a few strands of shine
            c.dots([(12, int(top_y) + 3), (13, int(top_y) + 2), (17, int(top_y) + 2)], ramp(hc)[4])
            return
        if side:
            # top of the head, the back of the head and a thin sideburn in front of the ear
            m = cap & ~rect(FW, FH, 0, int(head_cy) - 1, FW, FH)
            m |= rect(FW, FH, 17, int(head_cy) - 1, 23, int(head_cy) + (2 if style != 'bob' else 6)) & cap
            m |= rect(FW, FH, 15, int(head_cy) - 1, 16, int(head_cy) + 1)
            if style == 'bob':
                m |= rect(FW, FH, 17, int(head_cy) + 2, 22, int(head_cy) + 6)
            m |= poly(FW, FH, [(9, top_y + 3), (13, top_y + 1), (12, top_y + 6), (10, top_y + 7)])  # fringe
            if style == 'spiky':
                m |= poly(FW, FH, [(11, top_y + 1), (13, top_y - 3), (15, top_y + 1)]) | poly(FW, FH, [(15, top_y), (18, top_y - 3), (19, top_y + 1)])
        else:
            m = cap & ~rect(FW, FH, 0, int(head_cy), FW, FH)
            # jagged fringe
            for i, x in enumerate(range(9, 23)):
                drop = (2, 3, 2, 1, 2, 3, 2, 2, 3, 1, 2, 3, 2, 2)[i]
                m |= rect(FW, FH, x, int(head_cy) - 3, x, int(head_cy) - 3 + drop)
            m |= rect(FW, FH, 8, int(head_cy) - 3, 9, int(head_cy) + (2 if style != 'bob' else 7))
            m |= rect(FW, FH, 22, int(head_cy) - 3, 23, int(head_cy) + (2 if style != 'bob' else 7))
            if style == 'long':
                m |= rect(FW, FH, 7, int(head_cy) - 2, 9, int(head_cy) + 12) | rect(FW, FH, 22, int(head_cy) - 2, 24, int(head_cy) + 12)
            if style == 'spiky':
                for sx in (10, 14, 18):
                    m |= poly(FW, FH, [(sx, top_y + 2), (sx + 2, top_y - 3), (sx + 4, top_y + 2)])
        c.paint(m, hc, line=True)
        if side:
            # the ear sits on top of the hair at the side of the head
            ear = ellipse(FW, FH, 17.5, head_cy + 1.5, 1.6, 2.1)
            c.paint(ear, skin, soft=True)
            c.dots([(17, int(head_cy + 1.5))], ramp(skin)[1])
        if style == 'bun':
            c.paint(ellipse(FW, FH, 16 if not side else 18, top_y - 0.5, 3.3, 3), hc, line=True)
        c.dots([(11 if not side else 14, int(top_y) + 2), (12 if not side else 15, int(top_y) + 2), (13 if not side else 16, int(top_y) + 1)], ramp(hc)[5])

    def hat():
        h = L.get('hat')
        if not h:
            return
        col = L.get('hatc', '#888888')
        ty = head_cy - 8
        if h == 'beanie':
            m = ellipse(FW, FH, 16 if not side else 15.5, head_cy - 2.5, 8.3, 6.8) & ~rect(FW, FH, 0, int(head_cy) - 2, FW, FH)
            c.paint(m, col, line=True)
            band = rect(FW, FH, 8, int(head_cy) - 4, 23, int(head_cy) - 2) if not side else rect(FW, FH, 8, int(head_cy) - 4, 22, int(head_cy) - 2)
            c.paint(band, shift(hx(col), -0.1), line=True)
            for x in range(9, 23, 2):
                c.dots([(x, int(head_cy) - 3)], ramp(col)[2])
            c.paint(ellipse(FW, FH, 16 if not side else 17, ty - 1, 2, 1.8), '#f4efe2', soft=True)
        elif h == 'cap':
            m = ellipse(FW, FH, 16, head_cy - 3, 8, 5.5) & ~rect(FW, FH, 0, int(head_cy) - 3, FW, FH)
            c.paint(m, col, line=True)
            if side:
                c.paint(rect(FW, FH, 4, int(head_cy) - 4, 12, int(head_cy) - 3), shift(hx(col), -0.2), shade=False)
            elif not back:
                c.paint(rect(FW, FH, 9, int(head_cy) - 4, 22, int(head_cy) - 3), shift(hx(col), -0.25), shade=False)
            if not back:
                c.dots([(16 if not side else 13, int(head_cy) - 6)], '#f4efe2')
        elif h == 'bucket':
            c.paint(ellipse(FW, FH, 16, head_cy - 3.5, 6.5, 5) & ~rect(FW, FH, 0, int(head_cy) - 3, FW, FH), col, line=True)
            c.paint(rect(FW, FH, 6, int(head_cy) - 4, 25, int(head_cy) - 3), shift(hx(col), -0.12), line=True)
        elif h == 'captain':
            m = rect(FW, FH, 8, int(ty) - 1, 23, int(head_cy) - 4) | rect(FW, FH, 7, int(ty), 24, int(ty) + 2)
            if side:
                m = rect(FW, FH, 8, int(ty) - 1, 22, int(head_cy) - 4) | rect(FW, FH, 7, int(ty), 23, int(ty) + 2)
            c.paint(m, '#f4f2ec' if col == '#24305a' and False else col, line=True)
            c.paint(rect(FW, FH, 8, int(head_cy) - 4, 23, int(head_cy) - 4), '#e8e4dc', shade=False)
            if not back:
                visor = rect(FW, FH, 9, int(head_cy) - 3, 22, int(head_cy) - 3) if not side else rect(FW, FH, 5, int(head_cy) - 3, 12, int(head_cy) - 3)
                c.paint(visor, '#1a1a22', shade=False)
                c.dots([(15 if not side else 10, int(ty) + 2), (16 if not side else 11, int(ty) + 2)], '#f0c840')
        elif h == 'straw' or h == 'ranger':
            brim_w = 11 if h == 'straw' else 10
            c.paint(ellipse(FW, FH, 16, head_cy - 4.5, 5.8, 4) & ~rect(FW, FH, 0, int(head_cy) - 3, FW, FH), col, line=True)
            brim = ellipse(FW, FH, 16 if not side else 15, head_cy - 3, brim_w + 0.5, 1.8)
            c.paint(brim, shift(hx(col), -0.05), line=True)
            if h == 'straw':
                yy, xx = np.mgrid[0:FH, 0:FW]
                weave = brim & ((xx + yy) % 3 == 0)
                c.rgb[weave] = ramp(col)[2]
                c.paint(rect(FW, FH, 11, int(head_cy) - 5, 21, int(head_cy) - 5), '#c84a3a', shade=False)
            else:
                c.paint(rect(FW, FH, 11, int(head_cy) - 5, 21, int(head_cy) - 5), '#3a2a1a', shade=False)
        elif h == 'bandana':
            m = ellipse(FW, FH, 16, head_cy - 2.5, 8.2, 6) & ~rect(FW, FH, 0, int(head_cy) - 2, FW, FH)
            c.paint(m, col, line=True)
            if back or side:
                kx = 16 if back else 22
                c.paint(poly(FW, FH, [(kx - 1, head_cy - 3), (kx + 3, head_cy + 1), (kx, head_cy + 1)]), col, line=True)
            c.dots([(11, int(head_cy) - 5), (14, int(head_cy) - 6), (18, int(head_cy) - 5)], '#e8e4dc')

    # back to front
    hair(False)
    if side:
        legs()
        if pose == 'cheer':
            pass
        torso()
        head()
        face()
        beard()
        hair(True)
        hat()
        arms(True)
    elif back:
        legs()
        torso()
        arms(True)
        head()
        hair(True)
        hat()
    else:
        legs()
        torso()
        if pose != 'cheer':
            arms(True)
        head()
        face()
        beard()
        hair(True)
        hat()
        if pose == 'cheer':
            arms(True)
    return c.finish()


POSES = ['stand', 'walk_a', 'walk_b', 'cast', 'cheer']
DIRS = ['down', 'up', 'left', 'right']


def person_sheet(look):
    sheet = np.zeros((FH * 4, FW * 5, 4), np.uint8)
    for r, d in enumerate(DIRS):
        for col, p in enumerate(POSES):
            if d == 'right':
                img = draw_person(look, 'left', p)[:, ::-1]
            else:
                img = draw_person(look, d, p)
            sheet[r * FH:(r + 1) * FH, col * FW:(col + 1) * FW] = img
    return sheet


def make_characters(preview):
    names = list(LOOKS)
    for n in names:
        save(person_sheet(LOOKS[n]), 'chars2/%s.png' % n)
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        rows = []
        for n in names[:6]:
            rows.append(person_sheet(LOOKS[n]))
        big = np.concatenate(rows, 1)
        Image.fromarray(big, 'RGBA').resize((big.shape[1] * 3, big.shape[0] * 3), Image.NEAREST).save(PREVIEW + '/chars_a.png')
        rows = [person_sheet(LOOKS[n]) for n in names[6:12]]
        big = np.concatenate(rows, 1)
        Image.fromarray(big, 'RGBA').resize((big.shape[1] * 3, big.shape[0] * 3), Image.NEAREST).save(PREVIEW + '/chars_b.png')
    print('characters:', len(names))


# ============================================================================ cats

CW = 32
COATS = {
    'ginger': dict(base='#e48c3c', stripe='#b8602a', belly='#f6d6a8', eye='#78c048'),
    'black': dict(base='#36303a', belly='#36303a', eye='#e8c838'),
    'tabby': dict(base='#a08c6e', stripe='#5e4c3a', belly='#e4d8c0', eye='#9ac040'),
    'calico': dict(base='#f4f0e8', patches=['#e08a3c', '#36303a'], belly='#f4f0e8', eye='#d8a838'),
    'cream': dict(base='#f0dcb4', stripe='#d4b080', belly='#faf0dc', eye='#e8a838'),
    'grey': dict(base='#8e929c', stripe='#6a6e7a', belly='#c8ccd4', eye='#e8c838'),
    'siamese': dict(base='#efe4cc', points='#5a4034', belly='#f8f0e0', eye='#58a8e8'),
    'tortie': dict(base='#3a3034', patches=['#c8702e', '#8a4a2a'], belly='#3a3034', eye='#e8b838'),
    'tux': dict(base='#2e2a32', belly='#f4f2ec', tux=True, eye='#98c848'),
    'bicolor': dict(base='#f4f2ec', patches=['#6a6a74'], belly='#f4f2ec', eye='#d8b838', capped=True),
}


def draw_cat(coat, direction, pose):
    C = COATS[coat]
    c = Canvas(CW, CW)
    base = C['base']
    rng = np.random.RandomState(abs(hash(coat)) % 1000)
    side = direction == 'left'
    back = direction == 'up'
    walk = pose in ('walk_a', 'walk_b')
    bob = -1 if pose == 'walk_a' else 0

    def coat_paint(m, under=False, light=(-1, -1)):
        if not m.any():
            return
        c.paint(m, base, line=True, light=light)
        yy, xx = np.mgrid[0:CW, 0:CW]
        if C.get('stripe'):
            if side or pose == 'sleep':
                st = m & (((xx + (yy // 3)) % 4) == 0) & (yy < np.max(np.nonzero(m)[0]) - 1)
            else:
                st = m & ((yy % 3) == 0) & ((xx + yy) % 5 != 0)
            c.rgb[st] = ramp(C['stripe'])[3]
        for i, pc in enumerate(C.get('patches', [])):
            noise = np.sin(xx * 0.7 + i * 2.1 + rng.rand() * 3) + np.cos(yy * 0.9 - i * 1.3 + rng.rand() * 3)
            pm = m & (noise > 0.9 - i * 0.2)
            c.rgb[pm] = ramp(pc)[3]
            c.rgb[pm & ~np.roll(m, -1, 0)] = ramp(pc)[2]

    def legs(xs, y0, y1, far=False):
        for x0 in xs:
            m = rect(CW, CW, x0, y0, x0 + 1, y1)
            col = base if not far else shift(hx(base), -0.18)
            c.paint(m, col if not C.get('tux') and not C.get('points') else (C['belly'] if C.get('tux') else C['points']), shade=False)
            c.dots([(x0, y1), (x0 + 1, y1)], C['belly'] if not C.get('points') else ramp(C['points'])[1])

    def tail(pts, width=2):
        m = line_mask(CW, CW, pts, width=width)
        c.paint(m, base if not C.get('points') else C['points'], line=True)

    def head(cx, cy, facing):
        hm = ellipse(CW, CW, cx, cy, 4.8, 4.2)
        coat_paint(hm)
        # ears
        if facing == 'side':
            ears = poly(CW, CW, [(cx - 3.5, cy - 2.5), (cx - 2.5, cy - 7), (cx - 0.5, cy - 3.5)]) | poly(CW, CW, [(cx + 0.5, cy - 3.5), (cx + 2.5, cy - 7), (cx + 3.5, cy - 2.5)])
        else:
            ears = poly(CW, CW, [(cx - 4.5, cy - 1.5), (cx - 4, cy - 7), (cx - 1, cy - 3.5)]) | poly(CW, CW, [(cx + 1, cy - 3.5), (cx + 4, cy - 7), (cx + 4.5, cy - 1.5)])
        c.paint(ears, base if not C.get('points') else C['points'], line=True)
        inner = []
        if facing != 'back':
            if facing == 'side':
                inner = [(int(cx - 2.5), int(cy - 5)), (int(cx + 2), int(cy - 5))]
            else:
                inner = [(int(cx - 3.5), int(cy - 4)), (int(cx + 3), int(cy - 4))]
            c.dots(inner, '#f0a0a8')
        if C.get('points') and facing != 'back':
            mask = ellipse(CW, CW, cx - (1.5 if facing == 'side' else 0), cy + 1.2, 2.8, 2.4)
            c.rgb[mask] = ramp(C['points'])[3]
        if C.get('tux') and facing != 'back':
            mz = ellipse(CW, CW, cx - (2 if facing == 'side' else 0), cy + 2, 2.2, 1.6)
            c.rgb[mz] = ramp(C['belly'])[3]
        if C.get('capped'):
            cap = hm & (np.mgrid[0:CW, 0:CW][0] < cy)
            c.rgb[cap] = ramp(C['patches'][0])[3]
        if facing == 'back':
            return
        eye = C['eye']
        if pose == 'sleep':
            if facing == 'side':
                c.dots([(int(cx - 3), int(cy)), (int(cx - 2), int(cy))], '#2a2028')
            return
        if facing == 'side':
            ex, ey = int(cx - 2.5), int(cy - 0.5)
            c.dots([(ex, ey), (ex, ey + 1)], eye)
            c.dots([(ex + 1, ey), (ex + 1, ey + 1)], '#1a1418')
            c.dots([(int(cx - 5), int(cy + 1))], '#e88a98')
        else:
            for ex in (int(cx - 3), int(cx + 2)):
                c.dots([(ex, int(cy - 0.5)), (ex, int(cy + 0.5))], eye)
                c.dots([(ex + 1, int(cy - 0.5)), (ex + 1, int(cy + 0.5))], '#1a1418')
            c.dots([(int(cx), int(cy + 2))], '#e88a98')
            c.dots([(int(cx) - 1, int(cy + 3)), (int(cx) + 1, int(cy + 3))], ramp(base)[1])

    if pose == 'sleep':
        body = ellipse(CW, CW, 16, 24, 9, 4.6)
        tail([(24, 25), (25, 28), (18, 29), (9, 28)], 2)
        coat_paint(body)
        if not C.get('tux'):
            pass
        head(9.5, 22.5, 'side' if not back else 'back')
        return c.finish()

    if side:
        if pose == 'sit':
            tail([(23, 27), (25, 29), (16, 29.5), (10, 29.5)], 2)
            legs((11, 14), 23, 28)
            body = ellipse(CW, CW, 17, 22.5, 6.5, 5.5) | ellipse(CW, CW, 13, 19, 3.5, 5)
            coat_paint(body)
            belly = ellipse(CW, CW, 12.5, 21, 2, 3.5) & body
            c.paint(belly, C['belly'], shade=False)
            head(12, 12.5 + bob, 'side')
            return c.finish()
        ph = {'walk_a': 1, 'walk_b': -1}.get(pose, 0)
        tail([(24, 19), (27, 15), (28, 10), (26, 7)], 2)
        legs((10 - ph, 20 + ph), 22 + bob, 27, far=True)
        body = ellipse(CW, CW, 17, 19.5 + bob, 8.5, 4.3)
        coat_paint(body)
        belly = body & ~ellipse(CW, CW, 17, 18.5 + bob, 8.5, 3.8)
        c.paint(belly, C['belly'], shade=False)
        legs((12 + ph, 22 - ph), 22 + bob, 27)
        head(8.5, 14.5 + bob, 'side')
        return c.finish()

    # front and back
    if back:
        legs((12, 18), 24, 28)
        body = ellipse(CW, CW, 16, 21 + bob, 6, 5.5)
        coat_paint(body)
        tail([(16, 22), (17, 15), (20, 9), (22, 8)], 2)
        head(16, 12.5 + bob, 'back')
        return c.finish()
    if pose == 'sit':
        body = ellipse(CW, CW, 16, 23, 6.5, 5.5)
        coat_paint(body)
        c.paint(ellipse(CW, CW, 16, 22, 3, 4) & body, C['belly'], shade=False)
        legs((13, 17), 24, 28)
        tail([(21, 27), (24, 26), (25, 22)], 2)
        head(16, 14, 'front')
        return c.finish()
    ph = {'walk_a': 1, 'walk_b': -1}.get(pose, 0)
    tail([(20, 21), (24, 17), (25, 12)], 2)
    body = ellipse(CW, CW, 16, 21 + bob, 5.5, 5)
    coat_paint(body)
    c.paint(ellipse(CW, CW, 16, 21 + bob, 2.6, 4) & body, C['belly'], shade=False)
    legs((12, 18), 23 + bob + (1 if ph > 0 else 0), 28)
    legs((14, 16), 24 + bob + (1 if ph < 0 else 0), 28)
    head(16, 13.5 + bob, 'front')
    return c.finish()


CAT_POSES = ['stand', 'walk_a', 'walk_b', 'sit', 'sleep']


def cat_sheet(coat):
    sheet = np.zeros((CW * 4, CW * 5, 4), np.uint8)
    for r, d in enumerate(DIRS):
        for col, p in enumerate(CAT_POSES):
            if d == 'right':
                img = draw_cat(coat, 'left', p)[:, ::-1]
            else:
                img = draw_cat(coat, d, p)
            sheet[r * CW:(r + 1) * CW, col * CW:(col + 1) * CW] = img
    return sheet


def make_cats(preview):
    sheets = []
    for coat in COATS:
        sh = cat_sheet(coat)
        save(sh, 'cats2/%s.png' % coat)
        sheets.append(sh)
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        big = np.concatenate([np.concatenate(sheets[:5], 1), np.concatenate(sheets[5:], 1)], 0)
        bg = np.zeros_like(big)
        bg[..., :3] = (60, 90, 70)
        bg[..., 3] = 255
        a = big[..., 3:4] / 255.0
        comp = (big[..., :3] * a + bg[..., :3] * (1 - a)).astype(np.uint8)
        Image.fromarray(comp).resize((comp.shape[1] * 3, comp.shape[0] * 3), Image.NEAREST).save(PREVIEW + '/cats.png')
    print('cats:', len(COATS))


# ========================================================================== plants

def _hash2(x, y, seed):
    h = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


def hashmap(w, h, seed, cell=1):
    yy, xx = np.mgrid[0:h, 0:w]
    xx = xx // cell
    yy = yy // cell
    hv = (xx.astype(np.int64) * 374761393 + yy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    hv = ((hv ^ (hv >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((hv ^ (hv >> 16)) & 0xFFFFFFFF) / 4294967296.0


def lit_blobs(w, h, blobs, seed, rough=0.18):
    """Union of spheres seen from the front: returns (mask, brightness 0..1)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    best = np.full((h, w), -1.0)
    bright = np.zeros((h, w))
    L = np.array([-0.55, -0.65, 0.55])
    L /= np.linalg.norm(L)
    ang_noise = lambda a, i: 1.0 + rough * (np.sin(a * 5 + i * 1.7) * 0.5 + np.sin(a * 11 + i * 3.1) * 0.35 + np.sin(a * 23 + i) * 0.15)
    for i, (cx, cy, r) in enumerate(blobs):
        dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
        ang = np.arctan2(dy, dx)
        rr = r * ang_noise(ang, i + seed)
        d2 = dx * dx + dy * dy
        inside = d2 < rr * rr
        hgt = np.sqrt(np.clip(rr * rr - d2, 0, None)) + (cy * -0.02)  # higher blobs sit in front a touch
        z = hgt / rr
        nx, ny = dx / rr, dy / rr
        b = nx * L[0] + ny * L[1] + z * L[2]
        upd = inside & (hgt + i * 0.01 > best)
        best[upd] = hgt[upd] + i * 0.01
        bright[upd] = b[upd]
    mask = best >= 0
    return mask, bright


def tone_paint(c, mask, bright, palette, seed, leaf=0.35, cell=2):
    """Quantise brightness into the palette with leafy noise and Bayer dithering."""
    noise = hashmap(c.w, c.h, seed, cell) - 0.5
    noise2 = hashmap(c.w, c.h, seed + 7, 1) - 0.5
    v = np.clip((bright + 0.35) / 1.25 + noise * leaf + noise2 * 0.12, 0, 0.999)
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    v = v * (len(palette) - 1) + (BAYER4[yy % 4, xx % 4] - 0.5) * 0.9
    idx = np.clip(np.round(v), 0, len(palette) - 1).astype(int)
    pal = np.array([hx(p) for p in palette])
    r = ramp(palette[len(palette) // 2])
    r[0] = shift(hx(palette[0]), -0.45, 0.2)
    pid = len(c.ramps)
    c.ramps.append(r)
    c.flags.append(False)
    c.rgb[mask] = pal[idx[mask]]
    c.part[mask] = pid


def trunk(c, x, y_top, y_bot, w_top, w_bot, color, seed, roots=True):
    pts = [(x - w_top / 2, y_top), (x + w_top / 2, y_top), (x + w_bot / 2, y_bot), (x - w_bot / 2, y_bot)]
    m = poly(c.w, c.h, pts)
    if roots:
        m |= poly(c.w, c.h, [(x - w_bot / 2 - 3, y_bot), (x - w_bot / 2, y_bot - 4), (x - w_bot / 2 + 1, y_bot)])
        m |= poly(c.w, c.h, [(x + w_bot / 2 + 3, y_bot), (x + w_bot / 2, y_bot - 4), (x + w_bot / 2 - 1, y_bot)])
    c.paint(m, color, light=(-1, 0))
    # bark grooves
    hv = hashmap(c.w, c.h, seed, 1)
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    grooves = m & ((xx + (yy // 5)) % 3 == 0) & (hv > 0.35)
    c.rgb[grooves] = ramp(color)[1]
    return m


PAL = {
    'oak': ['#24462e', '#2f5a37', '#3f7a45', '#5b9a52', '#79b85a', '#a7d872'],
    'autumn': ['#5a2a1a', '#8a3a1e', '#c8642a', '#e08a32', '#f0b048', '#f8d878'],
    'pine': ['#1a3a30', '#22493a', '#2f5e45', '#3f7650', '#5a9460', '#7ab070'],
    'birch': ['#3a5a2a', '#4f7a34', '#6a9a3e', '#8ab84a', '#aed05a', '#d0e878'],
    'palm': ['#2a4a1e', '#3a6626', '#4f8430', '#6aa43a', '#8ac44a', '#b0dc6a'],
    'willow': ['#2a4a32', '#36603e', '#4a7a4a', '#62965a', '#80b06a', '#a8cc80'],
    'mangrove': ['#1e3a2a', '#2a4e34', '#3a6640', '#4e804a', '#6a9a58', '#8ab868'],
    'bush': ['#24462e', '#2f5a37', '#3f7a45', '#5b9a52', '#79b85a', '#a7d872'],
}


def tree_oak(seed, pal='oak', w=96, h=112):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    trunk(c, w / 2, 62, h - 3, 7, 11, '#7a5434', seed)
    # a couple of branches peeking out
    c.paint(line_mask(w, h, [(w / 2, 74), (w / 2 - 14, 62)], 3) | line_mask(w, h, [(w / 2 + 1, 70), (w / 2 + 15, 60)], 3), '#6a4a2e', shade=False)
    blobs = [(w / 2, 40, 26), (w / 2 - 20, 52, 18), (w / 2 + 21, 50, 18), (w / 2 - 9, 26, 18), (w / 2 + 11, 24, 17), (w / 2, 58, 16)]
    blobs = [(x + rng.uniform(-3, 3), y + rng.uniform(-3, 3), r * rng.uniform(0.9, 1.08)) for x, y, r in blobs]
    m, b = lit_blobs(w, h, blobs, seed)
    tone_paint(c, m, b, PAL[pal], seed)
    if pal == 'oak' and seed % 2 == 0:
        # a few blossoms or fruit
        hv = hashmap(w, h, seed + 3, 1)
        fl = m & (hv > 0.985)
        c.rgb[fl] = hx('#f4f0d8')
    return c.finish()


def tree_pine(seed, w=72, h=120):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    trunk(c, w / 2, 90, h - 3, 5, 8, '#6a4a30', seed)
    tiers = 6
    mask = c.mask()
    bright = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    for i in range(tiers):
        t = i / (tiers - 1)
        top = 6 + i * 14
        bot = top + 30
        half = 8 + t * 24
        tri = poly(w, h, [(w / 2, top), (w / 2 + half, bot), (w / 2 - half, bot)])
        # jagged hem
        jag = (np.sin(xx * 1.3 + i * 2) > 0.2) & (yy > bot - 3)
        tri &= ~jag
        lx = (xx - w / 2) / max(half, 1)
        ly = (yy - top) / (bot - top)
        bb = -lx * 0.6 - ly * 0.35 + 0.35
        mask |= tri
        bright[tri] = bb[tri]
    tone_paint(c, mask, bright, PAL['pine'], seed, leaf=0.45, cell=2)
    return c.finish()


def tree_birch(seed, w=72, h=112):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    tm = trunk(c, w / 2, 26, h - 3, 3, 6, '#ece8dc', seed, roots=False)
    # black birch marks
    hv = hashmap(w, h, seed, 1)
    yy, xx = np.mgrid[0:h, 0:w]
    marks = tm & ((yy % 7) < 1) & (hv > 0.3)
    c.rgb[marks] = hx('#2a2a2a')
    blobs = [(w / 2, 34, 15), (w / 2 - 10, 46, 12), (w / 2 + 11, 44, 12), (w / 2 - 5, 20, 11), (w / 2 + 7, 22, 11),
             (w / 2 + rng.uniform(-8, 8), 56, 10), (w / 2 - 14, 30, 9), (w / 2 + 15, 32, 9)]
    blobs = [(x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), r) for x, y, r in blobs]
    m, b = lit_blobs(w, h, blobs, seed, rough=0.3)
    tone_paint(c, m, b, PAL['birch'], seed, leaf=0.5, cell=1)
    return c.finish()


def tree_palm(seed, w=104, h=120):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    lean = rng.uniform(-12, 12)
    pts = [(w / 2 + lean * t * t, h - 3 - t * 76) for t in np.linspace(0, 1, 14)]
    tm = c.mask()
    for i in range(len(pts) - 1):
        tm |= line_mask(w, h, [pts[i], pts[i + 1]], 6 - i * 0.15)
    c.paint(tm, '#a8845a', light=(-1, 0))
    yy, xx = np.mgrid[0:h, 0:w]
    rings = tm & (yy % 4 == 0)
    c.rgb[rings] = ramp('#a8845a')[1]
    cx, cy = pts[-1]
    fm = c.mask()
    bright = np.zeros((h, w))
    angles = [-2.9, -2.5, -2.1, -1.75, -1.4, -1.05, -0.7, -0.3, 0.05, 2.75, 3.2]
    for k, a in enumerate(angles):
        a += rng.uniform(-0.08, 0.08)
        length = rng.uniform(30, 42) * (0.75 if abs(a + 1.57) < 0.5 else 1.0)
        droop = rng.uniform(16, 26)
        prev = (cx, cy)
        for t in np.linspace(0, 1, 16)[1:]:
            px = cx + math.cos(a) * length * t
            py = cy + math.sin(a) * length * t * 0.75 + droop * t * t
            seg = line_mask(w, h, [prev, (px, py)], 2)
            # leaflets both sides, hanging down and outward, shorter toward the tip
            lw = 7 * (1 - t) ** 0.7 + 1.5
            dxn, dyn = px - prev[0], py - prev[1]
            nl = math.hypot(dxn, dyn) or 1
            nx, ny = -dyn / nl, dxn / nl
            l1 = line_mask(w, h, [(px, py), (px + nx * lw * 0.6, py + abs(ny) * lw * 0.6 + lw * 0.7)], 1)
            l2 = line_mask(w, h, [(px, py), (px - nx * lw * 0.6, py + abs(ny) * lw * 0.6 + lw * 0.7)], 1)
            part = seg | l1 | l2
            fm |= part
            up = -math.sin(a)
            bright[part] = 0.45 * up + 0.2 - t * 0.45 + (0.15 if math.cos(a) < 0 else -0.1)
            prev = (px, py)
    tone_paint(c, fm, bright, PAL['palm'], seed, leaf=0.25, cell=1)
    for dx, dy in ((-3, 4), (2, 5), (0, 2)):
        c.paint(ellipse(w, h, cx + dx, cy + dy, 2.4, 2.4), '#6a4a2a')
    return c.finish()


def tree_willow(seed, w=96, h=112):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    trunk(c, w / 2, 50, h - 3, 7, 11, '#6a5a44', seed)
    blobs = [(w / 2, 34, 24), (w / 2 - 18, 42, 16), (w / 2 + 18, 42, 16)]
    m, b = lit_blobs(w, h, blobs, seed)
    # hanging strands
    yy, xx = np.mgrid[0:h, 0:w]
    for x in range(int(w / 2 - 34), int(w / 2 + 34), 2):
        top = 30 + abs(x - w / 2) * 0.25
        length = 30 + rng.uniform(0, 34) - abs(x - w / 2) * 0.3
        strand = (xx == x) & (yy > top) & (yy < top + length)
        m |= strand
        b[strand] = 0.2 - (yy[strand] - top) / 80
    tone_paint(c, m, b, PAL['willow'], seed, leaf=0.3, cell=1)
    return c.finish()


def tree_mangrove(seed, w=96, h=96):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    roots = c.mask()
    for k in range(7):
        x0 = w / 2 + (k - 3) * 2
        x1 = w / 2 + (k - 3) * 9 + rng.uniform(-3, 3)
        pts = [(x0, 52), ((x0 + x1) / 2, 60 - abs(k - 3) * 1.5), (x1, h - 3)]
        for i in range(2):
            roots |= line_mask(w, h, [pts[i], pts[i + 1]], 2)
    c.paint(roots, '#6a5440', shade=False)
    trunk(c, w / 2, 36, 56, 6, 8, '#6a5440', seed, roots=False)
    blobs = [(w / 2, 28, 22), (w / 2 - 20, 34, 15), (w / 2 + 20, 33, 15), (w / 2 - 6, 18, 14), (w / 2 + 9, 17, 13)]
    m, b = lit_blobs(w, h, blobs, seed)
    tone_paint(c, m, b, PAL['mangrove'], seed)
    return c.finish()


def tree_dead(seed, w=64, h=96):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    m = c.mask()

    def branch(x, y, a, length, width, depth):
        nonlocal m
        x2, y2 = x + math.cos(a) * length, y + math.sin(a) * length
        m |= line_mask(w, h, [(x, y), (x2, y2)], max(1, int(width)))
        if depth > 0:
            for da in (-0.5, 0.45):
                branch(x2, y2, a + da + rng.uniform(-0.15, 0.15), length * 0.68, width * 0.65, depth - 1)

    branch(w / 2, h - 3, -math.pi / 2, 34, 6, 4)
    c.paint(m, '#7a6a5a', light=(-1, 0))
    return c.finish()


def bush(seed, w=40, h=30, flowers=None, pal='bush'):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    blobs = [(w / 2, h - 11, 11), (w / 2 - 9, h - 8, 8), (w / 2 + 9, h - 8, 8), (w / 2 + rng.uniform(-4, 4), h - 16, 8)]
    m, b = lit_blobs(w, h, blobs, seed)
    m &= np.mgrid[0:h, 0:w][0] < h - 1
    tone_paint(c, m, b, PAL[pal], seed, leaf=0.4, cell=1)
    if flowers:
        hv = hashmap(w, h, seed + 9, 1)
        fl = m & (hv > 0.93)
        c.rgb[fl] = hx(flowers)
        yy, xx = np.mgrid[0:h, 0:w]
        c.rgb[fl & np.roll(fl, 1, 0)] = shift(hx(flowers), 0.2, -0.3)
    return c.finish()


def flowers(seed, color, w=20, h=16):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    stems = c.mask()
    heads = []
    for k in range(5):
        x = rng.randint(3, w - 3)
        top = rng.randint(3, 8)
        stems |= rect(w, h, x, top, x, h - 2)
        heads.append((x, top))
    c.paint(stems, '#4f8a3a', shade=False)
    for x, y in heads:
        c.paint(ellipse(w, h, x + 0.5, y + 0.5, 1.8, 1.8), color, soft=True)
        c.dots([(x, y)], '#f8e070')
    return c.finish()


def reeds(seed, w=28, h=36, cattail=True):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    m = c.mask()
    tops = []
    for k in range(9):
        x0 = rng.uniform(4, w - 4)
        lean = rng.uniform(-5, 5)
        top = rng.uniform(4, 14)
        m |= line_mask(w, h, [(x0, h - 1), (x0 + lean, top)], 1)
        tops.append((x0 + lean, top))
    c.paint(m, '#7a9a4a', shade=False)
    if cattail:
        for x, y in tops[:4]:
            c.paint(ellipse(w, h, x + 0.5, y + 3, 1.3, 3), '#6a4a2a', soft=True)
    return c.finish()


def fern(seed, w=40, h=28):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    m = c.mask()
    for k in range(6):
        a = math.pi + 0.3 + k * (math.pi - 0.6) / 5
        x0, y0 = w / 2, h - 2
        prev = (x0, y0)
        for t in np.linspace(0, 1, 8)[1:]:
            px = x0 + math.cos(a) * 18 * t
            py = y0 + math.sin(a) * 18 * t + t * t * 11
            m |= line_mask(w, h, [prev, (px, py)], 2)
            prev = (px, py)
    c.paint(m, '#4f8a3a')
    return c.finish()


def rock(seed, w=36, h=26, moss=False):
    c = Canvas(w, h)
    rng = np.random.RandomState(seed)
    blobs = [(w / 2, h * 0.62, h * 0.55), (w / 2 - w * 0.22, h * 0.72, h * 0.4), (w / 2 + w * 0.24, h * 0.75, h * 0.36)]
    blobs = [(x + rng.uniform(-2, 2), y, r * rng.uniform(0.9, 1.1)) for x, y, r in blobs]
    m, b = lit_blobs(w, h, blobs, seed, rough=0.12)
    yy, xx = np.mgrid[0:h, 0:w]
    m &= yy < h - 1
    tone_paint(c, m, b, ['#3e3a50', '#55516a', '#6e6a84', '#8a8698', '#a8a4b4', '#c8c4d0'], seed, leaf=0.15, cell=2)
    # cracks
    for k in range(2):
        x = rng.uniform(w * 0.3, w * 0.7)
        cr = line_mask(w, h, [(x, h * 0.4), (x + rng.uniform(-4, 4), h * 0.65), (x + rng.uniform(-6, 6), h - 3)], 1) & m
        c.rgb[cr] = hx('#4a465c')
    if moss:
        top = m & ~np.roll(m, 4, 0)
        hv = hashmap(w, h, seed, 1)
        c.rgb[top & (hv > 0.25)] = hx('#5b9a52')
        c.rgb[top & (hv > 0.75)] = hx('#79b85a')
    return c.finish()


def make_plants(preview):
    out = {}
    for i in range(3):
        out['oak%d' % i] = tree_oak(11 + i)
    out['autumn0'] = tree_oak(21, 'autumn')
    out['autumn1'] = tree_oak(22, 'autumn')
    for i in range(2):
        out['pine%d' % i] = tree_pine(31 + i)
    for i in range(2):
        out['birch%d' % i] = tree_birch(41 + i)
    for i in range(2):
        out['palm%d' % i] = tree_palm(51 + i)
    out['willow0'] = tree_willow(61)
    out['mangrove0'] = tree_mangrove(71)
    out['mangrove1'] = tree_mangrove(72)
    out['dead0'] = tree_dead(81)
    for i in range(3):
        out['bush%d' % i] = bush(91 + i)
    out['bush_pink'] = bush(95, flowers='#f6a0c0')
    out['bush_white'] = bush(96, flowers='#f8f4e8')
    out['bush_yellow'] = bush(97, flowers='#f8d850')
    for i, col in enumerate(['#e85a6a', '#f8e070', '#9a7ae8', '#f8f4ec', '#f0a040']):
        out['flowers%d' % i] = flowers(101 + i, col)
    out['reeds0'] = reeds(111)
    out['reeds1'] = reeds(112, cattail=False)
    out['fern0'] = fern(121)
    out['fern1'] = fern(122)
    for i in range(3):
        out['rock%d' % i] = rock(131 + i, moss=(i == 2))
    out['boulder0'] = rock(141, 64, 44)
    out['boulder1'] = rock(142, 56, 40, moss=True)
    for k, img in out.items():
        save(img, 'plants/%s.png' % k)
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        W = sum(im.shape[1] + 4 for im in out.values())
        Hh = max(im.shape[0] for im in out.values())
        sheet = np.zeros((Hh, W, 4), np.uint8)
        x = 0
        for im in out.values():
            sheet[Hh - im.shape[0]:, x:x + im.shape[1]] = im
            x += im.shape[1] + 4
        bg = np.zeros_like(sheet)
        bg[..., :3] = (120, 170, 110)
        a = sheet[..., 3:4] / 255.0
        comp = (sheet[..., :3] * a + bg[..., :3] * (1 - a)).astype(np.uint8)
        half = comp.shape[1] // 2
        Image.fromarray(comp[:, :half]).resize((half * 2, Hh * 2), Image.NEAREST).save(PREVIEW + '/plants_a.png')
        Image.fromarray(comp[:, half:]).resize(((comp.shape[1] - half) * 2, Hh * 2), Image.NEAREST).save(PREVIEW + '/plants_b.png')
    print('plants:', len(out))


# ============================================================================ fish

FWD, FHT = 80, 48
# Generic body shapes: length (share of the frame), height (px), where the body is
# deepest, how blunt the head is, tail-base height, back/belly asymmetry, tail and fins.
FISH = {
    'torp': dict(L=.74, H=14, peak=.36, blunt=1.5, tb=.26, asym=.05, tail='fork', dorsal='two', eye=2.0),
    'deep': dict(L=.62, H=24, peak=.4, blunt=1.25, tb=.24, asym=.14, tail='fork', dorsal='spiny', eye=2.3),
    'grouper': dict(L=.7, H=22, peak=.42, blunt=1.1, tb=.36, asym=.08, tail='round', dorsal='spiny', eye=2.0, mouth=4),
    'tuna': dict(L=.72, H=18, peak=.42, blunt=1.7, tb=.1, asym=.0, tail='lunate', dorsal='tuna', eye=2.2, finlets=True),
    'shark': dict(L=.8, H=13, peak=.36, blunt=2.2, tb=.16, asym=.02, tail='shark', dorsal='shark', eye=1.4, gills=5, pec=1.6),
    'eel': dict(L=.95, H=8, peak=.18, blunt=1.5, tb=.35, asym=.0, tail='pointed', dorsal='eel', eye=1.4),
    'ribbon': dict(L=.96, H=6, peak=.15, blunt=1.8, tb=.2, asym=.0, tail='pointed', dorsal='eel', eye=1.8),
    'oar': dict(L=.96, H=7, peak=.12, blunt=2.0, tb=.2, asym=.0, tail='pointed', dorsal='crest', eye=1.8),
    'jacket': dict(L=.62, H=22, peak=.45, blunt=0.95, tb=.28, asym=.04, tail='round', dorsal='spine', eye=2.0, mouth=1),
    'trigger': dict(L=.62, H=24, peak=.46, blunt=1.0, tb=.3, asym=.08, tail='truncate', dorsal='spine', eye=2.0, mouth=1),
    'parrot': dict(L=.68, H=20, peak=.4, blunt=1.05, tb=.32, asym=.06, tail='truncate', dorsal='long', eye=2.0, beak=True),
    'puffer': dict(L=.56, H=27, peak=.45, blunt=0.9, tb=.3, asym=.0, tail='round', dorsal='small', eye=2.8, spines=True, mouth=1),
    'flathead': dict(L=.82, H=10, peak=.26, blunt=1.0, tb=.32, asym=-.15, tail='round', dorsal='two', eye=2.0, mouth=4),
    'gar': dict(L=.7, H=8, peak=.55, blunt=2.6, tb=.32, asym=.0, tail='fork', dorsal='rear', eye=1.8, bill=12),
    'disc': dict(L=.56, H=28, peak=.5, blunt=0.9, tb=.24, asym=.0, tail='truncate', dorsal='long', eye=2.2),
    'saw': dict(L=.72, H=12, peak=.36, blunt=2.2, tb=.16, asym=.02, tail='shark', dorsal='shark', eye=1.4, saw=16, pec=1.5),
    'clown': dict(L=.6, H=18, peak=.45, blunt=1.0, tb=.36, asym=.04, tail='round', dorsal='two', eye=2.2, mouth=1),
    'idol': dict(L=.5, H=26, peak=.5, blunt=0.85, tb=.24, asym=.0, tail='truncate', dorsal='filament', eye=2.0, snout=4),
    'lion': dict(L=.62, H=18, peak=.42, blunt=1.1, tb=.3, asym=.06, tail='round', dorsal='lion', eye=2.0, fans=True),
    'hump': dict(L=.7, H=24, peak=.4, blunt=1.2, tb=.34, asym=.12, tail='round', dorsal='long', eye=2.0, hump=6, mouth=3),
    'boar': dict(L=.56, H=24, peak=.45, blunt=0.9, tb=.24, asym=.05, tail='truncate', dorsal='tall', eye=2.4, snout=3),
    'dory': dict(L=.56, H=28, peak=.48, blunt=0.85, tb=.24, asym=.0, tail='round', dorsal='tall', eye=2.4, mouth=3),
    'bat': dict(L=.5, H=21, peak=.5, blunt=0.9, tb=.24, asym=.0, tail='truncate', dorsal='bat', eye=2.2),
    'wobbe': dict(L=.82, H=11, peak=.3, blunt=1.4, tb=.24, asym=-.1, tail='round', dorsal='two', eye=1.6, tassels=True),
    'flying': dict(L=.66, H=12, peak=.36, blunt=1.6, tb=.24, asym=.04, tail='fork', dorsal='rear', eye=2.2, wings=True),
    'mahi': dict(L=.72, H=20, peak=.22, blunt=3.2, tb=.16, asym=.1, tail='fork', dorsal='long', eye=2.0),
    'marlin': dict(L=.66, H=16, peak=.4, blunt=1.8, tb=.1, asym=.0, tail='lunate', dorsal='marlin', eye=2.0, bill=14),
    'sail': dict(L=.66, H=15, peak=.4, blunt=1.8, tb=.1, asym=.0, tail='lunate', dorsal='sail', eye=2.0, bill=14),
    'lantern': dict(L=.62, H=12, peak=.32, blunt=1.8, tb=.3, asym=.0, tail='fork', dorsal='small', eye=3.0),
    'chimaera': dict(L=.95, H=14, peak=.18, blunt=2.0, tb=.06, asym=.05, tail='pointed', dorsal='two', eye=3.2, pec=1.8),
    'gulper': dict(L=.95, H=12, peak=.1, blunt=3.0, tb=.06, asym=.0, tail='pointed', dorsal='none', eye=1.4, mouth=14),
    'angler': dict(L=.62, H=26, peak=.35, blunt=1.4, tb=.28, asym=.05, tail='round', dorsal='small', eye=1.6, mouth=10, lure=True),
    'odd': dict(L=.52, H=30, peak=.5, blunt=1.0, tb=.6, asym=.0, tail='truncate', dorsal='tall', eye=2.6),
}


def parse_look(look):
    parts = look.split('|') + [''] * 8
    return dict(shape=parts[0], c1=parts[1] or '#888888', c2=parts[2] or '#aaaaaa', c3=parts[3] or '#dddddd',
                pat=parts[4] or 'none', pc=parts[5] if parts[5] and parts[5] != '#000' else '#222222', fc=parts[6] or parts[1],
                mods=parts[7].split())


def body_colour(c, m, top, bot, x0, x1, c1, c2, c3, seed):
    """Three-band countershading (dark back, mid sides, pale belly) with dithered seams."""
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    t = np.zeros((c.h, c.w))
    rng_ = bot - top
    rng_[rng_ < 1] = 1
    t = (yy - top[None, :]) / rng_[None, :]
    dith = (BAYER4[yy % 4, xx % 4] - 0.5) * 0.12
    tt = t + dith
    r1, r2, r3 = ramp(c1), ramp(c2), ramp(c3)
    out = np.zeros((c.h, c.w, 3), np.uint8)
    band1 = tt < 0.36
    band2 = (tt >= 0.36) & (tt < 0.7)
    band3 = tt >= 0.7
    out[band1] = r1[3]
    out[band2] = r2[3]
    out[band3] = r3[3]
    out[(tt < 0.1)] = r1[4]
    out[(tt > 0.93)] = r3[2]
    u = (xx - x0) / max(1, (x1 - x0))
    tailshade = (u > 0.86) & band1
    out[tailshade] = r1[2]
    pid = len(c.ramps)
    rr = ramp(c1)
    c.ramps.append(rr)
    c.flags.append(False)
    c.rgb[m] = out[m]
    c.part[m] = pid
    return t


def pattern(c, m, t, kind, pc, x0, x1, top, bot, seed):
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    rng = np.random.RandomState(seed)
    P = ramp(pc)
    u = (xx - x0) / max(1, (x1 - x0))
    if kind == 'spots':
        hv = hashmap(c.w, c.h, seed, 2)
        sm = m & (hv > 0.82) & (t < 0.72) & (u > 0.12) & ((xx + yy) % 2 == 0)
        c.rgb[sm] = P[3]
    elif kind == 'bars':
        n = 5
        sm = m & (np.abs(((u * n + 0.3) % 1.0) - 0.5) < 0.13) & (u > 0.1) & (u < 0.95) & (t < 0.85)
        c.rgb[sm] = P[3]
    elif kind == 'stripes':
        sm = m & ((np.floor(t * 9)) % 2 == 0) & (t > 0.1) & (t < 0.8) & (u > 0.15)
        c.rgb[sm] = P[3]
    elif kind == 'lines':
        sm = m & (np.abs((t * 6) % 1.0 - 0.5) < 0.09) & (u > 0.18) & (t < 0.85)
        c.rgb[sm] = P[3]
    elif kind == 'lat':
        sm = m & (np.abs(t - 0.48) < 0.08) & (u > 0.12)
        c.rgb[sm] = P[3]
    elif kind == 'scales':
        sm = m & (((xx // 3) + (yy // 2)) % 2 == 0) & ((xx % 3) == 0) & (u > 0.18)
        c.rgb[sm] = P[2]
    elif kind == 'glow':
        for k in range(9):
            uu = 0.2 + k * 0.08
            x = int(x0 + uu * (x1 - x0))
            if 0 <= x < c.w:
                y = int(bot[x] - 2)
                c.dots([(x, y)], P[4])
    elif kind == 'band':
        sm = m & (np.abs(u - 0.35) < 0.06)
        c.rgb[sm] = P[3]
    elif kind == 'harness':
        for uu in (0.3, 0.5, 0.7):
            sm = m & (np.abs(u - uu - (t - 0.3) * 0.12) < 0.035) & (t < 0.6)
            c.rgb[sm] = P[3]
        sm = m & (t < 0.25) & (u > 0.18) & (u < 0.3)
        c.rgb[sm] = P[3]
    elif kind == 'clown':
        for uu in (0.2, 0.52, 0.86):
            band = m & (np.abs(u - uu) < 0.06)
            edge = m & (np.abs(np.abs(u - uu) - 0.075) < 0.018)
            c.rgb[band] = P[4]
            c.rgb[edge] = hx('#1a1a1a')
    elif kind in ('dory', 'shoulder'):
        cx = x0 + (0.48 if kind == 'dory' else 0.3) * (x1 - x0)
        cyy = (top[int(cx)] + bot[int(cx)]) / 2 if 0 <= int(cx) < c.w else 24
        spot = ellipse(c.w, c.h, cx, cyy, 3.2, 3.2) & m
        ring = ellipse(c.w, c.h, cx, cyy, 4.3, 4.3) & m & ~spot
        if kind == 'dory':
            c.rgb[ring] = hx('#f0d070')
        c.rgb[spot] = P[3]
    elif kind == 'blotch':
        hv = hashmap(c.w, c.h, seed, 4)
        sm = m & (hv > 0.62) & (t < 0.75)
        c.rgb[sm] = P[3]
        c.rgb[sm & (hashmap(c.w, c.h, seed + 1, 1) > 0.7)] = P[4]
    elif kind == 'belly':
        sm = m & (t > 0.6)
        c.rgb[sm] = P[3]
    elif kind == 'oblique':
        sm = m & (((xx + yy) // 3) % 3 == 0) & (u > 0.15) & (t < 0.85)
        c.rgb[sm] = P[3]
    elif kind == 'wavy':
        sm = m & (np.abs(((t * 5 + np.sin(xx * 0.5) * 0.25) % 1.0) - 0.5) < 0.1) & (u > 0.15)
        c.rgb[sm] = P[3]
    elif kind == 'tang':
        sm = m & (u > 0.75)
        c.rgb[sm] = P[3]
    elif kind == 'prism':
        hue = (u * 0.9 + t * 0.2) % 1.0
        for i in range(c.h):
            for j in range(c.w):
                if m[i, j]:
                    r, g, b = colorsys.hsv_to_rgb(hue[i, j], 0.45, 0.95 - t[i, j] * 0.3)
                    c.rgb[i, j] = (int(r * 255), int(g * 255), int(b * 255))


def fin(c, pts, color, rays=True, behind_mask=None):
    m = poly(c.w, c.h, pts)
    if not m.any():
        return m
    r = ramp(color)
    pid = len(c.ramps)
    c.ramps.append(r)
    c.flags.append(False)
    # fins are a touch see-through: lighter body tone with darker rays
    col = np.array(r[4])
    keep = m & (c.part < 0) if behind_mask is None else m
    c.rgb[keep] = col
    c.part[keep] = pid
    if rays:
        yy, xx = np.mgrid[0:c.h, 0:c.w]
        ray = keep & ((xx + yy) % 3 == 0)
        c.rgb[ray] = r[2]
    return m


def generic_fish(L, seed):
    P = dict(FISH.get(L['shape'], FISH['torp']))
    mods = L['mods']
    if 'big' in mods:
        P['H'] *= 1.12
    if 'slim' in mods:
        P['H'] *= 0.8
    if 'long' in mods:
        P['L'] = min(0.86, P['L'] * 1.12)
    if 'blunt' in mods:
        P['blunt'] *= 1.5
    if 'snapper' in mods:
        P['asym'] += 0.06
        P['H'] *= 1.05
    if 'sleek' in mods:
        P['H'] *= 0.9
        P['blunt'] *= 0.85
    if 'bigeye' in mods:
        P['eye'] *= 1.5
    c = Canvas(FWD, FHT)
    yc = 24.0
    bill = P.get('bill', 0) + P.get('saw', 0) + P.get('snout', 0)
    Lpx = P['L'] * 62
    tail_len = {'fork': 13, 'deepfork': 15, 'round': 10, 'truncate': 8, 'lunate': 14, 'shark': 16, 'pointed': 0}[P['tail'] if 'deepfork' not in mods else 'deepfork']
    total = bill + Lpx + tail_len
    x0 = (FWD - total) / 2 + bill
    x1 = x0 + Lpx
    xs = np.arange(FWD)
    top = np.full(FWD, yc)
    bot = np.full(FWD, yc)
    H = P['H']
    for x in range(FWD):
        u = (x + 0.5 - x0) / Lpx
        if u < 0 or u > 1:
            continue
        p = P['peak']
        if u < p:
            f = (1 - (1 - u / p) ** 2) ** (1.0 / P['blunt'])
        else:
            v = (u - p) / (1 - p)
            f = 1 - (1 - P['tb']) * v ** 1.5
        half = H / 2 * f
        top[x] = yc - half * (1 + P['asym'])
        bot[x] = yc + half * (1 - P['asym'])
        if P.get('hump'):
            top[x] -= P['hump'] * math.exp(-((u - 0.2) / 0.12) ** 2)
    yy, xx = np.mgrid[0:FHT, 0:FWD]
    body = (yy + 0.5 >= top[None, :]) & (yy + 0.5 <= bot[None, :]) & (xx + 0.5 >= x0) & (xx + 0.5 <= x1)
    fc = L['fc']
    tbx = int(min(FWD - 1, x1))
    tb_top, tb_bot = top[min(FWD - 1, int(x1) - 1)], bot[min(FWD - 1, int(x1) - 1)]
    mid = (tb_top + tb_bot) / 2

    # ----- fins behind the body
    tl = P['tail'] if 'deepfork' not in mods else 'deepfork'
    if tl == 'fork' or tl == 'deepfork':
        sp = 9 if tl == 'fork' else 12
        fin(c, [(x1 - 1, tb_top), (x1 + tail_len, mid - sp), (x1 + tail_len - 5, mid), (x1 + tail_len, mid + sp), (x1 - 1, tb_bot)], fc)
    elif tl == 'lunate':
        fin(c, [(x1 - 1, mid - 1), (x1 + tail_len * 0.5, mid - 4), (x1 + tail_len, mid - 12), (x1 + tail_len * 0.6, mid), (x1 + tail_len, mid + 12), (x1 + tail_len * 0.5, mid + 4), (x1 - 1, mid + 1)], fc)
    elif tl == 'round':
        fin(c, [(x1 - 1, tb_top), (x1 + tail_len * 0.7, mid - 7), (x1 + tail_len, mid - 3), (x1 + tail_len, mid + 3), (x1 + tail_len * 0.7, mid + 7), (x1 - 1, tb_bot)], fc)
    elif tl == 'truncate':
        fin(c, [(x1 - 1, tb_top), (x1 + tail_len, mid - 8), (x1 + tail_len, mid + 8), (x1 - 1, tb_bot)], fc)
    elif tl == 'shark':
        fin(c, [(x1 - 1, tb_top), (x1 + tail_len, mid - 13), (x1 + tail_len - 3, mid - 10), (x1 + 3, mid), (x1 + tail_len * 0.55, mid + 7), (x1 - 1, tb_bot)], fc, rays=False)
    dors = P['dorsal']
    def at(u):
        x = int(min(FWD - 1, max(0, x0 + u * Lpx)))
        return x, top[x], bot[x]
    if dors in ('two', 'spiny'):
        xa, ta, _ = at(0.32)
        xb, tbb, _ = at(0.55)
        if dors == 'spiny':
            pts = [(xa - 2, ta + 1)]
            for k in range(6):
                xk, tk, _ = at(0.3 + k * 0.05)
                pts += [(xk, tk - 6 + (k % 2) * 2), (xk + 1, tk - 3)]
            xe, te, _ = at(0.62)
            pts += [(xe, te - 4), (xe + 3, te + 1)]
            fin(c, pts, fc)
        else:
            fin(c, [(xa - 3, ta + 1), (xa, ta - 6), (xa + 4, ta + 1)], fc)
            fin(c, [(xb - 2, tbb + 1), (xb + 1, tbb - 4), (xb + 6, tbb + 1)], fc)
        xn, _, bn = at(0.62)
        fin(c, [(xn - 3, bn - 1), (xn, bn + 4), (xn + 4, bn - 1)], fc)
    elif dors == 'long':
        pts = []
        for k in range(10):
            xk, tk, _ = at(0.18 + k * 0.075)
            pts.append((xk, tk - 4 - (1 if k % 3 == 0 else 0)))
        xs0, ts0, _ = at(0.16)
        xs1, ts1, _ = at(0.9)
        fin(c, [(xs0, ts0 + 1)] + pts + [(xs1, ts1 + 1)], fc)
        xa0, _, ba0 = at(0.55)
        xa1, _, ba1 = at(0.9)
        fin(c, [(xa0, ba0 - 1), (xa0 + 2, ba0 + 4), (xa1, ba1 + 3), (xa1, ba1 - 1)], fc)
    elif dors == 'tuna':
        xa, ta, _ = at(0.36)
        fin(c, [(xa - 4, ta + 1), (xa - 1, ta - 7), (xa + 4, ta + 1)], fc)
        xb, tbb, _ = at(0.62)
        fin(c, [(xb - 2, tbb + 1), (xb + 1, tbb - 6), (xb + 3, tbb + 1)], fc)
        xn, _, bn = at(0.62)
        fin(c, [(xn - 2, bn - 1), (xn + 1, bn + 6), (xn + 3, bn - 1)], fc)
    elif dors == 'shark':
        xa, ta, _ = at(0.38)
        fin(c, [(xa - 5, ta + 1), (xa + 1, ta - 9), (xa + 5, ta + 1)], fc, rays=False)
        xb, tbb, _ = at(0.72)
        fin(c, [(xb - 2, tbb + 1), (xb, tbb - 4), (xb + 3, tbb + 1)], fc, rays=False)
        xn, _, bn = at(0.72)
        fin(c, [(xn - 2, bn - 1), (xn, bn + 3), (xn + 3, bn - 1)], fc, rays=False)
    elif dors == 'eel':
        pts_t = [(at(u)[0], at(u)[1] - 2) for u in np.linspace(0.25, 1.0, 12)]
        pts_b = [(at(u)[0], at(u)[2] + 2) for u in np.linspace(1.0, 0.45, 9)]
        fin(c, [(at(0.25)[0], at(0.25)[1] + 1)] + pts_t + [(x1 + 3, yc)] + pts_b + [(at(0.45)[0], at(0.45)[2] - 1)], fc, rays=False)
    elif dors == 'crest':
        pts_t = [(at(u)[0], at(u)[1] - 3 - (2 if i % 2 else 0)) for i, u in enumerate(np.linspace(0.02, 1.0, 22))]
        fin(c, [(at(0.02)[0], at(0.02)[1] + 1)] + pts_t + [(x1 + 2, yc)], '#e04a4a')
        fin(c, [(at(0.02)[0], at(0.02)[1]), (at(0.02)[0] + 2, at(0.02)[1] - 10), (at(0.08)[0], at(0.08)[1] - 9), (at(0.1)[0], at(0.1)[1])], '#e04a4a')
    elif dors == 'spine':
        xa, ta, _ = at(0.3)
        fin(c, [(xa - 1, ta + 1), (xa + 1, ta - 7), (xa + 2, ta + 1)], fc, rays=False)
        xb0, tb0, _ = at(0.55)
        xb1, tb1, _ = at(0.85)
        fin(c, [(xb0, tb0 + 1), (xb0 + 3, tb0 - 4), (xb1, tb1 - 3), (xb1, tb1 + 1)], fc)
        xa0, _, ba0 = at(0.55)
        xa1, _, ba1 = at(0.85)
        fin(c, [(xa0, ba0 - 1), (xa0 + 3, ba0 + 4), (xa1, ba1 + 3), (xa1, ba1 - 1)], fc)
    elif dors in ('tall', 'bat', 'filament', 'lion'):
        h_ = {'tall': 8, 'bat': 9, 'filament': 6, 'lion': 9}[dors]
        pts = []
        for k in range(8):
            xk, tk, _ = at(0.25 + k * 0.08)
            pts.append((xk, tk - h_ + (k * 0.6 if dors != 'bat' else -k * 0.2) + (2 if (dors == 'lion' and k % 2) else 0)))
        fin(c, [(at(0.22)[0], at(0.22)[1] + 1)] + pts + [(at(0.88)[0], at(0.88)[1] + 1)], fc)
        bpts = []
        for k in range(6):
            xk, _, bk = at(0.4 + k * 0.08)
            bpts.append((xk, bk + (h_ * 0.7 if dors in ('bat', 'tall') else 4) - k * 0.5))
        fin(c, [(at(0.38)[0], at(0.38)[2] - 1)] + bpts + [(at(0.88)[0], at(0.88)[2] - 1)], fc)
        if dors == 'filament':
            fx, ft, _ = at(0.35)
            c.paint(line_mask(FWD, FHT, [(fx, ft - h_), (fx + 14, ft - h_ - 8), (fx + 30, ft - h_ - 4)], 1), '#f4f0e0', shade=False)
    elif dors in ('marlin', 'sail'):
        hh = 10 if dors == 'marlin' else 18
        pts = [(at(0.12)[0], at(0.12)[1] + 1), (at(0.16)[0], at(0.16)[1] - hh)]
        for k in range(6):
            xk, tk, _ = at(0.22 + k * 0.08)
            pts.append((xk, tk - hh * (0.95 - k * 0.12) if dors == 'sail' else tk - hh * max(0.15, 0.8 - k * 0.18)))
        pts.append((at(0.72)[0], at(0.72)[1] + 1))
        fin(c, pts, fc)
        xn, _, bn = at(0.62)
        fin(c, [(xn - 2, bn - 1), (xn + 1, bn + 5), (xn + 3, bn - 1)], fc)
    elif dors == 'rear':
        xb, tbb, _ = at(0.75)
        fin(c, [(xb - 3, tbb + 1), (xb, tbb - 4), (xb + 4, tbb + 1)], fc)
        xn, _, bn = at(0.75)
        fin(c, [(xn - 3, bn - 1), (xn, bn + 4), (xn + 4, bn - 1)], fc)
    elif dors == 'small':
        xb, tbb, _ = at(0.62)
        fin(c, [(xb - 2, tbb + 1), (xb + 1, tbb - 4), (xb + 4, tbb + 1)], fc)
        xn, _, bn = at(0.62)
        fin(c, [(xn - 2, bn - 1), (xn + 1, bn + 3), (xn + 4, bn - 1)], fc)
    if P.get('finlets'):
        for u in (0.8, 0.86, 0.92):
            xf, tf, bf = at(u)
            c.dots([(xf, int(tf) - 1), (xf, int(bf) + 1)], ramp(fc)[3])
    if P.get('wings'):
        xw, tw, bw = at(0.3)
        fin(c, [(xw, (tw + bw) / 2), (xw + 26, tw - 12), (xw + 32, tw - 8), (xw + 6, (tw + bw) / 2 + 2)], fc)
    if P.get('fans'):
        xw, tw, bw = at(0.3)
        for k in range(5):
            c.paint(line_mask(FWD, FHT, [(xw, (tw + bw) / 2 + 2), (xw + 6 + k * 3, bw + 8 - k)], 1), '#f4ece0', shade=False)

    # ----- bill, saw, snout (in front of the head)
    if P.get('bill'):
        c.paint(poly(FWD, FHT, [(x0 + 2, yc - 2), (x0 - P['bill'], yc - 1), (x0 + 2, yc + 1)]), L['c1'], shade=False)
    if P.get('saw'):
        sm = rect(FWD, FHT, x0 - P['saw'], int(yc) - 1, x0 + 2, int(yc))
        c.paint(sm, L['c2'], shade=False)
        for k in range(0, P['saw'], 3):
            c.dots([(int(x0 - P['saw'] + k), int(yc) - 2), (int(x0 - P['saw'] + k), int(yc) + 1)], '#f4f0e0')
    if P.get('snout'):
        c.paint(poly(FWD, FHT, [(x0 + 3, yc - 3), (x0 - P['snout'], yc - 1), (x0 - P['snout'], yc + 1), (x0 + 3, yc + 1)]), L['c2'], shade=False)

    # ----- the body
    t = body_colour(c, body, top, bot, x0, x1, L['c1'], L['c2'], L['c3'], seed)
    pattern(c, body, t, L['pat'], L['pc'], x0, x1, top, bot, seed)
    if P.get('spines'):
        hv = hashmap(FWD, FHT, seed + 5, 1)
        edge = body & ~np.roll(body, 1, 0) | body & ~np.roll(body, -1, 0)
        c.rgb[edge & (hv > 0.6)] = ramp(L['c1'])[1]
    if P.get('tassels'):
        for k in range(4):
            xk, tk, bk = at(0.02 + k * 0.03)
            c.dots([(xk, int(bk) + 1), (xk, int(bk) + 2)], ramp(L['c2'])[2])
    # gill arc
    xg = int(x0 + Lpx * 0.2)
    if P.get('gills'):
        n = 6 if 'sixgill' in mods else P['gills']
        for k in range(n):
            gx = int(x0 + Lpx * (0.2 + k * 0.025))
            if 0 <= gx < FWD:
                for gy in range(int(top[gx] + 3), int(bot[gx] - 2)):
                    c.dots([(gx, gy)], ramp(L['c2'])[1])
    elif 0 <= xg < FWD and L['shape'] not in ('eel', 'ribbon', 'oar', 'gulper'):
        for gy in range(int(top[xg] + 2), int(bot[xg] - 1)):
            off = int(round(((gy - (top[xg] + bot[xg]) / 2) / max(1, (bot[xg] - top[xg]) / 2)) ** 2 * 2))
            c.dots([(xg + off, gy)], ramp(L['c2'])[1])
    # pectoral fin on top of the body
    pec = P.get('pec', 1.0)
    xp, tp, bp = at(0.24)
    py = (tp + bp) / 2 + 2
    fin(c, [(xp, py - 1), (xp + 6 * pec, py + 3 * pec), (xp + 2, py + 2)], fc, behind_mask=True)
    # mouth
    mw = P.get('mouth', 2)
    mx0 = x0 + 0.5
    my = yc + 1 if L['shape'] not in ('flathead',) else yc
    c.dots([(int(mx0 + k), int(my)) for k in range(mw)], ramp(L['c2'])[0])
    if P.get('beak'):
        c.paint(ellipse(FWD, FHT, x0 + 2, yc, 2.2, 2.4), '#f0ece0', shade=False)
    if mw >= 10:
        teeth = [(int(mx0 + k), int(my) - 1) for k in range(0, mw, 2)] + [(int(mx0 + k + 1), int(my) + 1) for k in range(0, mw, 2)]
        c.dots(teeth, '#f4f0e8')
    if P.get('lure'):
        lx, lt, _ = at(0.12)
        c.paint(line_mask(FWD, FHT, [(lx + 2, lt), (lx - 2, lt - 8), (lx - 6, lt - 9)], 1), ramp(L['c1'])[2], shade=False)
        c.paint(ellipse(FWD, FHT, lx - 7, lt - 9, 2, 2), L['pc'], shade=False)
    # eye
    ex = x0 + Lpx * (0.11 if L['shape'] not in ('mahi', 'chimaera') else 0.13)
    ix = int(min(FWD - 1, max(0, ex)))
    ey = top[ix] + (bot[ix] - top[ix]) * 0.38
    er = P['eye']
    eye_c = '#5ab0f0' if 'blueeye' in mods else '#f4ecc8'
    c.paint(ellipse(FWD, FHT, ex, ey, er + 0.6, er + 0.6) & body, eye_c, shade=False)
    c.paint(ellipse(FWD, FHT, ex + 0.2, ey + 0.1, er * 0.65, er * 0.65), '#1a1622', shade=False)
    c.dots([(int(ex - er * 0.3), int(ey - er * 0.3))], '#ffffff')
    if 'crown' in mods:
        cx_, ct_, _ = at(0.22)
        for k in range(5):
            c.dots([(cx_ + k * 2, int(ct_) - 3 - (k % 2) * 2), (cx_ + k * 2, int(ct_) - 2)], '#ffd24d')
    return c


def legend_glow(img, color='#ffe680'):
    """A soft halo of sparkles around legends."""
    a = img[..., 3] > 0
    ring = np.zeros_like(a)
    for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        ring |= np.roll(np.roll(a, dy, 0), dx, 1)
    ring &= ~a
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    sparkle = ring & ((xx * 7 + yy * 13) % 9 == 0)
    img[sparkle] = (*hx(color), 255)
    return img


def special_ray(L, seed, eagle=False):
    c = Canvas(FWD, FHT)
    yy, xx = np.mgrid[0:FHT, 0:FWD]
    cx, cy = 30.0, 24.0
    rx, ry = 15.0, 21.0
    k = 1.15 if not eagle else 0.95
    disc = (np.abs((xx + 0.5 - cx) / rx) ** k + np.abs((yy + 0.5 - cy) / ry) ** k) <= 1.0
    if eagle:
        disc |= ellipse(FWD, FHT, cx - 15, cy, 4.5, 3.5)
    tail = line_mask(FWD, FHT, [(cx + 10, cy), (cx + 30, cy + 1), (cx + 46, cy + 3)], 2 if not eagle else 1)
    c.paint(tail, L['c1'], shade=False)
    c.paint(ellipse(FWD, FHT, cx + 13, cy, 3, 2.5), L['c1'])
    m = disc
    r1 = ramp(L['c1'])
    d = np.sqrt(((xx + 0.5 - cx + 4) / rx) ** 2 + ((yy + 0.5 - cy + 5) / ry) ** 2)
    pid = len(c.ramps)
    c.ramps.append(r1)
    c.flags.append(False)
    tone = np.clip((d * 3.2 + (BAYER4[yy % 4, xx % 4] - 0.5)).astype(int), 0, 3)
    pal = np.array([r1[4], r1[3], r1[3], r1[2]])
    c.rgb[m] = pal[tone[m]]
    c.part[m] = pid
    if L['pat'] == 'spots':
        hv = hashmap(FWD, FHT, seed, 2)
        sp = m & (hv > 0.84) & ((xx + yy) % 2 == 0)
        c.rgb[sp] = ramp(L['pc'])[3]
    for ey in (cy - 4, cy + 4):
        c.dots([(int(cx - 9), int(ey)), (int(cx - 8), int(ey))], '#1a1622')
        c.dots([(int(cx - 7), int(ey))], ramp(L['c1'])[4])
    return c


def special_guitar(L, seed):
    c = Canvas(FWD, FHT)
    cy = 24.0
    head = poly(FWD, FHT, [(4, cy), (24, cy - 12), (34, cy - 9), (36, cy), (34, cy + 9), (24, cy + 12)])
    body = poly(FWD, FHT, [(30, cy - 6), (64, cy - 3), (74, cy - 1), (74, cy + 1), (64, cy + 3), (30, cy + 6)])
    fin(c, [(66, cy - 2), (78, cy - 8), (76, cy), (78, cy + 6), (66, cy + 2)], L['fc'])
    c.paint(body | head, L['c1'], light=(-1, -1))
    for xx_ in (44, 58):
        c.paint(ellipse(FWD, FHT, xx_, cy, 3, 1.6), ramp(L['c1'])[2], shade=False)
    if L['pat'] == 'lines':
        yy, xx = np.mgrid[0:FHT, 0:FWD]
        m = (head | body) & ((yy % 4) == 0) & (xx > 10)
        c.rgb[m] = ramp(L['pc'])[3]
    c.dots([(14, int(cy) - 3), (14, int(cy) + 3)], '#1a1622')
    return c


def special_squid(L, seed, cuttle=False):
    c = Canvas(FWD, FHT)
    cy = 24.0
    # arms trailing to the left
    arms = c.mask()
    for k in range(8):
        a = (k - 3.5) * 0.12
        pts = [(30, cy + (k - 3.5) * 0.8)]
        for t in np.linspace(0.2, 1, 6):
            pts.append((30 - t * (20 if not cuttle else 10), cy + (k - 3.5) * 1.6 * t + math.sin(t * 5 + k) * 1.5))
        arms |= line_mask(FWD, FHT, pts, 2 if not cuttle else 2)
    if not cuttle:
        for side in (-1, 1):
            arms |= line_mask(FWD, FHT, [(30, cy), (16, cy + side * 3), (4, cy + side * 6)], 1)
            arms |= ellipse(FWD, FHT, 4, cy + side * 6, 2, 1.5)
    c.paint(arms, L['c2'], line=True)
    if cuttle:
        skirt = ellipse(FWD, FHT, 50, cy, 24, 12)
        fin(c, [(28, cy - 9), (50, cy - 13), (72, cy - 9), (74, cy), (72, cy + 9), (50, cy + 13), (28, cy + 9)], L['fc'])
        mantle = ellipse(FWD, FHT, 50, cy, 21, 10)
    else:
        fin(c, [(62, cy - 2), (77, cy - 10), (76, cy), (77, cy + 10), (62, cy + 2)], L['fc'])
        mantle = ellipse(FWD, FHT, 52, cy, 22, 7) | ellipse(FWD, FHT, 34, cy, 6, 6)
    top = np.full(FWD, cy - 10.0)
    bot = np.full(FWD, cy + 10.0)
    t = body_colour(c, mantle, top, bot, 28, 74, L['c1'], L['c2'], L['c3'], seed)
    pattern(c, mantle, t, L['pat'], L['pc'], 28, 74, top, bot, seed)
    ex, ey = (34, cy - 1)
    c.paint(ellipse(FWD, FHT, ex, ey, 3, 3), '#f4ecc8', shade=False)
    c.paint(ellipse(FWD, FHT, ex, ey + 0.3, 1.8, 1.4 if cuttle else 1.8), '#1a1622', shade=False)
    c.dots([(ex - 1, int(ey) - 1)], '#ffffff')
    return c


def special_octo(L, seed):
    c = Canvas(FWD, FHT)
    arms = c.mask()
    rng = np.random.RandomState(seed)
    for k in range(8):
        base = (34 + k * 2.2, 26)
        pts = [base]
        ang = math.pi * (0.55 + k * 0.08)
        for t in np.linspace(0.15, 1, 8):
            pts.append((base[0] + math.cos(ang) * t * 26 + math.sin(t * 6 + k) * 2.5 * t, base[1] + math.sin(ang) * t * 14 + t * 6))
        arms |= line_mask(FWD, FHT, pts, 3 if k % 2 else 2)
    c.paint(arms, L['c2'], line=True)
    yy, xx = np.mgrid[0:FHT, 0:FWD]
    suckers = arms & ((xx + yy) % 4 == 0)
    c.rgb[suckers] = ramp(L['c3'])[3]
    head = ellipse(FWD, FHT, 46, 15, 13, 11) | ellipse(FWD, FHT, 42, 24, 9, 5)
    top = np.full(FWD, 4.0)
    bot = np.full(FWD, 29.0)
    t = body_colour(c, head, top, bot, 30, 60, L['c1'], L['c2'], L['c3'], seed)
    pattern(c, head, t, L['pat'], L['pc'], 30, 60, top, bot, seed)
    for ex in (38, 46):
        c.paint(ellipse(FWD, FHT, ex, 21, 2.4, 2.4), '#f4ecc8', shade=False)
        c.paint(rect(FWD, FHT, ex - 1, 21, ex + 1, 21), '#1a1622', shade=False)
    return c


def special_seahorse(L, seed, dragon=False):
    c = Canvas(FWD, FHT)
    cx = 40
    pts = [(cx - 2, 8), (cx + 4, 12), (cx + 6, 20), (cx + 4, 28), (cx, 34), (cx + 2, 40), (cx + 8, 41), (cx + 8, 37)]
    body = c.mask()
    widths = [7, 8, 9, 9, 7, 4, 3, 2]
    for i in range(len(pts) - 1):
        body |= line_mask(FWD, FHT, [pts[i], pts[i + 1]], widths[i])
    body |= ellipse(FWD, FHT, cx - 1, 9, 5, 4.5)
    snout = poly(FWD, FHT, [(cx - 4, 7), (cx - 14, 9), (cx - 14, 11), (cx - 4, 11)])
    fin(c, [(cx + 7, 18), (cx + 13, 16), (cx + 13, 24), (cx + 7, 24)], L['fc'])
    top = np.full(FWD, 4.0)
    bot = np.full(FWD, 44.0)
    m = body | snout
    t = body_colour(c, m, np.full(FWD, 0.0), np.full(FWD, 44.0), cx - 14, cx + 10, L['c1'], L['c2'], L['c3'], seed)
    yy, xx = np.mgrid[0:FHT, 0:FWD]
    ridges = m & (yy % 3 == 0) & (yy > 12)
    c.rgb[ridges] = ramp(L['c1'])[2]
    pattern(c, m, t, L['pat'], L['pc'], cx - 14, cx + 10, top, bot, seed)
    c.paint(ellipse(FWD, FHT, cx - 2, 8, 1.6, 1.6), '#1a1622', shade=False)
    c.dots([(cx - 3, 7)], '#ffffff')
    c.dots([(cx, 3), (cx + 1, 2), (cx + 2, 3)], ramp(L['c1'])[2])
    if dragon:
        rng = np.random.RandomState(seed)
        for (lx, ly) in ((cx + 8, 12), (cx + 10, 28), (cx - 4, 22), (cx + 4, 36), (cx - 6, 14), (cx + 12, 34)):
            c.paint(ellipse(FWD, FHT, lx, ly, 3.5, 2), L['fc'], soft=True)
    return c


def special_crab(L, seed):
    c = Canvas(FWD, FHT)
    cx, cy = 40.0, 28.0
    legs = c.mask()
    for side in (-1, 1):
        for k in range(4):
            ax = cx + side * 10
            ay = cy - 2 + k * 3
            knee = (ax + side * 9, ay - 4 + k)
            foot = (ax + side * 15, ay + 4 + k * 1.5)
            legs |= line_mask(FWD, FHT, [(ax, ay), knee, foot], 2)
    c.paint(legs, L['c1'], line=True)
    for side in (-1, 1):
        arm = line_mask(FWD, FHT, [(cx + side * 8, cy - 5), (cx + side * 14, cy - 12), (cx + side * 13, cy - 18)], 3)
        c.paint(arm, L['c1'], line=True)
        claw = ellipse(FWD, FHT, cx + side * 13, cy - 20, 5, 4) & ~poly(FWD, FHT, [(cx + side * 13, cy - 20), (cx + side * 11, cy - 27), (cx + side * 15, cy - 27)])
        c.paint(claw, L['c2'], light=(-1, -1))
        c.dots([(int(cx + side * 13), int(cy - 24))], ramp(L['fc'])[1])
    shell = ellipse(FWD, FHT, cx, cy, 15, 9) | poly(FWD, FHT, [(cx - 15, cy - 1), (cx - 19, cy - 4), (cx - 13, cy - 4)]) | poly(FWD, FHT, [(cx + 15, cy - 1), (cx + 19, cy - 4), (cx + 13, cy - 4)])
    t = body_colour(c, shell, np.full(FWD, cy - 9), np.full(FWD, cy + 9), cx - 15, cx + 15, L['c1'], L['c2'], L['c3'], seed)
    pattern(c, shell, t, L['pat'], L['pc'], cx - 15, cx + 15, np.full(FWD, cy - 9), np.full(FWD, cy + 9), seed)
    for side in (-1, 1):
        c.paint(line_mask(FWD, FHT, [(cx + side * 3, cy - 8), (cx + side * 4, cy - 12)], 1), L['c1'], shade=False)
        c.dots([(int(cx + side * 4), int(cy - 13))], '#1a1622')
    return c


def special_lobster(L, seed):
    c = Canvas(FWD, FHT)
    cy = 24.0
    ant = line_mask(FWD, FHT, [(24, cy - 3), (12, cy - 10), (2, cy - 8)], 1) | line_mask(FWD, FHT, [(24, cy + 3), (12, cy + 10), (2, cy + 12)], 1)
    c.paint(ant, L['c1'], shade=False)
    legs = c.mask()
    for k in range(4):
        x = 30 + k * 4
        legs |= line_mask(FWD, FHT, [(x, cy - 4), (x - 3, cy - 10)], 1) | line_mask(FWD, FHT, [(x, cy + 4), (x - 3, cy + 10)], 1)
    c.paint(legs, L['c1'], shade=False)
    fin(c, [(64, cy - 2), (76, cy - 9), (78, cy), (76, cy + 9), (64, cy + 2)], L['fc'])
    body = ellipse(FWD, FHT, 34, cy, 11, 6.5)
    for k in range(5):
        body |= ellipse(FWD, FHT, 46 + k * 4, cy, 4.5 - k * 0.3, 5.5 - k * 0.4)
    t = body_colour(c, body, np.full(FWD, cy - 7), np.full(FWD, cy + 7), 22, 66, L['c1'], L['c2'], L['c3'], seed)
    yy, xx = np.mgrid[0:FHT, 0:FWD]
    seg = body & (xx > 44) & ((xx - 44) % 4 == 0)
    c.rgb[seg] = ramp(L['c1'])[1]
    spines = body & ((xx + yy) % 5 == 0) & (xx < 44)
    c.rgb[spines] = ramp(L['c1'])[4]
    c.dots([(24, int(cy) - 3), (24, int(cy) + 3)], '#1a1622')
    return c


def draw_fish(look, seed, legend=False):
    L = parse_look(look)
    sh = L['shape']
    if sh == 'ray':
        c = special_ray(L, seed, eagle='eagle' in L['mods'])
    elif sh == 'guitar':
        c = special_guitar(L, seed)
    elif sh == 'squid':
        c = special_squid(L, seed)
    elif sh == 'cuttle':
        c = special_squid(L, seed, cuttle=True)
    elif sh == 'octo':
        c = special_octo(L, seed)
    elif sh == 'seahorse':
        c = special_seahorse(L, seed)
    elif sh == 'dragon':
        c = special_seahorse(L, seed, dragon=True)
    elif sh == 'crab':
        c = special_crab(L, seed)
    elif sh == 'lobster':
        c = special_lobster(L, seed)
    else:
        c = generic_fish(L, seed)
    img = c.finish()
    if legend or 'legend' in L['mods']:
        img = legend_glow(img)
    return img


def make_fish(preview):
    cat = json.load(open(os.path.join(ROOT, 'godot', 'data', 'catalog.json')))
    done = []
    for i, e in enumerate(cat['items']):
        if e['cat'] not in ('fish', 'legend'):
            continue
        img = draw_fish(e.get('look', e['art']), 1000 + i, e['cat'] == 'legend')
        save(img, 'fish2/%s.png' % e['id'])
        done.append((e['id'], img))
    # everything else (junk, treasure, shells...) is upscaled cleanly from the old art
    for e in cat['items']:
        if e['cat'] in ('fish', 'legend'):
            continue
        src = os.path.join(OUT, 'fish', e['id'] + '.png')
        if os.path.exists(src):
            save(scale2x(np.array(Image.open(src).convert('RGBA'))), 'fish2/%s.png' % e['id'])
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        cols = 10
        for page in range(0, len(done), 60):
            chunk = done[page:page + 60]
            rows = (len(chunk) + cols - 1) // cols
            sheet = np.zeros((rows * FHT, cols * FWD, 4), np.uint8)
            for k, (_, img) in enumerate(chunk):
                r, col = divmod(k, cols)
                sheet[r * FHT:(r + 1) * FHT, col * FWD:(col + 1) * FWD] = img
            bg = np.zeros_like(sheet)
            bg[..., :3] = (40, 70, 100)
            a = sheet[..., 3:4] / 255.0
            comp = (sheet[..., :3] * a + bg[..., :3] * (1 - a)).astype(np.uint8)
            Image.fromarray(comp).resize((comp.shape[1] * 2, comp.shape[0] * 2), Image.NEAREST).save(PREVIEW + '/fish_%d.png' % (page // 60))
    print('fish:', len(done))


def scale2x(img):
    """EPX / Scale2x: doubles pixel art without blurring it."""
    h, w = img.shape[:2]
    out = np.zeros((h * 2, w * 2, 4), np.uint8)
    pad = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='edge')
    eq = lambda a, b: np.all(a == b, axis=-1)
    P_ = pad[1:-1, 1:-1]
    A = pad[:-2, 1:-1]
    B = pad[1:-1, 2:]
    C = pad[1:-1, :-2]
    D = pad[2:, 1:-1]
    for (dy, dx), (n1, n2, o1, o2) in (((0, 0), (C, A, D, B)), ((0, 1), (A, B, C, D)), ((1, 0), (D, C, B, A)), ((1, 1), (B, D, A, C))):
        cond = eq(n1, n2) & ~eq(n1, o1) & ~eq(n2, o2)
        res = np.where(cond[..., None], n1, P_)
        out[dy::2, dx::2] = res
    return out


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    preview = '--preview' in sys.argv
    if what in ('characters', 'all'):
        make_characters(preview)
    if what in ('cats', 'all'):
        make_cats(preview)
    if what in ('plants', 'all'):
        make_plants(preview)
    if what in ('fish', 'all'):
        make_fish(preview)
