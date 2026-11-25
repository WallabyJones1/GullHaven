"""Gullhaven HD-2D land art: everything for farming, foraging, mining, hunting and crafting.
Usage: python3 tools/godot_land_art.py [--preview]

Same palette rules as tools/godot_art.py and godot_interior_art.py: hue-shifted ramps,
dark selective outlines, light from the top left. Writes:
  godot/art/land/icons/<item>.png   16x16 item icons (menus, the bag, float-ups)
  godot/art/land/crops/<crop>_<stage>.png   four growth stages per crop
  godot/art/land/ore_<kind>.png, rubble.png   rocks to mine
  godot/art/land/animals/<animal>.png   two-frame walk strips (facing left)
  godot/art/land/<prop>.png   the workbench, the cook pot, the garden sign
  godot/art/tex/soil.png, soil_wet.png   tilled garden beds
  godot/art/decor/<piece>.png   furniture you can craft for your hut
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_art import OUT, PREVIEW, hashmap, hx, ramp, rock, shift  # noqa: E402
from godot_interior_art import Pix  # noqa: E402


def lit(p, cx, cy, rx, ry, base):
    """A shaded blob: base colour, a highlight up and left, a shadow down and right."""
    r = ramp(base)
    p.ellipse(cx, cy, rx, ry, r[2])
    p.ellipse(cx - rx * 0.12, cy - ry * 0.12, rx * 0.86, ry * 0.86, r[3])
    p.ellipse(cx - rx * 0.35, cy - ry * 0.35, max(0.8, rx * 0.32), max(0.8, ry * 0.3), r[4])


# =========================================================================== icons (16x16)

def icon_root(body, leaf='#5aa04a', long=False):
    p = Pix(16, 16)
    if long:  # a carrot: a tapering cone
        for i in range(10):
            w = max(0.6, 3.2 - i * 0.32)
            p.rect(8 - w, 5 + i, 7 + w, 5 + i, ramp(body)[3 if i < 7 else 2])
        p.rect(6, 6, 6, 10, ramp(body)[4])
        for y in (8, 11):
            p.px(9, y, ramp(body)[1])
    else:
        lit(p, 8, 10, 5, 4.6, body)
        p.px(6, 13, ramp(body)[1])
    for dx in (-2, 0, 2):
        p.line(8, 6, 8 + dx, 1, leaf)
    p.px(8, 1, shift(hx(leaf), 0.2))
    return p.outline()


def icon_potato():
    p = Pix(16, 16)
    lit(p, 8, 9, 6, 4.5, '#c8a060')
    for x, y in ((6, 8), (10, 10), (8, 11)):
        p.px(x, y, '#8a6a3a')
    return p.outline()


def icon_wheat():
    p = Pix(16, 16)
    for x0 in (5, 8, 11):
        p.line(x0, 15, x0 - (x0 - 8) // 2, 6, '#c8a048')
        for k in range(4):
            p.px(x0 - (x0 - 8) // 2 - 1, 2 + k * 2, '#f0d070')
            p.px(x0 - (x0 - 8) // 2 + 1, 3 + k * 2, '#e0b850')
    p.rect(5, 11, 11, 12, '#a87a38')
    return p.outline()


def icon_berries(c='#5a2a6a', leaf='#4a8a3a'):
    p = Pix(16, 16)
    p.line(8, 2, 8, 5, '#6a4a2a')
    p.ellipse(11, 4, 3, 1.6, leaf)
    for cx, cy in ((6, 8), (10, 8), (8, 11), (5, 12), (11, 12)):
        lit(p, cx, cy, 2.4, 2.4, c)
    return p.outline()


def icon_strawberry():
    p = Pix(16, 16)
    for i in range(9):
        w = 5 - i * 0.5
        p.rect(8 - w, 4 + i, 7 + w, 4 + i, ramp('#e04a4a')[3 if i < 6 else 2])
    p.rect(4, 5, 5, 8, '#f07a6a')
    for x, y in ((6, 7), (9, 6), (8, 9), (10, 10), (6, 10)):
        p.px(x, y, '#f8e070')
    for dx in (-3, -1, 1, 3):
        p.line(8, 4, 8 + dx, 2, '#4a9a3a')
    return p.outline()


def icon_pumpkin():
    p = Pix(16, 16)
    for dx in (-3, 0, 3):
        lit(p, 8 + dx, 10, 3.6, 4.6, '#e88a2a')
    for x in (5, 8, 11):
        p.line(x, 6, x, 14, ramp('#e88a2a')[1])
    p.rect(7, 3, 8, 6, '#6a8a3a')
    return p.outline()


def icon_mushroom(cap='#c84a3a', spots=True, stem='#efe6d2'):
    p = Pix(16, 16)
    p.rect(6, 8, 9, 14, stem)
    p.rect(6, 8, 6, 14, shift(hx(stem), -0.15))
    for y in range(7):
        w = math.sqrt(max(0.0, 1 - ((y - 6) / 6.0) ** 2)) * 7
        p.rect(8 - w, 2 + y, 7 + w, 2 + y, ramp(cap)[3 if y > 1 else 4])
    if spots:
        for x, y in ((5, 5), (9, 4), (11, 7), (7, 7)):
            p.px(x, y, '#f8f4ec')
    return p.outline()


def icon_herb():
    p = Pix(16, 16)
    for a, l in ((-0.9, 6), (-0.3, 8), (0.3, 8), (0.9, 6), (0.0, 10)):
        x1 = 8 + math.sin(a) * l
        y1 = 14 - math.cos(a) * l
        p.line(8, 14, x1, y1, '#3a7a3a')
        p.ellipse(x1, y1, 1.8, 1.4, '#6ab85a')
    return p.outline()


def icon_flower():
    p = Pix(16, 16)
    p.line(8, 15, 8, 7, '#3a7a3a')
    p.ellipse(10, 11, 2, 1, '#5aa04a')
    for k in range(5):
        a = k * math.tau / 5
        p.ellipse(8 + math.cos(a) * 3, 5 + math.sin(a) * 3, 2, 2, '#e87ab0')
    p.ellipse(8, 5, 1.5, 1.5, '#f8d850')
    return p.outline()


def icon_rock(base='#8a8698', fleck=None):
    p = Pix(16, 16)
    lit(p, 8, 9, 6.5, 5.2, base)
    p.line(6, 7, 8, 11, ramp(base)[1])
    if fleck:
        for x, y in ((5, 8), (9, 7), (10, 11), (7, 12), (11, 9)):
            p.px(x, y, fleck)
            p.px(x + 1, y, shift(hx(fleck), 0.25))
    return p.outline()


def icon_bar(base):
    p = Pix(16, 16)
    r = ramp(base)
    for i in range(6):
        p.rect(3 + i // 2, 6 + i, 12 - i // 2, 6 + i, r[3])
    p.rect(4, 6, 11, 6, r[5])
    p.rect(3, 11, 12, 11, r[1])
    p.line(5, 8, 7, 8, r[4])
    return p.outline()


def icon_gem(base):
    p = Pix(16, 16)
    r = ramp(base)
    pts = [(8, 2), (13, 7), (8, 14), (3, 7)]
    for y in range(2, 15):
        if y <= 7:
            w = (y - 2) * 1.0
        else:
            w = (14 - y) * 0.71
        p.rect(8 - w, y, 8 + w, y, r[3] if y > 6 else r[4])
    p.line(8, 2, 8, 14, r[2])
    p.px(6, 5, r[5])
    p.px(5, 6, r[5])
    return p.outline()


def icon_coal():
    p = Pix(16, 16)
    for cx, cy, rr in ((6, 10, 3.5), (10, 9, 3.2), (8, 12, 3)):
        lit(p, cx, cy, rr, rr * 0.85, '#3a3a44')
    p.px(5, 8, '#8a8a9a')
    p.px(10, 7, '#8a8a9a')
    return p.outline()


def icon_meat():
    p = Pix(16, 16)
    lit(p, 7, 9, 5, 4, '#c85a50')
    p.ellipse(7, 9, 2.5, 1.8, '#e88a80')
    p.rect(11, 5, 13, 6, '#efe6d2')
    p.line(10, 7, 12, 5, '#efe6d2')
    return p.outline()


def icon_feather():
    p = Pix(16, 16)
    p.line(3, 14, 12, 2, '#d8d0c0')
    for i in range(8):
        x = 4 + i
        y = 12 - int(i * 1.3)
        p.line(x, y, x - 2, y - 2, '#7a9ab8')
        p.line(x, y, x + 1, y + 2, '#5a7a98')
    return p.outline()


def icon_hide():
    p = Pix(16, 16)
    pts = [(3, 4), (6, 2), (10, 2), (13, 4), (12, 9), (14, 13), (9, 12), (7, 12), (2, 13), (4, 9)]
    from PIL import ImageDraw
    im = Image.new('1', (16, 16), 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    m = np.array(im, bool)
    r = ramp('#a8784a')
    p.a[m, :3] = r[3]
    p.a[m, 3] = 255
    p.rect(6, 5, 9, 9, r[4])
    return p.outline()


def icon_antler():
    p = Pix(16, 16)
    c = '#d8c8a0'
    p.line(8, 15, 6, 6, c)
    p.line(6, 6, 3, 2, c)
    p.line(6, 8, 10, 4, c)
    p.line(7, 11, 11, 9, c)
    p.line(10, 4, 12, 1, c)
    return p.outline()


def icon_seed(color):
    p = Pix(16, 16)
    p.box(3, 2, 12, 14, '#e8dcc0')
    lit(p, 7.5, 8, 3, 3, color)
    p.rect(4, 12, 11, 12, '#a8946a')
    return p.outline()


def icon_bowl(soup):
    p = Pix(16, 16)
    p.ellipse(8, 8, 6.5, 2.2, ramp(soup)[3])
    p.ellipse(7, 7.6, 3, 1, ramp(soup)[4])
    for y in range(9, 14):
        w = 6.5 - (y - 9) * 0.9
        p.rect(8 - w, y, 7 + w, y, ramp('#c8a070')[3 if y < 12 else 2])
    p.line(5, 4, 6, 2, '#e8e8f0')
    p.line(10, 4, 11, 1, '#e8e8f0')
    return p.outline()


def icon_pie(fill):
    p = Pix(16, 16)
    p.ellipse(8, 9, 7, 4, '#d8a058')
    p.ellipse(8, 8.5, 5.5, 3, fill)
    for x in (4, 7, 10):
        p.line(x, 7, x + 3, 11, '#e8b868')
    return p.outline()


def icon_roast():
    p = Pix(16, 16)
    p.ellipse(8, 11, 7, 3, '#e8e8f0')
    lit(p, 7, 9, 4, 3, '#b8603a')
    p.ellipse(12, 10, 1.6, 1.6, '#e88a2a')
    p.ellipse(3.5, 10, 1.6, 1.6, '#c8a060')
    return p.outline()


def icon_tool(kind, head='#9a9aa8'):
    p = Pix(16, 16)
    wood = '#9a6a3a'
    if kind == 'hoe':
        p.line(3, 14, 11, 3, wood)
        p.rect(10, 2, 14, 4, head)
    elif kind == 'can':
        p.box(3, 6, 10, 13, head)
        p.line(10, 8, 14, 5, head)
        p.line(4, 6, 8, 3, head)
        p.line(8, 3, 10, 6, head)
    elif kind == 'axe':
        p.line(4, 14, 11, 3, wood)
        p.ellipse(11, 4, 3, 2.5, head)
        p.rect(9, 3, 10, 6, head)
    elif kind == 'pick':
        p.line(4, 14, 10, 4, wood)
        for x in range(3, 14):
            y = 3 + int(((x - 8) / 5.0) ** 2 * 2)
            p.px(x, y, head)
            p.px(x, y + 1, shift(hx(head), -0.2))
    elif kind == 'bow':
        for t in range(13):
            y = 2 + t
            x = 5 + int(round(math.sin(t / 12 * math.pi) * 5))
            p.px(x, y, wood)
            p.px(x + 1, y, shift(hx(wood), 0.2))
        p.line(5, 2, 5, 14, '#e8e4d8')
    elif kind == 'arrow':
        p.line(2, 14, 13, 3, wood)
        p.rect(12, 2, 14, 3, head)
        p.line(2, 12, 4, 14, '#e8e4d8')
        p.line(3, 11, 5, 13, '#d85a5a')
    elif kind == 'rope':
        p.ring(8, 8, 3, 6, '#c8a870')
        p.ring(8, 8, 3.5, 4.2, '#a88a50')
    elif kind == 'lantern':
        p.box(5, 4, 11, 13, '#5a5a6a')
        p.rect(6, 6, 10, 11, '#ffd870')
        p.line(6, 2, 10, 2, '#5a5a6a')
        p.line(8, 2, 8, 4, '#5a5a6a')
    elif kind == 'scrap':
        p.box(3, 7, 9, 12, '#8a8a98')
        p.line(9, 5, 13, 10, '#a86a4a')
        p.ring(11, 6, 1, 2, '#9a9aa8')
    elif kind == 'compost':
        lit(p, 8, 10, 6, 4, '#5a4030')
        for x, y in ((5, 9), (9, 8), (11, 11)):
            p.px(x, y, '#c87a6a')
    elif kind == 'charm':
        p.ring(8, 6, 3, 4, '#c8a048')
        lit(p, 8, 11, 3, 3, '#ff7a3a')
    elif kind == 'map':
        p.box(2, 3, 13, 12, '#e8dcb8')
        p.line(4, 10, 7, 6, '#a85a3a')
        p.line(7, 6, 11, 8, '#a85a3a')
        p.px(11, 8, '#d83a3a')
    return p.outline()


ICONS = {
    # produce
    'turnip': lambda: icon_root('#e8d0e0', '#5aa04a'),
    'carrot': lambda: icon_root('#f08a2a', '#4a9a3a', long=True),
    'potato': icon_potato,
    'wheat': icon_wheat,
    'strawberry': icon_strawberry,
    'pumpkin': icon_pumpkin,
    # seeds
    'seed_turnip': lambda: icon_seed('#e8d0e0'), 'seed_carrot': lambda: icon_seed('#f08a2a'),
    'seed_potato': lambda: icon_seed('#c8a060'), 'seed_wheat': lambda: icon_seed('#f0d070'),
    'seed_strawberry': lambda: icon_seed('#e04a4a'), 'seed_pumpkin': lambda: icon_seed('#e88a2a'),
    # forage
    'berries': icon_berries, 'mushroom': lambda: icon_mushroom('#c84a3a'),
    'chanterelle': lambda: icon_mushroom('#e8a83a', False, '#f0c870'), 'herbs': icon_herb, 'wildflowers': icon_flower,
    # mining
    'stone': lambda: icon_rock(), 'coal': icon_coal, 'copper_ore': lambda: icon_rock('#7a7480', '#d8783a'),
    'iron_ore': lambda: icon_rock('#7a7480', '#c8a8a0'), 'silver_ore': lambda: icon_rock('#6a6a7a', '#e8f0ff'),
    'gold_ore': lambda: icon_rock('#6a6070', '#f8d040'), 'quartz': lambda: icon_gem('#e8eef8'),
    'amethyst': lambda: icon_gem('#a86ad8'), 'ember_crystal': lambda: icon_gem('#ff6a2a'),
    'copper_bar': lambda: icon_bar('#d8783a'), 'iron_bar': lambda: icon_bar('#a8a8b8'),
    'silver_bar': lambda: icon_bar('#e0e8f8'), 'gold_bar': lambda: icon_bar('#f8c830'),
    # hunting
    'meat': icon_meat, 'feather': icon_feather, 'hide': icon_hide, 'antler': icon_antler,
    # cooking
    'veg_stew': lambda: icon_bowl('#c8783a'), 'mushroom_soup': lambda: icon_bowl('#b8a080'),
    'pumpkin_soup': lambda: icon_bowl('#f0982a'), 'berry_pie': lambda: icon_pie('#7a2a6a'),
    'strawberry_tart': lambda: icon_pie('#e04a4a'), 'roast_dinner': icon_roast, 'bread_loaf': lambda: icon_pie('#d8a058'),
    # tools and crafts
    'hoe': lambda: icon_tool('hoe'), 'watering_can': lambda: icon_tool('can', '#5a8ab8'),
    'axe_stone': lambda: icon_tool('axe', '#8a8698'), 'axe_copper': lambda: icon_tool('axe', '#d8783a'),
    'axe_iron': lambda: icon_tool('axe', '#b8b8c8'),
    'pick_stone': lambda: icon_tool('pick', '#8a8698'), 'pick_copper': lambda: icon_tool('pick', '#d8783a'),
    'pick_iron': lambda: icon_tool('pick', '#b8b8c8'), 'pick_silver': lambda: icon_tool('pick', '#e8f0ff'),
    'bow': lambda: icon_tool('bow'), 'bow_fine': lambda: icon_tool('bow'), 'arrows': lambda: icon_tool('arrow', '#8a8698'),
    'twine': lambda: icon_tool('rope'), 'scrap_bundle': lambda: icon_tool('scrap'), 'compost': lambda: icon_tool('compost'),
    'ember_lantern': lambda: icon_tool('lantern'), 'ember_charm': lambda: icon_tool('charm'), 'old_map': lambda: icon_tool('map'),
}


# =========================================================================== crops

CROP_LOOK = {
    'turnip': ('#e8d0e0', '#5aa04a'), 'carrot': ('#f08a2a', '#4a9a3a'), 'potato': ('#c8a060', '#4a8a4a'),
    'wheat': ('#f0d070', '#7aa04a'), 'strawberry': ('#e04a4a', '#3a8a3a'), 'pumpkin': ('#e88a2a', '#4a8a3a'),
}


def crop(kind, stage):
    p = Pix(20, 22)
    body, leaf = CROP_LOOK[kind]
    # a little mound of soil under everything
    p.ellipse(10, 20, 7, 2, '#6a4a30')
    p.ellipse(9, 19.5, 5, 1.2, '#7a5a3a')
    if stage == 0:
        for x in (7, 10, 13):
            p.px(x, 19, '#c8b890')
        return p.outline()
    if kind == 'wheat':
        n = [0, 4, 7, 9][stage]
        for i in range(n):
            x = 4 + i * 1.5
            top = 19 - [0, 5, 11, 16][stage] + (i % 3)
            col = leaf if stage < 3 else '#d8b050'
            p.line(x, 19, x + (i % 2), top, col)
            if stage == 3:
                for k in range(3):
                    p.px(int(x) + (i % 2) - 1, top + k * 2, '#f0d070')
                    p.px(int(x) + (i % 2) + 1, top + 1 + k * 2, '#e8c058')
        return p.outline()
    if stage == 1:
        p.line(10, 19, 10, 15, leaf)
        p.ellipse(8, 15, 2, 1, leaf)
        p.ellipse(12, 14, 2, 1, shift(hx(leaf), 0.15))
        return p.outline()
    if kind == 'pumpkin':
        p.line(3, 18, 17, 17, leaf)
        for x, y in ((5, 15), (10, 13), (15, 15)):
            p.ellipse(x, y, 3, 2.2, leaf if stage == 2 else shift(hx(leaf), -0.1))
        if stage == 3:
            for dx in (-3, 0, 3):
                lit(p, 10 + dx, 15, 3.2, 3.6, body)
            p.rect(9, 10, 10, 12, '#6a8a3a')
        else:
            lit(p, 13, 17, 1.8, 1.6, '#c8d06a')
        return p.outline()
    # leafy crops
    h = 8 if stage == 2 else 11
    for dx, tilt in ((-4, -3), (-1, -1), (2, 1), (5, 3)):
        p.line(10 + dx // 2, 19, 10 + dx + tilt // 2, 19 - h + abs(dx) // 2, leaf)
        p.ellipse(10 + dx + tilt // 2, 19 - h + abs(dx) // 2, 2.2, 1.6, shift(hx(leaf), 0.1 if dx < 0 else -0.05))
    if stage == 3:
        if kind == 'strawberry':
            for x, y in ((5, 15), (9, 13), (14, 15), (12, 17)):
                lit(p, x, y, 1.8, 2.0, body)
        elif kind == 'potato':
            for x in (6, 13):
                lit(p, x, 18.5, 2.4, 1.6, body)
            for x, y in ((8, 9), (12, 10)):
                p.px(x, y, '#f0f0f8')
        else:  # turnip and carrot tops show above the soil
            lit(p, 10, 18, 3.2 if kind == 'turnip' else 2.2, 2.2, body)
    return p.outline()


# =========================================================================== ores, props, animals

ORE_FLECK = {'stone': None, 'coal': '#2a2a34', 'copper': '#e0803a', 'iron': '#d8b8b0', 'silver': '#f0f6ff',
             'gold': '#ffd840', 'crystal': '#ff6a2a', 'amethyst': '#b070e0'}


def ore_rock(kind, seed):
    img = rock(seed, 34, 26, moss=(kind == 'stone'))
    fleck = ORE_FLECK[kind]
    if fleck:
        rng = np.random.RandomState(seed + 5)
        a = img[..., 3] > 0
        ys, xs = np.nonzero(a)
        inner = [(y, x) for y, x in zip(ys, xs) if 4 < y < 23 and 3 < x < 31]
        for k in range(16 if kind != 'crystal' and kind != 'amethyst' else 7):
            y, x = inner[rng.randint(len(inner))]
            if kind in ('crystal', 'amethyst'):  # crystals poke out as little spikes
                c = hx(fleck)
                for d in range(4):
                    if y - d >= 0:
                        img[y - d, x, :3] = shift(c, 0.2 * (d % 2))
                        img[y - d, x, 3] = 255
                img[y, x + 1, :3] = shift(c, -0.2)
            else:
                img[y, x, :3] = hx(fleck)
                if x + 1 < 34 and img[y, x + 1, 3]:
                    img[y, x + 1, :3] = shift(hx(fleck), -0.25)
    return img


def rubble():
    p = Pix(28, 10)
    for cx, cy, rr in ((7, 6, 3.5), (14, 7, 3), (20, 6, 3.2), (11, 4, 2.5), (17, 4, 2.2)):
        lit(p, cx, cy, rr, rr * 0.75, '#8a8698')
    return p.outline()


def workbench():
    p = Pix(44, 34)
    wood = '#a8743f'
    p.box(2, 12, 41, 16, wood)
    for x in (4, 37):
        p.box(x, 16, x + 3, 33, shift(hx(wood), -0.15))
    p.box(6, 26, 37, 28, shift(hx(wood), -0.1))
    # tools on top and on the back board
    p.box(5, 2, 38, 11, shift(hx(wood), -0.25))
    p.line(9, 4, 13, 10, '#9a6a3a')
    p.rect(12, 3, 15, 5, '#9a9aa8')
    p.line(20, 3, 20, 10, '#9a6a3a')
    p.rect(18, 3, 22, 4, '#9a9aa8')
    p.ring(30, 6, 1.5, 3, '#c8a870')
    p.box(26, 9, 33, 11, '#c8a870')
    p.box(8, 10, 15, 11, '#8a8a98')
    return p.outline()


def cookpot():
    p = Pix(32, 34)
    # tripod and pot over a small fire
    p.line(4, 33, 16, 2, '#5a3a24')
    p.line(28, 33, 16, 2, '#5a3a24')
    p.line(16, 2, 16, 10, '#3a3a44')
    lit(p, 16, 18, 9, 7, '#3a3a48')
    p.ellipse(16, 12, 8, 2, '#4a4a58')
    p.ellipse(16, 12, 6, 1.2, '#c8783a')
    for cx, c in ((11, '#ff9a2a'), (16, '#ffd84a'), (21, '#ff7a2a')):
        p.ellipse(cx, 29, 2.4, 3.6, c)
    p.rect(8, 31, 24, 33, '#6a4a30')
    return p.outline()


def garden_sign():
    p = Pix(24, 30)
    p.box(10, 12, 13, 29, '#8a5a34')
    p.box(1, 2, 22, 13, '#c8a070')
    p.line(4, 6, 19, 6, '#6a4a2a')
    p.line(4, 9, 15, 9, '#6a4a2a')
    lit(p, 18, 9, 2, 2, '#f08a2a')
    return p.outline()


def soil(wet=False):
    p = Pix(32, 32)
    base = '#6a4a30' if not wet else '#4a3020'
    r = ramp(base)
    p.rect(0, 0, 31, 31, r[3])
    n = hashmap(32, 32, 77 if not wet else 78, 1)
    for row in range(4):
        y0 = row * 8
        p.rect(0, y0 + 1, 31, y0 + 2, r[4])
        p.rect(0, y0 + 5, 31, y0 + 6, r[1])
    for y in range(32):
        for x in range(32):
            if n[y, x] > 0.9:
                p.px(x, y, r[2])
            elif n[y, x] < 0.05:
                p.px(x, y, '#9a8a70' if not wet else '#6a5a48')
    return p


def _animal_frame(kind, f):
    if kind == 'rabbit':
        p = Pix(22, 16)
        hop = 1 if f else 0
        lit(p, 12, 10 - hop, 6, 4, '#a8886a')
        lit(p, 6, 7 - hop, 3.2, 3, '#a8886a')
        p.line(6, 4 - hop, 5, 0, '#a8886a')
        p.line(7, 4 - hop, 8, 0, '#b8987a')
        p.px(5, 6 - hop, '#1a1418')
        p.ellipse(18, 9 - hop, 1.6, 1.6, '#f4f0e8')
        p.rect(8, 13 - hop, 9, 15 - hop * 2, '#8a6a4a')
        p.rect(14 + f, 13, 16 + f, 15, '#8a6a4a')
    elif kind == 'duck':
        p = Pix(22, 18)
        bob = f
        lit(p, 12, 12 + bob, 7, 4, '#8a7a5a')
        p.ellipse(15, 11 + bob, 4, 2, '#6a5a3a')
        lit(p, 6, 6 + bob, 3, 3, '#2a7a4a')
        p.rect(1, 6 + bob, 3, 7 + bob, '#f0b030')
        p.px(5, 5 + bob, '#1a1418')
        p.rect(6, 9 + bob, 8, 9 + bob, '#f4f0e8')
        p.rect(10, 16, 11, 17, '#f0b030')
        p.rect(14 - f, 16, 15 - f, 17, '#f0b030')
    elif kind == 'deer':
        p = Pix(40, 38)
        coat = '#b0784a'
        lit(p, 22, 20, 11, 6, coat)
        p.ellipse(28, 21, 4, 3, shift(hx(coat), 0.15))
        p.line(12, 18, 9, 9, coat)
        p.line(13, 18, 10, 9, coat)
        p.line(14, 18, 11, 10, coat)
        lit(p, 8, 8, 4, 3, coat)
        p.rect(2, 8, 5, 9, shift(hx(coat), -0.1))
        p.px(1, 8, '#1a1418')
        p.px(7, 7, '#1a1418')
        for a, b in ((9, 4), (12, 3)):
            p.line(a, 5, b - 2, 0, '#d8c8a0')
            p.line(b - 2, 2, b + 1, 0, '#d8c8a0')
        legs = [(14, 0), (17, 1), (27, 0), (30, 1)]
        for x, s in legs:
            dx = (1 if (s + f) % 2 else -1)
            p.line(x, 25, x + dx, 36, shift(hx(coat), -0.2))
        for x, y in ((18, 17), (24, 16), (21, 21)):
            p.px(x, y, '#f0e0c8')
        p.ellipse(33, 17, 1.6, 1.6, '#f4f0e8')
    elif kind == 'boar':
        p = Pix(34, 22)
        coat = '#5a4038'
        lit(p, 19, 11, 11, 6, coat)
        lit(p, 7, 12, 5, 4.5, coat)
        p.rect(1, 12, 3, 14, '#8a6a5a')
        p.line(3, 15, 5, 12, '#f0e8d8')
        p.px(6, 10, '#1a1418')
        for x in range(10, 28, 3):
            p.px(x, 5, '#3a2a24')
        for x, s in ((11, 0), (14, 1), (24, 0), (27, 1)):
            dx = (1 if (s + f) % 2 else -1)
            p.line(x, 16, x + dx, 21, '#3a2a24')
    elif kind == 'pheasant':
        p = Pix(26, 20)
        lit(p, 13, 12, 6, 4, '#b8603a')
        p.line(18, 11, 25, 7 + f, '#8a5a3a')
        p.line(18, 12, 25, 9 + f, '#a86a3a')
        lit(p, 7, 7, 2.6, 2.6, '#2a5a6a')
        p.ellipse(7, 7, 1.2, 1.2, '#d83a3a')
        p.px(6, 6, '#1a1418')
        p.rect(3, 7, 4, 7, '#e8c070')
        p.rect(7, 9, 9, 9, '#f4f0e8')
        p.line(11, 16, 11 - f, 19, '#8a6a4a')
        p.line(14, 16, 14 + f, 19, '#8a6a4a')
    return p.outline()


def animal(kind):
    a = _animal_frame(kind, 0).a
    b = _animal_frame(kind, 1).a
    strip = np.concatenate([a, b], axis=1)
    return strip


# =========================================================================== crafted furniture (32 px a metre)

def rocking_chair():
    p = Pix(30, 40)
    wood = '#8a5a34'
    for x in (5, 22):
        p.box(x, 4, x + 2, 30, wood)
    for y in (6, 11, 16):
        p.box(5, y, 24, y + 1, shift(hx(wood), 0.1))
    p.box(4, 22, 27, 25, wood)
    p.box(6, 18, 25, 22, '#c84a4a')
    for x in (6, 22):
        p.line(x, 25, x + 1, 33, wood)
    for x in range(1, 29):
        y = 34 + int(((x - 15) / 14.0) ** 2 * 4)
        p.px(x, y, shift(hx(wood), -0.15))
        p.px(x, y + 1, shift(hx(wood), -0.3))
    return p.outline()


def chair():
    p = Pix(20, 32)
    wood = '#a8743f'
    p.box(3, 2, 5, 30, wood)
    p.box(15, 2, 17, 18, wood)
    for y in (4, 8, 12):
        p.box(3, y, 17, y + 1, shift(hx(wood), 0.1))
    p.box(2, 17, 18, 20, wood)
    p.box(15, 20, 17, 30, shift(hx(wood), -0.15))
    return p.outline()


def planter():
    p = Pix(40, 26)
    p.box(2, 12, 37, 25, '#8a5a34')
    p.rect(3, 12, 36, 13, '#5a3a24')
    for x0 in range(5, 36, 6):
        for a in (-0.6, 0.0, 0.6):
            x1 = x0 + math.sin(a) * 4
            y1 = 12 - math.cos(a) * (6 + (x0 % 4))
            p.line(x0, 12, x1, y1, '#3a7a3a')
            p.ellipse(x1, y1, 1.6, 1.2, '#6ab85a')
    return p.outline()


def pumpkin_lantern():
    p = Pix(22, 20)
    for dx in (-4, 0, 4):
        lit(p, 11 + dx, 12, 4.5, 6, '#e88a2a')
    p.rect(10, 3, 12, 6, '#6a8a3a')
    for x, y in ((7, 10), (14, 10)):
        p.rect(x, y, x + 2, y + 1, '#ffe070')
    for x in range(7, 16, 2):
        p.px(x, 15, '#ffe070')
        p.px(x + 1, 16, '#ffe070')
    return p.outline()


def wheat_sheaf():
    p = Pix(22, 36)
    for i in range(11):
        x0 = 4 + i * 1.4
        p.line(11, 30, x0, 4 + (i % 3), '#d8b050')
        for k in range(3):
            p.px(int(x0), 4 + (i % 3) + k * 2, '#f0d070')
    for i in range(7):
        p.line(11, 22, 7 + i, 35, '#c8a048')
    p.rect(7, 20, 15, 22, '#a8743f')
    return p.outline()


def antler_mount():
    p = Pix(32, 30)
    p.ellipse(16, 22, 9, 7, '#8a5a34')
    p.ellipse(16, 22, 6, 5, '#a8743f')
    c = '#e0d0a8'
    for s in (-1, 1):
        p.line(16 + s * 3, 18, 16 + s * 9, 8, c)
        p.line(16 + s * 9, 8, 16 + s * 13, 2, c)
        p.line(16 + s * 6, 13, 16 + s * 3, 6, c)
        p.line(16 + s * 9, 8, 16 + s * 6, 1, c)
        p.line(16 + s * 11, 5, 16 + s * 15, 6, c)
    return p.outline()


def rug_hide():
    p = Pix(64, 44)
    from PIL import ImageDraw
    im = Image.new('1', (64, 44), 0)
    pts = [(6, 6), (16, 2), (26, 6), (38, 6), (48, 2), (58, 6), (54, 18), (62, 30), (52, 40), (40, 36), (24, 36), (12, 40), (2, 30), (10, 18)]
    ImageDraw.Draw(im).polygon(pts, fill=1)
    m = np.array(im, bool)
    r = ramp('#a8784a')
    p.a[m, :3] = r[3]
    p.a[m, 3] = 255
    n = hashmap(64, 44, 31, 2)
    p.a[m & (n > 0.8), :3] = r[4]
    p.a[m & (n < 0.15), :3] = r[2]
    inner = np.array(Image.new('1', (64, 44), 0))
    p.ellipse(32, 21, 16, 10, r[4])
    return p.outline()


def ore_shelf():
    p = Pix(40, 40)
    wood = '#7a5030'
    p.box(2, 2, 37, 39, wood)
    p.rect(4, 4, 35, 37, shift(hx(wood), -0.35))
    for y in (14, 26, 37):
        p.box(4, y, 35, y + 1, wood)
    gems = [('#d8783a', 8, 11), ('#e8f0ff', 16, 11), ('#f8d040', 25, 11), ('#a86ad8', 31, 10),
            ('#ff6a2a', 10, 23), ('#e8eef8', 20, 23), ('#c8a8a0', 29, 23), ('#3a3a44', 12, 34), ('#f8c830', 24, 34)]
    for c, x, y in gems:
        lit(p, x, y, 2.6, 2.4, c)
    return p.outline()


def crystal_lamp():
    p = Pix(20, 40)
    p.box(5, 34, 14, 39, '#5a5a6a')
    p.box(8, 18, 11, 34, '#7a7a8a')
    for y in range(4, 18):
        w = 5 - abs(y - 11) * 0.6
        p.rect(10 - w, y, 9 + w, y, ramp('#ff7a3a')[3 if y > 10 else 4])
    p.line(10, 4, 10, 17, '#ffd070')
    return p.outline()


def flower_vase():
    p = Pix(20, 32)
    for i, c in enumerate(('#e87ab0', '#f8d850', '#7ab0e8', '#f0f0f0', '#e85a5a')):
        x = 4 + i * 3
        p.line(10, 20, x, 6 + (i % 2) * 3, '#3a7a3a')
        p.ellipse(x, 6 + (i % 2) * 3, 2, 2, c)
    for y in range(18, 31):
        w = 4 + math.sin((y - 18) / 13 * math.pi) * 2
        p.rect(10 - w, y, 9 + w, y, ramp('#4a7ab0')[3 if y < 27 else 2])
    return p.outline()


def hay_bale():
    p = Pix(36, 24)
    p.box(2, 4, 33, 23, '#e0c060')
    n = hashmap(36, 24, 41, 1)
    for y in range(5, 23):
        for x in range(3, 33):
            if n[y, x] > 0.8:
                p.px(x, y, '#c8a048')
            elif n[y, x] < 0.1:
                p.px(x, y, '#f0d880')
    for x in (10, 25):
        p.rect(x, 4, x, 23, '#8a5a34')
    return p.outline()


def scarecrow():
    p = Pix(32, 50)
    p.box(15, 10, 16, 49, '#8a5a34')
    p.box(3, 18, 28, 19, '#8a5a34')
    p.box(9, 17, 22, 32, '#5a7ab8')
    p.rect(9, 24, 22, 25, '#c84a4a')
    lit(p, 15.5, 11, 5, 5, '#e8d090')
    p.px(13, 10, '#1a1418')
    p.px(18, 10, '#1a1418')
    p.line(13, 13, 18, 13, '#8a5a34')
    p.rect(8, 3, 23, 6, '#c8a048')
    p.rect(11, 0, 20, 4, '#c8a048')
    for x in (3, 28):
        p.line(x, 19, x - 1 if x == 3 else x + 1, 23, '#e0c060')
    return p.outline()


def copper_pots():
    p = Pix(40, 26)
    p.box(1, 1, 38, 3, '#5a3a24')
    for i, (x, r) in enumerate(((7, 5), (19, 6), (31, 4.5))):
        p.line(x, 3, x, 8, '#3a3a44')
        lit(p, x, 14, r, r - 0.5, '#d8783a')
        p.line(x + r, 13, x + r + 4, 11, '#a85a2a')
    return p.outline()


def mushroom_lamp():
    p = Pix(20, 30)
    p.box(7, 14, 12, 29, '#efe6d2')
    for y in range(9):
        w = math.sqrt(max(0.0, 1 - ((y - 8) / 8.0) ** 2)) * 9
        p.rect(10 - w, 4 + y, 9 + w, 4 + y, ramp('#e04a8a')[3 if y > 2 else 4])
    for x, y in ((6, 8), (12, 7), (15, 10), (9, 10)):
        p.px(x, y, '#fff4c0')
    return p.outline()


def stone_hearth():
    p = Pix(48, 40)
    for y in range(8, 40, 6):
        off = (y // 6 % 2) * 4
        for x in range(2 + off - 4, 46, 8):
            p.box(max(2, x), y, min(45, x + 7), y + 5, '#9a9488')
    p.rect(14, 20, 33, 39, '#2a2024')
    p.box(10, 4, 37, 8, '#8a8478')
    for cx, c in ((19, '#ff9a2a'), (24, '#ffd84a'), (29, '#ff7a2a')):
        p.ellipse(cx, 33, 3, 5, c)
    return p.outline()


DECOR = {
    'rocking_chair': rocking_chair, 'chair': chair, 'planter': planter, 'pumpkin_lantern': pumpkin_lantern,
    'wheat_sheaf': wheat_sheaf, 'antler_mount': antler_mount, 'rug_hide': rug_hide, 'ore_shelf': ore_shelf,
    'crystal_lamp': crystal_lamp, 'flower_vase': flower_vase, 'hay_bale': hay_bale, 'scarecrow': scarecrow,
    'copper_pots': copper_pots, 'mushroom_lamp': mushroom_lamp, 'stone_hearth': stone_hearth,
}


# =========================================================================== outdoor pieces for plots (28 px a metre)

def mailbox(color='#d84a4a'):
    p = Pix(20, 36)
    p.box(8, 14, 11, 35, '#7a5030')
    r = ramp(color)
    p.box(2, 4, 17, 15, color)
    p.ellipse(9.5, 5, 7.5, 3, r[4])
    p.rect(3, 9, 16, 9, r[1])
    p.box(16, 3, 18, 9, '#f0d040')
    return p.outline()


def bench():
    p = Pix(44, 26)
    wood = '#a8743f'
    for y in (4, 8):
        p.box(2, y, 41, y + 2, wood)
    p.box(1, 14, 42, 16, wood)
    for x in (4, 38):
        p.box(x, 16, x + 2, 25, '#4a4a58')
        p.box(x, 2, x + 2, 14, '#4a4a58')
    return p.outline()


def lamppost():
    p = Pix(16, 64)
    p.box(6, 12, 9, 61, '#3a3a48')
    p.box(4, 60, 11, 63, '#3a3a48')
    p.box(3, 2, 12, 12, '#3a3a48')
    p.rect(5, 4, 10, 10, '#ffe080')
    p.rect(6, 5, 7, 7, '#fff8d0')
    return p.outline()


def well():
    p = Pix(40, 46)
    for y in range(26, 45, 5):
        off = (y // 5 % 2) * 4
        for x in range(2 + off - 4, 38, 8):
            p.box(max(3, x), y, min(36, x + 7), y + 4, '#9a9488')
    p.ellipse(20, 26, 16, 4, '#2a3a5a')
    for x in (5, 33):
        p.box(x, 6, x + 2, 26, '#7a5030')
    p.box(1, 2, 38, 7, '#b8503a')
    p.line(20, 7, 20, 18, '#c8a870')
    p.box(17, 18, 23, 23, '#8a5a34')
    return p.outline()


def birdbath():
    p = Pix(28, 32)
    p.ellipse(14, 8, 12, 4, '#b8b4ac')
    p.ellipse(14, 7, 9, 2.5, '#6aaad8')
    p.box(11, 10, 16, 27, '#a8a49c')
    p.box(6, 27, 21, 31, '#a8a49c')
    p.px(18, 5, '#3a3a48')
    p.ellipse(19, 4, 2.5, 1.6, '#8a6a4a')
    return p.outline()


def gnome():
    p = Pix(18, 30)
    for y in range(0, 12):
        w = y * 0.55
        p.rect(9 - w, y, 8 + w, y, ramp('#d83a3a')[3 if y > 2 else 4])
    lit(p, 9, 14, 4, 3, '#f0c8a0')
    p.px(7, 13, '#1a1418')
    p.px(11, 13, '#1a1418')
    p.ellipse(9, 18, 5, 4, '#f4f0e8')
    p.box(3, 19, 14, 26, '#3a6ab8')
    p.box(4, 26, 7, 29, '#5a3a24')
    p.box(10, 26, 13, 29, '#5a3a24')
    return p.outline()


def umbrella():
    p = Pix(48, 52)
    p.line(24, 10, 24, 51, '#e8e4dc')
    for y in range(0, 14):
        w = 4 + y * 1.5
        for x in range(int(24 - w), int(24 + w)):
            seg = int((x - (24 - w)) / max(1, (2 * w) / 6)) % 2
            p.px(x, y, '#e84a5a' if seg else '#f8f0e8')
    return p.outline()


def sale_sign():
    p = Pix(28, 34)
    p.box(12, 14, 15, 33, '#8a5a34')
    p.box(1, 2, 26, 15, '#f4ecd8')
    p.rect(3, 4, 24, 4, '#c84a3a')
    p.rect(3, 13, 24, 13, '#c84a3a')
    for x in range(5, 23, 4):
        p.rect(x, 7, x + 2, 10, '#5a3a24')
    return p.outline()


def stump():
    p = Pix(24, 16)
    p.ellipse(12, 10, 10, 5, '#7a5030')
    p.ellipse(12, 7, 9, 3.5, '#c8a070')
    p.ring(12, 7, 3, 4, '#a8804a')
    return p.outline()


OUTDOOR = {'mailbox': mailbox, 'bench': bench, 'lamppost': lamppost, 'well': well, 'birdbath': birdbath, 'gnome': gnome,
           'umbrella': umbrella, 'sale_sign': sale_sign, 'stump': stump}


# =========================================================================== sea monsters and treasure

def serpent_head(f=0):
    p = Pix(56, 60)
    skin = '#3a8a7a'
    for y in range(20, 60):
        w = 9 + (y - 20) * 0.12
        x = 28 + math.sin(y * 0.12) * 3
        p.rect(x - w, y, x + w, y, ramp(skin)[3 if (y // 4) % 2 else 2])
    lit(p, 28, 18, 16, 12, skin)
    p.ellipse(16, 22 + f, 10, 5, '#2a6a5a')
    p.rect(8, 22 + f, 24, 23 + f, '#1a2a2a')
    for x in range(10, 24, 3):
        p.px(x, 21 + f, '#f4f0e8')
    p.ellipse(28, 12, 3, 3, '#ffe060')
    p.px(28, 12, '#1a1418')
    for k in range(5):
        p.line(36 + k * 3, 6 + k * 4, 44 + k * 3, 2 + k * 4, '#e8604a')
    for y in range(28, 58, 6):
        p.line(20, y, 36, y, '#a8d8b8')
    return p.outline()


def serpent_hump():
    p = Pix(44, 26)
    skin = '#3a8a7a'
    for x in range(2, 42):
        h = math.sin((x - 2) / 40 * math.pi) * 20
        p.rect(x, 25 - h, x, 25, ramp(skin)[3 if (x // 4) % 2 else 2])
    for x in range(10, 36, 5):
        h = math.sin((x - 2) / 40 * math.pi) * 20
        p.line(x, 25 - h - 4, x + 2, 25 - h + 1, '#e8604a')
    return p.outline()


def tentacle(f=0):
    p = Pix(30, 72)
    skin = '#a84a7a'
    for y in range(0, 72):
        t = y / 71
        w = 2 + t * 10
        x = 15 + math.sin(t * 5 + f * 1.4) * (1 - t) * 9
        p.rect(x - w, y, x + w, y, ramp(skin)[3 if x > 14 else 2])
        if y % 7 == 3 and t > 0.2:
            p.ellipse(x + w * 0.4, y, 1.6, 1.6, '#f0c8d8')
    return p.outline()


def chest(open_=False):
    p = Pix(34, 28)
    wood = '#8a5a34'
    p.box(2, 12, 31, 27, wood)
    p.rect(2, 18, 31, 19, '#c8a048')
    p.rect(15, 12, 18, 27, '#c8a048')
    if open_:
        p.box(2, 0, 31, 8, shift(hx(wood), -0.15))
        p.ellipse(16, 12, 12, 3, '#ffd84a')
        for x, y in ((9, 10), (16, 9), (23, 10), (12, 11)):
            p.px(x, y, '#fff8c0')
    else:
        p.box(2, 5, 31, 12, wood)
        p.ellipse(16.5, 6, 14.5, 3, shift(hx(wood), 0.12))
        p.rect(15, 5, 18, 12, '#c8a048')
    p.box(14, 15, 19, 20, '#e8c048')
    return p.outline()


def icon_scale():
    p = Pix(16, 16)
    for y in range(2, 15):
        w = 6 - abs(y - 7) * 0.6
        p.rect(8 - w, y, 7 + w, y, ramp('#3a9a8a')[4 if y < 6 else 3])
    p.line(8, 3, 8, 13, '#2a6a5a')
    return p.outline()


def icon_harpoon():
    p = Pix(16, 16)
    p.line(2, 14, 12, 4, '#8a6a4a')
    p.line(12, 4, 14, 1, '#b8b8c8')
    p.line(11, 3, 14, 3, '#b8b8c8')
    p.line(13, 6, 13, 2, '#b8b8c8')
    p.line(2, 14, 1, 15, '#c8a870')
    return p.outline()


def icon_tmap():
    p = Pix(16, 16)
    p.box(1, 3, 14, 13, '#e8d8a8')
    p.line(3, 11, 6, 7, '#a85a3a')
    p.line(6, 7, 9, 9, '#a85a3a')
    p.line(10, 5, 12, 7, '#d83a3a')
    p.line(12, 5, 10, 7, '#d83a3a')
    return p.outline()


SEA = {'serpent_head_0': lambda: serpent_head(0), 'serpent_head_1': lambda: serpent_head(2), 'serpent_hump': serpent_hump,
       'tentacle_0': lambda: tentacle(0), 'tentacle_1': lambda: tentacle(1), 'chest': chest, 'chest_open': lambda: chest(True)}
ICONS.update({'serpent_scale': icon_scale, 'harpoon': icon_harpoon, 'treasure_map': icon_tmap, 'kraken_ink': lambda: icon_bowl('#2a1a3a')})


def save_img(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(img, 'RGBA').save(path)
    return img


def main():
    preview = '--preview' in sys.argv
    out = []
    for k, fn in ICONS.items():
        out.append(fn().save('land/icons/%s.png' % k))
    for kind in CROP_LOOK:
        for st in range(4):
            out.append(crop(kind, st).save('land/crops/%s_%d.png' % (kind, st)))
    for i, kind in enumerate(ORE_FLECK):
        out.append(save_img(ore_rock(kind, 40 + i), 'land/ore_%s.png' % kind))
    out.append(rubble().save('land/rubble.png'))
    out.append(workbench().save('land/workbench.png'))
    out.append(cookpot().save('land/cookpot.png'))
    out.append(garden_sign().save('land/garden_sign.png'))
    soil().save('tex/soil.png')
    soil(True).save('tex/soil_wet.png')
    for kind in ('rabbit', 'duck', 'deer', 'boar', 'pheasant'):
        out.append(save_img(animal(kind), 'land/animals/%s.png' % kind))
    for k, fn in DECOR.items():
        out.append(fn().save('decor/%s.png' % k))
    for k, fn in OUTDOOR.items():
        out.append(fn().save('land/outdoor/%s.png' % k))
    for k, fn in SEA.items():
        out.append(fn().save('land/sea/%s.png' % k))
    print('land art: %d icons, %d crops, %d decor pieces' % (len(ICONS), len(CROP_LOOK) * 4, len(DECOR)))
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        W = 10 * 52
        rows = (len(out) + 9) // 10
        sheet = Image.new('RGBA', (W, rows * 52), (60, 80, 60, 255))
        for i, t in enumerate(out):
            im = Image.fromarray(t, 'RGBA')
            im.thumbnail((48, 48), Image.NEAREST)
            sheet.alpha_composite(im, ((i % 10) * 52 + 2, (i // 10) * 52 + 2))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        sheet.save(os.path.join(PREVIEW, 'land_art.png'))
        print(os.path.join(PREVIEW, 'land_art.png'))


if __name__ == '__main__':
    main()
