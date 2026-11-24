# Gullhaven HD-2D (Godot 4.6)

The desktop rebuild of Gullhaven: pixel-art characters in a lit 3D harbour, with
tilt-shift focus, bloom, weather and a day-night cycle. The web game on `main` is untouched.
It plays by the web game's own rules (time, tide, weather, moon, season, bait and the full
catalogue) and uses its own synthesized music and sound.

## Opening it

1. In GitHub Desktop, fetch, switch to the **`hd2d`** branch, and pull.
2. In Godot 4.6, choose **Import**, browse to the repo's `godot/` folder and pick
   `project.godot`. The first open imports the art, which takes a few seconds.
3. Press **Play** (F5).

## Controls

| Action                         | Keyboard / mouse            | Gamepad            |
|--------------------------------|-----------------------------|--------------------|
| Walk                           | WASD or arrow keys          | Left stick         |
| Cast (hold, release)           | E, Space or left click      | A                  |
| Strike on the "!" / reel (hold)| E, Space or left click      | A                  |
| Steer against a run            | A/D or left/right           | Left stick         |
| Talk, shop, pet a cat, dig     | E (while facing them)       | A                  |
| Change bait                    | R                           | Y                  |
| Logbook                        | L or Tab                    | Back               |
| Reel in early / close a menu   | Q or Esc                    | B                  |
| Skip an hour                   | T                           |                    |
| Quality high/low               | F2                          |                    |
| Hide the HUD (photo mode)      | P                           |                    |

## How it plays

- **Two fishing grounds.** The quay and dock fish the **Harbour**; the sand to the west
  fishes the **Sandy Shallows**, with its own fish (whiting, tailor, flathead, sharks).
- **The clock is shared with the web game.** One real second is one town minute. The
  tide turns every 6 town hours (you can watch the water climb the beach), the weather
  every 4 (calm, windy, rain, fog, storm), the moon each real week, and the season too.
  Many fish only bite at certain times, tides, weather or seasons.
- **Shadows.** Every shadow's size comes from what could really bite there right now.
  Big shadow, big fish.
- **Bait and gear.** Hale's Tackle on the quay sells rods (cast further, fish pull less,
  Graphite and up can land legends), reels (reel faster), lines (stronger) and bait at the
  web game's prices. Bait changes what bites: Luderick only take weed bait, calamari want
  a squid jig. Lures are kept unless the line snaps.
- **Fights with personality.** Runners run, jumpers jump (let go while they're in the
  air or the line snaps), sulkers dive, darters dart (squid ink!). Runs are telegraphed;
  hold the opposite direction to steer. Keep tension under the marks for **Perfect** or
  **Great** catches. Back-to-back catches build a **streak** for bonus Shells.
- **Surprises.** Junk (yes, the rubber duck), treasure and letters in bottles, golden
  (1 in 400) and albino (1 in 250) fish, and legends for those with the right rod and
  conditions.
- **Feeding frenzies.** Every few minutes the water boils somewhere. Bites come fast and
  rare fish are three times as likely, for one minute.
- **Townsfolk.** Old Marlo (dock), Pip (beach) and Juniper (lane) ask for fish. Land one
  that fits and it's kept for them; bring it over for a reward. Between requests they
  tell you what's biting right now.
- **Beachcombing.** Sparkles on the sand are shells, sea glass and treasure to dig up.
  Low tide uncovers more beach.
- **Logbook.** Every fish and find, with silhouettes for ones you haven't caught, a hint
  for each, your best sizes, and a "Biting now" marker.

The save lives in Godot's user folder (`user://gullhaven_save.json`).

## Layout

```
godot/
  project.godot
  scenes/main.tscn        the only scene; everything is built in code
  scripts/
    main.gd               lighting, post-processing, wiring
    sea.gd                the shared rules: clock, tide, weather, what bites
    harbour.gd            the diorama, tide level, zones and model slots
    player.gd             the fisher and footsteps
    fishing.gd            cast, bite, fight styles, catch
    fish_school.gd        fish shadows and feeding frenzies
    town.gd               townsfolk, requests, cats, beachcombing
    shop.gd               Hale's Tackle
    logbook.gd            the Logbook
    day_night.gd          sun, moon, lamps, weather, tide, music choice
    audio.gd              music, ambience and effects
    camera_rig.gd         follow camera and tilt-shift focus
    hud.gd, ui_kit.gd     on-screen layer and menu style
    save_game.gd          JSON save
    input_setup.gd        key, mouse and pad bindings
  shaders/water.gdshader  the sea (depth, foam, shadows, wind, rain rings)
  art/                    textures, sprites, catalogue art, cats, fonts (from the web game)
  audio/                  music, ambience and effects (rendered from the web game)
  data/catalog.json       the catalogue, bait and gear tables (from the web game)
  models/                 drop Blender .glb files here (see models/README.md)
```

`art/`, `data/` and `audio/` come from the web game's code-drawn art and synthesized
sound. To refresh them after changing the web game, run these from the repo root (they
need Python's `playwright`, and the audio one needs `ffmpeg`):

```
python3 tools/export_godot_assets.py
python3 tools/export_godot_audio.py
```
