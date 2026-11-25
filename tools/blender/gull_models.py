"""Gullhaven 3D models, built in Blender from code.

Low-poly models with little pixel-art textures (nearest-filtered, about 16 texels a metre,
the same as the world's sprites) so they sit in the HD-2D world: trees, bushes, flowers,
reeds and rocks; gulls, crabs, butterflies, dolphins and a whale's tail; the sea monsters
and the treasure chest; the garden things for plots on Driftwood Lane; and every fish in
the catalogue (see gull_fish.py).

Run it two ways:
  - headless, to (re)export every model into godot/models/:
        python tools/blender/export_models.py            (needs `pip install bpy`)
  - in a live Blender (the MCP), to look at them: exec this file, then call
        showcase() to lay them all out in a "Gullhaven Models" collection.

Every builder returns one object with its origin at the base (the ground, or for fish
the middle of the body), +X forward, Z up (Godot gets Y up, glTF's convention).
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

TEXEL = 1.0 / 16.0
COLLECTION = "Gullhaven Models"


# --- colours, textures and materials ------------------------------------------------------

def hexc(h, a=1.0):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (r, g, b, a)


def shade(c, k):
    """Lighter (k > 1) or darker (k < 1), staying in range."""
    return tuple(min(1.0, max(0.0, v * k)) for v in c[:3]) + (c[3] if len(c) > 3 else 1.0,)


def mix(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3)) + (1.0,)


def _srgb_to_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


_images = {}


def pixel_image(name, w, h, fn):
    """A little image painted pixel by pixel: fn(x, y) -> (r, g, b, a) in sRGB, y=0 at the top."""
    key = "gh_" + name
    if key in _images and _images[key].name in bpy.data.images:
        return _images[key]
    old = bpy.data.images.get(key)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(key, w, h, alpha=True)
    px = [0.0] * (w * h * 4)
    for y in range(h):
        for x in range(w):
            c = fn(x, y)
            i = ((h - 1 - y) * w + x) * 4  # Blender's rows go bottom up
            px[i] = c[0]
            px[i + 1] = c[1]
            px[i + 2] = c[2]
            px[i + 3] = c[3] if len(c) > 3 else 1.0
    img.pixels = px
    img.pack()
    _images[key] = img
    return img


def speckle(name, colours, size=16, seed=1, weights=None):
    """Leaves, grass, stone: random pixels from a palette (weights favour the first ones)."""
    rng = random.Random(seed)
    weights = weights or [1.0] * len(colours)
    return pixel_image(name, size, size, lambda x, y: rng.choices(colours, weights)[0])


def bark(name, base, size=16, seed=2, lines=None):
    rng = random.Random(seed)
    dark = shade(base, 0.72)
    light = shade(base, 1.18)
    cols = [rng.random() for _ in range(size)]

    def f(x, y):
        if lines and rng.random() < 0.05:
            return lines
        v = cols[x]
        if v < 0.22:
            return dark
        if v > 0.85:
            return light
        return base if rng.random() > 0.08 else dark
    return pixel_image(name, size, size, f)


_mats = {}


def mat(name, colour=None, image=None, rough=0.95, emit=None, emit_strength=2.0, alpha=False):
    key = "gh_" + name
    if key in _mats and _mats[key].name in bpy.data.materials:
        return _mats[key]
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-300, 0)
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.location = (-650, 0)
        tex.image = image
        tex.interpolation = "Closest"  # glTF: a NEAREST sampler, so it stays pixel art
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
    elif colour is not None:
        c = colour if len(colour) == 4 else tuple(colour) + (1.0,)
        bsdf.inputs["Base Color"].default_value = tuple(_srgb_to_linear(v) for v in c[:3]) + (1.0,)
    if emit is not None:
        e = emit if len(emit) == 4 else tuple(emit) + (1.0,)
        bsdf.inputs["Emission Color"].default_value = tuple(_srgb_to_linear(v) for v in e[:3]) + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    _mats[key] = m
    return m


# --- building meshes ------------------------------------------------------------------------

class Builder:
    """Collects bits of geometry (each with a material) into one mesh object."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def add(self, verts, faces, m, smooth=False, uv="box", uv_scale=1.0, uv_fn=None, uvs=None):
        """verts: [(x,y,z)], faces: [[i,...]]; uv: 'box' (per-face projection, 1 m = one
        16-texel tile * uv_scale) or uv_fn(v, face_normal) -> (u, v)."""
        bv = [self.bm.verts.new(v) for v in verts]
        index = {v: i for i, v in enumerate(bv)}
        mi = self._mi(m)
        out = []
        for f in faces:
            try:
                face = self.bm.faces.new([bv[i] for i in f])
            except ValueError:
                continue
            face.material_index = mi
            face.smooth = smooth
            face.normal_update()
            n = face.normal
            for loop in face.loops:
                co = loop.vert.co
                if uvs is not None:
                    loop[self.uv].uv = uvs[index[loop.vert]]
                elif uv_fn:
                    loop[self.uv].uv = uv_fn(co, n)
                else:
                    ax = max(range(3), key=lambda k: abs(n[k]))
                    if ax == 0:
                        u, v = co.y, co.z
                    elif ax == 1:
                        u, v = co.x, co.z
                    else:
                        u, v = co.x, co.y
                    loop[self.uv].uv = (u * uv_scale, v * uv_scale)
            out.append(face)
        return out

    def add_bm(self, other, m, matrix=None, smooth=False, uv_scale=1.0):
        """Add a temporary bmesh (from a bmesh.ops primitive)."""
        if matrix:
            bmesh.ops.transform(other, matrix=matrix, verts=other.verts)
        verts = [tuple(v.co) for v in other.verts]
        idx = {v: i for i, v in enumerate(other.verts)}
        faces = [[idx[v] for v in f.verts] for f in other.faces]
        other.free()
        return self.add(verts, faces, m, smooth=smooth, uv_scale=uv_scale)

    def finish(self, collection=None):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        (collection or target_collection()).objects.link(ob)
        return ob


def target_collection():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def ico(radius, subdiv=1, seed=0, jitter=0.12, squash=(1.0, 1.0, 1.0), at=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    rng = random.Random(seed)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1.0 + (rng.random() - 0.5) * 2.0 * jitter
        v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2])) * k + Vector(at)
        _ = d
    return bm


def cylinder(r1, r2, h, segs=6, at=(0, 0, 0), cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=Vector(at) + Vector((0, 0, h / 2)), verts=bm.verts)
    return bm


def box(sx, sy, sz, at=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(at) + Vector((0, 0, sz / 2)), verts=bm.verts)
    return bm


def tube(points, radii, segs=6):
    """A bent tube through points (list of Vector) with a radius at each."""
    verts, faces = [], []
    n = len(points)
    for i, p in enumerate(points):
        t = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized()
        b = t.cross(a).normalized()
        for k in range(segs):
            ang = k / segs * math.tau
            verts.append(tuple(p + (a * math.cos(ang) + b * math.sin(ang)) * radii[i]))
    for i in range(n - 1):
        for k in range(segs):
            a0 = i * segs + k
            a1 = i * segs + (k + 1) % segs
            faces.append([a0, a1, a1 + segs, a0 + segs])
    faces.append(list(range(segs))[::-1])
    faces.append([(n - 1) * segs + k for k in range(segs)])
    return verts, faces


def flat_poly(outline, thickness=0.02, axis="y"):
    """A thin slab from a 2D outline [(u, v)], in the XZ plane (axis y) or XY plane (axis z)."""
    n = len(outline)
    verts = []
    for side in (-1, 1):
        for (u, v) in outline:
            if axis == "y":
                verts.append((u, side * thickness / 2, v))
            else:
                verts.append((u, v, side * thickness / 2))
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    return verts, faces


