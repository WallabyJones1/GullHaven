"""Gullhaven HD-2D interior art: floors, walls and the decor that furnishes every room.
Usage: python3 tools/godot_interior_art.py [--preview]

Tiling 64x64 floor and wall textures go to godot/art/tex/, decor sprites (shelves, rod
racks, fireplaces, paintings, charts, nets, lanterns, the forge...) to godot/art/decor/.
Same palette rules as tools/godot_art.py: hue-shifted ramps, dark selective outlines,
light from the top left."""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_art import OUT, PREVIEW, hashmap, hx, ramp, shift  # noqa: E402


class Pix:
    """A small RGBA pixel canvas with shaded shapes and an outline pass."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, :3] = hx(c) if isinstance(c, str) else c
            self.a[y, x, 3] = 255

    def rect(self, x0, y0, x1, y1, c):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(self.w - 1, int(x1)), min(self.h - 1, int(y1))
        if x1 < x0 or y1 < y0:
            return
        self.a[y0:y1 + 1, x0:x1 + 1, :3] = hx(c) if isinstance(c, str) else c
        self.a[y0:y1 + 1, x0:x1 + 1, 3] = 255

    def box(self, x0, y0, x1, y1, base, edge=True):
        """A lit box: highlight on the top and left, shadow on the bottom and right."""
        r = ramp(base)
        self.rect(x0, y0, x1, y1, r[3])
        self.rect(x0, y0, x1, y0, r[4])
        self.rect(x0, y0, x0, y1, r[4])
        self.rect(x0, y1, x1, y1, r[1])
        self.rect(x1, y0, x1, y1, r[2])
        if edge:
            self.px(x0, y0, r[5])

    def ellipse(self, cx, cy, rx, ry, c):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        m = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0
        self.a[m, :3] = hx(c) if isinstance(c, str) else c
        self.a[m, 3] = 255

    def ring(self, cx, cy, r0, r1, c):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        d = np.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
        m = (d <= r1) & (d >= r0)
        self.a[m, :3] = hx(c) if isinstance(c, str) else c
        self.a[m, 3] = 255

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n):
            t = i / max(1, n - 1)
            self.px(int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), c)

    def outline(self, c=None):
        alpha = self.a[..., 3] > 0
        out = np.zeros_like(alpha)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(alpha, dy, 0), dx, 1)
            if dy == 1:
                sh[0, :] = False
            if dy == -1:
                sh[-1, :] = False
            if dx == 1:
                sh[:, 0] = False
            if dx == -1:
                sh[:, -1] = False
            out |= sh & ~alpha
        if c is None:
            # darken the colour of the neighbouring pixel
            ys, xs = np.nonzero(out)
            for y, x in zip(ys, xs):
                best = None
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and alpha[ny, nx]:
                        best = tuple(self.a[ny, nx, :3])
                        break
                self.a[y, x, :3] = ramp(best)[0] if best else (20, 18, 30)
                self.a[y, x, 3] = 255
        else:
            self.a[out, :3] = hx(c)
            self.a[out, 3] = 255
        return self

    def save(self, rel):
        path = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(self.a, 'RGBA').save(path)
        return self.a


# ===================================================================== tiling floors and walls

def floor_wood(base='#a8743f', seed=1):
    p = Pix(64, 64)
    r = ramp(base)
    n = hashmap(64, 64, seed, 1)
    for row in range(8):  # boards 8 px wide, running left to right
        y0 = row * 8
        off = (row * 23) % 64
        tone = r[3] if row % 3 else shift(hx(base), -0.06)
        p.rect(0, y0, 63, y0 + 7, tone)
        p.rect(0, y0, 63, y0, r[4])
        p.rect(0, y0 + 7, 63, y0 + 7, r[1])
        for x in range(64):  # grain
            if n[y0 + 3, x] > 0.86:
                p.px(x, y0 + 3, r[2])
            if n[y0 + 5, x] > 0.9:
                p.px(x, y0 + 5, r[2])
        for j in (off, (off + 40) % 64):  # board ends with nails
            p.rect(j, y0, j, y0 + 6, r[1])
            p.px((j + 2) % 64, y0 + 2, r[0])
            p.px((j + 2) % 64, y0 + 5, r[0])
    return p


def floor_tile(a='#c86a48', b='#ead8b8'):
    p = Pix(64, 64)
    for ty in range(4):
        for tx in range(4):
            c = a if (tx + ty) % 2 == 0 else b
            p.box(tx * 16, ty * 16, tx * 16 + 15, ty * 16 + 15, c)
            r = ramp(c)
            p.rect(tx * 16 + 4, ty * 16 + 4, tx * 16 + 11, ty * 16 + 11, r[3])
            p.px(tx * 16 + 7, ty * 16 + 7, r[4])
            p.px(tx * 16 + 8, ty * 16 + 8, r[2])
    return p


def floor_stone(base='#8a8478', seed=3):
    p = Pix(64, 64)
    r = ramp(base)
    p.rect(0, 0, 63, 63, r[1])
    rows = [(0, 15), (16, 33), (34, 47), (48, 63)]
    n = hashmap(64, 64, seed, 2)
    for i, (y0, y1) in enumerate(rows):
        x = (i * 13) % 20 - 20
        while x < 64:
            w = 14 + int(n[y0, max(0, x) % 64] * 12)
            c = shift(hx(base), (n[y1, (x + 3) % 64] - 0.5) * 0.16)
            for k in range(2):  # draw wrapped
                xs = x + k * 64
                p.box(max(0, xs + 1), y0 + 1, min(63, xs + w - 1), y1 - 1, c)
            x += w
    for y in range(64):
        for x in range(64):
            if n[y, x] > 0.93 and p.a[y, x, 0] > r[1][0]:
                p.px(x, y, ramp(tuple(p.a[y, x, :3]))[2])
    return p


def wall_paper(base='#ece0c4', motif='#c8a88a', seed=4):
    p = Pix(64, 64)
    p.rect(0, 0, 63, 63, base)
    r = ramp(base)
    for x in range(0, 64, 16):  # faint stripes
        p.rect(x, 0, x + 1, 63, r[2] if False else shift(hx(base), -0.04))
    for y in range(4, 64, 16):
        for x in range(8, 64, 16):
            oy = 8 if (x // 16) % 2 else 0
            yy = (y + oy) % 64
            p.px(x, yy - 1, motif)
            p.px(x - 1, yy, motif)
            p.px(x + 1, yy, motif)
            p.px(x, yy + 1, motif)
            p.px(x, yy, shift(hx(motif), 0.2))
    return p


def wall_wood(base='#8a5a34', seed=5):
    p = Pix(64, 64)
    r = ramp(base)
    n = hashmap(64, 64, seed, 1)
    for col in range(8):
        x0 = col * 8
        tone = r[3] if col % 2 else shift(hx(base), 0.05)
        p.rect(x0, 0, x0 + 7, 63, tone)
        p.rect(x0, 0, x0, 63, r[4])
        p.rect(x0 + 7, 0, x0 + 7, 63, r[1])
        for y in range(64):
            if n[y, x0 + 3] > 0.85:
                p.px(x0 + 3, y, r[2])
        knot = int(n[5, x0] * 50) + 6
        p.px(x0 + 4, knot, r[1])
        p.px(x0 + 4, knot + 1, r[2])
    return p


def wall_plaster(base='#e8dcc8', seed=6):
    p = Pix(64, 64)
    p.rect(0, 0, 63, 63, base)
    n = hashmap(64, 64, seed, 2)
    r = ramp(base)
    for y in range(64):
        for x in range(64):
            v = n[y, x]
            if v > 0.9:
                p.px(x, y, shift(hx(base), -0.05))
            elif v < 0.05:
                p.px(x, y, r[4])
    return p


# ===================================================================== decor sprites

WOOD = '#9a6a3c'
DARKWOOD = '#6a4428'
IRON = '#4a4a58'
BRASS = '#d8a840'


def bookshelf():
    p = Pix(48, 64)
    p.box(0, 0, 47, 63, DARKWOOD)
    p.rect(3, 3, 44, 60, ramp(DARKWOOD)[1])
    cols = ['#b84a3a', '#3a6aa8', '#4a8a4a', '#d8b050', '#7a4a8a', '#e8e0c8', '#3a8a8a', '#a85a2a']
    n = hashmap(48, 64, 9, 1)
    for s, y in enumerate((4, 19, 34, 49)):
        x = 4
        k = s * 3
        while x < 43:
            w = 2 + int(n[y, x] * 3)
            h = 10 + int(n[y + 1, x] * 3)
            c = cols[(k * 5 + x) % len(cols)]
            if n[y + 2, x] > 0.85 and x < 38:  # a leaning book
                for i in range(h):
                    p.rect(x + i // 4, y + 13 - i, x + i // 4 + w - 1, y + 13 - i, c)
                x += w + 3
            else:
                p.box(x, y + 13 - h, x + w - 1, y + 13, c, edge=False)
                p.px(x + w // 2, y + 15 - h, shift(hx(c), 0.35))
                x += w
            k += 1
        p.box(2, y + 14, 45, y + 15, WOOD)
    return p.outline()


def shelf(kind):
    p = Pix(48, 40)
    for y in (16, 36):
        p.box(0, y, 47, y + 3, WOOD)
        p.rect(4, y + 4, 5, y + 6, ramp(WOOD)[1])
        p.rect(42, y + 4, 43, y + 6, ramp(WOOD)[1])
    n = hashmap(48, 40, 11 if kind == 'jars' else 12, 1)
    for row, y in enumerate((16, 36)):
        x = 3
        while x < 42:
            if kind == 'jars':
                c = ['#d8a840', '#c84a3a', '#5a9a4a', '#e8e0d0', '#7a4a2a'][int(n[y, x] * 5)]
                h = 7 + int(n[y - 1, x] * 6)
                w = 5
                p.box(x, y - h, x + w, y - 1, '#b8d8e0')
                p.rect(x + 1, y - h + 3, x + w - 1, y - 2, c)
                p.rect(x, y - h - 1, x + w, y - h, '#c8a060')
                p.px(x + 1, y - h + 1, '#ffffff')
                x += w + 2
            else:  # bait tins and tackle boxes
                if n[y, x] > 0.6:
                    p.box(x, y - 5, x + 7, y - 1, ['#c84a3a', '#3a7ab8', '#d8a840'][int(n[y - 2, x] * 3)])
                    p.rect(x + 2, y - 4, x + 5, y - 3, '#e8e0c8')
                    x += 9
                else:
                    p.box(x, y - 9, x + 5, y - 1, '#8a9aa8')
                    p.rect(x + 1, y - 6, x + 4, y - 3, '#7a5a3a' if n[y - 3, x] > 0.5 else '#e86a8a')
                    p.rect(x, y - 10, x + 5, y - 10, '#5a5a6a')
                    x += 7
    return p.outline()


def rod_rack():
    p = Pix(48, 56)
    p.box(0, 50, 47, 55, DARKWOOD)
    p.box(0, 6, 47, 9, DARKWOOD)
    rods = ['#c8a050', '#3a3a48', '#2a6a5a', '#b84a3a', '#d8d0c0', '#5a4a8a']
    for i, c in enumerate(rods):
        x = 4 + i * 7
        p.rect(x, 1 + (i % 2) * 2, x, 52, c)
        p.rect(x + 1, 1 + (i % 2) * 2, x + 1, 52, shift(hx(c), -0.3))
        p.rect(x - 1, 38, x + 2, 46, '#3a2a20')  # cork grip
        p.rect(x - 1, 39, x + 2, 40, '#c8a070')
        p.ellipse(x + 3.5, 34.5, 2.2, 2.2, '#8a8a98')  # reel
        p.px(x + 3, 33, '#e8e8f0')
        for gy in (12, 22, 30):
            p.px(x + 2, gy, '#d8d8e0')
    return p.outline()


def window():
    """The frame only: the panes stay clear so the glow behind shows through."""
    p = Pix(32, 36)
    p.box(0, 0, 31, 31, '#e8e0d0')
    p.a[3:29, 3:29, 3] = 0
    p.rect(15, 3, 16, 28, '#e8e0d0')
    p.rect(3, 15, 28, 16, '#e8e0d0')
    p.rect(17, 3, 17, 28, '#b8b0a0')
    p.rect(3, 17, 28, 17, '#b8b0a0')
    p.box(0, 31, 31, 35, WOOD)  # sill
    p.box(4, 27, 11, 31, '#c86a48')  # a pot plant on the sill
    p.ellipse(7.5, 25, 5, 4, '#4a8a3a')
    p.px(6, 23, '#7ac85a')
    p.px(9, 22, '#e86a8a')
    return p.outline()


def fireplace():
    p = Pix(56, 52)
    stone = '#9a9088'
    n = hashmap(56, 52, 21, 1)
    for row, y in enumerate(range(0, 52, 7)):
        off = (row % 2) * 6
        for x in range(-off, 56, 12):
            c = shift(hx(stone), (n[y, max(0, x) % 56] - 0.5) * 0.18)
            p.box(max(0, x), y, min(55, x + 11), min(51, y + 6), c)
    p.box(0, 10, 55, 14, DARKWOOD)  # mantel
    p.a[22:52, 12:44, :3] = hx('#1a1418')
    p.a[22:52, 12:44, 3] = 255
    p.ellipse(28, 23, 16, 6, '#1a1418')
    for x in range(14, 43, 4):  # soot back
        p.px(x, 30 + (x % 3), '#2a2228')
    p.box(15, 46, 40, 49, '#5a3a24')  # logs
    p.box(18, 43, 38, 46, '#6a4428')
    p.box(8, 3, 13, 9, '#d8a840')  # candlestick and a jar on the mantel
    p.rect(10, 0, 11, 2, '#f0e8d0')
    p.box(40, 4, 46, 9, '#3a7ab8')
    return p.outline()


def fire_frames():
    """Four 16x16 flame frames in a row."""
    p = Pix(64, 16)
    for f in range(4):
        n = hashmap(16, 16, 40 + f, 1)
        for y in range(16):
            for x in range(16):
                dx = abs(x - 7.5) / 7.5
                top = 15 - (12 - dx * 10) * (0.75 + n[0, x] * 0.4)
                if y >= top:
                    t = (y - top) / max(1.0, 15 - top)
                    c = '#fff4b0' if t > 0.65 and dx < 0.45 else ('#ffb040' if t > 0.3 else '#e85a2a')
                    p.px(f * 16 + x, y, c)
    return p


def painting(kind):
    p = Pix(32, 24)
    p.box(0, 0, 31, 23, '#c8983a')
    p.rect(2, 2, 29, 21, '#7a5a2a')
    if kind == 'sea':
        p.rect(3, 3, 28, 12, '#a8d0e8')
        p.rect(3, 13, 28, 20, '#3a6aa8')
        p.ellipse(22, 7, 3, 3, '#fff0b0')
        for x in range(3, 29, 3):
            p.px(x, 14 + (x % 2), '#a8d0e8')
        p.rect(8, 9, 9, 13, '#e8e0d0')  # a far sail
        p.rect(10, 11, 10, 13, '#e8e0d0')
    elif kind == 'boat':
        p.rect(3, 3, 28, 20, '#e8d8b0')
        p.rect(3, 15, 28, 20, '#4a7ab0')
        p.rect(9, 12, 22, 14, '#b84a3a')
        p.rect(10, 15, 21, 15, '#8a2a2a')
        p.rect(15, 4, 15, 11, '#5a3a24')
        p.rect(16, 5, 21, 11, '#f4f0e8')
    else:  # a portrait of the town's founder
        p.rect(3, 3, 28, 20, '#4a5a4a')
        p.ellipse(16, 10, 5, 6, '#e8b890')
        p.rect(9, 15, 23, 20, '#2a3a6a')
        p.rect(11, 4, 21, 6, '#e8e4dc')
        p.px(14, 10, '#2a2020')
        p.px(18, 10, '#2a2020')
    return p.outline()


def chart():
    p = Pix(44, 30)
    p.box(0, 0, 43, 29, '#e8dcb8')
    p.rect(2, 2, 41, 27, '#c8dce0')
    n = hashmap(44, 30, 31, 2)
    for y in range(3, 27):
        for x in range(3, 41):
            d = ((x - 14) / 9) ** 2 + ((y - 13) / 7) ** 2
            if d < 1.0 + (n[y, x] - 0.5) * 0.5:
                p.px(x, y, '#d8c890')
            elif ((x - 32) / 4) ** 2 + ((y - 20) / 3) ** 2 < 1:
                p.px(x, y, '#d8c890')
    p.line(20, 16, 31, 20, '#b84a3a')  # a dotted route
    for x in range(20, 32, 2):
        p.px(x, 16 + (x - 20) // 3, '#e8dcb8')
    p.ring(36, 7, 2, 4, '#5a5a6a')  # compass rose
    p.rect(36, 2, 36, 12, '#5a5a6a')
    p.px(5, 25, '#3a6aa8')
    return p.outline()


def notice_board():
    p = Pix(40, 34)
    p.box(0, 0, 39, 29, DARKWOOD)
    p.rect(2, 2, 37, 27, '#b88a5a')
    papers = [(4, 4, 13, 15, '#f4f0e0'), (16, 3, 25, 11, '#f0e0a0'), (27, 5, 35, 16, '#f4f0e0'), (6, 17, 17, 25, '#e8d8f0'),
              (21, 14, 32, 25, '#f4f0e0')]
    for x0, y0, x1, y1, c in papers:
        p.box(x0, y0, x1, y1, c)
        for ly in range(y0 + 3, y1 - 1, 2):
            p.rect(x0 + 2, ly, x1 - 2, ly, '#8a8a9a')
        p.px((x0 + x1) // 2, y0 + 1, '#c84a3a')
    p.rect(4, 29, 6, 33, DARKWOOD)
    p.rect(33, 29, 35, 33, DARKWOOD)
    return p.outline()


def lantern():
    p = Pix(12, 20)
    p.rect(5, 0, 6, 2, IRON)
    p.box(2, 3, 9, 5, IRON)
    p.rect(3, 6, 8, 15, '#ffd070')
    p.rect(5, 8, 6, 13, '#fff4c0')
    p.rect(2, 6, 2, 15, IRON)
    p.rect(9, 6, 9, 15, IRON)
    p.box(2, 16, 9, 18, IRON)
    return p.outline()


def rope_coil():
    p = Pix(22, 14)
    for i, (rx, ry) in enumerate(((10, 6), (8, 4.6), (6, 3.2))):
        p.ellipse(11, 8, rx, ry, '#c8a060' if i % 2 == 0 else '#a8804a')
    p.ellipse(11, 8, 3, 1.6, '#6a4a2a')
    for x in range(2, 20, 3):
        p.px(x, 8 + (x % 2), '#8a6a3a')
    return p.outline()


def anchor():
    p = Pix(26, 30)
    c = '#5a5a6a'
    p.ring(13, 4, 2, 3.5, c)
    p.rect(12, 7, 14, 24, c)
    p.rect(6, 10, 20, 11, c)
    for x in range(3, 24):
        y = int(24 - 6 * (1 - ((x - 13) / 10) ** 2))
        p.rect(x, y, x, y + 2, c)
    p.rect(2, 18, 4, 21, c)
    p.rect(22, 18, 24, 21, c)
    p.rect(13, 8, 13, 23, '#8a8a9a')
    return p.outline()


def ship_wheel():
    p = Pix(30, 30)
    for k in range(8):
        a = k * np.pi / 4
        x1, y1 = 15 + np.cos(a) * 14, 15 + np.sin(a) * 14
        p.line(15, 15, x1, y1, WOOD)
        p.ellipse(x1, y1, 1.6, 1.6, DARKWOOD)
    p.ring(15, 15, 8, 10.5, WOOD)
    p.ring(15, 15, 9.5, 10.5, DARKWOOD)
    p.ellipse(15, 15, 3, 3, BRASS)
    return p.outline()


def life_ring():
    p = Pix(22, 22)
    p.ring(11, 11, 5, 10, '#f4f0e8')
    yy, xx = np.mgrid[0:22, 0:22]
    ang = (np.degrees(np.arctan2(yy - 10.5, xx - 10.5)) + 360) % 360
    d = np.hypot(xx - 10.5, yy - 10.5)
    m = (d >= 5) & (d <= 10) & ((ang // 45) % 2 == 0)
    p.a[m, :3] = hx('#d83a3a')
    p.ring(11, 11, 7.2, 7.8, '#c8b8a0')
    return p.outline()


def net_wall():
    p = Pix(56, 36)
    for i in range(0, 56, 5):
        p.line(i, 0, i + 8, 33, '#6a8a7a')
        p.line(i + 8, 0, i, 33, '#6a8a7a')
    p.rect(0, 0, 55, 1, '#c8a060')
    for x, y, c in ((8, 14, '#e8a030'), (24, 22, '#d84a3a'), (40, 12, '#e8a030'), (48, 26, '#f4f0e8')):
        p.ellipse(x, y, 3, 3, c)
        p.px(x - 1, y - 1, shift(hx(c), 0.35))
    p.a[34:, :, 3] = 0
    return p.outline()


def bread():
    p = Pix(28, 16)
    p.box(1, 8, 26, 15, '#b88a4a')
    for x in range(3, 25, 3):
        p.rect(x, 9, x, 14, '#8a6230')
    for cx, cy, rx in ((7, 7, 5), (15, 6, 6), (22, 7, 4.5)):
        p.ellipse(cx, cy, rx, 3.4, '#d89040')
        p.rect(int(cx - rx / 2), int(cy - 2), int(cx + rx / 2), int(cy - 2), '#f0c070')
        for k in (-2, 0, 2):
            p.px(int(cx + k), int(cy - 1), '#a86a28')
    return p.outline()


def fish_ice():
    p = Pix(36, 16)
    p.box(0, 9, 35, 15, '#8a9aa8')
    p.rect(1, 6, 34, 9, '#e8f4f8')
    n = hashmap(36, 16, 51, 1)
    for x in range(1, 35):
        if n[6, x] > 0.6:
            p.px(x, 6, '#ffffff')
    for i, (x, c) in enumerate(((3, '#8aa0b8'), (13, '#c86a6a'), (23, '#a8b8a0'))):
        p.ellipse(x + 5, 6, 5.5, 2.2, c)
        p.rect(x - 1, 5, x, 7, shift(hx(c), -0.2))
        p.px(x + 8, 5, '#1a1a20')
        p.rect(x + 2, 6, x + 7, 6, shift(hx(c), 0.3))
    return p.outline()


def clock():
    p = Pix(16, 40)
    p.box(1, 0, 14, 39, DARKWOOD)
    p.ellipse(7.5, 7, 5, 5, '#f4ecd8')
    p.px(7, 4, '#2a2020')
    p.rect(7, 4, 7, 7, '#2a2020')
    p.rect(7, 7, 9, 7, '#2a2020')
    p.rect(4, 14, 11, 33, ramp(DARKWOOD)[1])
    p.rect(7, 15, 8, 27, BRASS)
    p.ellipse(7.5, 28, 2.5, 2.5, BRASS)
    return p.outline()


def plant_pot(kind=0):
    p = Pix(18, 26)
    p.box(4, 17, 13, 25, '#c86a48')
    p.rect(3, 17, 14, 18, '#d87a58')
    if kind == 0:
        for k in range(7):
            a = -np.pi / 2 + (k - 3) * 0.42
            p.line(8.5, 17, 8.5 + np.cos(a) * 9, 17 + np.sin(a) * 13, '#3a7a3a')
            p.ellipse(8.5 + np.cos(a) * 8, 17 + np.sin(a) * 11, 2, 1.6, '#5aa04a')
    else:
        p.ellipse(8.5, 11, 6, 7, '#3a7a3a')
        p.ellipse(7, 9, 3, 3, '#5aa04a')
        for x, y in ((5, 8), (10, 12), (9, 6)):
            p.px(x, y, '#e86a8a')
    return p.outline()


def rug(base, border, w=64, h=40):
    p = Pix(w, h)
    p.rect(0, 0, w - 1, h - 1, border)
    p.rect(3, 3, w - 4, h - 4, base)
    p.rect(5, 5, w - 6, h - 6, border)
    p.rect(6, 6, w - 7, h - 7, base)
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            d = abs(x + 0.5 - cx) / (w * 0.24) + abs(y + 0.5 - cy) / (h * 0.24)
            if d < 1:
                p.px(x, y, border if int(d * 3.5) % 2 == 0 else shift(hx(base), 0.25))
    for x in range(0, w, 2):  # fringe
        p.px(x, 0, '#f0e8d0')
        p.px(x, h - 1, '#f0e8d0')
    return p


def quilt(base='#c84a4a'):
    p = Pix(32, 40)
    p.rect(0, 0, 31, 39, '#f4f0e8')
    p.box(2, 1, 29, 9, '#f4f0e8')  # pillow
    for ty in range(4):
        for tx in range(4):
            c = base if (tx + ty) % 2 == 0 else '#f0d8a0'
            p.rect(tx * 8, 12 + ty * 7, tx * 8 + 7, 12 + ty * 7 + 6, c)
            p.px(tx * 8 + 3, 12 + ty * 7 + 3, shift(hx(c), -0.25))
    p.rect(0, 11, 31, 12, shift(hx(base), -0.2))
    return p


def stove():
    p = Pix(32, 34)
    p.box(0, 4, 31, 33, '#3a3a44')
    p.rect(0, 2, 31, 4, '#5a5a66')
    p.box(4, 12, 27, 28, '#2a2a30')
    p.rect(7, 16, 24, 25, '#e86a2a')
    p.rect(9, 19, 22, 24, '#ffb040')
    p.rect(12, 21, 19, 23, '#fff0a0')
    p.rect(4, 8, 27, 9, BRASS)
    p.rect(13, 0, 18, 2, '#5a5a66')
    return p.outline()


def anvil():
    p = Pix(28, 20)
    p.box(4, 13, 23, 19, '#5a3a24')
    p.box(8, 8, 19, 13, '#3a3a44')
    p.box(2, 2, 25, 8, '#4a4a56')
    p.rect(2, 2, 25, 2, '#8a8a9a')
    for x in range(0, 5):
        p.rect(x - 0, 4, x, 5, '#4a4a56')
    return p.outline()


def furnace():
    p = Pix(44, 52)
    n = hashmap(44, 52, 61, 1)
    for row, y in enumerate(range(0, 52, 6)):
        off = (row % 2) * 5
        for x in range(-off, 44, 10):
            c = shift(hx('#8a5a4a'), (n[y, max(0, x) % 44] - 0.5) * 0.2)
            p.box(max(0, x), y, min(43, x + 9), min(51, y + 5), c)
    p.ellipse(22, 30, 13, 10, '#1a1012')
    p.ellipse(22, 33, 10, 7, '#e85a2a')
    p.ellipse(22, 35, 7, 4, '#ffb040')
    p.ellipse(22, 36, 4, 2, '#fff0a0')
    p.rect(9, 40, 35, 51, '#3a2a28')
    return p.outline()


def gears():
    p = Pix(36, 36)
    for cx, cy, r, teeth in ((13, 14, 10, 10), (27, 26, 7, 8)):
        for k in range(teeth):
            a = k * 2 * np.pi / teeth
            p.ellipse(cx + np.cos(a) * r, cy + np.sin(a) * r, 2.2, 2.2, WOOD)
        p.ring(cx, cy, r * 0.35, r, WOOD)
        p.ring(cx, cy, r * 0.85, r, DARKWOOD)
        for k in range(4):
            a = k * np.pi / 2
            p.line(cx, cy, cx + np.cos(a) * r * 0.9, cy + np.sin(a) * r * 0.9, DARKWOOD)
        p.ellipse(cx, cy, 2, 2, IRON)
    return p.outline()


def sacks():
    p = Pix(36, 22)
    for cx, cy, c in ((9, 13, '#e8dcc0'), (25, 13, '#d8c8a8'), (17, 8, '#f0e8d0')):
        p.ellipse(cx, cy, 8, 8, c)
        p.rect(cx - 2, cy - 9, cx + 2, cy - 7, shift(hx(c), -0.2))
        p.rect(cx - 3, cy - 1, cx + 3, cy + 1, '#8a6a3a')
    return p.outline()


def tea_set():
    p = Pix(28, 14)
    p.ellipse(9, 8, 6, 5, '#e8f0f4')
    p.rect(6, 2, 12, 3, '#e8f0f4')
    p.px(9, 1, '#5a8aa8')
    p.line(15, 6, 18, 4, '#e8f0f4')
    p.rect(3, 7, 15, 7, '#5a8aa8')
    for x in (21, 25):
        p.box(x - 2, 9, x + 2, 13, '#e8f0f4')
        p.rect(x - 1, 9, x + 1, 9, '#8a5a3a')
    return p.outline()


def telescope():
    p = Pix(22, 30)
    p.line(11, 16, 4, 28, DARKWOOD)
    p.line(11, 16, 18, 28, DARKWOOD)
    p.line(11, 16, 11, 28, DARKWOOD)
    for i in range(14):
        x, y = 3 + i, 12 - i * 0.6
        p.rect(x, int(y), x, int(y) + 3 - i // 6, BRASS if i % 5 else '#a87a28')
    return p.outline()


def trophy_board():
    p = Pix(44, 26)
    p.box(0, 0, 43, 25, DARKWOOD)
    p.rect(3, 3, 40, 22, WOOD)
    p.box(16, 21, 27, 24, BRASS)
    return p.outline()


def crate_stack():
    p = Pix(32, 30)
    for x0, y0 in ((0, 14), (16, 14), (8, 0)):
        p.box(x0, y0, x0 + 15, y0 + 15, '#b88a4a')
        p.rect(x0 + 2, y0 + 7, x0 + 13, y0 + 8, '#8a6230')
        p.line(x0 + 2, y0 + 2, x0 + 13, y0 + 13, '#8a6230')
    return p.outline()


def boat_model():
    p = Pix(40, 32)
    p.box(4, 26, 35, 31, DARKWOOD)
    for x in range(6, 34):
        top = 18 + int(abs(x - 20) / 6)
        p.rect(x, top, x, 24 - int(abs(x - 20) ** 1.6 / 30), '#3a6aa8')
    p.rect(6, 18, 33, 18, '#f4f0e8')
    p.rect(19, 3, 19, 18, '#5a3a24')
    for y in range(4, 16):
        p.rect(20, y, 20 + int((y - 3) * 0.9), y, '#f4f0e8')
    p.rect(10, 8, 18, 8, '#5a3a24')
    for y in range(9, 16):
        p.rect(18 - int((y - 8) * 0.9), y, 18, y, '#e8e0d0')
    return p.outline()


def driftwood():
    p = Pix(44, 22)
    logs = [(3, 15, 40, 19, '#c8b8a0'), (8, 10, 36, 14, '#b8a488'), (14, 5, 30, 9, '#d8ccb8')]
    for x0, y0, x1, y1, c in logs:
        p.box(x0, y0, x1, y1, c)
        p.ellipse(x1, (y0 + y1) / 2 + 0.5, 2, (y1 - y0) / 2 + 0.5, shift(hx(c), 0.12))
        p.px(x1, (y0 + y1) // 2, shift(hx(c), -0.25))
        for x in range(x0 + 3, x1 - 2, 5):
            p.px(x, y0 + 2, shift(hx(c), -0.18))
    p.line(30, 4, 36, 1, '#a89878')  # a stray branch
    return p.outline()


def mark_stone():
    """A weathered standing stone with the keeper's mark: a gull with one wing."""
    p = Pix(28, 36)
    stone = '#8a8a86'
    p.ellipse(14, 20, 12, 16, stone)
    p.rect(3, 22, 24, 35, stone)
    n = hashmap(28, 36, 71, 2)
    for y in range(36):
        for x in range(28):
            if p.a[y, x, 3] and n[y, x] > 0.86:
                p.px(x, y, shift(hx(stone), -0.12))
            if p.a[y, x, 3] and n[y, x] < 0.05:
                p.px(x, y, '#5a7a4a')  # moss
    carve = '#34343c'
    lit = '#c4c4bc'
    # the gull: a body, a head, a tail, and only one wing raised
    for x0, y0, x1, y1 in ((6, 20, 20, 20), (6, 21, 19, 21)):
        p.line(x0, y0, x1, y1, carve)
    p.rect(20, 18, 22, 20, carve)  # head
    p.px(23, 19, '#d8a040')  # beak
    for i in range(7):  # the wing, sweeping up and back
        p.line(9 + i, 19 - i, 14 + i // 2, 19 - i, carve)
    p.line(4, 19, 6, 21, carve)  # tail
    p.line(4, 22, 6, 21, carve)
    for x in range(6, 21):
        p.px(x, 22, lit)
    p.px(21, 21, lit)
    for x in range(4, 24):
        p.px(x, 35, shift(hx(stone), -0.3))
    return p.outline()


def bottle():
    p = Pix(12, 22)
    p.rect(4, 0, 7, 2, '#a87a4a')  # cork
    p.rect(4, 3, 7, 6, '#7ab8a0')
    p.ellipse(5.5, 14, 5, 8, '#7ab8a0')
    p.rect(3, 9, 8, 18, '#f0e6c8')  # the letter rolled inside
    p.rect(3, 12, 8, 12, '#c84a3a')
    p.px(3, 7, '#e8fff4')
    p.px(2, 10, '#e8fff4')
    return p.outline()


def gulls_eye():
    """The lost lens: a faceted crystal that holds the light."""
    p = Pix(28, 28)
    p.ellipse(14, 14, 12, 12, '#c8a040')  # brass ring
    p.ellipse(14, 14, 10, 10, '#bfefff')
    p.ellipse(14, 14, 7, 7, '#8ad8f8')
    p.ellipse(14, 14, 4, 4, '#fff8d8')
    for k in range(8):
        a = k * np.pi / 4
        p.line(14 + np.cos(a) * 4, 14 + np.sin(a) * 4, 14 + np.cos(a) * 9, 14 + np.sin(a) * 9, '#e8fbff')
    p.px(10, 9, '#ffffff')
    p.px(11, 9, '#ffffff')
    return p.outline()


def cave_mouth():
    p = Pix(48, 40)
    rock = '#5a4a48'
    p.ellipse(24, 26, 24, 22, rock)
    p.ellipse(24, 30, 13, 14, '#140a0a')
    p.ellipse(24, 36, 9, 5, '#3a1810')
    p.ellipse(24, 37, 5, 2.5, '#e86a2a')  # a glow from deep inside
    n = hashmap(48, 40, 81, 2)
    for y in range(40):
        for x in range(48):
            if p.a[y, x, 3] and n[y, x] > 0.85 and tuple(p.a[y, x, :3]) == hx(rock):
                p.px(x, y, shift(hx(rock), 0.18))
    p.a[39:, :, 3] = 0
    return p.outline()


def dartboard():
    p = Pix(34, 34)
    p.ellipse(17, 17, 16, 16, '#2a2020')
    for i, (r, c) in enumerate(((14, '#e8dcc0'), (11, '#2a2a2a'), (8, '#e8dcc0'), (5, '#3a8a4a'), (2.5, '#c83a3a'))):
        p.ellipse(17, 17, r, r, c)
    for k in range(10):
        a = k * np.pi / 5
        p.line(17 + np.cos(a) * 5, 17 + np.sin(a) * 5, 17 + np.cos(a) * 14, 17 + np.sin(a) * 14, '#8a7a6a')
    p.ellipse(17, 17, 1.2, 1.2, '#ffd24d')
    return p.outline()


def skip_stone():
    p = Pix(8, 6)
    p.ellipse(4, 3, 3.6, 2.4, '#9a9690')
    p.px(3, 2, '#c8c4bc')
    return p.outline()


def eye_carving():
    p = Pix(16, 12)
    p.ellipse(8, 6, 7, 4, '#3a3a40')
    p.ellipse(8, 6, 5, 3, '#c8c0a0')
    p.ellipse(8, 6, 2.2, 2.2, '#2a2a30')
    p.px(7, 5, '#f0f0e0')
    return p


# ===================================================================== critters

def gull_frames():
    """Four 16x12 frames: wings up, level, down, and standing."""
    p = Pix(64, 12)
    white, grey, dark, beak = '#f4f4f0', '#b8bcc4', '#3a3a44', '#e8a030'
    for f, wing in enumerate(('up', 'level', 'down')):
        ox = f * 16
        p.ellipse(ox + 8, 7, 4.5, 2, white)  # body
        p.px(ox + 12, 6, white)
        p.px(ox + 13, 6, beak)
        p.px(ox + 11, 6, dark)
        if wing == 'up':
            p.line(ox + 7, 6, ox + 3, 1, grey)
            p.line(ox + 9, 6, ox + 12, 1, grey)
            p.px(ox + 3, 1, dark)
            p.px(ox + 12, 1, dark)
        elif wing == 'level':
            p.line(ox + 2, 5, ox + 14, 5, grey)
            p.px(ox + 1, 5, dark)
            p.px(ox + 15, 5, dark)
        else:
            p.line(ox + 7, 7, ox + 3, 10, grey)
            p.line(ox + 9, 7, ox + 12, 10, grey)
        p.line(ox + 3, 7, ox + 4, 8, grey)  # tail
    ox = 48  # standing
    p.ellipse(ox + 8, 6, 4, 2.5, white)
    p.rect(ox + 5, 5, ox + 9, 6, grey)
    p.rect(ox + 11, 3, ox + 12, 5, white)
    p.px(ox + 13, 4, beak)
    p.px(ox + 12, 3, dark)
    p.rect(ox + 7, 9, ox + 7, 11, beak)
    p.rect(ox + 9, 9, ox + 9, 11, beak)
    return p


def crab_frames():
    p = Pix(24, 8)
    for f in range(2):
        ox = f * 12
        p.ellipse(ox + 6, 4, 3.5, 2.2, '#d0503a')
        p.px(ox + 4, 2, '#1a1a1a')
        p.px(ox + 8, 2, '#1a1a1a')
        p.rect(ox + 0, 2 + f, ox + 1, 3 + f, '#e06a4a')  # claws
        p.rect(ox + 10, 3 - f, ox + 11, 4 - f, '#e06a4a')
        for k, x in enumerate((3, 5, 7, 9)):
            p.px(ox + x, 6 + (k + f) % 2, '#a83a2a')
    return p


def butterfly_frames():
    p = Pix(16, 7)
    p.ellipse(3.5, 3.5, 3, 3, '#ffffff')
    p.rect(3, 1, 4, 6, '#3a3030')
    p.rect(9, 2, 14, 5, '#ffffff')
    p.rect(11, 1, 12, 6, '#3a3030')
    return p


def dolphin():
    p = Pix(30, 14)
    for x in range(2, 27):
        t = (x - 2) / 24.0
        y = int(8 - math.sin(t * math.pi) * 5)
        p.rect(x, y, x, y + 3 - int(abs(t - 0.5) * 3), '#5a6a80')
        p.px(x, y + 3 - int(abs(t - 0.5) * 3), '#c8d0d8')
    p.rect(13, 1, 15, 3, '#5a6a80')  # fin
    p.px(25, 7, '#1a1a20')
    p.rect(0, 9, 3, 10, '#5a6a80')  # tail
    return p.outline()


def whale_tail():
    p = Pix(34, 22)
    p.rect(14, 10, 19, 21, '#3a4250')
    for x in range(0, 34):
        d = abs(x - 16.5)
        y = int(4 + (d / 16.5) ** 2 * -3 + d * 0.15)
        p.rect(x, max(0, y), x, min(10, y + 5 - int(d / 6)), '#3a4250')
    p.rect(15, 0, 18, 4, '#00000000') if False else None
    p.a[0:3, 15:19, 3] = 0  # the notch
    p.line(2, 4, 14, 8, '#5a6474')
    return p.outline()


def smoke():
    p = Pix(16, 16)
    yy, xx = np.mgrid[0:16, 0:16]
    d = np.hypot(xx - 7.5, yy - 7.5) / 7.5
    a = np.clip(1.0 - d, 0, 1) ** 1.5
    p.a[..., :3] = 235
    p.a[..., 3] = (a * 200).astype(np.uint8)
    return p


CRITTERS = {'gull': gull_frames, 'crab': crab_frames, 'butterfly': butterfly_frames, 'dolphin': dolphin,
            'whale_tail': whale_tail, 'smoke': smoke}


def bed_frame_texture():
    return quilt()


DECOR = {
    'bookshelf': bookshelf, 'shelf_jars': lambda: shelf('jars'), 'shelf_bait': lambda: shelf('bait'),
    'rod_rack': rod_rack, 'window': window, 'fireplace': fireplace, 'fire': fire_frames,
    'painting_sea': lambda: painting('sea'), 'painting_boat': lambda: painting('boat'),
    'portrait': lambda: painting('portrait'), 'chart': chart, 'notice_board': notice_board, 'lantern': lantern,
    'rope_coil': rope_coil, 'anchor': anchor, 'ship_wheel': ship_wheel, 'life_ring': life_ring, 'net_wall': net_wall,
    'bread': bread, 'fish_ice': fish_ice, 'clock': clock, 'plant_fern': lambda: plant_pot(0),
    'plant_flower': lambda: plant_pot(1), 'rug_red': lambda: rug('#a83a3a', '#e8c070'),
    'rug_blue': lambda: rug('#3a5a98', '#e8dcc0'), 'rug_green': lambda: rug('#3a7a5a', '#e8c070'),
    'quilt_red': lambda: quilt('#c84a4a'), 'quilt_blue': lambda: quilt('#4a6ac8'), 'stove': stove, 'anvil': anvil,
    'furnace': furnace, 'gears': gears, 'sacks': sacks, 'tea_set': tea_set, 'telescope': telescope,
    'trophy_board': trophy_board, 'crates': crate_stack, 'boat_model': boat_model, 'driftwood': driftwood,
    'mark_stone': mark_stone, 'bottle': bottle, 'gulls_eye': gulls_eye, 'cave_mouth': cave_mouth,
    'dartboard': dartboard, 'skip_stone': skip_stone, 'eye_carving': eye_carving,
}
TEX = {
    'floor_wood': lambda: floor_wood(), 'floor_wood_dark': lambda: floor_wood('#7a5030', 2),
    'floor_tile': lambda: floor_tile(), 'floor_tile_blue': lambda: floor_tile('#4a7ab0', '#e8e4dc'),
    'floor_stone': lambda: floor_stone(), 'wall_paper': lambda: wall_paper(),
    'wall_paper_green': lambda: wall_paper('#c8dcc0', '#6a9a6a', 7), 'wall_paper_blue': lambda: wall_paper('#c8d8e8', '#6a8ab0', 8),
    'wall_wood': lambda: wall_wood(), 'wall_wood_light': lambda: wall_wood('#b88a5a', 9),
    'wall_plaster': lambda: wall_plaster(), 'wall_stone': lambda: floor_stone('#a09888', 10),
}


def main():
    preview = '--preview' in sys.argv
    out = {}
    for k, fn in TEX.items():
        out['tex/' + k] = fn().save('tex/%s.png' % k)
    for k, fn in DECOR.items():
        out['decor/' + k] = fn().save('decor/%s.png' % k)
    for k, fn in CRITTERS.items():
        out['critters/' + k] = fn().save('critters/%s.png' % k)
    print('interior art: %d textures, %d decor sprites' % (len(TEX), len(DECOR)))
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        tiles = [v for k, v in out.items()]
        W = 8 * 72
        rows = (len(tiles) + 7) // 8
        sheet = Image.new('RGBA', (W, rows * 72), (40, 44, 60, 255))
        for i, t in enumerate(tiles):
            im = Image.fromarray(t, 'RGBA')
            im.thumbnail((68, 68))
            sheet.alpha_composite(im, ((i % 8) * 72 + 2, (i // 8) * 72 + 2))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        sheet.save(os.path.join(PREVIEW, 'interior_art.png'))


if __name__ == '__main__':
    main()
