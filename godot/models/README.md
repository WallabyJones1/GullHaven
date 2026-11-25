# 3D models

Everything in here is built in Blender from code, by `tools/blender/gull_models.py` (plants,
critters, sea monsters, garden things, the ledger board) and `tools/blender/gull_fish.py`
(every fish in the catalogue, from its `look` in `data/catalog*.json`). They're low-poly with
little pixel-art textures (16 texels a metre, nearest filtered) so they sit in the HD-2D world
beside the sprite characters.

| Folder      | What                                                | Used by                     |
|-------------|-----------------------------------------------------|-----------------------------|
| `plants/`   | trees, bushes, ferns, flowers, reeds, rocks, boulders | world.gd (MultiMeshes), plots |
| `critters/` | gull, crab, butterfly, dolphin, whale tail           | ambient.gd                  |
| `sea/`      | serpent head and humps, kraken tentacle, chests      | monsters.gd, treasure.gd    |
| `outdoor/`  | garden things, mailbox, sale sign, ledger board, bollard | plots.gd, empire.gd     |
| `fish/`     | 217 fish, crabs, lobsters, squid, rays, seahorses     | fishing.gd, ambient.gd, player.gd |

## Remaking them

    pip install bpy==5.1.2            # Blender as a Python module (Python 3.13)
    python tools/blender/export_models.py                 # everything
    python tools/blender/export_models.py fish --only coral_trout,octopus --preview /tmp/fish.png

Or in Blender itself: run `gull_models.py` (and `gull_fish.py`) from the Text Editor, then
`showcase()` lays every model out in a "Gullhaven Models" collection.

## Conventions

- 1 Blender unit = 1 metre; Z up in Blender (Y up in Godot).
- Origin at the base (the ground), or the middle of the body for fish (1 m nose to tail;
  the game scales them to each fish's size).
- Fish, gulls, gnomes and pumpkins face +X; things with a front (benches, chests, signs)
  face Blender's -Y, which is toward the camera in Godot.
- Wings are separate child objects named `Wing.L` / `Wing.R` (`Wing_L` / `Wing_R` in Godot),
  so the game can flap them.