def transform_verts(verts, m):
    return [tuple(m @ Vector(v)) for v in verts]


# --- plants -----------------------------------------------------------------------------------

LEAF = {
    "oak": ["#3f8a32", "#4f9e3a", "#2f6e2a", "#66b648", "#24572a"],
    "autumn": ["#d9822a", "#e89a34", "#b8601e", "#f2b648", "#9a4a1a"],
    "birch": ["#7ac24a", "#8fd25a", "#5ea43c", "#a8e070", "#4a8a34"],
    "willow": ["#5aa048", "#6eb456", "#46863c", "#88c86a", "#386e32"],
    "mangrove": ["#3a7a3a", "#4a8e44", "#2c6230", "#5ea456", "#22502a"],
    "pine": ["#2e6a48", "#3a7a52", "#24563e", "#4a8a5e", "#1c4834"],
    "palm": ["#4a9a3a", "#5aae44", "#3a7e32", "#78c456", "#2e6428"],
    "bush": ["#4a9a3a", "#5aae44", "#3a7e32", "#78c456", "#2e6428"],
    "fern": ["#3e8e3a", "#52a246", "#2e7030", "#6cba58"],
    "reeds": ["#6a9a3a", "#82b04a", "#567e30", "#a0c060"],
    "grass": ["#5a9e3c", "#6cb248", "#4a8432"],
}
BARK = {"oak": "#6a4628", "autumn": "#5e3e24", "birch": "#e8e4dc", "willow": "#5e4630", "mangrove": "#5a4030",
        "pine": "#5a3a24", "palm": "#9a7a4e", "dead": "#6a5a4a"}


def clumps(name, colours, size=16, seed=1, extra=None, extra_w=0.0):
    """Leaves: soft clumps (2 x 2 pixel blobs) of a few close shades, lit from the top
    left, and an occasional blossom or berry."""
    rng = random.Random(seed)
    base, dark, light = colours[0], colours[2] if len(colours) > 2 else shade(colours[0], 0.8), colours[1]
    deep = colours[4] if len(colours) > 4 else shade(base, 0.7)
    cells = {}
    for cy in range(size // 2):
        for cx in range(size // 2):
            r = rng.random()
            cells[(cx, cy)] = light if r < 0.22 else dark if r < 0.42 else deep if r < 0.47 else base
    dots = set()
    if extra:
        for _ in range(int(size * size * extra_w * 0.02)):
            dots.add((rng.randrange(size), rng.randrange(size)))
    ex = [hexc(c) for c in (extra or [])]

    def f(x, y):
        if (x, y) in dots and ex:
            return ex[(x * 7 + y) % len(ex)]
        c = cells[(x // 2, y // 2)]
        if (x % 2 == 0 and y % 2 == 0) and c is light:
            return shade(light, 1.06)
        if (x % 2 == 1 and y % 2 == 1) and c is base:
            return shade(base, 0.94)
        return c
    return pixel_image(name, size, size, f)


def leaf_mat(kind, seed=3, extra=None, extra_w=0.0):
    cols = [hexc(c) for c in LEAF[kind]]
    name = "leaf_%s_%d_%s" % (kind, seed, "_".join(x.strip("#") for x in (extra or [])))
    return mat(name, image=clumps(name, cols, 16, seed, extra, extra_w))


def bark_mat(kind):
    if kind == "birch":
        return mat("bark_birch", image=bark("bark_birch", hexc(BARK["birch"]), lines=hexc("#2a2a2a")))
    return mat("bark_" + kind, image=bark("bark_" + kind, hexc(BARK[kind])))


def _canopy(b, m, centre, radius, n, seed, squash=(1, 1, 0.85), spread=0.75, subdiv=2):
    rng = random.Random(seed)
    for i in range(n):
        if i == 0:
            off = Vector((0, 0, 0))
            r = radius
        else:
            a = rng.random() * math.tau
            el = rng.uniform(-0.3, 0.8)
            off = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))) * radius * spread
            r = radius * rng.uniform(0.5, 0.75)
        b.add_bm(ico(r, subdiv, seed * 31 + i, 0.08, squash, Vector(centre) + off), m)


def broadleaf(name, kind, height, width, seed, trunk_frac=0.42, lumps=7, fruit=None):
    b = Builder(name)
    rng = random.Random(seed)
    th = height * trunk_frac
    tr = width * 0.07
    # a slightly leaning trunk with two branches into the canopy
    lean = Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0))
    pts = [Vector((0, 0, 0)), Vector((0, 0, th * 0.5)) + lean * 0.4, Vector((0, 0, th)) + lean, Vector((0, 0, th * 1.35)) + lean * 1.3]
    v, f = tube(pts, [tr * 1.35, tr, tr * 0.8, tr * 0.5], 6)
    b.add(v, f, bark_mat(kind))
    for s in (-1, 1):
        a = rng.random() * math.tau
        d = Vector((math.cos(a), math.sin(a), 0))
        bp = [pts[2], pts[2] + d * width * 0.18 * s + Vector((0, 0, th * 0.3))]
        v, f = tube(bp, [tr * 0.55, tr * 0.25], 5)
        b.add(v, f, bark_mat(kind))
    cr = width * 0.32
    centre = Vector((0, 0, height - cr * 0.95)) + lean * 1.2
    extra = None
    if fruit:
        extra = [fruit]
    _canopy(b, leaf_mat(kind, seed, extra, 0.6 if fruit else 0.0), centre, cr, lumps, seed)
    return b.finish()


def birch(name, height, width, seed):
    b = Builder(name)
    rng = random.Random(seed)
    th = height * 0.55
    pts = [Vector((0, 0, 0)), Vector((rng.uniform(-.1, .1), 0, th * 0.5)), Vector((rng.uniform(-.15, .15), rng.uniform(-.1, .1), th)),
           Vector((0, 0, height * 0.85))]
    v, f = tube(pts, [0.2, 0.16, 0.12, 0.06], 6)
    b.add(v, f, bark_mat("birch"), uv_scale=1.0)
    m = leaf_mat("birch", seed)
    rng2 = random.Random(seed + 9)
    for i in range(6):
        z = th + (height - th) * (i / 6.0) + 0.2
        r = width * (0.3 - i * 0.025)
        a = rng2.random() * math.tau
        off = Vector((math.cos(a), math.sin(a), 0)) * width * 0.08
        b.add_bm(ico(r, 1, seed + i, 0.15, (1, 1, 0.8), Vector((0, 0, z)) + off), m)
    return b.finish()


def pine(name, height, width, seed):
    b = Builder(name)
    v, f = tube([Vector((0, 0, 0)), Vector((0, 0, height * 0.3))], [0.25, 0.2], 6)
    b.add(v, f, bark_mat("pine"))
    m = leaf_mat("pine", seed)
    tiers = 5
    rng = random.Random(seed)
    for i in range(tiers):
        t = i / tiers
        z0 = height * (0.16 + t * 0.66)
        r = width * 0.5 * (1.0 - t * 0.78)
        h = height * 0.3
        bm = cylinder(r, 0.0, h, 8, (0, 0, z0))
        # ragged skirt
        for vert in bm.verts:
            if vert.co.z < z0 + 0.01:
                vert.co.z -= rng.uniform(0.0, 0.25)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rng.random() * 3, 3, "Z"), verts=bm.verts)
        b.add_bm(bm, m)
    return b.finish()


