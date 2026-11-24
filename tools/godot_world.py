"""Gullhaven's world for the Godot build: a 1280 x 1024 m coast, sea, river, lake and
islands, designed in code.
Usage: python3 tools/godot_world.py [--preview]

Writes godot/world/:
  height.bin  float32 heights, 1 m grid, rows run north to south (z), columns west to east (x)
  data.bin    4 planes of W*H bytes: material, fishing zone, boat tier needed, flags
  world.json  towns, buildings, docks, people, lamps, gates, lakes, landmarks, trees
  map.png     the painted map shown in game (M)

Layout (north is up, -z): Gullhaven sits on the west coast around a walled harbour. A
mangrove river runs out to the north and winds inland past Willowford up to a waterfall
below Mirrorlake in the hills. A long sandy bay curves along the south with Tideglass Cay
in it. Out east the sea gets deeper and stranger: Mossbank on the coral shelf, Kelpwood in
its fog bank, Lantern Key among the kelp, the coral atoll's lagoon, Wrecker's Cove behind
its breakers, volcanic Ember Isle, and past them all the Deep."""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'godot', 'world')
PREVIEW = os.environ.get('WORLD_PREVIEW', '/tmp/claude-0/world_preview')
W, H = 1280, 1024

MATS = ['grass', 'sand', 'rock', 'dirt', 'cobble', 'forest', 'mud', 'pebble']
M = {k: i for i, k in enumerate(MATS)}
ZONES = ['', 'harbour', 'shallows', 'estuary', 'reef', 'kelp', 'wreck', 'blue', 'deep', 'lake', 'seagrass', 'lagoon']
Z = {k: i for i, k in enumerate(ZONES)}
F_ROAD, F_TOWN, F_RIVER, F_COMB, F_DECK, F_FOG, F_EMBER, F_HIGHLAND = 1, 2, 4, 8, 16, 32, 64, 128

zz, xx = np.mgrid[0:H, 0:W].astype(np.float64)
xx += 0.5
zz += 0.5


# ------------------------------------------------------------------------ noise

