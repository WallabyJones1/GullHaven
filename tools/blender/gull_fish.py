"""Every fish in the Gullhaven catalogue as a little 3D model, built from its catalogue
"look" (shape|back|belly|light|pattern|pattern colour|fin colour|extra), the same data the
2D sprites are drawn from. Each model is 1 m nose to tail along +X (the game scales it to
the fish's size), with its origin in the middle of the body, and a 32 x 16 pixel-art skin.
"""
import json
import math
import os
import random

from mathutils import Matrix, Vector

import gull_models as G
from gull_models import Builder, flat_poly, hexc, ico, mat, mix, pixel_image, shade, transform_verts, tube, cylinder

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "data"))

# Body profiles: (t from tail 0 to nose 1, half height, half width) as fractions of length.
P_TORP = [(0, .022, .01), (.12, .045, .025), (.45, .12, .065), (.75, .11, .062), (.93, .06, .04), (1, .012, .012)]
P_DEEP = [(0, .025, .01), (.14, .06, .025), (.45, .2, .06), (.72, .19, .058), (.92, .09, .04), (1, .02, .012)]
P_DISC = [(0, .03, .01), (.16, .09, .02), (.45, .3, .045), (.7, .28, .045), (.92, .12, .03), (1, .03, .01)]
P_GROUPER = [(0, .03, .015), (.15, .07, .04), (.45, .16, .1), (.75, .15, .1), (.94, .09, .07), (1, .03, .03)]
P_TUNA = [(0, .015, .01), (.1, .035, .025), (.45, .15, .1), (.72, .14, .1), (.93, .07, .05), (1, .015, .015)]
P_GAR = [(0, .02, .01), (.15, .03, .02), (.5, .045, .03), (.8, .04, .028), (.9, .025, .02), (1, .006, .006)]
P_PUFF = [(0, .03, .02), (.15, .08, .06), (.45, .26, .22), (.75, .25, .21), (.94, .13, .11), (1, .04, .04)]
P_FLAT = [(0, .015, .015), (.15, .025, .04), (.5, .05, .1), (.8, .05, .12), (.95, .035, .09), (1, .01, .03)]
P_EEL = [(0, .015, .01), (.1, .035, .025), (.4, .045, .035), (.8, .045, .035), (.95, .035, .03), (1, .015, .015)]
P_RIBBON = [(0, .01, .006), (.1, .03, .01), (.4, .05, .012), (.85, .055, .014), (.97, .04, .012), (1, .015, .008)]
P_SHARK = [(0, .015, .01), (.15, .035, .03), (.45, .1, .09), (.72, .1, .09), (.92, .06, .06), (1, .015, .02)]
P_FLATSHARK = [(0, .012, .015), (.15, .025, .04), (.45, .055, .13), (.75, .05, .13), (.95, .035, .1), (1, .01, .05)]
P_ANGLER = [(0, .025, .02), (.15, .06, .05), (.45, .2, .19), (.78, .24, .22), (.95, .2, .2), (1, .1, .1)]
P_HUMP = [(0, .03, .015), (.15, .07, .035), (.45, .2, .08), (.72, .2, .08), (.85, .2, .07), (.95, .1, .05), (1, .03, .02)]
P_MAHI = [(0, .02, .01), (.12, .05, .025), (.45, .14, .055), (.8, .16, .06), (.97, .15, .05), (1, .05, .03)]
P_MOLA = [(0, .26, .04), (.1, .33, .06), (.5, .38, .08), (.85, .3, .07), (1, .08, .03)]