def palm(name, height, seed):
    b = Builder(name)
    rng = random.Random(seed)
    bend = Vector((rng.choice((-1, 1)) * 0.9, rng.uniform(-0.4, 0.4), 0))
    pts = [Vector((0, 0, 0)) + bend * (t * t) + Vector((0, 0, height * 0.9 * t)) for t in [i / 7 for i in range(8)]]
    v, f = tube(pts, [0.26 - 0.1 * (i / 7) for i in range(8)], 6)
    # ringed trunk texture
    ring = pixel_image("palm_rings", 8, 8, lambda x, y: hexc("#7a5a36") if y % 4 == 0 else hexc("#a8865a") if y % 4 == 1 else hexc("#9a7a4e"))
    b.add(v, f, mat("bark_palm", image=ring), uv_scale=2.0)
    top = pts[-1]
    lm = leaf_mat("palm", seed)
    n = 8
    for i in range(n):
        a = i / n * math.tau + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = d.cross(Vector((0, 0, 1)))
        L = height * rng.uniform(0.42, 0.5)
        segs = 5
        verts = []
        for s in range(segs + 1):
            t = s / segs
            p = top + d * L * t + Vector((0, 0, 0.6 * math.sin(t * math.pi * 0.8) - 1.6 * t * t))
            w = 0.55 * math.sin(math.pi * min(1.0, t * 1.1 + 0.05))
            verts += [tuple(p - side * w + Vector((0, 0, -0.08))), tuple(p), tuple(p + side * w + Vector((0, 0, -0.08)))]
        faces = []
        for s in range(segs):
            o = s * 3
            faces += [[o, o + 3, o + 4, o + 1], [o + 1, o + 4, o + 5, o + 2]]
        b.add(verts, faces, lm)
    # coconuts
    nut = mat("coconut", hexc("#6a4a2a"))
    for i in range(3):
        a = i / 3 * math.tau
        b.add_bm(ico(0.18, 1, i, 0.05, (1, 1, 1), top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, -0.25))), nut)
    return b.finish()


def willow(name, height, width, seed):
    b = Builder(name)
    rng = random.Random(seed)
    th = height * 0.45
    v, f = tube([Vector((0, 0, 0)), Vector((0.1, 0, th * 0.6)), Vector((0, 0.1, th)), Vector((0, 0, th * 1.3))], [0.42, 0.3, 0.26, 0.15], 7)
    b.add(v, f, bark_mat("willow"))
    m = leaf_mat("willow", seed)
    top = Vector((0, 0, height * 0.82))
    b.add_bm(ico(width * 0.33, 1, seed, 0.12, (1, 1, 0.6), top), m)
    # drooping curtains of leaves
    n = 16
    for i in range(n):
        a = i / n * math.tau + rng.uniform(-0.1, 0.1)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = d.cross(Vector((0, 0, 1)))
        r0 = width * rng.uniform(0.3, 0.45)
        root = top + d * r0 + Vector((0, 0, -0.2))
        drop = height * rng.uniform(0.45, 0.62)
        w = rng.uniform(0.45, 0.7)
        verts = [tuple(root - side * w), tuple(root + side * w), tuple(root + d * 0.35 + side * w * 0.8 - Vector((0, 0, drop))),
                 tuple(root + d * 0.35 - side * w * 0.8 - Vector((0, 0, drop)))]
        b.add(verts, [[0, 1, 2, 3]], m)
    return b.finish()


def mangrove(name, height, width, seed):
    b = Builder(name)
    rng = random.Random(seed)
    bm_ = bark_mat("mangrove")
    hub = Vector((0, 0, height * 0.3))
    for i in range(9):
        a = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        foot = d * width * rng.uniform(0.32, 0.45) + Vector((0, 0, -0.3))
        mid = hub * 0.6 + d * width * 0.25
        v, f = tube([foot, mid, hub], [0.06, 0.07, 0.1], 4)
        b.add(v, f, bm_)
    v, f = tube([hub, hub + Vector((0, 0, height * 0.3))], [0.22, 0.16], 6)
    b.add(v, f, bm_)
    _canopy(b, leaf_mat("mangrove", seed), Vector((0, 0, height * 0.72)), width * 0.32, 7, seed, (1, 1, 0.7))
    return b.finish()


def dead_tree(name, height, seed):
    b = Builder(name)
    rng = random.Random(seed)
    m = bark_mat("dead")

    def branch(p, d, length, r, depth):
        end = p + d * length
        v, f = tube([p, (p + end) / 2 + Vector((rng.uniform(-.1, .1), rng.uniform(-.1, .1), 0)), end], [r, r * 0.8, r * 0.5], 5)
        b.add(v, f, m)
        if depth <= 0:
            return
        for _ in range(2 if depth > 1 else 3):
            nd = (d + Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(0.0, 0.6)))).normalized()
            branch(end, nd, length * 0.62, r * 0.55, depth - 1)
    branch(Vector((0, 0, 0)), Vector((0, 0, 1)), height * 0.45, 0.2, 3)
    return b.finish()


def bush(name, kind, width, height, seed, flowers=None):
    b = Builder(name)
    m = leaf_mat("bush", seed, flowers, 1.6 if flowers else 0.0)
    rng = random.Random(seed)
    r = width * 0.32
    b.add_bm(ico(r * 1.05, 1, seed, 0.15, (1, 1, height / width * 1.1), (0, 0, r * 0.75)), m)
    for i in range(4):
        a = i / 4 * math.tau + rng.random()
        b.add_bm(ico(r * 0.75, 1, seed + i, 0.15, (1, 1, 0.85), (math.cos(a) * r * 0.75, math.sin(a) * r * 0.75, r * 0.5)), m)
    if flowers:
        fm = mat("flower_" + flowers[0].strip("#"), hexc(flowers[0]))
        for i in range(10):
            a = rng.random() * math.tau
            el = rng.uniform(0.1, 1.2)
            p = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))) * r * 1.15 + Vector((0, 0, r * 0.7))
            b.add_bm(ico(0.09, 0, seed + 50 + i, 0.0, (1, 1, 1), p), fm)
    return b.finish()


def fern(name, seed):
    b = Builder(name)
    rng = random.Random(seed)
    m = leaf_mat("fern", seed)
    for i in range(9):
        a = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = d.cross(Vector((0, 0, 1)))
        L = rng.uniform(0.8, 1.05)
        verts = []
        for s in range(5):
            t = s / 4
            p = d * L * t + Vector((0, 0, 0.7 * math.sin(t * 2.2) * (1 - t * 0.4)))
            w = 0.2 * math.sin(math.pi * min(1, t + 0.1))
            verts += [tuple(p - side * w), tuple(p + side * w)]
        faces = [[s * 2, s * 2 + 2, s * 2 + 3, s * 2 + 1] for s in range(4)]
        b.add(verts, faces, m)
    return b.finish()