def _lattice(ix, iz, seed):
    h = (ix.astype(np.int64) * 374761393 + iz.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


def vnoise(x, z, scale, seed):
    fx, fz = x / scale, z / scale
    ix, iz = np.floor(fx), np.floor(fz)
    tx, tz = fx - ix, fz - iz
    sx, sz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
    a = _lattice(ix, iz, seed)
    b = _lattice(ix + 1, iz, seed)
    c = _lattice(ix, iz + 1, seed)
    d = _lattice(ix + 1, iz + 1, seed)
    return a + (b - a) * sx + (c - a) * sz + (a - b - c + d) * sx * sz


def fbm(x, z, scale, octaves, seed, gain=0.5):
    v = 0.0
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        v = v + amp * vnoise(x, z, scale / (2 ** o), seed + o * 17)
        tot += amp
        amp *= gain
    return v / tot


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def curve(points, t_values):
    """Monotone piecewise-cubic through (t, v) control points."""
    pts = np.array(points, float)
    return np.interp(t_values, pts[:, 0], pts[:, 1])


def catmull(points, n=24):
    out = []
    P = [points[0]] + list(points) + [points[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = map(np.array, (P[i - 1], P[i], P[i + 1], P[i + 2]))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(np.array(points[-1], float))
    return np.array(out)


def dist_to_polyline(pts):
    """Distance from every cell to a polyline, plus the arc length (0..1) of the nearest point."""
    pts = np.asarray(pts, float)
    best = np.full((H, W), 1e9)
    along = np.zeros((H, W))
    seglen = np.hypot(np.diff(pts[:, 0]), np.diff(pts[:, 1]))
    total = seglen.sum()
    acc = 0.0
    x0b, x1b = pts[:, 0].min() - 80, pts[:, 0].max() + 80
    z0b, z1b = pts[:, 1].min() - 80, pts[:, 1].max() + 80
    sub = (slice(max(0, int(z0b)), min(H, int(z1b))), slice(max(0, int(x0b)), min(W, int(x1b))))
    X, Zz = xx[sub], zz[sub]
    bsub = best[sub]
    asub = along[sub]
    for i in range(len(pts) - 1):
        ax, az = pts[i]
        bx, bz = pts[i + 1]
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz or 1.0
        t = np.clip(((X - ax) * dx + (Zz - az) * dz) / L2, 0, 1)
        px, pz = ax + t * dx, az + t * dz
        d = np.hypot(X - px, Zz - pz)
        upd = d < bsub
        bsub[upd] = d[upd]
        asub[upd] = (acc + t[upd] * seglen[i]) / total
        acc += seglen[i]
    best[sub] = bsub
    along[sub] = asub
    return best, along


# ------------------------------------------------------------------- the shapes

# West coast: x of the shoreline for each z (north to south).
COAST = [(0, 610), (90, 620), (170, 590), (240, 548), (300, 515), (345, 492), (380, 488), (430, 470), (480, 452),
         (520, 445), (560, 440), (600, 440), (650, 448), (700, 436), (760, 412), (820, 392), (880, 384), (1024, 384)]
# South coast: z of the shoreline for each x (west to east); it ends in a point at x 820.
SOUTH = [(0, 900), (360, 902), (400, 888), (450, 930), (520, 952), (600, 958), (680, 950), (760, 930), (800, 924), (830, 940)]
RIVER = [(492, 362), (462, 352), (430, 346), (398, 334), (366, 318), (336, 300), (310, 284), (290, 262), (270, 236),
         (250, 210), (232, 186), (216, 166), (206, 154)]
LAKE = dict(name='Mirrorlake', cx=150.0, cz=112.0, rx=58.0, rz=40.0, level=22.0)
BASIN = (446, 548, 506, 604)  # Gullhaven harbour basin: x0, z0, x1, z1

ISLANDS = [
    # id, name, centre x, z, radius, peak height, shore (sand/rock), shape seed
    dict(id='gullrock', name='Gull Rock', x=572, z=470, r=13, peak=7, shore='rock', seed=3),
    dict(id='tideglass', name='Tideglass Cay', x=566, z=826, r=26, peak=2.2, shore='sand', seed=5),
    dict(id='mossbank', name='Mossbank', x=770, z=318, r=34, peak=9, shore='sand', seed=7),
    dict(id='kelpwood', name='Kelpwood', x=772, z=640, r=30, peak=8, shore='sand', seed=11),
    dict(id='lantern', name='Lantern Key', x=982, z=548, r=34, peak=14, shore='rock', seed=13),
    dict(id='cove', name="Wrecker's Cove", x=1086, z=214, r=40, peak=20, shore='rock', seed=17, cove=True),
    dict(id='ember', name='Ember Isle', x=1066, z=872, r=46, peak=30, shore='rock', seed=19, volcano=True),
]
ATOLL = dict(id='atoll', name='Turquoise Atoll', x=902, z=846, R=44, width=9, seed=23)


def build_land():
    """Signed distance in metres: positive on land, negative at sea."""
    nz = (fbm(xx, zz, 60, 3, 101) - 0.5) * 18 + (fbm(xx, zz, 14, 2, 102) - 0.5) * 4
    cx = curve(COAST, zz[:, 0])[:, None]
    west = cx - xx + nz
    sz = curve(SOUTH, xx[0, :])[None, :]
    # the south coast's eastern tip tapers smoothly off into the sea
    south = zz - sz + nz * 0.7 - smooth(770, 900, xx) * 260
    land = np.maximum(west, south)
    for I in ISLANDS:
        d = np.hypot(xx - I['x'], zz - I['z'])
        ang = np.arctan2(zz - I['z'], xx - I['x'])
        wob = 1 + 0.18 * np.sin(ang * 3 + I['seed']) + 0.1 * np.sin(ang * 7 + I['seed'] * 2) + (vnoise(xx, zz, 9, I['seed']) - 0.5) * 0.25
        s = I['r'] * wob - d
        if I.get('cove'):
            # a sheltered cove bites into the island's west side
            dc = np.hypot(xx - (I['x'] - I['r'] * 0.55), zz - I['z'])
            s = np.minimum(s, dc - I['r'] * 0.42)
        land = np.maximum(land, s)
    # the atoll: a thin ring of sand around a lagoon, with two channels
    A = ATOLL
    d = np.hypot(xx - A['x'], zz - A['z'])
    ang = np.arctan2(zz - A['z'], xx - A['x'])
    ring = A['width'] / 2 * (1 + 0.4 * np.sin(ang * 5 + 1)) - np.abs(d - A['R'] * (1 + 0.08 * np.sin(ang * 3)))
    gaps = (np.abs(np.angle(np.exp(1j * (ang - 2.4)))) < 0.16) | (np.abs(np.angle(np.exp(1j * (ang + 0.5)))) < 0.12)
    ring = np.where(gaps & (np.abs(d - A['R']) < 14), -4, ring)
    land = np.maximum(land, ring)
    return land


def build():
    land = build_land()
    # the river and the harbour basin are cut into the land
    rpts = catmull(RIVER, 18)
    rd, ralong = dist_to_polyline(rpts)
    rwidth = 34 - ralong * 22  # wide at the mangrove mouth, narrow up by the falls
    river = rd < rwidth / 2
    land = np.where(river, np.minimum(land, -(rwidth / 2 - rd)), land)
    bx0, bz0, bx1, bz1 = BASIN
    basin = (xx > bx0) & (xx < bx1) & (zz > bz0) & (zz < bz1)
    # breakwater arms north and south of the basin, out to a lighthouse on the north arm
    north_arm = (xx > 438) & (xx < 514) & (zz > 539) & (zz < 548)
    south_arm = (xx > 438) & (xx < 504) & (zz > 604) & (zz < 612)
    land = np.where(basin, np.minimum(land, -3.0), land)
    land = np.where(north_arm | south_arm, np.maximum(land, 2.0), land)
    lake_d = ((xx - LAKE['cx']) / LAKE['rx']) ** 2 + ((zz - LAKE['cz']) / LAKE['rz']) ** 2
    lake_d = lake_d * (1 + (vnoise(xx, zz, 18, 31) - 0.5) * 0.3)
    lake = lake_d < 1.0

    # ---------------------------------------------------------------- heights
    hills = fbm(xx, zz, 140, 4, 201)
    ridges = 1 - np.abs(fbm(xx, zz, 90, 3, 202) * 2 - 1)
    inland = smooth(10, 160, land)
    # a mountain range in the north-west around the lake, rising from the coast
    mount = 46 * np.exp(-(((xx - 150) / 230) ** 2 + ((zz - 120) / 210) ** 2)) + 14 * ridges * np.exp(-(((xx - 150) / 300) ** 2 + ((zz - 140) / 260) ** 2))
    hgt = 1.0 + inland * (hills * 9 + mount)
    # beaches and rocky shores near the water
    sandy = fbm(xx, zz, 70, 2, 203) > 0.42
    shore_h = np.where(sandy, 0.25 + land * 0.075, 0.5 + land * 0.32)
    hgt = np.where(land < 18, np.minimum(hgt, shore_h) + smooth(8, 18, land) * (hgt - np.minimum(hgt, shore_h)), hgt)
    # gentle terraces inland, the HD-2D look: flat steps with steep risers
    step = 2.0
    k = hgt / step
    fr = k - np.floor(k)
    terr = (np.floor(k) + smooth(0.72, 1.0, fr)) * step
    hgt = np.where((land > 25) & (hgt > 2.5), terr, hgt)

    # a broad valley follows the river down from the falls; only near the falls is it a gorge
    valley = 1.1 + np.maximum(0, rd - rwidth / 2) * (0.09 + ralong * 0.05)
    vblend = smooth(0.95, 0.8, ralong) * (land > 0)
    hgt = np.where(vblend > 0, hgt * (1 - vblend) + np.minimum(hgt, valley) * vblend, hgt)

    # sea floor: shallow near the shore, deeper out east, the trench past x 1150
    base = -2.2 - smooth(560, 1000, xx) * 14 - smooth(1120, 1240, xx) * 26 + (fbm(xx, zz, 50, 3, 204) - 0.5) * 3
    bay = (zz > 640) & (xx < 800) & (xx > 380)
    bay_w = smooth(600, 700, zz) * smooth(840, 740, xx)
    bay_floor = -2.6 + (fbm(xx, zz, 40, 2, 205) - 0.5) * 1.2
    base = np.where(bay_w > 0, base * (1 - bay_w) + np.maximum(base, bay_floor) * bay_w, base)
    shelf = -0.3 + land * 0.07
    sea = np.maximum(shelf, base)
    hgt = np.where(land >= 0, hgt, sea)
    # river bed, basin and lake
    hgt = np.where(river, np.minimum(hgt, -0.4 - 1.4 * np.clip(1 - rd / (rwidth / 2), 0, 1) ** 0.7), hgt)
    near_river = (rd < rwidth / 2 + 14) & ~river & (land > 0)
    hgt = np.where(near_river, np.minimum(hgt, 0.45 + (rd - rwidth / 2) * 0.14), hgt)
    hgt = np.where(basin, -2.4, hgt)
    hgt = np.where(north_arm | south_arm, 0.9, hgt)
    lake_bed = LAKE['level'] - 3.6 * (1 - lake_d)
    hgt = np.where(lake, np.minimum(lake_bed, LAKE['level'] - 0.3), hgt)
    lake_shore = (lake_d >= 1.0) & (lake_d < 1.6)
    hgt = np.where(lake_shore, np.maximum(hgt, LAKE['level'] + 0.4 + (lake_d - 1.0) * 6), hgt)
    # the islands: rounded hills, a volcano, a cove
    for I in ISLANDS:
        d = np.hypot(xx - I['x'], zz - I['z'])
        on = (land > 0) & (d < I['r'] * 1.6)
        r = I['r']
        ih = 0.4 + I['peak'] * smooth(r * 0.95, r * 0.15, d) ** 1.2 * (0.75 + 0.5 * fbm(xx, zz, 20, 2, I['seed']))
        if I['shore'] == 'sand':
            ih = np.minimum(ih, 0.3 + land * 0.1 + smooth(6, 16, land) * I['peak'])
        if I.get('volcano'):
            crater = I['peak'] * 0.75 * smooth(r * 0.2, 0, d)
            ih = ih - crater
        hgt = np.where(on, ih, hgt)
    A = ATOLL
    da = np.hypot(xx - A['x'], zz - A['z'])
    lagoon = (da < A['R'] * 0.95) & (land < 0)
    hgt = np.where(lagoon, np.maximum(hgt, -1.6 + (fbm(xx, zz, 12, 2, 206) - 0.5)), hgt)
    ring_land = (land > 0) & (np.abs(da - A['R']) < 12)
    hgt = np.where(ring_land, np.minimum(hgt, 0.4 + land * 0.12), hgt)
    # breakers around Wrecker's Cove: a broken reef ring, just under the surface
    I = ISLANDS[5]
    dc = np.hypot(xx - I['x'], zz - I['z'])
    reefring = (np.abs(dc - I['r'] * 2.1) < 5) & (land < 0) & (vnoise(xx, zz, 7, 41) > 0.35)
    hgt = np.where(reefring, np.maximum(hgt, -0.5), hgt)
    return dict(land=land, hgt=hgt, river=river, rd=rd, rwidth=rwidth, ralong=ralong, basin=basin, lake=lake,
                lake_d=lake_d, north_arm=north_arm, south_arm=south_arm, sandy=sandy, lagoon=lagoon, bay=bay,
                reefring=reefring, rpts=rpts)


# ------------------------------------------------------------------- the towns

def B(kind, x, z, w, d, h=3.2, rot=0, wall='plaster', roof='roof_red', name='', sign='', role=''):
    return dict(kind=kind, x=x, z=z, w=w, d=d, h=h, rot=rot, wall=wall, roof=roof, name=name, sign=sign, role=role)


def towns():
    T = []
    # Gullhaven: the quay runs along x 446 facing the basin; streets climb west
    g = dict(id='gullhaven', name='Gullhaven', x=410.0, z=575.0, r=62, h=0.9, buildings=[], docks=[], quays=[], lamps=[],
             people=[], props=[], street='cobble')
    gb = g['buildings']
    # rot is the direction the door faces: 0 east (toward the harbour), 1 south, 2 west, 3 north
    gb += [
        B('shop', 431, 556, 7, 6, 3.4, 0, 'plaster', 'roof_green', "Hale's Tackle", 'TACKLE', 'tackle'),
        B('shop', 431, 572, 7, 6, 3.2, 0, 'stone', 'roof_blue', 'Fishmonger', 'FISH', 'fishmonger'),
        B('tavern', 430, 590, 9, 8, 4.4, 0, 'timber', 'roof_red', 'The Gull & Anchor', 'TAVERN', 'tavern'),
        B('shop', 417, 545, 7, 6, 3.2, 1, 'timber', 'roof_red', 'Boatyard Office', 'BOATS', 'boatyard'),
        B('shop', 404, 556, 6, 6, 3.0, 0, 'plaster', 'roof_blue', "Juniper's Bakery", 'BAKERY', 'bakery'),
        B('shop', 404, 572, 7, 6, 3.2, 0, 'timber', 'roof_green', 'Carpenter', 'CARPENTER', 'carpenter'),
        B('museum', 402, 592, 11, 9, 4.6, 0, 'stone', 'roof_blue', 'Aquarium & Museum', 'AQUARIUM', 'museum'),
        B('hall', 386, 575, 9, 8, 4.2, 0, 'stone', 'roof_red', 'Harbourmaster', 'HARBOURMASTER', 'harbourmaster'),
        B('house', 388, 552, 6, 5, 3.0, 1, 'plaster', 'roof_red', 'Cottage'),
        B('house', 377, 560, 5, 5, 3.2, 0, 'timber', 'roof_blue', 'Cottage'),
        B('house', 388, 598, 6, 5, 3.0, 3, 'plaster', 'roof_green', 'Cottage'),
        B('house', 374, 592, 5, 6, 3.4, 0, 'stone', 'roof_red', 'Cottage'),
        B('house', 418, 612, 6, 5, 3.0, 3, 'plaster', 'roof_blue', 'Cottage'),
        B('house', 368, 575, 6, 5, 3.0, 0, 'timber', 'roof_red', 'Cottage'),
        B('house', 401, 534, 6, 5, 3.0, 1, 'plaster', 'roof_green', 'Cottage'),
    ]
    g['lighthouse'] = dict(x=510.0, z=543.5)
    g['quays'] = [dict(x0=444.5, z0=546.0, x1=447.5, z1=606.0)]
    g['docks'] = [dict(x=447.0, z=560.0, w=30.0, d=3.0), dict(x=447.0, z=577.0, w=36.0, d=3.0), dict(x=447.0, z=594.0, w=24.0, d=3.0)]
    g['lamps'] = [[442, 552], [442, 566], [442, 582], [442, 598], [422, 540], [410, 565], [410, 584], [395, 566], [395, 585],
                  [470, 543.5], [496, 543.5], [470, 608], [490, 608]]
    g['people'] = [
        dict(name='Hale', sheet='hale', x=437.5, z=559.0, role='shop:tackle', inside='tackle'),
        dict(name='Mags', sheet='fishmonger', x=437.5, z=575.0, role='shop:fishmonger', inside='fishmonger'),
        dict(name='Old Marlo', sheet='marlo', x=476.0, z=578.5, role='ask:harbour'),
        dict(name='Juniper', sheet='juniper', x=409.0, z=559.0, role='ask:any', inside='bakery'),
        dict(name='Bosun Pell', sheet='boatwright', x=420.5, z=551.0, role='shop:boatyard', inside='boatyard'),
        dict(name='Tess', sheet='carpenter', x=409.0, z=575.0, role='shop:carpenter', inside='carpenter'),
        dict(name='Dr. Finch', sheet='curator', x=409.0, z=596.0, role='shop:museum', inside='museum'),
        dict(name='Rosa', sheet='keeper', x=437.0, z=593.0, role='shop:tavern', inside='tavern'),
        dict(name='Harbourmaster Quill', sheet='villager_d', x=392.0, z=578.0, role='shop:harbourmaster', inside='harbourmaster'),
        dict(name='Nell', sheet='villager_a', x=398.0, z=566.0, role='tips'),
        dict(name='Pip', sheet='pip', x=431.0, z=692.0, role='ask:shallows'),  # down on the beach by your hut
    ]
    g['props'] = [['crates', 443, 560], ['barrels', 443, 571], ['crates', 443, 588], ['nets', 443, 600], ['stall', 422, 566]]
    T.append(g)

    # the player's hut on the beach south of town, with its own little jetty
    hut = dict(x=420.0, z=676.0, rot=0, jetty=dict(x=428.0, z=676.0, w=16.0, d=2.4))

    # Willowford: a river town with a mill, an inn and a ranger station
    w = dict(id='willowford', name='Willowford', x=326.0, z=240.0, r=30, h=None, buildings=[], docks=[], quays=[], lamps=[],
             people=[], props=[], street='dirt')
    w['buildings'] = [
        B('mill', 306, 240, 7, 7, 6.0, 2, 'stone', 'roof_red', 'Willowford Mill', 'MILL', 'mill'),
        B('tavern', 336, 228, 9, 7, 4.2, 1, 'timber', 'roof_green', 'The Willow Inn', 'INN', 'inn'),
        B('shop', 322, 222, 7, 6, 3.2, 1, 'plaster', 'roof_blue', 'General Store', 'STORE', 'general'),
        B('shop', 344, 246, 7, 6, 3.2, 2, 'timber', 'roof_red', 'Ranger Station', 'RANGER', 'ranger'),
        B('house', 330, 258, 6, 5, 3.0, 3, 'plaster', 'roof_red', 'Cottage'),
        B('house', 316, 254, 5, 5, 3.2, 3, 'timber', 'roof_green', 'Cottage'),
        B('house', 348, 262, 6, 5, 3.0, 2, 'stone', 'roof_blue', 'Cottage'),
    ]
    w['docks'] = [dict(x=300.0, z=252.0, w=10.0, d=2.6, rot=2)]
    w['lamps'] = [[314, 236], [330, 236], [330, 248], [318, 246]]
    w['people'] = [
        dict(name='Miller Ottie', sheet='villager_b', x=311.0, z=241.0, role='tips', inside='mill'),
        dict(name='Wren', sheet='keeper', x=336.0, z=233.0, role='shop:inn', inside='inn'),
        dict(name='Barnaby', sheet='villager_c', x=322.0, z=227.0, role='shop:general', inside='general'),
        dict(name='Ranger Hollis', sheet='ranger', x=340.0, z=246.0, role='shop:ranger', inside='ranger'),
        dict(name='Ivy', sheet='kid_b', x=304.0, z=250.0, role='ask:estuary'),
    ]
    T.append(w)

    lodge = dict(id='mirrorlake', name='Mirrorlake Lodge', x=196.0, z=96.0, r=22, h=24.5, buildings=[], docks=[], quays=[], lamps=[],
                 people=[], props=[], street='dirt')
    lodge['buildings'] = [
        B('lodge', 200, 88, 11, 8, 4.6, 1, 'timber', 'roof_green', 'Mirrorlake Lodge', 'LODGE', 'lodge'),
        B('house', 212, 102, 5, 5, 3.0, 2, 'timber', 'roof_red', 'Boathouse'),
    ]
    lodge['docks'] = [dict(x=196.0, z=108.0, w=10.0, d=2.4, rot=2)]
    lodge['lamps'] = [[194, 96], [206, 96]]
    lodge['people'] = [dict(name='Old Sable', sheet='salvager', x=190.0, z=100.0, role='ask:lake'),
                       dict(name='Elsie', sheet='villager_a', x=204.0, z=92.0, role='shop:lodge', inside='lodge')]
    T.append(lodge)

    # island settlements, from the web game
    def island_town(I, kind_shop, sign, shop_name, roof, wall, keeper, sheet, ask, local, extra=None):
        # settle on the side facing Gullhaven, down by the water
        ang = math.atan2(575 - I['z'], 430 - I['x'])
        t = dict(id=I['id'], name=I['name'], x=I['x'] + math.cos(ang) * I['r'] * 0.42, z=I['z'] + math.sin(ang) * I['r'] * 0.42,
                 r=I['r'] * 0.42, h=1.6 if I['shore'] == 'sand' else 2.2, blend=12, auto_dock=ang,
                 buildings=[], docks=[], quays=[], lamps=[], people=[], props=[], street='sand')
        cx, cz = t['x'], t['z']
        t['buildings'] = [
            B('shop', cx - 6, cz - 4, 7, 6, 3.2, 1, wall, roof, shop_name, sign, kind_shop),
            B('house', cx + 6, cz - 5, 5, 5, 3.0, 1, wall, roof, 'Cottage'),
            B('house', cx - 2, cz - 14, 5, 4, 3.0, 1, wall, roof, 'Cottage'),
        ]
        t['lamps'] = [[cx, cz + 2], [cx - 9, cz + 1]]
        t['people'] = [dict(name=keeper, sheet=sheet, x=cx - 6, z=cz, role='shop:' + kind_shop, inside=kind_shop),
                       dict(name=local, sheet='islander', x=cx + 4, z=cz + 3, role='ask:' + ask)]
        if extra:
            extra(t)
        return t

    I = {i['id']: i for i in ISLANDS}
    T.append(island_town(I['tideglass'], 'baittea', 'BAIT & TEA', 'Bait & Tea', 'roof_blue', 'plaster', 'Auntie Coral', 'villager_d', 'shallows', 'Marina'))
    T.append(island_town(I['mossbank'], 'home', 'HOME GOODS', 'Home Goods', 'roof_green', 'plaster', 'Fern', 'villager_c', 'reef', 'Old Tom'))
    T.append(island_town(I['kelpwood'], 'kelptea', 'KELP TEA', 'Kelp Tea House', 'roof_green', 'timber', 'Master Ito', 'curator', 'kelp', 'Sorrel'))
    T.append(island_town(I['lantern'], 'boatworks', 'BOATWORKS', 'Lantern Boatworks', 'roof_blue', 'stone', 'Captain Ada', 'marlo', 'kelp', 'Keeper Moss'))
    T.append(island_town(I['cove'], 'salvager', 'SALVAGER', 'Salvager', 'roof_red', 'timber', 'Scrapper Jo', 'salvager', 'wreck', 'Dregs'))
    T.append(island_town(I['ember'], 'forge', 'FORGE', 'Ember Forge', 'roof_red', 'stone', 'Smith Brandt', 'boatwright', 'blue', 'Cinder'))
    return T, hut


# --------------------------------------------------------------------- painting

def finish(S, T, hut):
    land, hgt = S['land'], S['hgt'].copy()
    mat = np.zeros((H, W), np.uint8)
    zone = np.zeros((H, W), np.uint8)
    tier = np.zeros((H, W), np.uint8)
    flags = np.zeros((H, W), np.uint8)

    # towns: flatten to a plateau and keep the trees out
    for t in T:
        d = np.hypot(xx - t['x'], zz - t['z'])
        r = t['r']
        on = land > 0
        if t['h'] is None:
            core = (d < r) & on
            t['h'] = float(np.median(hgt[core])) if core.any() else 1.2
            t['h'] = max(1.0, t['h'])
        wgt = smooth(r + t.get('blend', 32), r * 0.9, d) * on
        hgt = hgt * (1 - wgt) + t['h'] * wgt
        flags[(d < r + 4) & on] |= F_TOWN
        for b in t['buildings']:
            b['y'] = t['h']
        if 'auto_dock' in t:
            # walk out from the village until the water is about a metre deep, and build there
            a = t['auto_dock']
            dxz = (math.cos(a), math.sin(a))
            for step in range(2, 120):
                px, pz = t['x'] + dxz[0] * step, t['z'] + dxz[1] * step
                if not (0 <= int(pz) < H and 0 <= int(px) < W):
                    break
                if hgt[int(pz), int(px)] < -0.2:
                    deg = math.degrees(a) % 360
                    rot = 0 if (deg < 45 or deg >= 315) else 1 if deg < 135 else 2 if deg < 225 else 3
                    sx = px - dxz[0] * 4
                    sz_ = pz - dxz[1] * 4
                    t['docks'].append(dict(x=round(sx, 1), z=round(sz_, 1), w=16.0, d=2.6, rot=rot))
                    t['moor'] = [round(px + dxz[0] * 10, 1), round(pz + dxz[1] * 10, 1)]
                    break
    # the hut's patch of beach
    dh = np.hypot(xx - hut['x'], zz - hut['z'])
    hw = smooth(14, 7, dh) * (land > 0)
    hgt = hgt * (1 - hw) + 1.0 * hw
    flags[(dh < 9) & (land > 0)] |= F_TOWN
    hut['y'] = 1.0

    # roads: smoothed height profiles, dirt between towns, cobbles in Gullhaven
    roads = [
        [(400, 545), (400, 610)], [(376, 566), (440, 566)], [(376, 584), (440, 584)], [(440, 552), (440, 604)],
        [(400, 610), (410, 640), (418, 668)],  # down to the hut and the beach
        [(400, 545), (410, 500), (430, 440), (452, 392), (452, 368), (450, 338), (420, 318), (372, 300), (336, 284)],  # north road, over the river
        [(336, 284), (300, 270), (270, 248), (250, 228), (232, 210), (222, 186), (214, 150), (206, 124), (200, 100)],  # up to the lake
    ]
    road_mask = np.zeros((H, W), bool)
    for i, rp in enumerate(roads):
        pts = catmull(rp, 10)
        d, along = dist_to_polyline(pts)
        wdt = 3.2 if i >= 5 else 2.4
        m = (d < wdt) & (land > -0.5)
        # follow a smoothed version of the ground height along the road
        prof = np.array([hgt[int(np.clip(p[1], 0, H - 1)), int(np.clip(p[0], 0, W - 1))] for p in pts])
        prof = np.maximum(prof, 0.8)
        prof = ndimage.uniform_filter1d(prof, 9, mode='nearest')
        target = np.interp(along, np.linspace(0, 1, len(prof)), prof)
        blend = smooth(wdt + 4, wdt * 0.6, d) * (land > 0)
        hgt = np.where(blend > 0, hgt * (1 - blend) + target * blend, hgt)
        road_mask |= m
    flags[road_mask] |= F_ROAD

    # the mountain path is steep: a hairpin cut keeps it walkable (handled by the road blend)
    # Land materials
    slope = np.hypot(*np.gradient(hgt))
    forest = (fbm(xx, zz, 90, 3, 301) > 0.52) & (land > 30)
    mat[:] = M['grass']
    mat[forest] = M['forest']
    mat[(land > 0) & (hgt < 1.6) & S['sandy'] & (land < 30)] = M['sand']
    mat[(land > 0) & (land < 4) & ~S['sandy']] = M['pebble']
    mat[slope > 0.85] = M['rock']
    mat[(land > 0) & (hgt > 44)] = M['rock']
    # mangrove mud at the river mouth
    mouth = (S['rd'] < S['rwidth'] / 2 + 22) & (S['ralong'] < 0.3) & (land > -1)
    mat[mouth & (hgt < 1.4)] = M['mud']
    # under the water: sand in the shallows, pebbles deeper, mud in the river
    under = hgt < 0
    mat[under] = M['sand']
    mat[under & (hgt < -5)] = M['pebble']
    mat[S['river']] = M['mud']
    mat[road_mask] = M['dirt']
    for t in T:
        d = np.hypot(xx - t['x'], zz - t['z'])
        if t['street'] == 'cobble':
            mat[road_mask & (d < t['r'] + 6)] = M['cobble']
        elif t['street'] == 'sand':
            mat[(d < t['r'] * 0.7) & (land > 0)] = M['sand']
    # volcanic Ember Isle
    Ei = ISLANDS[6]
    de = np.hypot(xx - Ei['x'], zz - Ei['z'])
    mat[(de < Ei['r'] * 1.2) & (land > 0) & (hgt > 3)] = M['rock']
    flags[(de < Ei['r'] * 2.2) & (land < 4)] |= F_EMBER
    # beachcombing on dry sandy shores
    flags[(mat == M['sand']) & (land > 0) & (hgt < 1.6)] |= F_COMB
    flags[S['river']] |= F_RIVER

    # ------------------------------------------------------ fishing zones
    water = hgt < 0.0
    lake = S['lake']
    zone[water] = Z['shallows']
    zone[water & (hgt < -10)] = Z['blue']
    zone[water & (xx > 1150)] = Z['deep']
    # the harbour: the basin and the water along Gullhaven's coast
    harb = water & (np.hypot(xx - 482, (zz - 576) * 0.8) < 105) & (xx < 600)
    zone[harb] = Z['harbour']
    # the bay: sandy shallows with seagrass meadows
    bay = water & S['bay']
    zone[bay] = Z['shallows']
    meadow = bay & (fbm(xx, zz, 36, 3, 302) > 0.55) & (hgt < -1.0)
    zone[meadow] = Z['seagrass']
    zone[S['river']] = Z['estuary']
    mouth_w = water & (np.hypot(xx - 492, zz - 362) < 60)
    zone[mouth_w] = Z['estuary']
    for I in ISLANDS:
        d = np.hypot(xx - I['x'], zz - I['z'])
        ring = water & (d < I['r'] * 2.4)
        if I['id'] in ('mossbank', 'gullrock'):
            zone[ring] = Z['reef']
        elif I['id'] in ('kelpwood', 'lantern'):
            zone[ring] = Z['kelp']
        elif I['id'] == 'cove':
            zone[water & (d < I['r'] * 2.8)] = Z['wreck']
        elif I['id'] == 'tideglass':
            zone[water & (d < I['r'] * 2.0) & (zone != Z['seagrass'])] = Z['shallows']
        elif I['id'] == 'ember':
            zone[ring] = Z['blue']
    A = ATOLL
    da = np.hypot(xx - A['x'], zz - A['z'])
    zone[water & (da < A['R'] + 26) & (da > A['R'] - 2)] = Z['reef']
    zone[S['lagoon'] & water] = Z['lagoon']
    zone[lake] = Z['lake']
    zone[~water & ~lake] = 0

    # ------------------------------------------------------ boat tiers
    # 1 rowboat, 2 dinghy, 3 skiff, 4 trawler, 5 cutter
    d_main = ndimage.distance_transform_edt(np.maximum(S['land'] < 0, False) | True) if False else None
    tier[water] = 1
    tier[water & ((xx > 640) | (zz < 300))] = 2
    tier[water & (xx > 860)] = 3
    I = ISLANDS[5]
    dc = np.hypot(xx - I['x'], zz - I['z'])
    tier[water & (dc < I['r'] * 2.6)] = 4
    tier[water & (xx > 1150)] = 5
    tier[water & bay] = 1
    tier[S['river'] | lake] = 1
    # Kelpwood's fog bank: a ring around the island you need a deck lamp to cross
    Ik = ISLANDS[3]
    dk = np.hypot(xx - Ik['x'], zz - Ik['z'])
    flags[water & (dk < Ik['r'] * 2.6) & (dk > Ik['r'] * 1.5)] |= F_FOG
    # the highlands past the ranger gate
    flags[(land > 0) & (np.hypot(xx - 170, zz - 120) < 120) & (zz < 205)] |= F_HIGHLAND

    # docks and quays are solid decks (not water) for casting and fishing
    for t in T:
        for dk_ in t['docks']:
            x0, z0, wd, dp = dk_['x'], dk_['z'], dk_['w'], dk_['d']
            rot = dk_.get('rot', 0)
            if rot in (0, 2):
                xs = (x0, x0 + wd) if rot == 0 else (x0 - wd, x0)
                zs = (z0 - dp / 2, z0 + dp / 2)
            else:
                zs = (z0, z0 + wd) if rot == 1 else (z0 - wd, z0)
                xs = (x0 - dp / 2, x0 + dp / 2)
            dk_['rect'] = [xs[0], zs[0], xs[1], zs[1]]
            m = (xx > xs[0]) & (xx < xs[1]) & (zz > zs[0]) & (zz < zs[1])
            flags[m] |= F_DECK
    j = hut['jetty']
    hut['jetty']['rect'] = [j['x'], j['z'] - j['d'] / 2, j['x'] + j['w'], j['z'] + j['d'] / 2]
    m = (xx > j['x']) & (xx < j['x'] + j['w']) & (zz > j['z'] - j['d'] / 2) & (zz < j['z'] + j['d'] / 2)
    flags[m] |= F_DECK

    return hgt, mat, zone, tier, flags


# ------------------------------------------------------------------ vegetation

PLANTS = ['oak0', 'oak1', 'oak2', 'autumn0', 'autumn1', 'pine0', 'pine1', 'birch0', 'birch1', 'palm0', 'palm1', 'willow0',
          'mangrove0', 'mangrove1', 'dead0', 'bush0', 'bush1', 'bush2', 'bush_pink', 'bush_white', 'bush_yellow',
          'flowers0', 'flowers1', 'flowers2', 'flowers3', 'flowers4', 'reeds0', 'reeds1', 'fern0', 'fern1',
          'rock0', 'rock1', 'rock2', 'boulder0', 'boulder1']
P = {k: i for i, k in enumerate(PLANTS)}


def scatter(hgt, mat, flags, S):
    rng = np.random.RandomState(2026)
    out = []
    cell = 3
    gz, gx = np.mgrid[0:H:cell, 0:W:cell]
    jx = gx + rng.uniform(0, cell, gx.shape)
    jz = gz + rng.uniform(0, cell, gz.shape)
    ix = np.clip(jx.astype(int), 0, W - 1)
    iz = np.clip(jz.astype(int), 0, H - 1)
    h = hgt[iz, ix]
    m = mat[iz, ix]
    f = flags[iz, ix]
    land = S['land'][iz, ix]
    slope = np.hypot(*np.gradient(hgt))[iz, ix]
    r = rng.uniform(0, 1, gx.shape)
    pick = rng.uniform(0, 1, gx.shape)
    dens = fbm(jx, jz, 70, 3, 401)
    ok = (h > 0.35) & ((f & (F_TOWN | F_ROAD | F_DECK)) == 0) & (slope < 0.8)
    rd = S['rd'][iz, ix]
    ralong = S['ralong'][iz, ix]
    xs, zs = jx.ravel(), jz.ravel()
    for k in range(xs.size):
        if not ok.flat[k]:
            continue
        hh, mm, rr, pk = h.flat[k], m.flat[k], r.flat[k], pick.flat[k]
        x, z = xs[k], zs[k]
        kind = None
        # mangroves line the river mouth
        if rd.flat[k] < 30 and ralong.flat[k] < 0.35 and hh < 2.5:
            if rr < 0.35:
                kind = 'mangrove0' if pk < 0.5 else 'mangrove1'
            elif rr < 0.5:
                kind = 'reeds0'
        elif mm == M['sand']:
            tropical = x > 700 or z > 760
            if rr < (0.05 if tropical else 0.012):
                kind = 'palm0' if pk < 0.5 else 'palm1'
            elif rr < 0.06 and hh < 1.0:
                kind = 'reeds1' if pk < 0.5 else 'reeds0'
        elif mm == M['forest']:
            if rr < 0.42:
                if hh > 14:
                    kind = 'pine0' if pk < 0.5 else 'pine1'
                elif x < 360 and z < 340:
                    kind = ['autumn0', 'autumn1', 'oak1', 'birch0'][int(pk * 4)]
                else:
                    kind = ['oak0', 'oak1', 'oak2', 'birch0', 'birch1', 'pine0'][int(pk * 6)]
            elif rr < 0.5:
                kind = 'fern0' if pk < 0.5 else 'fern1'
        elif mm == M['grass']:
            d = dens.flat[k]
            if rr < 0.03 + max(0.0, d - 0.55) * 0.5:
                kind = ['oak0', 'oak1', 'oak2', 'birch0', 'willow0' if rd.flat[k] < 40 else 'oak0'][int(pk * 5)]
            elif rr < 0.07:
                kind = ['bush0', 'bush1', 'bush2', 'bush_pink', 'bush_white', 'bush_yellow'][int(pk * 6)]
            elif rr < 0.14:
                kind = 'flowers%d' % int(pk * 5)
            elif rr < 0.15:
                kind = 'rock%d' % int(pk * 3)
            elif hh > 12 and rr < 0.2:
                kind = 'pine0' if pk < 0.5 else 'pine1'
        elif mm == M['rock']:
            if rr < 0.04:
                kind = 'boulder0' if pk < 0.5 else 'boulder1'
            elif rr < 0.07:
                kind = 'dead0' if x > 1000 and z > 800 else 'rock%d' % int(pk * 3)
        elif mm == M['pebble']:
            if rr < 0.04:
                kind = 'rock%d' % int(pk * 3)
        if kind:
            out.append([round(float(x), 1), round(float(z), 1), P[kind]])
    return out


# ---------------------------------------------------------------------- export

def main():
    preview = '--preview' in sys.argv
    S = build()
    T, hut = towns()
    hgt, mat, zone, tier, flags = finish(S, T, hut)
    trees = scatter(hgt, mat, flags, S)
    os.makedirs(OUT, exist_ok=True)
    hgt.astype('<f4').tofile(os.path.join(OUT, 'height.bin'))
    # planar: all materials, then all zones, then tiers, then flags (W*H bytes each)
    np.concatenate([mat.ravel(), zone.ravel(), tier.ravel(), flags.ravel()]).astype(np.uint8).tofile(os.path.join(OUT, 'data.bin'))
    make_textures()
    gull = T[0]
    meta = dict(
        size=[W, H], sea_level=0.0, materials=MATS, zones=ZONES, plants=PLANTS,
        flags=dict(road=F_ROAD, town=F_TOWN, river=F_RIVER, comb=F_COMB, deck=F_DECK, fog=F_FOG, ember=F_EMBER, highland=F_HIGHLAND),
        spawn=[436.0, 566.0], hut=hut,
        lakes=[dict(name=LAKE['name'], x=LAKE['cx'], z=LAKE['cz'], rx=LAKE['rx'] * 1.15, rz=LAKE['rz'] * 1.15, level=LAKE['level'])],
        waterfall=dict(x=206.0, z=150.0, top=LAKE['level'], bottom=0.0, width=8.0),
        bridge=dict(x=450.0, z=352.0, length=36.0, rot=0, broken=True),
        gates=[dict(id='ranger', x=244.0, z=218.0, r=6.0, needs='permit_ranger', text='The ranger gate is locked. Ranger Hollis in Willowford has the key.')],
        towns=T, islands=ISLANDS + [ATOLL],
        landmarks=[dict(name=t['name'], x=t['x'], z=t['z']) for t in T] +
                  [dict(name='Mirrorlake', x=LAKE['cx'], z=LAKE['cz']), dict(name='Gull Rock', x=572, z=470),
                   dict(name='Turquoise Atoll', x=ATOLL['x'], z=ATOLL['z']), dict(name='The Deep', x=1210, z=520),
                   dict(name='Gull Bay', x=520, z=760), dict(name='Mangrove Estuary', x=470, z=380)],
        trees=trees,
    )
    with open(os.path.join(OUT, 'world.json'), 'w') as f:
        json.dump(meta, f, separators=(',', ':'))
    paint_map(hgt, mat, zone, flags, T, os.path.join(OUT, 'map.png'))
    if preview:
        os.makedirs(PREVIEW, exist_ok=True)
        paint_preview(hgt, mat, zone, tier, flags, T, trees, hut)
    print('world: %d x %d m, %d plants, %d towns, %d buildings' % (W, H, len(trees), len(T), sum(len(t['buildings']) for t in T)))


def hillshade(hgt):
    gz, gx = np.gradient(hgt)
    light = np.clip(0.75 - gx * 0.35 - gz * 0.35, 0.35, 1.25)
    return light


def paint_map(hgt, mat, zone, flags, T, path):
    """The in-game map: soft painted colours, half resolution."""
    col = np.zeros((H, W, 3))
    deep = np.clip(-hgt / 30, 0, 1)[..., None]
    col[:] = np.array([110, 190, 210]) * (1 - deep) + np.array([24, 60, 110]) * deep
    landc = {M['grass']: (122, 176, 96), M['forest']: (74, 132, 76), M['sand']: (238, 220, 168), M['rock']: (150, 146, 160),
             M['dirt']: (196, 160, 112), M['cobble']: (210, 200, 184), M['mud']: (120, 110, 80), M['pebble']: (170, 162, 150)}
    island = hgt >= 0
    for k, c in landc.items():
        col[island & (mat == k)] = c
    col[island] *= hillshade(hgt)[island][:, None]
    col[(zone == Z['lake'])] = (120, 196, 220)
    col[(flags & F_ROAD) > 0] = (196, 160, 112)
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).resize((W // 2, H // 2), Image.LANCZOS)
    img.save(path)


def paint_preview(hgt, mat, zone, tier, flags, T, trees, hut):
    col = np.zeros((H, W, 3))
    deep = np.clip(-hgt / 30, 0, 1)[..., None]
    col[:] = np.array([110, 190, 210]) * (1 - deep) + np.array([20, 50, 100]) * deep
    landc = {M['grass']: (122, 176, 96), M['forest']: (64, 120, 70), M['sand']: (238, 220, 168), M['rock']: (150, 146, 160),
             M['dirt']: (196, 160, 112), M['cobble']: (220, 210, 190), M['mud']: (110, 100, 70), M['pebble']: (170, 162, 150)}
    island = hgt >= 0
    for k, c in landc.items():
        col[island & (mat == k)] = c
    col[island] *= hillshade(hgt)[island][:, None]
    col[zone == Z['lake']] = (120, 196, 220)
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for t in T:
        for b in t['buildings']:
            w, dd = (b['w'], b['d']) if b['rot'] in (0, 2) else (b['d'], b['w'])
            d.rectangle([b['x'] - w / 2, b['z'] - dd / 2, b['x'] + w / 2, b['z'] + dd / 2], fill=(200, 80, 60))
        for dk in t['docks']:
            r = dk['rect']
            d.rectangle(r, fill=(140, 100, 60))
        d.text((t['x'] + 10, t['z'] - 10), t['name'], fill=(0, 0, 0))
    d.ellipse([hut['x'] - 3, hut['z'] - 3, hut['x'] + 3, hut['z'] + 3], fill=(255, 220, 0))
    img.save(PREVIEW + '/world.png')
    img.crop((330, 470, 560, 720)).resize((690, 750), Image.NEAREST).save(PREVIEW + '/gullhaven.png')
    # zones and tiers
    zc = np.zeros((H, W, 3), np.uint8)
    pal = [(60, 60, 60), (79, 159, 208), (127, 208, 216), (106, 154, 122), (240, 120, 120), (60, 150, 90), (120, 100, 90),
           (40, 80, 200), (20, 30, 90), (150, 210, 240), (120, 200, 100), (90, 230, 210)]
    for i, c in enumerate(pal):
        zc[zone == i] = c
    zc[hgt >= 0] = (230, 230, 220)
    Image.fromarray(zc).save(PREVIEW + '/zones.png')
    tc = np.zeros((H, W, 3), np.uint8)
    tpal = [(230, 230, 220), (180, 230, 255), (120, 190, 240), (70, 140, 220), (240, 160, 80), (200, 60, 60)]
    for i, c in enumerate(tpal):
        tc[tier == i] = c
    tc[(flags & F_FOG) > 0] = (200, 200, 200)
    tc[(flags & F_HIGHLAND) > 0] = (200, 180, 120)
    Image.fromarray(tc).save(PREVIEW + '/tiers.png')
    # plants
    pc = (np.clip(col, 0, 255).astype(np.uint8)).copy()
    for x, z, k in trees:
        if 0 <= int(z) < H and 0 <= int(x) < W:
            pc[int(z), int(x)] = (20, 70, 20) if k < 15 else (200, 60, 160)
    Image.fromarray(pc).save(PREVIEW + '/plants.png')


def make_textures():
    """Extra 64 px seamless pixel textures for the terrain: natural rock, forest floor,
    mud and pebbles (grass, sand, dirt and cobbles come from the web game)."""
    n = 64
    yy, xx_ = np.mgrid[0:n, 0:n].astype(float)

    def wn(scale, seed):  # noise that wraps at 64
        p = n / scale
        fx, fz = xx_ / scale, yy / scale
        ix, iz = np.floor(fx), np.floor(fz)
        tx, tz = fx - ix, fz - iz
        sx, sz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
        L = lambda a, b: _lattice(np.mod(a, p), np.mod(b, p), seed)
        a, b, c, d = L(ix, iz), L(ix + 1, iz), L(ix, iz + 1), L(ix + 1, iz + 1)
        return a + (b - a) * sx + (c - a) * sz + (a - b - c + d) * sx * sz

    def paint(name, pal, v, extra=None):
        bay = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
        q = np.clip(v * len(pal) + (bay[yy.astype(int) % 4, xx_.astype(int) % 4] - 0.5) * 0.7, 0, len(pal) - 1).astype(int)
        cols = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in pal], np.uint8)
        img = cols[q]
        if extra is not None:
            extra(img)
        Image.fromarray(img).save(os.path.join(ROOT, 'godot', 'art', 'tex', name + '.png'))

    # rock: big soft lumps with dark cracks
    v = wn(16, 501) * 0.6 + wn(8, 502) * 0.3 + wn(4, 503) * 0.1
    def cracks(img):
        c = np.abs(wn(16, 504) - 0.5) < 0.03
        img[c] = (78, 72, 92)
    paint('rock', ['#5e5a72', '#6e6a84', '#7c7894', '#8a86a0', '#9a96ae'], v, cracks)
    v = wn(8, 511) * 0.6 + wn(4, 512) * 0.4
    def leaves(img):
        h = _lattice(xx_, yy, 513)
        img[h > 0.95] = (122, 96, 52)
        img[(h > 0.9) & (h <= 0.95)] = (92, 130, 70)
    paint('forest', ['#2c5434', '#335e3a', '#3c6a40', '#467646'], v, leaves)
    v = wn(16, 521) * 0.7 + wn(4, 522) * 0.3
    def puddles(img):
        img[wn(8, 523) > 0.78] = (88, 96, 92)
    paint('mud', ['#5a4a32', '#64543a', '#6e5e42', '#78684a'], v, puddles)
    v = wn(4, 531)
    def stones(img):
        h = _lattice(xx_ // 3, yy // 3, 532)
        img[h > 0.7] = (178, 170, 160)
        img[(h > 0.55) & (h <= 0.7)] = (140, 132, 126)
    paint('pebble', ['#9a8c78', '#a6987e', '#b2a486'], v, stones)


if __name__ == '__main__':
    main()