# shape -> (profile, tail, dorsal, mods)
ARCH = {
    "torp": (P_TORP, "fork", "mid", {}),
    "deep": (P_DEEP, "fork", "long", {}),
    "disc": (P_DISC, "square", "tall", {}),
    "grouper": (P_GROUPER, "round", "long", {"mouth": 1.4}),
    "tuna": (P_TUNA, "lunate", "mid", {"finlets": True}),
    "gar": (P_GAR, "fork", "back", {"beak": .22, "length": 1.0}),
    "parrot": (P_DEEP, "square", "long", {"beak_lip": True}),
    "jacket": (P_DEEP, "round", "spine", {}),
    "puffer": (P_PUFF, "round", "small", {"spikes": True}),
    "flathead": (P_FLAT, "round", "low", {"top_eyes": True}),
    "angler": (P_ANGLER, "round", "small", {"lure": True, "mouth": 2.0}),
    "trigger": (P_DEEP, "lunate", "tall", {}),
    "clown": (P_GROUPER, "round", "long", {}),
    "lion": (P_GROUPER, "round", "spines", {"fans": True}),
    "hump": (P_HUMP, "round", "long", {}),
    "wobbe": (P_FLATSHARK, "shark", "shark_back", {"tassels": True}),
    "shark": (P_SHARK, "shark", "shark", {"snout": True}),
    "eel": (P_EEL, "eel", "eel", {"length": 1.0}),
    "gulper": (P_EEL, "eel", "eel", {"mouth": 3.0}),
    "oar": (P_RIBBON, "eel", "crest", {}),
    "ribbon": (P_RIBBON, "eel", "eel", {}),
    "marlin": (P_TUNA, "lunate", "marlin", {"beak": .25}),
    "sail": (P_TUNA, "lunate", "sail", {"beak": .25}),
    "mahi": (P_MAHI, "fork", "crest", {}),
    "flying": (P_TORP, "fork", "mid", {"wings": True}),
    "lantern": (P_TORP, "fork", "mid", {"big_eye": True}),
    "dory": (P_DISC, "round", "streamers", {}),
    "boar": (P_DEEP, "square", "tall", {"snout_small": True}),
    "idol": (P_DISC, "lunate", "idol", {"snout_small": True}),
    "bat": (P_DISC, "square", "bat", {}),
    "saw": (P_FLATSHARK, "shark", "shark", {"saw": True}),
    "guitar": (P_FLATSHARK, "shark", "shark_back", {"guitar": True}),
    "chimaera": (P_SHARK, "whip", "shark", {"big_eye": True}),
    "odd": (P_MOLA, "mola", "mola", {}),
}


def catalogue():
    out = []
    for f in ("catalog.json", "catalog_extra.json"):
        p = os.path.join(DATA, f)
        if not os.path.exists(p):
            continue
        items = json.load(open(p))["items"]
        if isinstance(items, dict):
            items = list(items.values())
        for it in items:
            if it.get("cat") in ("fish", "legend") and it.get("look"):
                out.append(it)
    seen = set()
    uniq = []
    for it in out:
        if it["id"] not in seen:
            seen.add(it["id"])
            uniq.append(it)
    return uniq


def parse(look):
    p = look.split("|")
    while len(p) < 8:
        p.append("")
    return {"shape": p[0], "back": hexc(p[1]), "belly": hexc(p[2]), "light": hexc(p[3]), "pattern": p[4],
            "pc": hexc(p[5] if p[5] and p[5] != "#000" else "#222222"), "fin": hexc(p[6] or p[1]), "extra": p[7]}


# --- the skin -------------------------------------------------------------------------------