def flowers(name, colour, seed):
    b = Builder(name)
    rng = random.Random(seed)
    stem = mat("stem", hexc("#3e8a32"))
    pet = mat("petal_" + colour.strip("#"), hexc(colour))
    eye = mat("flower_eye", hexc("#f2d040"))
    for i in range(6):
        p = Vector((rng.uniform(-0.38, 0.38), rng.uniform(-0.3, 0.3), 0))
        h = rng.uniform(0.35, 0.6)
        v, f = tube([p, p + Vector((rng.uniform(-.05, .05), 0, h))], [0.02, 0.015], 3)
        b.add(v, f, stem)
        top = p + Vector((0, 0, h))
        for k in range(5):
            a = k / 5 * math.tau
            c = top + Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0))
            b.add_bm(ico(0.055, 0, k, 0.0, (1, 1, 0.5), c), pet)
        b.add_bm(ico(0.04, 0, 9, 0.0, (1, 1, 1), top + Vector((0, 0, 0.02))), eye)
        # a leaf
        a = rng.random() * math.tau
        d = Vector((math.cos(a), math.sin(a), 0))
        base = p + Vector((0, 0, h * 0.3))
        b.add([tuple(base), tuple(base + d * 0.16 + Vector((0, 0, 0.08)) + d.cross(Vector((0, 0, 1))) * 0.05),
               tuple(base + d * 0.24 + Vector((0, 0, 0.14))), tuple(base + d * 0.16 + Vector((0, 0, 0.08)) - d.cross(Vector((0, 0, 1))) * 0.05)],
              [[0, 1, 2, 3]], stem)
    return b.finish()


def reeds(name, seed):
    b = Builder(name)
    rng = random.Random(seed)
    m = leaf_mat("reeds", seed)
    cat = mat("cattail", hexc("#6a4426"))
    for i in range(14):
        p = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.45, 0.45), 0))
        h = rng.uniform(1.2, 2.2)
        lean = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
        side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * 0.05
        verts = [tuple(p - side), tuple(p + side), tuple(p + lean * 0.5 + side * 0.6 + Vector((0, 0, h * 0.6))),
                 tuple(p + lean * 0.5 - side * 0.6 + Vector((0, 0, h * 0.6))), tuple(p + lean + Vector((0, 0, h)))]
        b.add(verts, [[0, 1, 2, 3], [3, 2, 4]], m)
        if i % 4 == 0:
            top = p + lean * 0.85 + Vector((0, 0, h * 0.85))
            v, f = tube([top, top + Vector((0, 0, 0.22))], [0.05, 0.05], 5)
            b.add(v, f, cat)
    return b.finish()


def rock(name, width, height, seed, moss=False):
    b = Builder(name)
    cols = [hexc(c) for c in ["#9a98a8", "#8a889a", "#acaab8", "#7a788a", "#b8b6c2"]]
    w = [5, 4, 3, 2, 1]
    if moss:
        cols += [hexc("#5a9a44"), hexc("#4a8a3a")]
        w += [1.5, 1.5]
    m = mat("stone_%d_%s" % (seed, moss), image=speckle("stone_%d_%s" % (seed, moss), cols, 16, seed, w))
    bm = ico(width * 0.5, 2, seed, 0.0, (1, 0.8, height / width * 1.6), (0, 0, 0))
    rng = random.Random(seed)
    for v in bm.verts:
        n = noise.noise(v.co * 1.7 + Vector((seed, seed * 2, 0)))
        v.co *= 1.0 + n * 0.25
        if v.co.z < 0:
            v.co.z *= 0.25
    # facet it: a few planar cuts by collapsing verts toward planes
    for _ in range(5):
        nrm = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1))).normalized()
        d = width * rng.uniform(0.25, 0.42)
        for v in bm.verts:
            k = v.co.dot(nrm)
            if k > d:
                v.co -= nrm * (k - d)
    bmesh.ops.translate(bm, vec=(0, 0, height * 0.12), verts=bm.verts)
    b.add_bm(bm, m)
    return b.finish()


PLANTS = {
    "oak0": lambda: broadleaf("oak0", "oak", 7.0, 6.0, 11),
    "oak1": lambda: broadleaf("oak1", "oak", 6.6, 5.6, 12, lumps=8),
    "oak2": lambda: broadleaf("oak2", "oak", 7.2, 6.0, 13, fruit="#f4f0e0"),
    "autumn0": lambda: broadleaf("autumn0", "autumn", 7.0, 6.0, 21),
    "autumn1": lambda: broadleaf("autumn1", "autumn", 6.8, 5.8, 22, lumps=8),
    "birch0": lambda: birch("birch0", 7.0, 4.4, 31),
    "birch1": lambda: birch("birch1", 6.6, 4.2, 32),
    "pine0": lambda: pine("pine0", 7.5, 4.5, 41),
    "pine1": lambda: pine("pine1", 7.2, 4.2, 42),
    "palm0": lambda: palm("palm0", 7.4, 51),
    "palm1": lambda: palm("palm1", 7.0, 52),
    "willow0": lambda: willow("willow0", 7.0, 6.0, 61),
    "mangrove0": lambda: mangrove("mangrove0", 6.0, 6.0, 71),
    "mangrove1": lambda: mangrove("mangrove1", 5.8, 5.6, 72),
    "dead0": lambda: dead_tree("dead0", 6.0, 81),
    "bush0": lambda: bush("bush0", "bush", 2.0, 1.4, 91),
    "bush1": lambda: bush("bush1", "bush", 1.9, 1.3, 92),
    "bush2": lambda: bush("bush2", "bush", 2.0, 1.4, 93, ["#f4f4f0"]),
    "bush_pink": lambda: bush("bush_pink", "bush", 2.0, 1.5, 94, ["#f08ab8", "#e06aa0"]),
    "bush_white": lambda: bush("bush_white", "bush", 2.0, 1.5, 95, ["#f8f8f4", "#e0e4f0"]),
    "bush_yellow": lambda: bush("bush_yellow", "bush", 2.0, 1.5, 96, ["#f4d040", "#e8b830"]),
    "fern0": lambda: fern("fern0", 101),
    "fern1": lambda: fern("fern1", 102),
    "flowers0": lambda: flowers("flowers0", "#e84a5a", 111),
    "flowers1": lambda: flowers("flowers1", "#f4d040", 112),
    "flowers2": lambda: flowers("flowers2", "#8a6ae8", 113),
    "flowers3": lambda: flowers("flowers3", "#f8f8f0", 114),
    "flowers4": lambda: flowers("flowers4", "#f49a30", 115),
    "reeds0": lambda: reeds("reeds0", 121),
    "reeds1": lambda: reeds("reeds1", 122),
    "rock0": lambda: rock("rock0", 2.0, 1.2, 131),
    "rock1": lambda: rock("rock1", 1.9, 1.1, 132),
    "rock2": lambda: rock("rock2", 2.0, 1.2, 133, moss=True),
    "boulder0": lambda: rock("boulder0", 3.8, 2.5, 141),
    "boulder1": lambda: rock("boulder1", 3.4, 2.3, 142, moss=True),
}


# --- critters ----------------------------------------------------------------------------------

