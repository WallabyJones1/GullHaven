"""Export every Gullhaven model to godot/models/<group>/<name>.glb (headless Blender via bpy).

    python tools/blender/export_models.py [group ...] [--only name,name] [--preview out.png]

With --preview it also renders a contact sheet of what it exported (Cycles, CPU).
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gull_models as G  # noqa: E402

try:
    import gull_fish as F  # noqa: E402
    G.GROUPS["fish"] = F.FISH
except ImportError:
    F = None

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "models"))


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def preview(objs, path, cols=8, cell=360):
    cols = min(cols, len(objs))
    """Line the exported models up and render them, each scaled into a cell."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    rows = (len(objs) + cols - 1) // cols
    scene.render.resolution_x = cols * cell
    scene.render.resolution_y = rows * cell
    scene.render.film_transparent = False
    for i, ob in enumerate(objs):
        dims = max(ob.dimensions) or 1.0
        for c in ob.children_recursive:
            dims = max(dims, max(c.dimensions))
        s = 1.6 / dims
        ob.scale = (s, s, s)
        ob.location = ((i % cols) * 2.0, -(i // cols) * 3.6, 0)
        ob.rotation_euler = (0, 0, math.radians(-30))
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = cols * 2.1
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cx = (cols - 1) * 1.0
    cy = -(rows - 1) * 1.8
    d = 40.0
    cam.rotation_euler = (math.radians(60), 0, 0)
    cam.location = (cx, cy - d * math.sin(math.radians(60)) - 0.4, d * math.cos(math.radians(60)) + 0.6)
    scene.camera = cam
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.5
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(40), math.radians(15), math.radians(-30))
    scene.collection.objects.link(so)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.32, 0.4, 0.5, 1)
    bg.inputs[1].default_value = 0.9
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[1:]
    only = None
    prev = None
    if "--only" in args:
        i = args.index("--only")
        only = set(args[i + 1].split(","))
        del args[i:i + 2]
    if "--preview" in args:
        i = args.index("--preview")
        prev = args[i + 1]
        del args[i:i + 2]
    groups = args or list(G.GROUPS)
    clear()
    made = []
    for g in groups:
        out = os.path.join(ROOT, g)
        os.makedirs(out, exist_ok=True)
        for name, fn in G.GROUPS[g].items():
            if only and name not in only:
                continue
            ob = fn()
            G.export_glb(ob, os.path.join(out, name + ".glb"))
            made.append(ob)
            if not prev:
                for c in list(ob.children_recursive):
                    bpy.data.objects.remove(c, do_unlink=True)
                bpy.data.objects.remove(ob, do_unlink=True)
            print("exported %s/%s" % (g, name))
    if prev:
        preview(made, prev)
    print("done: %d models" % len(made))


main()