def skin(fid, L, w=32, h=16):
    rng = random.Random(fid)
    pat = L["pattern"]
    spots = [(rng.randrange(2, w - 4), rng.randrange(2, h - 5)) for _ in range(9)]
    glow = [(rng.randrange(3, w - 4), rng.randrange(3, h - 3)) for _ in range(7)]
    bars = rng.choice([4, 5, 6])
    prism = [hexc(c) for c in ("#ff7a6b", "#ffd24d", "#7fdcc0", "#6fb2ff", "#c39bff")]

    def px(x, y):
        v = 1.0 - y / (h - 1)  # 1 at the back, 0 at the belly
        if v > 0.72:
            c = shade(L["back"], 0.85)
        elif v > 0.52:
            c = L["back"]
        elif v > 0.32:
            c = mix(L["back"], L["belly"], 0.75)
        elif v > 0.16:
            c = L["belly"]
        else:
            c = L["light"]
        if (x * 7 + y * 13) % 11 == 0 and v > 0.4:
            c = shade(c, 0.93)
        pc = L["pc"]
        if pat == "spots" and any(abs(x - sx) + abs(y - sy) <= 0 for sx, sy in spots) and v > 0.25:
            c = pc
        elif pat == "spots" and v > 0.3 and (x * 5 + y * 3 + len(fid)) % 9 == 0:
            c = pc
        elif pat == "bars" and v > 0.25 and (x // 2) % bars == 1 and 4 < x < w - 3:
            c = pc
        elif pat in ("stripes", "lines") and v > 0.3 and y % (3 if pat == "stripes" else 4) == 1:
            c = pc
        elif pat == "lat" and y == h // 2 - 1:
            c = pc
        elif pat == "blotch" and v > 0.3 and math.sin(x * 0.9 + rng.random() * 0.01) * math.cos(y * 1.3) > 0.45:
            c = mix(c, pc, 0.8)
        elif pat == "scales" and v > 0.3 and (x + (y % 2)) % 2 == 0 and y % 2 == 0:
            c = shade(c, 0.82)
        elif pat == "glow" and (x, y) in glow:
            c = pc
        elif pat == "wavy" and v > 0.25 and (y + int(2 * math.sin(x * 0.8))) % 4 == 0:
            c = pc
        elif pat == "band" and v > 0.25 and w * 0.45 < x < w * 0.6:
            c = pc
        elif pat == "harness" and v > 0.3 and (abs(x - w * 0.65) < 1.5 or (abs(x - w * 0.4) < 1.2 and y < h * 0.6)):
            c = pc
        elif pat == "clown" and v > 0.2 and min(abs(x - w * 0.25), abs(x - w * 0.5), abs(x - w * 0.8)) < 1.6:
            c = pc if min(abs(x - w * 0.25), abs(x - w * 0.5), abs(x - w * 0.8)) < 1.0 else hexc("#1a1a1a")
        elif pat == "tang" and v > 0.5 and abs(y - h * 0.3) < 2 and x > w * 0.2:
            c = pc
        elif pat == "dory" and (x - w * 0.55) ** 2 + (y - h * 0.45) ** 2 < 5:
            c = pc if (x - w * 0.55) ** 2 + (y - h * 0.45) ** 2 < 3 else L["light"]
        elif pat == "shoulder" and (x - w * 0.72) ** 2 + (y - h * 0.4) ** 2 < 4:
            c = pc
        elif pat == "belly" and 0.18 < v < 0.36 and x % 3 == 0:
            c = pc
        elif pat == "oblique" and v > 0.5 and (x + y) % 5 == 0:
            c = pc
        elif pat == "prism":
            c = prism[(x // 3 + y // 4) % len(prism)]
        return c
    return pixel_image("fish_" + fid, w, h, px)


# --- the body -------------------------------------------------------------------------------

def _interp(prof, t):
    for i in range(len(prof) - 1):
        a, b = prof[i], prof[i + 1]
        if a[0] <= t <= b[0]:
            k = (t - a[0]) / max(1e-6, b[0] - a[0])
            k = k * k * (3 - 2 * k)
            return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k
    return prof[-1][1], prof[-1][2]


def body(b, prof, m, length=1.0, rings=14, segs=10, hump=0.0, droop=0.0):
    verts, faces, uvs = [], [], []
    for i in range(rings + 1):
        t = i / rings
        hh, ww = _interp(prof, t)
        x = (t - 0.5) * length
        zc = hump * max(0.0, math.sin((t - 0.4) * math.pi * 1.6)) * (1 if t > 0.4 else 0) - droop * (t - 0.5) ** 2
        for k in range(segs):
            a = k / segs * math.tau - math.pi / 2
            verts.append((x, math.cos(a) * ww, zc + math.sin(a) * hh))
            uvs.append((t, (math.sin(a) + 1) / 2))
    for i in range(rings):
        for k in range(segs):
            a0 = i * segs + k
            a1 = i * segs + (k + 1) % segs
            faces.append([a0, a1, a1 + segs, a0 + segs])
    faces.append([k for k in range(segs)][::-1])
    faces.append([rings * segs + k for k in range(segs)])
    b.add(verts, faces, m, uvs=uvs)


def fin(b, outline, m, at=(0, 0, 0), rot=None, axis="y", th=0.012):
    v, f = flat_poly(outline, th, axis)
    M = Matrix.Translation(at)
    if rot is not None:
        M = M @ rot
    b.add(transform_verts(v, M), f, m)


def eye(b, at, r, big=False):
    white = mat("eye_white", hexc("#f4f4ec"))
    black = mat("eye_black", hexc("#101014"))
    for s in (-1, 1):
        p = Vector((at[0], at[1] * s, at[2]))
        b.add_bm(ico(r * (1.4 if big else 1.0), 1, 1, 0.0, (1, 0.6, 1), p), white)
        b.add_bm(ico(r * (0.8 if big else 0.6), 1, 2, 0.0, (1, 0.6, 1), p + Vector((0.004, 0.008 * s, 0))), black)


def tail_fin(b, kind, m, x0, h):
    s = max(h, 0.05)
    if kind == "fork":
        o = [(0, 0), (-.06, s * 1.6), (-.14, s * 2.4), (-.1, s * .4), (-.1, -s * .4), (-.14, -s * 2.4), (-.06, -s * 1.6)]
    elif kind == "lunate":
        o = [(0, 0), (-.05, s * 1.8), (-.15, s * 3.0), (-.08, s * .5), (-.08, -s * .5), (-.15, -s * 3.0), (-.05, -s * 1.8)]
    elif kind == "square":
        o = [(0, s * .3), (-.12, s * 2.0), (-.13, -s * 2.0), (0, -s * .3)]
    elif kind == "round":
        o = [(0, s * .3)] + [(-.12 * math.cos(a), s * 2.0 * math.sin(a)) for a in [math.pi / 2 - i * math.pi / 6 for i in range(7)]] + [(0, -s * .3)]
    elif kind == "shark":
        o = [(0, 0), (-.08, s * 1.5), (-.2, s * 3.2), (-.12, s * .6), (-.1, -s * 1.0), (-.03, -s * .3)]
    elif kind == "eel":
        o = [(0, s * .6), (-.06, 0), (0, -s * .6)]
    elif kind == "whip":
        o = [(0, s * .5), (-.22, 0), (0, -s * .5)]
    elif kind == "mola":
        o = [(0, s * 1.0), (-.08, s * .6), (-.1, 0), (-.08, -s * .6), (0, -s * 1.0)]
    else:
        return
    fin(b, [(x0 + u, v) for (u, v) in o], m)


def fish(it):
    L = parse(it["look"])
    fid = it["id"]
    shape = L["shape"]
    if shape in SPECIAL:
        return SPECIAL[shape](fid, L)
    prof, tail, dors, mods = ARCH.get(shape, ARCH["torp"])
    extra = L["extra"]
    if extra in ("slim", "long", "sleek"):
        prof = [(t, h * 0.75, w * 0.8) for (t, h, w) in prof]
    elif extra in ("big", "blunt"):
        prof = [(t, h * 1.12, w * 1.1) for (t, h, w) in prof]
    b = Builder("fish_" + fid)
    bm = mat("fishskin_" + fid, image=skin(fid, L))
    fm = mat("fishfin_" + fid, shade(L["fin"], 0.95))
    hmax = max(p[1] for p in prof)
    body(b, prof, bm, hump=0.05 if shape == "hump" else 0.0)
    th0, _ = _interp(prof, 0.0)
    tail_fin(b, "eel" if extra == "nofin" else tail, fm, -0.5, max(th0, 0.03))
    top = lambda t: _interp(prof, t)[0]  # noqa: E731
    # dorsal fins
    if dors in ("mid", "long", "tall", "spine", "small", "low", "back", "crest", "marlin", "sail", "idol", "bat", "streamers", "spines"):
        span = {"mid": (.35, .62), "long": (.28, .72), "tall": (.25, .7), "spine": (.3, .65), "small": (.35, .55), "low": (.2, .7),
                "back": (.12, .3), "crest": (.1, .95), "marlin": (.3, .8), "sail": (.2, .8), "idol": (.4, .65), "bat": (.25, .7),
                "streamers": (.3, .7), "spines": (.25, .75)}[dors]
        hgt = {"mid": .07, "long": .06, "tall": .12, "spine": .05, "small": .04, "low": .03, "back": .05, "crest": .05, "marlin": .09,
               "sail": .28, "idol": .4, "bat": .3, "streamers": .14, "spines": .16}[dors]
        a, c = span
        pts = []
        n = 6
        for i in range(n + 1):
            t = a + (c - a) * i / n
            pts.append(((t - 0.5), top(t) * 0.92))
        outline = pts[::-1] + [(pts[0][0] + 0.02, pts[0][1] + hgt * 0.2), (pts[-1][0] - 0.04, pts[-1][1] + hgt)]
        if dors == "spines":
            for i in range(7):
                t = a + (c - a) * i / 6
                x = t - 0.5
                fin(b, [(x - .006, top(t) * .9), (x + .006, top(t) * .9), (x - .01, top(t) + hgt)], fm)
        else:
            outline = [(x, y) for (x, y) in pts] + [(pts[-1][0] - 0.02, pts[-1][1] + hgt * (0.4 if dors != "idol" else 1.0)),
                                                    (pts[len(pts) // 2][0], pts[len(pts) // 2][1] + hgt),
                                                    (pts[0][0] - 0.03, pts[0][1] + hgt * 0.25)]
            fin(b, outline[::-1] if False else outline, fm)
        if dors == "spine":
            t = 0.7
            fin(b, [(t - .5 - .008, top(t) * .9), (t - .5 + .008, top(t) * .9), (t - .5 - .03, top(t) + .1)], fm)
        # anal fin underneath (mirrors the back half)
        if dors not in ("crest", "back"):
            pts2 = [((t - 0.5), -top(t) * 0.92) for t in [a * 0.8 + (c * 0.8 - a * 0.8) * i / 4 for i in range(5)]]
            ah = hgt * (0.6 if dors not in ("bat", "idol", "sail") else 0.9)
            fin(b, pts2 + [(pts2[-1][0] - 0.02, pts2[-1][1] - ah * 0.4), (pts2[1][0], pts2[1][1] - ah)], fm)
    elif dors in ("shark", "shark_back"):
        t = 0.55 if dors == "shark" else 0.3
        x = t - 0.5
        fin(b, [(x + .08, top(t) * .9), (x - .06, top(t) * .9), (x - .06, top(t) + .11)], fm)
        fin(b, [(-.32, top(.18) * .9), (-.38, top(.18) * .9), (-.39, top(.18) + .04)], fm)
    elif dors == "eel":
        pts = [((t - 0.5), top(t) * 0.9) for t in [0.02 + i * 0.07 for i in range(11)]]
        fin(b, pts + [(pts[-1][0], pts[-1][1] + .02), (pts[0][0], pts[0][1] + .03)], fm)
        pts2 = [((t - 0.5), -top(t) * 0.9) for t in [0.02 + i * 0.05 for i in range(9)]]
        fin(b, pts2 + [(pts2[-1][0], pts2[-1][1] - .02), (pts2[0][0], pts2[0][1] - .03)], fm)
    elif dors == "mola":
        fin(b, [(-.38, .3), (-.3, .3), (-.42, .62)], fm)
        fin(b, [(-.38, -.3), (-.3, -.3), (-.42, -.62)], fm)
    if dors == "crest" and shape == "oar":
        red = mat("oar_crest", hexc("#e04a4a"))
        for i in range(5):
            x = 0.42 - i * 0.025
            fin(b, [(x, top(0.9) * .9), (x + .01, top(0.9) * .9), (x - .03, top(0.9) + .12 + i * .01)], red)
    # pectoral fins
    hp, wp = _interp(prof, 0.72)
    pl = 0.09 if not mods.get("wings") else 0.45
    for s in (-1, 1):
        rot = Matrix.Rotation(s * (0.6 if not mods.get("wings") else 1.35), 4, "X") @ Matrix.Rotation(-0.35, 4, "Z")
        o = [(0, 0), (-pl, pl * 0.35), (-pl * 0.8, -pl * 0.15)]
        if mods.get("fans"):
            o = [(0, 0), (-0.2, 0.18), (-0.26, 0.0), (-0.2, -0.16)]
        fin(b, o, fm, at=(0.22, s * wp * 0.9, -hp * 0.25), rot=rot, axis="y")
    # head bits
    hn, wn = _interp(prof, 0.88)
    big = mods.get("big_eye") or extra == "bigeye"
    ez = hn * 0.35
    if mods.get("top_eyes"):
        eye(b, (0.36, wn * 0.45, hn * 0.85), 0.02)
    else:
        eye(b, (0.39 if shape not in ("puffer", "angler") else 0.34, wn * 0.8, ez), 0.022 if shape not in ("puffer", "angler", "grouper") else 0.03, big)
    if mods.get("beak"):
        bl = mods["beak"]
        bk = mat("beak_" + fid, shade(L["back"], 0.8))
        b.add_bm(cylinder(0.012, 0.002, bl, 5), bk, Matrix.Translation((0.49, 0, 0)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    if mods.get("saw"):
        bk = mat("saw_" + fid, shade(L["back"], 0.9))
        fin(b, [(0.48, 0.035), (0.8, 0.02), (0.8, -0.02), (0.48, -0.035)], bk, axis="z", th=0.012)
        tooth = mat("tooth", hexc("#f8f4e8"))
        for i in range(8):
            x = 0.52 + i * 0.035
            for s in (-1, 1):
                fin(b, [(x, s * .025), (x + .012, s * .025), (x + .004, s * .045)], tooth, axis="z", th=0.008)
    if mods.get("guitar"):
        fin(b, [(0.4, 0), (0.15, 0.22), (-0.05, 0.12), (-0.05, -0.12), (0.15, -0.22)], bm, at=(0, 0, -0.01), axis="z", th=0.02)
    if mods.get("wobbe") or mods.get("tassels"):
        for i in range(6):
            a = -0.9 + i * 0.36
            fin(b, [(0.47, 0), (0.5, 0.01), (0.46 + 0.04 * math.cos(a), 0.08 * math.sin(a))], fm, axis="z", th=0.01)
    if mods.get("lure"):
        rod = mat("lure_rod", shade(L["back"], 0.8))
        glow = mat("lure_glow_" + fid, L["pc"], emit=L["pc"], emit_strength=4.0)
        v, f = tube([Vector((0.38, 0, hn * 0.9)), Vector((0.46, 0, hn + 0.12)), Vector((0.56, 0, hn + 0.1))], [0.006, 0.005, 0.004], 4)
        b.add(v, f, rod)
        b.add_bm(ico(0.025, 1, 3, 0.0, (1, 1, 1), (0.57, 0, hn + 0.08)), glow)
    if mods.get("mouth", 0) >= 1.4 or shape in ("gulper", "angler"):
        dark = mat("mouth_dark", hexc("#2a1418"))
        mw = 0.03 * mods.get("mouth", 1.4)
        fin(b, [(0.5, 0.0), (0.42, mw * 0.6), (0.42, -mw * 0.4)], dark, at=(0, 0, -hn * 0.15), axis="y", th=wn * 1.6)
    if shape == "puffer" or mods.get("spikes"):
        sp = mat("spike_" + fid, shade(L["belly"], 0.85))
        rng = random.Random(fid)
        for i in range(18):
            t = rng.uniform(0.25, 0.85)
            a = rng.uniform(0, math.tau)
            hh, ww = _interp(prof, t)
            p = Vector((t - 0.5, math.cos(a) * ww, math.sin(a) * hh))
            dirv = Vector((0, math.cos(a), math.sin(a)))
            M = Matrix.Translation(p) @ dirv.to_track_quat("Z", "X").to_matrix().to_4x4()
            b.add_bm(cylinder(0.008, 0.0, 0.04, 3), sp, M)
    if shape == "lantern" or L["pattern"] == "glow":
        gm = mat("photophore_" + fid, L["pc"], emit=L["pc"], emit_strength=3.0)
        hh, ww = _interp(prof, 0.5)
        for i in range(5):
            t = 0.3 + i * 0.1
            hh, ww = _interp(prof, t)
            for s in (-1, 1):
                b.add_bm(ico(0.008, 0, i, 0.0, (1, 1, 1), (t - 0.5, s * ww * 0.85, -hh * 0.5)), gm)
    if extra == "legend":
        crown = mat("legend_gold", hexc("#ffd24d"), emit=hexc("#ffd24d"), emit_strength=0.8)
        for i in range(3):
            t = 0.55 + i * 0.08
            fin(b, [(t - .5 - .02, top(t)), (t - .5 + .02, top(t)), (t - .5, top(t) + .06)], crown)
    if extra == "crown":
        crown = mat("legend_gold", hexc("#ffd24d"), emit=hexc("#ffd24d"), emit_strength=0.8)
        for i in range(4):
            fin(b, [(0.3 + i * .03, hn), (0.32 + i * .03, hn), (0.31 + i * .03, hn + .07)], crown)
    return b.finish()


# --- crustaceans, cephalopods, rays, seahorses ------------------------------------------------

def _crab(fid, L):
    b = Builder("fish_" + fid)
    shell = mat("fishskin_" + fid, image=skin(fid, L))
    dark = mat("crab_leg_" + fid, shade(L["fin"], 0.85))
    eyem = mat("eye_black", hexc("#101014"))
    wide = 1.4 if fid != "harbour_spider_crab" else 1.0
    G_ico = ico(0.25, 2, 1, 0.03, (0.85, wide, 0.35), (0, 0, 0))
    b.add_bm(G_ico, shell)
    for s in (-1, 1):
        for i in range(4):
            x = 0.08 - i * 0.07
            L_ = 0.42 if fid == "harbour_spider_crab" else 0.3
            v, f = tube([Vector((x, s * 0.28, 0)), Vector((x - 0.02, s * (0.28 + L_ * 0.5), 0.08)), Vector((x - 0.06, s * (0.28 + L_), -0.12))],
                        [0.025, 0.02, 0.012], 4)
            b.add(v, f, dark)
        v, f = tube([Vector((0.15, s * 0.25, 0)), Vector((0.3, s * 0.36, 0.05))], [0.035, 0.03], 5)
        b.add(v, f, shell)
        b.add_bm(ico(0.09, 1, 2, 0.0, (1.5, 0.8, 0.7), (0.4, s * 0.38, 0.06)), shell)
        v, f = tube([Vector((0.18, s * 0.07, 0.05)), Vector((0.21, s * 0.08, 0.13))], [0.01, 0.01], 4)
        b.add(v, f, dark)
        b.add_bm(ico(0.022, 1, 3, 0, (1, 1, 1), (0.21, s * 0.08, 0.14)), eyem)
    return b.finish()


def _lobster(fid, L):
    b = Builder("fish_" + fid)
    shell = mat("fishskin_" + fid, image=skin(fid, L))
    dark = mat("crab_leg_" + fid, shade(L["fin"], 0.85))
    eyem = mat("eye_black", hexc("#101014"))
    prof = [(0, .03, .07), (.1, .05, .08), (.35, .07, .08), (.6, .09, .09), (.85, .08, .08), (1, .03, .03)]
    body(b, prof, shell, rings=12)
    fin(b, [(-0.5, 0), (-0.6, 0.12), (-0.62, 0), (-0.6, -0.12)], shell, axis="z", th=0.02)
    bug = "bug" in fid
    for s in (-1, 1):
        for i in range(4):
            x = 0.25 - i * 0.07
            v, f = tube([Vector((x, s * 0.07, -0.03)), Vector((x, s * 0.16, -0.02)), Vector((x - 0.03, s * 0.2, -0.1))], [0.012, 0.01, 0.007], 4)
            b.add(v, f, dark)
        if not bug:
            v, f = tube([Vector((0.45, s * 0.03, 0.03)), Vector((0.75, s * 0.18, 0.08)), Vector((1.0, s * 0.3, 0.0))], [0.012, 0.008, 0.004], 4)
            b.add(v, f, dark)
            if "crayfish" in fid or "yabby" in fid or "marron" in fid:
                b.add_bm(ico(0.07, 1, 2, 0.0, (1.6, 0.7, 0.5), (0.55, s * 0.13, 0)), shell)
        else:
            fin(b, [(0.5, 0), (0.58, s * 0.12), (0.5, s * 0.16)], shell, axis="z", th=0.015)
        b.add_bm(ico(0.018, 1, 3, 0, (1, 1, 1), (0.47, s * 0.04, 0.06)), eyem)
    return b.finish()


def _octo(fid, L):
    b = Builder("fish_" + fid)
    sk = mat("fishskin_" + fid, image=skin(fid, L))
    b.add_bm(ico(0.2, 2, 1, 0.03, (1.1, 1, 1.15), (-0.08, 0, 0.12)), sk)
    for i in range(8):
        a = i / 8 * math.tau
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0.05, 0, -0.05)) + d * 0.08, Vector((0.1, 0, -0.12)) + d * 0.22, Vector((0.12, 0, -0.1)) + d * 0.38 + Vector((0, 0, 0.05)),
               Vector((0.1, 0, -0.05)) + d * 0.5]
        v, f = tube(pts, [0.05, 0.035, 0.02, 0.006], 5)
        b.add(v, f, sk)
    eye(b, (0.08, 0.13, 0.14), 0.03)
    return b.finish()


def _squid(fid, L, cuttle=False):
    b = Builder("fish_" + fid)
    sk = mat("fishskin_" + fid, image=skin(fid, L))
    fm = mat("fishfin_" + fid, shade(L["fin"], 0.95))
    prof = [(0, .01, .01), (.15, .06, .06), (.5, .09, .09), (.8, .08, .08), (1, .07, .07)] if not cuttle else \
        [(0, .03, .05), (.2, .08, .13), (.5, .1, .16), (.85, .09, .14), (1, .06, .09)]
    body(b, prof, sk, length=0.7, rings=10)
    for s in (-1, 1):
        if cuttle:
            fin(b, [(-0.33, 0), (0.3, 0), (0.25, s * 0.06), (-0.3, s * 0.06)], fm, at=(0, s * 0.14, -0.02), axis="z", th=0.01)
        else:
            fin(b, [(-0.35, 0), (-0.1, 0), (-0.25, s * 0.14)], fm, axis="z", th=0.01)
    for i in range(8 if cuttle else 10):
        a = i / (8 if cuttle else 10) * math.tau
        d = Vector((0, math.cos(a), math.sin(a)))
        long_ = (not cuttle) and i in (2, 7)
        Ln = 0.55 if long_ else 0.22
        v, f = tube([Vector((0.35, 0, 0)) + d * 0.04, Vector((0.35 + Ln * 0.6, 0, 0)) + d * 0.05, Vector((0.35 + Ln, 0, 0)) + d * 0.03],
                    [0.018, 0.012, 0.005], 4)
        b.add(v, f, sk)
    eye(b, (0.3, 0.08 if not cuttle else 0.12, 0.04), 0.03)
    return b.finish()


def _ray(fid, L):
    b = Builder("fish_" + fid)
    sk = mat("fishskin_" + fid, image=skin(fid, L))
    eagle = L["extra"] == "eagle"
    out = []
    n = 16
    for i in range(n):
        a = i / n * math.tau
        r = 0.32 + (0.22 if eagle else 0.12) * abs(math.sin(a)) ** 2
        out.append((math.cos(a) * r * (0.8 if eagle else 1.0) + 0.05, math.sin(a) * r * (1.4 if eagle else 1.15)))
    verts = [(0.05, 0, 0.045)] + [(x, y, 0.0) for (x, y) in out] + [(0.05, 0, -0.02)]
    faces = []
    for i in range(n):
        faces.append([0, 1 + i, 1 + (i + 1) % n])
        faces.append([n + 1, 1 + (i + 1) % n, 1 + i])
    b.add(verts, faces, sk, uv_fn=lambda co, nrm: (0.5 - co.y * 0.9, 0.5 + co.x * 0.9) if nrm.z > 0 else (0.5, 0.1))
    v, f = tube([Vector((-0.25, 0, 0)), Vector((-0.6, 0, 0.02)), Vector((-0.95, 0, 0.0))], [0.03, 0.015, 0.004], 4)
    b.add(v, f, mat("fishfin_" + fid, shade(L["fin"], 0.9)))
    eye(b, (0.22, 0.06, 0.04), 0.018)
    if L["extra"] == "legend":
        b.add_bm(ico(0.03, 1, 1, 0, (1, 1, 1), (0.0, 0, 0.06)), mat("legend_gold", hexc("#ffd24d"), emit=hexc("#ffd24d"), emit_strength=0.8))
    return b.finish()


def _seahorse(fid, L, dragon=False):
    b = Builder("fish_" + fid)
    sk = mat("fishskin_" + fid, image=skin(fid, L))
    fm = mat("fishfin_" + fid, shade(L["fin"], 0.95))
    pipe = "pipe" in fid
    if pipe:
        pts = [Vector((-0.5 + i * 0.1, 0, 0.02 * math.sin(i))) for i in range(11)]
        rad = [0.012 + 0.02 * math.sin(math.pi * i / 10) for i in range(11)]
    else:
        pts = [Vector((0.0, 0, -0.42)), Vector((-0.08, 0, -0.48)), Vector((-0.04, 0, -0.38)), Vector((-0.02, 0, -0.2)), Vector((0.04, 0, 0.0)),
               Vector((0.04, 0, 0.2)), Vector((0.0, 0, 0.35))]
        rad = [0.01, 0.018, 0.03, 0.06, 0.08, 0.07, 0.05]
    v, f = tube(pts, rad, 6)
    b.add(v, f, sk, uv_fn=lambda co, n: (0.5 + co.z, 0.5 + co.x * 3))
    head = pts[-1]
    snout = head + (Vector((0.15, 0, 0.0)) if not pipe else Vector((0.12, 0, 0)))
    v, f = tube([head, snout], [0.03, 0.012], 5)
    b.add(v, f, sk)
    eye(b, (head.x + 0.02, 0.035, head.z + 0.02), 0.014)
    fin(b, [(-0.05, -0.05), (-0.12, 0.02), (-0.04, 0.1)], fm, at=(0, 0, 0.05 if not pipe else 0.0))
    if dragon:
        leaf = mat("seadragon_leaf_" + fid, shade(L["fin"], 1.0))
        rng = random.Random(fid)
        for i, p in enumerate(pts):
            for s in (-1, 1):
                a = rng.uniform(0.3, 1.2)
                fin(b, [(0, 0), (0.06, 0.02), (0.02, 0.1)], leaf, at=tuple(p), rot=Matrix.Rotation(s * a, 4, "X"), axis="y")
    return b.finish()


SPECIAL = {"crab": _crab, "lobster": _lobster, "octo": _octo, "squid": lambda f, L: _squid(f, L, False),
           "cuttle": lambda f, L: _squid(f, L, True), "ray": _ray, "seahorse": lambda f, L: _seahorse(f, L, False),
           "dragon": lambda f, L: _seahorse(f, L, True)}

FISH = {it["id"]: (lambda it=it: fish(it)) for it in catalogue()}