def gull():
    """A herring gull, 0.6 m long; the wings are separate objects (Wing.L / Wing.R) to flap."""
    b = Builder("gull")
    white = mat("gull_white", hexc("#f4f4f0"))
    grey = mat("gull_grey", hexc("#a8b0bc"))
    black = mat("gull_black", hexc("#22242a"))
    beak = mat("gull_beak", hexc("#f2c030"))
    b.add_bm(ico(0.17, 1, 1, 0.0, (1.7, 0.85, 0.8), (0, 0, 0)), white)
    b.add_bm(ico(0.1, 1, 2, 0.0, (1, 0.9, 0.95), (0.25, 0, 0.1)), white)
    b.add_bm(cylinder(0.035, 0.0, 0.12, 4, (0, 0, 0)), beak, Matrix.Translation((0.34, 0, 0.09)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    for s in (-1, 1):
        b.add_bm(ico(0.018, 0, 3, 0.0, (1, 1, 1), (0.31, s * 0.06, 0.14)), black)
    v, f = flat_poly([(-0.25, -0.06), (-0.45, -0.05), (-0.45, 0.05), (-0.25, 0.06)], 0.03, "z")
    b.add(transform_verts(v, Matrix.Translation((0, 0, 0.02))), f, grey)
    body = b.finish()
    for s, nm in ((1, "Wing.L"), (-1, "Wing.R")):
        w = Builder("gull_" + nm)
        out = [(0.1, 0.0), (0.12, 0.25), (0.02, 0.55), (-0.08, 0.62), (-0.12, 0.3), (-0.1, 0.0)]
        v, f = flat_poly([(x, y * s) for (x, y) in out], 0.025, "z")
        w.add(v, f, grey)
        tip = [(0.02, 0.5 * s), (-0.08, 0.62 * s), (-0.1, 0.48 * s)]
        v, f = flat_poly(tip, 0.03, "z")
        w.add(v, f, black)
        wing = w.finish()
        wing.name = nm
        wing.parent = body
        wing.location = (0.0, 0.08 * s, 0.06)
    return body


def crab():
    b = Builder("crab")
    red = mat("crab_red", hexc("#d0502a"))
    dark = mat("crab_dark", hexc("#8a2a1a"))
    eye = mat("crab_eye", hexc("#1a1a1a"))
    b.add_bm(ico(0.12, 1, 4, 0.05, (1.0, 1.35, 0.45), (0, 0, 0.07)), red)
    for s in (-1, 1):
        for i in range(3):
            x = -0.05 + i * 0.05
            v, f = tube([Vector((x, s * 0.12, 0.06)), Vector((x - 0.02, s * 0.22, 0.08)), Vector((x - 0.04, s * 0.28, 0.0))], [0.015, 0.012, 0.008], 4)
            b.add(v, f, dark)
        v, f = tube([Vector((0.06, s * 0.1, 0.07)), Vector((0.16, s * 0.18, 0.09))], [0.02, 0.018], 4)
        b.add(v, f, red)
        b.add_bm(ico(0.05, 1, 5, 0.0, (1.3, 0.8, 0.7), (0.2, s * 0.19, 0.1)), red)
        b.add_bm(ico(0.018, 0, 6, 0.0, (1, 1, 1), (0.1, s * 0.04, 0.15)), eye)
    return b.finish()


def butterfly():
    b = Builder("butterfly")
    body = mat("fly_body", hexc("#2a2a2a"))
    b.add_bm(ico(0.012, 1, 1, 0.0, (3, 1, 1), (0, 0, 0)), body)
    root = b.finish()
    wing_img = pixel_image("fly_wing", 8, 8, lambda x, y: hexc("#2a2a2a") if (x == 0 or y == 0 or x == 7 or y == 7)
                           else hexc("#f4a030") if (x + y) % 5 else hexc("#f8f0d0"))
    wm = mat("fly_wing", image=wing_img)
    for s, nm in ((1, "Wing.L"), (-1, "Wing.R")):
        w = Builder("fly_" + nm)
        v, f = flat_poly([(0.02, 0.0), (0.05, 0.06 * s), (0.0, 0.08 * s), (-0.04, 0.05 * s), (-0.03, 0.0)], 0.004, "z")
        w.add(v, f, wm, uv_fn=lambda co, n: (co.x * 8 + 0.5, abs(co.y) * 8))
        o = w.finish()
        o.name = nm
        o.parent = root
    return root


def dolphin():
    b = Builder("dolphin")
    grey = mat("dolphin_grey", hexc("#7a8a9a"))
    belly = mat("dolphin_belly", hexc("#d8dee4"))
    sec = []
    L = 2.2
    for i in range(10):
        t = i / 9
        x = (0.5 - t) * L
        r = 0.32 * math.sin(math.pi * min(1, 0.08 + t * 1.0)) ** 0.8 + 0.03
        sec.append((x, r))
    verts, faces = [], []
    segs = 8
    for i, (x, r) in enumerate(sec):
        for k in range(segs):
            a = k / segs * math.tau
            verts.append((x, math.cos(a) * r * 0.85, math.sin(a) * r))
    for i in range(len(sec) - 1):
        for k in range(segs):
            a0 = i * segs + k
            a1 = i * segs + (k + 1) % segs
            faces.append([a0, a0 + segs, a1 + segs, a1])
    b.add(verts, faces, grey)
    b.add_bm(cylinder(0.08, 0.02, 0.3, 5, (0, 0, 0)), grey, Matrix.Translation((L * 0.5 + 0.12, 0, -0.02)) @ Matrix.Rotation(-math.pi / 2, 4, "Y"))
    v, f = flat_poly([(0.1, 0.0), (-0.15, 0.35), (-0.25, 0.32), (-0.2, 0.0)], 0.05, "y")
    b.add(transform_verts(v, Matrix.Translation((0, 0, 0.28))), f, grey)
    v, f = flat_poly([(0.0, 0.0), (-0.25, 0.4), (-0.3, 0.32), (-0.2, 0.0), (-0.3, -0.32), (-0.25, -0.4)], 0.05, "z")
    b.add(transform_verts(v, Matrix.Translation((-L * 0.5, 0, 0))), f, grey)
    b.add_bm(ico(0.2, 1, 1, 0.0, (3.5, 0.9, 0.5), (0.1, 0, -0.18)), belly)
    return b.finish()


def whale_tail():
    b = Builder("whale_tail")
    m = mat("whale", hexc("#3a4656"))
    v, f = tube([Vector((0, 0, -0.5)), Vector((0, 0, 0.6)), Vector((0.1, 0, 1.3))], [0.45, 0.3, 0.15], 8)
    b.add(v, f, m)
    out = [(0.0, 0.0), (-0.4, 0.5), (-0.2, 1.4), (0.15, 1.6), (0.25, 0.6), (0.3, 0.0), (0.25, -0.6), (0.15, -1.6), (-0.2, -1.4), (-0.4, -0.5)]
    v, f = flat_poly([(y, x) for (x, y) in out], 0.1, "z")  # spread across Y
    v = [(p[1], p[0], p[2]) for p in v]
    b.add(transform_verts(v, Matrix.Translation((0.05, 0, 1.4)) @ Matrix.Rotation(math.radians(80), 4, "Y")), f, m)
    return b.finish()


CRITTERS = {"gull": gull, "crab": crab, "butterfly": butterfly, "dolphin": dolphin, "whale_tail": whale_tail}


# --- the sea monsters and treasure ------------------------------------------------------------

def serpent_head():
    b = Builder("serpent_head")
    skin = mat("serpent_skin", image=speckle("serpent_skin", [hexc("#2e8a7a"), hexc("#3aa08c"), hexc("#247062"), hexc("#48b49c")], 16, 7, [4, 3, 2, 1]))
    belly = mat("serpent_belly", hexc("#d8d0a0"))
    fin = mat("serpent_fin", hexc("#c8384a"))
    eye = mat("serpent_eye", hexc("#f4e040"), emit=hexc("#f4e040"), emit_strength=1.5)
    pupil = mat("serpent_pupil", hexc("#101010"))
    tooth = mat("tooth", hexc("#f8f4e8"))
    # neck rising out of the water, head looking forward (+X)
    pts = [Vector((-1.2, 0, -1.0)), Vector((-0.9, 0, 0.6)), Vector((-0.4, 0, 2.0)), Vector((0.2, 0, 2.8))]
    v, f = tube(pts, [0.75, 0.68, 0.6, 0.55], 10)
    b.add(v, f, skin, uv_scale=1.5)
    b.add_bm(ico(0.75, 2, 3, 0.03, (1.6, 0.85, 0.75), (0.7, 0, 3.0)), skin)
    b.add_bm(ico(0.55, 2, 4, 0.02, (1.6, 0.75, 0.4), (1.1, 0, 2.62)), belly)
    for s in (-1, 1):
        b.add_bm(ico(0.18, 1, 5, 0.0, (1, 1, 1), (1.0, s * 0.5, 3.3)), eye)
        b.add_bm(ico(0.09, 1, 6, 0.0, (0.6, 1, 1.5), (1.12, s * 0.62, 3.32)), pupil)
        for k in range(4):
            b.add_bm(cylinder(0.06, 0.0, 0.22, 4, (0, 0, 0)), tooth, Matrix.Translation((1.4 - k * 0.22, s * 0.36, 2.78)) @ Matrix.Rotation(math.pi, 4, "X"))
        # frills
        v, f = flat_poly([(0, 0), (-0.6, 0.9), (-0.9, 0.2)], 0.06, "y")
        b.add(transform_verts(v, Matrix.Translation((0.2, s * 0.6, 3.1)) @ Matrix.Rotation(s * 0.6, 4, "X")), f, fin)
    for k in range(6):
        v, f = flat_poly([(0.25, 0), (0, 0.55), (-0.25, 0)], 0.06, "y")
        p = pts[0].lerp(pts[3], k / 5) if k < 5 else Vector((0.6, 0, 3.5))
        b.add(transform_verts(v, Matrix.Translation(p + Vector((-0.45 + k * 0.05, 0, 0.5)))), f, fin)
    return b.finish()


def serpent_hump():
    b = Builder("serpent_hump")
    skin = mat("serpent_skin")
    fin = mat("serpent_fin")
    pts = [Vector((-1.6, 0, -0.8)), Vector((-0.9, 0, 0.7)), Vector((0, 0, 1.1)), Vector((0.9, 0, 0.7)), Vector((1.6, 0, -0.8))]
    v, f = tube(pts, [0.6, 0.62, 0.62, 0.6, 0.55], 10)
    b.add(v, f, skin, uv_scale=1.5)
    for k in range(3):
        v, f = flat_poly([(0.25, 0), (0, 0.5), (-0.25, 0)], 0.06, "y")
        b.add(transform_verts(v, Matrix.Translation(pts[k + 1] + Vector((0, 0, 0.5)))), f, fin)
    return b.finish()


def tentacle():
    b = Builder("tentacle")
    skin = mat("kraken_skin", image=speckle("kraken_skin", [hexc("#c84a7a"), hexc("#d85a8a"), hexc("#a83a66"), hexc("#e070a0")], 16, 8, [4, 3, 2, 1]))
    sucker = mat("kraken_sucker", hexc("#f4c8d8"))
    pts = [Vector((0, 0, -1.0)) + Vector((0.5 * math.sin(t * 2.2), 0, 4.2 * t)) + Vector((0, 0, 0)) for t in [i / 9 for i in range(10)]]
    pts = [p + Vector((-0.9 * (i / 9) ** 2, 0, 0)) for i, p in enumerate(pts)]
    radii = [0.42 * (1 - i / 10.5) + 0.04 for i in range(10)]
    v, f = tube(pts, radii, 8)
    b.add(v, f, skin, uv_scale=1.5)
    for i in range(1, 9):
        p = pts[i]
        b.add_bm(ico(radii[i] * 0.35, 0, i, 0.0, (1, 1, 1), p + Vector((radii[i] * 0.85, 0, 0))), sucker)
    return b.finish()


def chest(open_=False):
    b = Builder("chest_open" if open_ else "chest")
    wood = mat("chest_wood", image=bark("chest_wood", hexc("#8a5a30")))
    band = mat("chest_band", hexc("#c8a040"), rough=0.4)
    gold = mat("gold", hexc("#f4c840"), rough=0.3, emit=hexc("#f4c840"), emit_strength=0.4)
    b.add_bm(box(0.9, 0.6, 0.45), wood)
    for x in (-0.3, 0.3):
        b.add_bm(box(0.08, 0.62, 0.47, (x, 0, -0.01)), band)
    b.add_bm(box(0.14, 0.04, 0.16, (0, -0.31, 0.3)), band)
    lid = cylinder(0.3, 0.3, 0.9, 8, (0, 0, 0))
    bmesh.ops.rotate(lid, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=lid.verts)
    for v in lid.verts:
        v.co.z = max(v.co.z, 0.0)
        v.co.y *= 1.0
    if open_:
        bmesh.ops.translate(lid, vec=(0, -0.3, 0), verts=lid.verts)
        bmesh.ops.rotate(lid, cent=(0, 0, 0), matrix=Matrix.Rotation(-1.9, 3, "X"), verts=lid.verts)
        bmesh.ops.translate(lid, vec=(0, 0.3, 0.45), verts=lid.verts)
        for i in range(14):
            rng = random.Random(i)
            b.add_bm(cylinder(0.06, 0.06, 0.02, 8, (rng.uniform(-0.35, 0.35), rng.uniform(-0.22, 0.22), 0.42 + rng.uniform(0, 0.1))), gold)
        b.add_bm(ico(0.07, 1, 3, 0, (1, 1, 1), (0.15, 0.05, 0.52)), mat("ruby", hexc("#e8304a"), rough=0.2))
    else:
        bmesh.ops.translate(lid, vec=(0, 0, 0.45), verts=lid.verts)
    b.add_bm(lid, wood)
    return b.finish()


SEA = {"serpent_head": serpent_head, "serpent_hump": serpent_hump, "tentacle": tentacle, "chest": lambda: chest(False),
       "chest_open": lambda: chest(True)}


# --- garden things for the plots --------------------------------------------------------------

def _wood(name="plank", c="#8a5a34"):
    return mat(name, image=bark(name, hexc(c)))


def bench():
    b = Builder("bench")
    w = _wood("bench_wood", "#a8683a")
    iron = mat("iron", hexc("#2a2c32"), rough=0.5)
    for k in range(3):
        b.add_bm(box(1.6, 0.12, 0.05, (0, -0.15 + k * 0.14, 0.45)), w)
    for k in range(2):
        b.add_bm(box(1.6, 0.05, 0.12, (0, 0.22, 0.62 + k * 0.18)), w)
    for x in (-0.7, 0.7):
        b.add_bm(box(0.06, 0.45, 0.45, (x, 0.0, 0.0)), iron)
        b.add_bm(box(0.06, 0.05, 0.5, (x, 0.24, 0.45)), iron)
    return b.finish()


def lamppost():
    b = Builder("lamppost")
    iron = mat("iron", hexc("#2a2c32"), rough=0.5)
    glass = mat("lamp_glass", hexc("#ffe8a0"), emit=hexc("#ffd870"), emit_strength=3.0)
    b.add_bm(cylinder(0.14, 0.1, 0.25, 8), iron)
    b.add_bm(cylinder(0.05, 0.04, 2.4, 6, (0, 0, 0.2)), iron)
    b.add_bm(box(0.26, 0.26, 0.32, (0, 0, 2.6)), glass)
    b.add_bm(cylinder(0.22, 0.02, 0.18, 4, (0, 0, 2.92)), iron, Matrix.Rotation(math.pi / 4, 4, "Z"))
    return b.finish()


def well():
    b = Builder("well")
    stone = mat("well_stone", image=speckle("well_stone", [hexc("#a8a6b0"), hexc("#8e8c98"), hexc("#bcbac4"), hexc("#74727e")], 16, 5, [4, 3, 2, 1]))
    water = mat("well_water", hexc("#4a7ab8"), rough=0.5)
    roof = mat("roof_red", hexc("#b83a2a"))
    w = _wood("well_wood", "#7a4a2a")
    ring = cylinder(0.75, 0.75, 0.75, 12)
    b.add_bm(ring, stone)
    b.add_bm(cylinder(0.62, 0.62, 0.02, 12, (0, 0, 0.68)), water)
    for y in (-0.62, 0.62):
        b.add_bm(box(0.1, 0.1, 1.5, (0, y, 0.7)), w)
    b.add_bm(cylinder(0.05, 0.05, 1.3, 6, (0, 0, 0)), w, Matrix.Translation((0, -0.65, 1.7)) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
    v = [(-0.85, -0.85, 2.05), (0.85, -0.85, 2.05), (0.85, 0.85, 2.05), (-0.85, 0.85, 2.05), (0, -0.95, 2.6), (0, 0.95, 2.6)]
    b.add(v, [[0, 1, 4], [3, 5, 2], [0, 4, 5, 3], [1, 2, 5, 4]], roof)
    b.add_bm(box(0.3, 0.3, 0.3, (0, 0, 1.15)), w)
    return b.finish()


def birdbath():
    b = Builder("birdbath")
    stone = mat("pale_stone", hexc("#c8c8d0"))
    water = mat("well_water", hexc("#4a7ab8"), rough=0.5)
    b.add_bm(cylinder(0.25, 0.2, 0.1, 8), stone)
    b.add_bm(cylinder(0.1, 0.12, 0.7, 8, (0, 0, 0.1)), stone)
    b.add_bm(cylinder(0.25, 0.45, 0.14, 10, (0, 0, 0.8)), stone)
    b.add_bm(cylinder(0.38, 0.38, 0.02, 10, (0, 0, 0.92)), water)
    return b.finish()


def gnome():
    b = Builder("gnome")
    red = mat("gnome_hat", hexc("#d83a2a"))
    blue = mat("gnome_coat", hexc("#3a5ad0"))
    skin = mat("gnome_skin", hexc("#f0c0a0"))
    beard = mat("gnome_beard", hexc("#f8f8f4"))
    boot = mat("gnome_boot", hexc("#4a2a1a"))
    for s in (-1, 1):
        b.add_bm(box(0.1, 0.08, 0.06, (0.02, s * 0.06, 0)), boot)
    b.add_bm(cylinder(0.16, 0.12, 0.3, 8, (0, 0, 0.05)), blue)
    b.add_bm(ico(0.11, 1, 1, 0, (1, 1, 1), (0, 0, 0.44)), skin)
    b.add_bm(cylinder(0.1, 0.02, 0.22, 6, (0, 0, 0)), beard, Matrix.Translation((0.07, 0, 0.44)) @ Matrix.Rotation(math.pi, 4, "X") @ Matrix.Rotation(-0.4, 4, "Y"))
    b.add_bm(cylinder(0.13, 0.0, 0.32, 8, (0, 0, 0.5)), red)
    b.add_bm(ico(0.025, 0, 1, 0, (1, 1, 1), (0.11, 0, 0.47)), mat("gnome_nose", hexc("#e89080")))
    return b.finish()


def umbrella():
    b = Builder("umbrella")
    pole = mat("pole_white", hexc("#f0f0ec"))
    b.add_bm(cylinder(0.03, 0.03, 2.2, 6), pole)
    segs = 8
    for k in range(segs):
        a0 = k / segs * math.tau
        a1 = (k + 1) / segs * math.tau
        m = mat("umbrella_red", hexc("#d83a3a")) if k % 2 else mat("umbrella_white", hexc("#f8f6f0"))
        v = [(0, 0, 2.35), (math.cos(a0) * 1.2, math.sin(a0) * 1.2, 1.9), (math.cos(a1) * 1.2, math.sin(a1) * 1.2, 1.9)]
        b.add(v, [[0, 1, 2]], m)
    return b.finish()


def stump():
    b = Builder("stump")
    w = bark_mat("oak")
    top = mat("stump_top", image=pixel_image("stump_rings", 16, 16, lambda x, y: hexc("#c89a64") if int(math.hypot(x - 7.5, y - 7.5)) % 3 else hexc("#a87a48")))
    b.add_bm(cylinder(0.42, 0.36, 0.45, 9), w)
    b.add(*[[(math.cos(k / 9 * math.tau) * 0.36, math.sin(k / 9 * math.tau) * 0.36, 0.451) for k in range(9)], [list(range(9))]], top,
          uv_fn=lambda co, n: (co.x * 1.35 + 0.5, co.y * 1.35 + 0.5))
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        v, f = tube([Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.1)), Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, -0.05))], [0.1, 0.05], 5)
        b.add(v, f, w)
    return b.finish()


