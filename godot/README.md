# Gullhaven HD-2D (Godot 4.6)

The desktop rebuild of Gullhaven: pixel-art characters in a lit 3D harbour, with
tilt-shift focus, bloom and a day-night cycle. The web game on `main` is untouched.
This is **Phase 0**: one harbour, one fisher, and the cast, bite and fight loop, built so
it can grow into the multiplayer, Steam-bound game in the plan.

## Opening it

1. In GitHub Desktop, fetch, switch to the **`hd2d`** branch, and pull.
2. In Godot 4.6, choose **Import**, browse to the repo's `godot/` folder and pick
   `project.godot`. The first open imports the art, which takes a few seconds.
3. Press **Play** (F5).

## Controls

| Action                    | Keyboard / mouse            | Gamepad            |
|---------------------------|-----------------------------|--------------------|
| Walk                      | WASD or arrow keys          | Left stick         |
| Cast (hold, release)      | E, Space or left click      | A                  |
| Strike on the "!"         | E, Space or left click      | A                  |
| Reel in (hold)            | E, Space or left click      | A                  |
| Steer against a run       | A/D or left/right           | Left stick         |
| Reel in early / cancel    | Q or Esc                    | B                  |
| Skip an hour              | T                           |                    |
| Quality high/low          | F2                          |                    |
| Hide the HUD (photo mode) | P                           |                    |

## How the fishing works

- **Cast:** hold to fill the bar and release near the top for a long cast. Casts that
  would land on the dock, the boat or the beach are shortened to the nearest open water.
- **Shadows:** every shadow in the water is a real fish, rolled for the time of day. Big
  shadow, big fish.
- **Bite:** a fish nibbles a few times (the bobber dips), then bites. You have 0.9 s
  from the "!" to strike. Strike early and you spook it.
- **Fight:** hold to reel. Tension rises while you reel and faster when the fish pulls;
  the line snaps at the top. Let go and the fish takes line; if the Reel bar empties, it
  escapes. Runs are telegraphed; hold the opposite direction to steer against them.
  Dives can't be steered, so ease off.
- **Catch tiers:** keep tension under the first mark for a **Perfect** catch (+50%
  Shells), under the second for **Great** (+20%).

The save lives in Godot's user folder (`user://gullhaven_save.json`).

## Layout

```
godot/
  project.godot
  scenes/main.tscn        the only scene; everything is built in code
  scripts/
    main.gd               lighting, post-processing, wiring
    harbour.gd            the diorama and model slots
    player.gd             the fisher
    fishing.gd            cast, bite, fight, catch
    fish_school.gd        fish shadows
    day_night.gd          time, sun, moon, lamps
    camera_rig.gd         follow camera and tilt-shift focus
    hud.gd                on-screen layer
    save_game.gd          JSON save
    input_setup.gd        key, mouse and pad bindings
  shaders/water.gdshader  the sea
  art/                    textures, sprites, fish, cats, fonts (exported from the web game)
  data/fish.json          the catalogue (exported from the web game)
  models/                 drop Blender .glb files here (see models/README.md)
```

`art/` and `data/` come from the web game's code-drawn art. To refresh them after
changing the web game, run `python3 tools/export_godot_assets.py` from the repo root
(it needs Python's `playwright`).
