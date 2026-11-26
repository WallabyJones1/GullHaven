"""Gullhaven's town life: market stalls, a fountain, lobster pots, drying racks, rowboats,
buoys, carts and signposts (group "town"), and the animals about town (group "animals"):
a dog, a chicken, a duck, a seal, a pelican and a goat.

Same conventions as gull_models.py: metres, Z up, origin on the ground, fronts face -Y
(the camera), animals face +X.
"""
import math
import random

from mathutils import Matrix, Vector

from gull_models import (Builder, bark, box, cylinder, flat_poly, hexc, ico, mat, pixel_image, shade, speckle,
                         transform_verts, tube, _wood)


# --- market stalls -------------------------------------------------------------------------------

def _stall(name, awning_a, awning_b, goods):
    b = Builder(name)
    w = _wood("stall_wood", "#9a6a3a")
    stripes = pixel_image("awning_%s_%s" % (awning_a.strip("#"), awning_b.strip("#")), 16, 4,
                          lambda x, y: hexc(awning_a) if (x // 2) % 2 == 0 else hexc(awning_b))
    aw = mat("awning_%s_%s" % (awning_a.strip("#"), awning_b.strip("#")), image=stripes)
    # counter and back shelf
    b.add_bm(box(2.6, 1.0, 0.95, (0, -0.1, 0)), w)
    b.add_bm(box(2.6, 0.3, 1.4, (0, 0.55, 0)), w)
    for x in (-1.25, 1.25):
        for y in (-0.55, 0.6):
            b.add_bm(cylinder(0.05, 0.05, 2.35, 5, (x, y, 0)), w)
    # striped awning sloping toward the front, with a scalloped edge
    v = [(-1.45, 0.75, 2.45), (1.45, 0.75, 2.45), (1.45, -0.95, 2.05), (-1.45, -0.95, 2.05)]
    b.add(v, [[0, 1, 2, 3]], aw, uv_fn=lambda co, n: ((co.x + 1.45) / 2.9 * 4, (co.y + 0.95) / 1.7))
    for i in range(7):
        x = -1.45 + i * (2.9 / 7)
        b.add([(x, -0.95, 2.05), (x + 2.9 / 7, -0.95, 2.05), (x + 1.45 / 7, -0.97, 1.88)], [[0, 1, 2]],
              mat("awning_edge_%s" % ((awning_a if i % 2 == 0 else awning_b).strip("#")), hexc(awning_a if i % 2 == 0 else awning_b)))
    rng = random.Random(name)
    goods(b, rng)
    return b.finish()


def _fish_goods(b, rng):
    ice = mat("ice", hexc("#dff0f8"), rough=0.3)
    b.add_bm(box(2.3, 0.75, 0.06, (0, -0.15, 0.95)), ice)
    cols = ["#7a9ab0", "#c8a050", "#d06a5a", "#8aa8a0", "#b8c0c8"]
    for i in range(14):
        c = hexc(rng.choice(cols))
        x = -1.0 + (i % 7) * 0.33
        y = -0.35 + (i // 7) * 0.32
        b.add_bm(ico(0.07, 1, i, 0.0, (2.4, 0.8, 0.55), (x, y, 1.04)), mat("fishgood_%s" % rng.choice("abcde"), c))
    b.add_bm(ico(0.08, 1, 3, 0.0, (1.3, 1.0, 0.6), (0.9, 0.3, 1.04)), mat("crab_red", hexc("#d0502a")))


def _veg_goods(b, rng):
    crate = _wood("crate_wood", "#b07a44")
    kinds = [("#e8822a", 0.07), ("#5aa83a", 0.09), ("#d83a3a", 0.065), ("#f0d040", 0.07), ("#8a4ab8", 0.07), ("#e8e0c8", 0.08)]
    for i, (c, r) in enumerate(kinds):
        x = -0.95 + (i % 3) * 0.95
        y = -0.35 + (i // 3) * 0.5
        b.add_bm(box(0.8, 0.42, 0.18, (x, y, 0.95)), crate)
        m = mat("veg_%s" % c.strip("#"), hexc(c))
        for k in range(6):
            b.add_bm(ico(r, 1, k, 0.1, (1, 1, 0.9), (x - 0.25 + (k % 3) * 0.25, y - 0.08 + (k // 3) * 0.16, 1.17)), m)


def _flower_goods(b, rng):
    pot = mat("pot_terracotta", hexc("#c8683a"))
    for i in range(8):
        x = -1.05 + (i % 4) * 0.7
        y = -0.35 + (i // 4) * 0.5
        b.add_bm(cylinder(0.12, 0.15, 0.2, 7, (x, y, 0.95)), pot, None)
        c = rng.choice(["#e84a5a", "#f4d040", "#8a6ae8", "#f8f8f0", "#f49a30", "#f08ab8"])
        b.add_bm(ico(0.16, 1, i, 0.2, (1, 1, 0.8), (x, y, 1.27)), mat("leafy", hexc("#4a9a3a")))
        for k in range(4):
            a = k / 4 * math.tau
            b.add_bm(ico(0.06, 0, k, 0.0, (1, 1, 1), (x + math.cos(a) * 0.1, y + math.sin(a) * 0.1, 1.38)), mat("bloom_%s" % c.strip("#"), hexc(c)))


def _bread_goods(b, rng):
    crust = mat("crust", hexc("#c88a40"))
    dark = mat("crust_dark", hexc("#9a5a28"))
    basket = mat("basket", image=speckle("basket", [hexc("#b08a50"), hexc("#987040"), hexc("#c8a060")], 8, 4))
    for i in range(3):
        x = -0.85 + i * 0.85
        b.add_bm(cylinder(0.32, 0.38, 0.16, 8, (x, -0.2, 0.95)), basket)
        for k in range(4):
            b.add_bm(ico(0.1, 1, k, 0.05, (1.8, 0.9, 0.7), (x - 0.12 + (k % 2) * 0.24, -0.28 + (k // 2) * 0.16, 1.15)),
                     crust if (i + k) % 3 else dark)
    for k in range(5):
        b.add_bm(ico(0.09, 1, k, 0.0, (1, 1, 0.6), (-1.0 + k * 0.5, 0.45, 1.45)), crust)


def _trinket_goods(b, rng):
    for i in range(10):
        x = -1.05 + (i % 5) * 0.52
        y = -0.3 + (i // 5) * 0.4
        c = rng.choice(["#f4f0e0", "#e8c8d8", "#a8d8e8", "#f4d890", "#c8e8c0"])
        b.add_bm(ico(0.07, 1, i, 0.25, (1.3, 1, 0.6), (x, y, 1.0)), mat("shell_%s" % c.strip("#"), hexc(c), rough=0.4))
    glass = mat("bottle_glass", hexc("#6ab8a0"), rough=0.15)
    for k in range(4):
        b.add_bm(cylinder(0.06, 0.04, 0.3, 6, (-0.9 + k * 0.6, 0.5, 1.4)), glass)


def stall_fish():
    return _stall("stall_fish", "#3a6ab0", "#f4f0e8", _fish_goods)


def stall_veg():
    return _stall("stall_veg", "#4a9a3a", "#f4f0e8", _veg_goods)


def stall_flowers():
    return _stall("stall_flowers", "#e06aa0", "#f8f0f4", _flower_goods)


def stall_bread():
    return _stall("stall_bread", "#d8783a", "#f8ecd8", _bread_goods)


def stall_trinkets():
    return _stall("stall_trinkets", "#8a5ac8", "#f4f0e8", _trinket_goods)


# --- the square and the quay ----------------------------------------------------------------------

def fountain():
    b = Builder("fountain")
    stone = mat("fountain_stone", image=speckle("fountain_stone", [hexc("#c8c4cc"), hexc("#b4b0bc"), hexc("#d8d4dc"), hexc("#a09cac")], 16, 6, [4, 3, 2, 1]))
    water = mat("fountain_water", hexc("#5a9ad8"), rough=0.2, emit=hexc("#3a7ac0"), emit_strength=0.15)
    b.add_bm(cylinder(2.2, 2.3, 0.55, 16), stone)
    b.add_bm(cylinder(1.95, 1.95, 0.04, 16, (0, 0, 0.45)), water)
    b.add_bm(cylinder(0.35, 0.45, 1.2, 10, (0, 0, 0.45)), stone)
    b.add_bm(cylinder(0.9, 0.6, 0.25, 12, (0, 0, 1.55)), stone)
    b.add_bm(cylinder(0.75, 0.75, 0.03, 12, (0, 0, 1.72)), water)
    b.add_bm(cylinder(0.18, 0.22, 0.5, 8, (0, 0, 1.75)), stone)
    # a stone gull on top, wings up
    gull = mat("statue", hexc("#e0dcd4"))
    b.add_bm(ico(0.2, 1, 1, 0.0, (1.6, 0.8, 0.8), (0, 0, 2.45)), gull)
    b.add_bm(ico(0.12, 1, 2, 0.0, (1, 1, 1), (0.28, 0, 2.58)), gull)
    b.add_bm(cylinder(0.05, 0.0, 0.14, 4, (0, 0, 0)), mat("statue_beak", hexc("#d8b860")), Matrix.Translation((0.38, 0, 2.56)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    for s in (-1, 1):
        v, f = flat_poly([(0.1, 0), (0.0, 0.55 * s), (-0.2, 0.7 * s), (-0.15, 0)], 0.04, "z")
        b.add(transform_verts(v, Matrix.Translation((0, 0.05 * s, 2.5)) @ Matrix.Rotation(-0.6 * s, 4, "X")), f, gull)
    # spouts of water
    for k in range(4):
        a = k / 4 * math.tau
        v, f = tube([Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 1.62)), Vector((math.cos(a) * 1.1, math.sin(a) * 1.1, 1.35)),
                     Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 0.5))], [0.04, 0.05, 0.06], 4)
        b.add(v, f, water)
    return b.finish()


def lobster_pots():
    b = Builder("lobster_pots")
    frame = mat("pot_frame", hexc("#5a4030"))
    netm = mat("pot_net", hexc("#3a6a5a"))
    for (x, y, z) in ((0, 0, 0), (0.62, 0.05, 0), (0.3, 0.02, 0.48)):
        b.add_bm(box(0.58, 0.42, 0.04, (x, y, z)), frame)
        for k in range(4):
            a = k / 3 * math.pi
            v, f = tube([Vector((x - 0.27, y + math.cos(a) * 0.2, z + 0.02 + math.sin(a) * 0.2)),
                         Vector((x + 0.27, y + math.cos(a) * 0.2, z + 0.02 + math.sin(a) * 0.2))], [0.015, 0.015], 4)
            b.add(v, f, frame)
        for k in range(5):
            xx = x - 0.27 + k * 0.135
            pts = [Vector((xx, y + math.cos(a) * 0.2, z + 0.02 + math.sin(a) * 0.2)) for a in [i / 6 * math.pi for i in range(7)]]
            v, f = tube(pts, [0.008] * 7, 3)
            b.add(v, f, netm)
    b.add_bm(ico(0.12, 1, 1, 0.0, (1, 1, 1), (-0.45, -0.3, 0.12)), mat("buoy_orange", hexc("#f07a2a")))
    return b.finish()


def drying_rack():
    b = Builder("drying_rack")
    w = _wood("post")
    fishm = [mat("dried_fish_a", hexc("#b89060")), mat("dried_fish_b", hexc("#a87a50"))]
    for x in (-0.9, 0.9):
        v, f = tube([Vector((x, -0.4, 0)), Vector((x, 0, 1.7))], [0.04, 0.035], 4)
        b.add(v, f, w)
        v, f = tube([Vector((x, 0.4, 0)), Vector((x, 0, 1.7))], [0.04, 0.035], 4)
        b.add(v, f, w)
    v, f = tube([Vector((-1.0, 0, 1.68)), Vector((1.0, 0, 1.68))], [0.035, 0.035], 5)
    b.add(v, f, w)
    for i in range(7):
        x = -0.75 + i * 0.25
        b.add_bm(ico(0.07, 1, i, 0.05, (0.6, 0.35, 2.4), (x, 0, 1.38)), fishm[i % 2])
        v, f = tube([Vector((x, 0, 1.66)), Vector((x, 0, 1.55))], [0.006, 0.006], 3)
        b.add(v, f, mat("twine", hexc("#8a6a3a")))
    return b.finish()


def rope_coil():
    b = Builder("rope_coil")
    rope = mat("rope", image=speckle("rope", [hexc("#c8a868"), hexc("#a8884a"), hexc("#d8bc80")], 8, 5))
    for layer in range(4):
        r = 0.3 - layer * 0.05
        pts = [Vector((math.cos(a) * r, math.sin(a) * r, 0.04 + layer * 0.06)) for a in [k / 12 * math.tau for k in range(13)]]
        v, f = tube(pts, [0.04] * 13, 5)
        b.add(v, f, rope)
    return b.finish()


def rowboat():
    """A rowboat pulled up on the beach, oars inside."""
    b = Builder("rowboat")
    hull = mat("rowboat_hull", image=pixel_image("rowboat_hull", 8, 8, lambda x, y: hexc("#f4f0e8") if y < 2 else hexc("#3a8aa8") if y < 7 else hexc("#2a3a4a")))
    inner = _wood("rowboat_inner", "#a8784a")
    L, W, H = 3.2, 1.2, 0.55
    secs = 9
    verts, faces = [], []
    for i in range(secs):
        t = i / (secs - 1)
        x = (t - 0.5) * L
        k = math.sin(math.pi * t) ** 0.6
        w = W * 0.5 * (0.15 + 0.85 * k)
        verts += [(x, -w, H), (x, -w * 0.6, 0.08), (x, 0, 0.0), (x, w * 0.6, 0.08), (x, w, H)]
    for i in range(secs - 1):
        o = i * 5
        for j in range(4):
            faces.append([o + j, o + j + 5, o + j + 6, o + j + 1])
    b.add(verts, faces, hull, uv_fn=lambda co, n: (co.x, 1.0 - co.z / H))
    b.add_bm(box(0.9, W * 0.9, 0.05, (0.0, 0, 0.32)), inner)
    b.add_bm(box(0.25, W * 0.85, 0.05, (0.9, 0, 0.35)), inner)
    for s in (-1, 1):
        v, f = tube([Vector((-1.1, s * 0.2, 0.3)), Vector((1.2, s * 0.35, 0.42))], [0.03, 0.03], 4)
        b.add(v, f, inner)
    return b.finish()


def buoy():
    b = Builder("buoy")
    red = mat("buoy_red", hexc("#d83a3a"))
    white = mat("buoy_white", hexc("#f4f4f0"))
    b.add_bm(cylinder(0.45, 0.5, 0.5, 10, (0, 0, -0.3)), red)
    b.add_bm(cylinder(0.3, 0.12, 0.6, 8, (0, 0, 0.2)), white)
    b.add_bm(cylinder(0.12, 0.12, 0.3, 6, (0, 0, 0.8)), red)
    b.add_bm(box(0.18, 0.18, 0.12, (0, 0, 1.1)), mat("buoy_light", hexc("#ffe080"), emit=hexc("#ffd040"), emit_strength=3.0))
    return b.finish()


def cart():
    b = Builder("cart")
    w = _wood("cart_wood", "#9a6a3a")
    iron = mat("iron", hexc("#2a2c32"), rough=0.5)
    b.add_bm(box(1.6, 1.0, 0.1, (0, 0, 0.55)), w)
    for (sx, sy, sz, x, y) in ((1.6, 0.06, 0.4, 0, -0.5), (1.6, 0.06, 0.4, 0, 0.5), (0.06, 1.0, 0.4, 0.8, 0), (0.06, 1.0, 0.4, -0.8, 0)):
        b.add_bm(box(sx, sy, sz, (x, y, 0.6)), w)
    for s in (-1, 1):
        wheel = cylinder(0.42, 0.42, 0.08, 12)
        import bmesh
        bmesh.ops.rotate(wheel, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=wheel.verts)
        bmesh.ops.translate(wheel, vec=(0.1, s * 0.58, 0.42), verts=wheel.verts)
        b.add_bm(wheel, iron)
    for s in (-1, 1):
        v, f = tube([Vector((0.8, s * 0.35, 0.6)), Vector((1.7, s * 0.3, 0.55))], [0.035, 0.03], 4)
        b.add(v, f, w)
    crate = _wood("crate_wood", "#b07a44")
    b.add_bm(box(0.5, 0.5, 0.45, (-0.4, -0.15, 0.6)), crate)
    b.add_bm(box(0.45, 0.45, 0.4, (0.25, 0.2, 0.6)), crate)
    b.add_bm(ico(0.12, 1, 1, 0.1, (1, 1, 1), (0.3, -0.25, 0.75)), mat("veg_e8822a", hexc("#e8822a")))
    return b.finish()


def signpost():
    b = Builder("signpost")
    w = _wood("post")
    board = mat("sign_board_plain", image=pixel_image("sign_plain", 16, 4, lambda x, y: hexc("#e8d8b0") if 0 < y < 3 and 0 < x < 15 else hexc("#8a6a3a")))
    b.add_bm(box(0.1, 0.1, 2.0), w)
    for i, (z, a) in enumerate(((1.75, 0.3), (1.45, -0.6), (1.15, 2.4))):
        v, f = flat_poly([(0.0, -0.1), (0.75, -0.1), (0.9, 0.0), (0.75, 0.1), (0.0, 0.1)], 0.04, "y")
        v = [(x, y, zz + z) for (x, y, zz) in v]
        b.add(transform_verts(v, Matrix.Rotation(a, 4, "Z")), f, board, uv_fn=lambda co, n: (co.length * 1.1, 0.5))
    return b.finish()


def bunting_flag():
    """One small triangular flag (the game strings lots of them between posts)."""
    b = Builder("bunting_flag")
    for c in ("#d83a3a",):
        v, f = flat_poly([(-0.12, 0.0), (0.12, 0.0), (0.0, -0.26)], 0.01, "y")
        b.add(v, f, mat("flag_red", hexc(c)))
    return b.finish()


def bell_tower():
    """The chapel's bell tower: a white tower, an open belfry with a bell, and a spire."""
    b = Builder("bell_tower")
    wall = mat("tower_wall", image=speckle("tower_wall", [hexc("#f0ece4"), hexc("#e4e0d8"), hexc("#f8f4ec")], 16, 8, [5, 2, 1]))
    roof = mat("spire", hexc("#3a5a8a"))
    bell = mat("bell", hexc("#d8b040"), rough=0.3)
    b.add_bm(box(2.2, 2.2, 6.0), wall)
    for x in (-1.0, 1.0):
        for y in (-1.0, 1.0):
            b.add_bm(box(0.3, 0.3, 1.6, (x, y, 6.0)), wall)
    b.add_bm(box(2.4, 2.4, 0.2, (0, 0, 7.6)), wall)
    b.add_bm(cylinder(1.7, 0.0, 3.0, 4, (0, 0, 7.8)), roof, Matrix.Rotation(math.pi / 4, 4, "Z"))
    b.add_bm(cylinder(0.45, 0.2, 0.7, 10, (0, 0, 6.5)), bell)
    b.add_bm(ico(0.08, 1, 1, 0, (1, 1, 1), (0, 0, 6.45)), bell)
    clock = mat("clock_face", image=pixel_image("clock_face", 8, 8, lambda x, y: hexc("#2a2a2a") if (x == 3 and 2 <= y <= 4) or (y == 4 and 3 <= x <= 5)
                                                  else hexc("#f8f4e8") if (x - 3.5) ** 2 + (y - 3.5) ** 2 < 12 else hexc("#3a5a8a")))
    v, f = flat_poly([(-0.5, 4.3), (0.5, 4.3), (0.5, 5.3), (-0.5, 5.3)], 0.02, "y")
    b.add([(x, y - 1.12, z) for (x, y, z) in v], f, clock, uv_fn=lambda co, n: (co.x + 0.5, co.z - 4.3))
    return b.finish()


def chimney_pot():
    b = Builder("chimney_pot")
    brick = mat("brick", image=pixel_image("brick", 8, 8, lambda x, y: hexc("#8a3a2a") if (y % 4 == 3 or (x + (4 if (y // 4) % 2 else 0)) % 8 == 7) else hexc("#b85a3a")))
    b.add_bm(box(0.6, 0.6, 1.0), brick)
    b.add_bm(cylinder(0.12, 0.1, 0.3, 6, (0, 0, 1.0)), mat("pot_terracotta", hexc("#c8683a")))
    return b.finish()


TOWN = {"stall_fish": stall_fish, "stall_veg": stall_veg, "stall_flowers": stall_flowers, "stall_bread": stall_bread,
        "stall_trinkets": stall_trinkets, "fountain": fountain, "lobster_pots": lobster_pots, "drying_rack": drying_rack,
        "rope_coil": rope_coil, "rowboat": rowboat, "buoy": buoy, "cart": cart, "signpost": signpost, "bunting_flag": bunting_flag,
        "bell_tower": bell_tower, "chimney_pot": chimney_pot}


# --- animals --------------------------------------------------------------------------------------

def _legs(b, m, xs, ys, h, r=0.03):
    for x in xs:
        for y in ys:
            v, f = tube([Vector((x, y, 0.0)), Vector((x, y, h))], [r, r * 1.2], 4)
            b.add(v, f, m)


def dog():
    b = Builder("dog")
    fur = mat("dog_fur", hexc("#b8783a"))
    light = mat("dog_light", hexc("#f0dcb8"))
    dark = mat("dog_dark", hexc("#2a1a10"))
    _legs(b, fur, (-0.22, 0.22), (-0.1, 0.1), 0.3, 0.04)
    b.add_bm(ico(0.16, 2, 1, 0.0, (2.1, 1.0, 1.0), (0, 0, 0.42)), fur)
    b.add_bm(ico(0.1, 1, 2, 0.0, (1.8, 0.9, 0.7), (0.05, 0, 0.33)), light)
    b.add_bm(ico(0.13, 2, 3, 0.0, (1.1, 1.0, 1.0), (0.36, 0, 0.58)), fur)
    b.add_bm(ico(0.07, 1, 4, 0.0, (1.4, 0.9, 0.8), (0.5, 0, 0.53)), light)
    b.add_bm(ico(0.03, 1, 5, 0.0, (1, 1, 1), (0.6, 0, 0.56)), dark)
    for s in (-1, 1):
        b.add_bm(ico(0.06, 1, 6, 0.0, (0.6, 0.5, 1.4), (0.3, s * 0.1, 0.66)), dark)
        b.add_bm(ico(0.018, 0, 7, 0.0, (1, 1, 1), (0.45, s * 0.06, 0.62)), dark)
    v, f = tube([Vector((-0.32, 0, 0.48)), Vector((-0.45, 0, 0.62)), Vector((-0.5, 0, 0.72))], [0.035, 0.03, 0.02], 4)
    b.add(v, f, fur)
    b.add_bm(cylinder(0.075, 0.075, 0.04, 8, (0.3, 0, 0.5)), mat("collar", hexc("#d83a3a")))
    return b.finish()


def chicken():
    b = Builder("chicken")
    white = mat("hen_white", hexc("#f4f0e4"))
    red = mat("hen_comb", hexc("#d83a2a"))
    yellow = mat("hen_beak", hexc("#f0b030"))
    _legs(b, yellow, (0.0,), (-0.04, 0.04), 0.12, 0.012)
    b.add_bm(ico(0.13, 1, 1, 0.0, (1.3, 0.9, 1.0), (0, 0, 0.24)), white)
    b.add_bm(ico(0.07, 1, 2, 0.0, (1, 1, 1), (0.12, 0, 0.38)), white)
    b.add_bm(cylinder(0.025, 0.0, 0.06, 4, (0, 0, 0)), yellow, Matrix.Translation((0.2, 0, 0.37)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    b.add_bm(ico(0.03, 0, 3, 0.0, (1.2, 0.5, 1.2), (0.12, 0, 0.46)), red)
    b.add_bm(ico(0.07, 1, 4, 0.0, (0.6, 0.5, 1.2), (-0.16, 0, 0.32)), white)
    return b.finish()


def duck():
    b = Builder("duck")
    body = mat("duck_body", hexc("#8a6a4a"))
    head = mat("duck_head", hexc("#2a7a4a"))
    beak = mat("duck_beak", hexc("#f0b030"))
    b.add_bm(ico(0.13, 1, 1, 0.0, (1.5, 0.95, 0.75), (0, 0, 0.1)), body)
    b.add_bm(ico(0.07, 1, 2, 0.0, (1, 1, 1), (0.16, 0, 0.24)), head)
    b.add_bm(ico(0.035, 1, 3, 0.0, (1.6, 1.1, 0.5), (0.24, 0, 0.22)), beak)
    b.add_bm(ico(0.04, 0, 4, 0.0, (1.4, 0.8, 0.8), (-0.18, 0, 0.16)), body)
    return b.finish()


def seal():
    b = Builder("seal")
    skin = mat("seal_skin", image=speckle("seal_skin", [hexc("#7a7e88"), hexc("#6a6e78"), hexc("#8a8e98"), hexc("#5a5e68")], 8, 3, [5, 3, 2, 1]))
    dark = mat("seal_dark", hexc("#1a1a20"))
    pts = [Vector((-0.65, 0, 0.08)), Vector((-0.3, 0, 0.18)), Vector((0.1, 0, 0.24)), Vector((0.4, 0, 0.32)), Vector((0.6, 0, 0.42))]
    v, f = tube(pts, [0.06, 0.2, 0.24, 0.17, 0.11], 8)
    b.add(v, f, skin)
    b.add_bm(ico(0.11, 1, 1, 0.0, (1.2, 1.0, 0.95), (0.66, 0, 0.45)), skin)
    for s in (-1, 1):
        b.add_bm(ico(0.025, 0, 2, 0.0, (1, 1, 1), (0.74, s * 0.06, 0.5)), dark)
        v, f = flat_poly([(0.2, 0), (0.0, 0.18 * s), (-0.1, 0.12 * s)], 0.03, "z")
        b.add(transform_verts(v, Matrix.Translation((0.25, s * 0.18, 0.08))), f, skin)
    v, f = flat_poly([(-0.6, 0), (-0.8, 0.15), (-0.82, -0.15)], 0.03, "z")
    b.add(transform_verts(v, Matrix.Translation((0, 0, 0.06))), f, skin)
    b.add_bm(ico(0.02, 0, 3, 0.0, (1, 1, 1), (0.78, 0, 0.44)), dark)
    return b.finish()


def pelican():
    b = Builder("pelican")
    white = mat("pelican_white", hexc("#f4f4f0"))
    grey = mat("pelican_grey", hexc("#9aa0a8"))
    beak = mat("pelican_beak", hexc("#f0a840"))
    _legs(b, beak, (0.0,), (-0.05, 0.05), 0.22, 0.015)
    b.add_bm(ico(0.18, 1, 1, 0.0, (1.4, 0.9, 1.0), (0, 0, 0.42)), white)
    b.add_bm(ico(0.12, 1, 2, 0.0, (1.5, 0.7, 0.9), (-0.08, 0, 0.47)), grey)
    v, f = tube([Vector((0.15, 0, 0.5)), Vector((0.2, 0, 0.7)), Vector((0.16, 0, 0.82))], [0.06, 0.05, 0.05], 5)
    b.add(v, f, white)
    b.add_bm(ico(0.07, 1, 3, 0.0, (1.1, 0.9, 1.0), (0.18, 0, 0.86)), white)
    v, f = flat_poly([(0.22, 0.02), (0.6, -0.02), (0.6, -0.05), (0.22, -0.12)], 0.06, "y")
    b.add(transform_verts(v, Matrix.Translation((0, 0, 0.86))), f, beak)
    b.add_bm(ico(0.018, 0, 4, 0, (1, 1, 1), (0.22, 0.05, 0.89)), mat("eye_black", hexc("#101014")))
    return b.finish()


def goat():
    b = Builder("goat")
    fur = mat("goat_fur", hexc("#e8e0d0"))
    dark = mat("goat_dark", hexc("#5a4a3a"))
    _legs(b, dark, (-0.2, 0.2), (-0.09, 0.09), 0.35, 0.03)
    b.add_bm(ico(0.17, 2, 1, 0.0, (1.7, 1.0, 1.0), (0, 0, 0.5)), fur)
    b.add_bm(ico(0.1, 1, 2, 0.0, (1.5, 0.8, 0.9), (0.35, 0, 0.66)), fur)
    for s in (-1, 1):
        v, f = tube([Vector((0.32, s * 0.04, 0.74)), Vector((0.25, s * 0.06, 0.86)), Vector((0.16, s * 0.06, 0.88))], [0.02, 0.015, 0.008], 4)
        b.add(v, f, dark)
        b.add_bm(ico(0.04, 0, 3, 0.0, (0.5, 0.4, 1.0), (0.3, s * 0.1, 0.7)), fur)
    b.add_bm(cylinder(0.03, 0.0, 0.1, 4, (0.45, 0, 0.5)), fur)
    b.add_bm(ico(0.015, 0, 4, 0, (1, 1, 1), (0.42, 0.06, 0.7)), mat("eye_black", hexc("#101014")))
    return b.finish()


ANIMALS = {"dog": dog, "chicken": chicken, "duck": duck, "seal": seal, "pelican": pelican, "goat": goat}