def scarecrow():
    b = Builder("scarecrow")
    w = _wood("post", "#7a5030")
    straw = mat("straw", image=speckle("straw", [hexc("#e8c860"), hexc("#d4b048"), hexc("#f4dc80")], 8, 3))
    shirt = mat("scare_shirt", image=pixel_image("plaid", 8, 8, lambda x, y: hexc("#c84a3a") if (x // 2 + y // 2) % 2 else hexc("#3a6a9a")))
    hat = mat("scare_hat", hexc("#6a4a2a"))
    b.add_bm(box(0.1, 0.1, 2.0), w)
    b.add_bm(box(0.08, 1.4, 0.08, (0, 0, 1.45)), w)
    b.add_bm(box(0.3, 0.6, 0.6, (0, 0, 1.05)), shirt)
    b.add_bm(ico(0.2, 1, 2, 0.05, (1, 1, 1.1), (0, 0, 1.88)), mat("sack", hexc("#d8c8a0")))
    b.add_bm(cylinder(0.32, 0.32, 0.03, 10, (0, 0, 2.02)), hat)
    b.add_bm(cylinder(0.16, 0.14, 0.22, 8, (0, 0, 2.04)), hat)
    for s in (-1, 1):
        b.add_bm(ico(0.1, 0, 4, 0.2, (1, 1, 1), (0, s * 0.72, 1.45)), straw)
    return b.finish()


def hay_bale():
    b = Builder("hay_bale")
    straw = mat("straw")
    twine = mat("twine", hexc("#8a6a3a"))
    b.add_bm(box(1.0, 0.6, 0.5), straw)
    for x in (-0.25, 0.25):
        b.add_bm(box(0.04, 0.62, 0.52, (x, 0, -0.01)), twine)
    return b.finish()


def pumpkin_lantern():
    b = Builder("pumpkin_lantern")
    orange = mat("pumpkin", hexc("#e8822a"))
    glow = mat("pumpkin_glow", hexc("#ffe080"), emit=hexc("#ffc040"), emit_strength=4.0)
    stem = mat("stem")
    for k in range(6):
        a = k / 6 * math.tau
        b.add_bm(ico(0.2, 1, k, 0.0, (0.8, 0.8, 0.9), (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.22)), orange)
    b.add_bm(cylinder(0.03, 0.025, 0.12, 5, (0, 0, 0.42)), stem)
    for s in (-1, 1):
        b.add_bm(box(0.02, 0.07, 0.06, (0.255, s * 0.08, 0.27)), glow)
    b.add_bm(box(0.02, 0.18, 0.04, (0.255, 0, 0.14)), glow)
    return b.finish()


def planter():
    b = Builder("planter")
    w = _wood("planter_wood", "#9a6a3a")
    soil = mat("soil", hexc("#4a3020"))
    b.add_bm(box(1.0, 0.45, 0.4), w)
    b.add_bm(box(0.92, 0.38, 0.02, (0, 0, 0.36)), soil)
    leaf = leaf_mat("fern", 7)
    for k in range(5):
        b.add_bm(ico(0.13, 1, k, 0.2, (1, 1, 1.2), (-0.36 + k * 0.18, 0, 0.48)), leaf)
    return b.finish()


def crates():
    b = Builder("crates")
    w = _wood("crate_wood", "#b07a44")
    dark = mat("crate_dark", hexc("#6a4424"))
    for (x, y, z, s) in ((-0.3, 0, 0, 0.6), (0.35, 0.05, 0, 0.55), (0.0, 0.0, 0.6, 0.5)):
        b.add_bm(box(s, s, s, (x, y, z)), w)
        b.add_bm(box(s + 0.02, 0.05, 0.05, (x, y - s / 2, z + s * 0.45)), dark)
    return b.finish()


def anchor():
    b = Builder("anchor")
    iron = mat("rusty", image=speckle("rusty", [hexc("#4a4e58"), hexc("#3a3e48"), hexc("#8a5a3a"), hexc("#5a5e68")], 8, 9, [4, 3, 1, 2]))
    b.add_bm(box(0.1, 0.1, 1.5, (0, 0, 0.1)), iron)
    b.add_bm(box(0.1, 0.7, 0.08, (0, 0, 1.3)), iron)
    v, f = tube([Vector((0, -0.6, 0.55)), Vector((0, -0.45, 0.15)), Vector((0, 0, 0.05)), Vector((0, 0.45, 0.15)), Vector((0, 0.6, 0.55))], [0.06] * 5, 6)
    b.add(v, f, iron)
    for s in (-1, 1):
        b.add_bm(cylinder(0.1, 0.0, 0.25, 4, (0, s * 0.6, 0.5)), iron)
    v, f = tube([Vector((0, 0, 1.6)) + Vector((0, math.cos(a) * 0.12, math.sin(a) * 0.12)) for a in [i / 8 * math.tau for i in range(9)]], [0.03] * 9, 5)
    b.add(v, f, iron)
    return b.finish()


def mailbox():
    b = Builder("mailbox")
    post = _wood("post")
    red = mat("mail_red", hexc("#d83a3a"))
    flag = mat("mail_flag", hexc("#f4d040"))
    b.add_bm(box(0.1, 0.1, 1.0), post)
    body = cylinder(0.16, 0.16, 0.5, 10)
    bmesh.ops.rotate(body, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=body.verts)
    bmesh.ops.translate(body, vec=(-0.25, 0, 1.08), verts=body.verts)
    b.add_bm(body, red)
    b.add_bm(box(0.04, 0.02, 0.25, (0.0, 0.18, 1.05)), flag)
    return b.finish()


def sale_sign():
    b = Builder("sale_sign")
    post = _wood("post")
    board = mat("sign_board", image=pixel_image("sale_board", 16, 8, lambda x, y: hexc("#c83a3a") if y in (0, 7) or x in (0, 15)
                                                 else hexc("#3a2a20") if (2 <= y <= 5 and x % 3 != 0 and 2 <= x <= 13) else hexc("#f4ecd8")))
    b.add_bm(box(0.08, 0.08, 1.3), post)
    v, f = flat_poly([(-0.5, 0.0), (0.5, 0.0), (0.5, 0.5), (-0.5, 0.5)], 0.05, "y")
    v = [(x, y - 0.06, z + 0.75) for (x, y, z) in v]
    b.add(v, f, board, uv_fn=lambda co, n: (co.x + 0.5, (co.z - 0.75) * 2.0))
    return b.finish()


def noticeboard():
    """The fleet ledger board at the head of your jetty: a roofed board with notes pinned up."""
    b = Builder("noticeboard")
    post = _wood("post")
    board = mat("ledger_board", image=bark("ledger_board", hexc("#6a4a2a")))
    roof = mat("roof_blue", hexc("#3a5a8a"))
    rng = random.Random(4)
    for x in (-0.65, 0.65):
        b.add_bm(box(0.1, 0.1, 2.1, (x, 0, 0)), post)
    b.add_bm(box(1.4, 0.08, 0.95, (0, 0, 0.85)), board)
    v = [(-0.85, -0.35, 2.05), (0.85, -0.35, 2.05), (0.85, 0.3, 2.05), (-0.85, 0.3, 2.05), (0, -0.4, 2.35), (0, 0.35, 2.35)]
    b.add([(x, y, z) for (x, y, z) in v], [[0, 1, 4], [3, 5, 2], [0, 4, 5, 3], [1, 2, 5, 4]], roof)
    for i in range(7):
        c = hexc(rng.choice(["#f4ecd8", "#f0e0a8", "#e8f0f4", "#f8d8c8"]))
        w = rng.uniform(0.2, 0.32)
        h = rng.uniform(0.22, 0.34)
        x = -0.5 + (i % 4) * 0.33 + rng.uniform(-0.04, 0.04)
        z = 0.95 + (i // 4) * 0.4 + rng.uniform(-0.04, 0.04)
        b.add_bm(box(w, 0.02, h, (x, -0.05, z)), mat("note_%d" % i, c))
        b.add_bm(ico(0.02, 0, i, 0, (1, 1, 1), (x, -0.07, z + h - 0.03)), mat("pin_red", hexc("#d83a3a")))
    # a lantern on the side
    b.add_bm(box(0.14, 0.14, 0.2, (0.78, -0.12, 1.55)), mat("lamp_glass", hexc("#ffe8a0"), emit=hexc("#ffd870"), emit_strength=3.0))
    return b.finish()


def bollard():
    b = Builder("bollard")
    iron = mat("iron", hexc("#2a2c32"), rough=0.5)
    rope = mat("rope", image=speckle("rope", [hexc("#c8a868"), hexc("#a8884a"), hexc("#d8bc80")], 8, 5))
    b.add_bm(cylinder(0.14, 0.12, 0.45, 8), iron)
    b.add_bm(cylinder(0.18, 0.18, 0.06, 8, (0, 0, 0.45)), iron)
    v, f = tube([Vector((0.0, 0.0, 0.25)) + Vector((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.02 * i)) for i, a in enumerate([k / 6 * math.tau for k in range(13)])],
                [0.035] * 13, 5)
    b.add(v, f, rope)
    return b.finish()


OUTDOOR = {"noticeboard": noticeboard, "bollard": bollard, "bench": bench, "lamppost": lamppost, "well": well, "birdbath": birdbath, "gnome": gnome, "umbrella": umbrella,
           "stump": stump, "scarecrow": scarecrow, "hay_bale": hay_bale, "pumpkin_lantern": pumpkin_lantern, "planter": planter,
           "crates": crates, "anchor": anchor, "mailbox": mailbox, "sale_sign": sale_sign}

GROUPS = {"plants": PLANTS, "critters": CRITTERS, "sea": SEA, "outdoor": OUTDOOR}


# --- exporting and showing ---------------------------------------------------------------------

def export_glb(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    stack = [ob]
    while stack:
        o = stack.pop()
        o.select_set(True)
        stack += list(o.children)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
                              export_image_format="AUTO", export_animations=False)


def showcase(groups=None, spacing=8.0):
    """Lay every model out in rows in the live Blender (one row per group)."""
    col = target_collection()
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    y = 0.0
    for g in (groups or GROUPS):
        x = 0.0
        for name, fn in GROUPS[g].items():
            ob = fn()
            ob.location = (x, y, 0)
            gap = spacing if g == "plants" else spacing * 0.5
            x += gap
        y -= spacing * 1.4
    return col
