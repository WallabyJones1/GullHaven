# Gullhaven HD-2D (Godot 4.6)

The desktop rebuild of Gullhaven: pixel-art characters in a big lit 3D coast, with
tilt-shift focus, bloom, weather and a day-night cycle. The web game on `main` is untouched.
It plays by the web game's own rules (time, tide, weather, moon, season, bait and the full
catalogue) and uses its own synthesized music and sound.

## Opening it

1. In GitHub Desktop, fetch, switch to the **`hd2d`** branch, and pull.
2. In Godot 4.6, choose **Import**, browse to the repo's `godot/` folder and pick
   `project.godot`. The first open imports the art, which takes a few seconds.
3. Press **Play** (F5).

## Controls

| Action                                  | Keyboard / mouse                 | Gamepad              |
|-----------------------------------------|----------------------------------|----------------------|
| Walk (relative to the camera)           | WASD or arrow keys               | Left stick           |
| Turn the camera                         | Q / E, or drag with right mouse  | Bumpers, right stick |
| Zoom                                    | Mouse wheel, - / =               | Right stick up/down  |
| Cast (hold, release), strike, reel      | Space, F or left click           | A                    |
| Talk, shop, pet a cat, dig              | Space or F (while facing them)   | A                    |
| Go inside (facing a door)               | Space or F; walk out to leave    | A                    |
| Steer against a run                     | A/D or left/right                | Left stick           |
| Change bait                             | R                                | Y                    |
| Logbook                                 | L or Tab                         | Back                 |
| Reel in early / close a menu            | Esc                              | B                    |
| Skip an hour                            | T                                |                      |
| Quality high/low                        | F2                               |                      |
| Hide the HUD (photo mode)               | P                                |                      |

## How it plays

- **A big coast to explore** (1.3 by 1 km). Gullhaven sits on its harbour basin with a
  lighthouse on the breakwater; your fishing hut is on the beach just south of town. Walk
  the coast road north to the mangrove estuary and follow the river inland to the mill
  town of **Willowford**, then up past the falls to **Mirrorlake**, a clear mountain lake
  with its own lodge. Across the bay lie six islands with their own villages
  (Tideglass Cay, Mossbank, Kelpwood, Lantern Key, Wrecker's Cove and Ember Isle), plus
  Gull Rock and the Turquoise Atoll, with the open blue and the deep beyond.
- **Every kind of water.** Wherever you cast decides what bites: the **Harbour**, the
  **Sandy Shallows**, the **Mangrove Estuary**, **Seagrass Meadows**, the **Coral Reef**,
  the **Kelp Forest**, the **Wreck Graveyard**, the **Turquoise Lagoon**, the **Open Blue**,
  **The Deep** and freshwater **Mirrorlake**. The corner of the screen tells you where
  you are and which water you'd be fishing; each new place gets a banner the first time.
- **Every building has an inside.** Face a door and press Space. Shops, taverns, the
  boatyard, the carpenter, the bakery, the harbourmaster, the mill, the lighthouse, every
  cottage and your own hut are furnished rooms; shopkeepers wait behind their counters.
  The aquarium's tanks fill with the fish you've caught, your hut's trophy board shows
  your biggest catch, and you can sleep in your hut (or rent a bed at the inn or the
  lodge) to skip to dawn. The harbourmaster's notice board says what's locked and why.
- **Locked places.** The hills past the ranger gate need a permit from Ranger Hollis in
  Willowford, the bridge over the estuary is broken, and Ember Isle is off limits for now.
  (Boats, unlock quests and the islands' ferries are the next update.)
- **The clock is shared with the web game.** One real second is one town minute. The
  tide turns every 6 town hours (you can watch the water climb the beach), the weather
  every 4 (calm, windy, rain, fog, storm), the moon each real week, and the season too.
  Many fish only bite at certain times, tides, weather or seasons.
- **Shadows.** Every shadow's size comes from what could really bite there right now.
  Big shadow, big fish.
- **Bait and gear.** Hale's Tackle on the quay sells rods (cast further, fish pull less,
  Graphite and up can land legends), reels (reel faster), lines (stronger) and bait at the
  web game's prices. Willowford's general store and the island tea houses stock the baits
  their own waters call for. Bait changes what bites: Luderick only take weed bait, calamari want
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
- **Townsfolk.** Every town has its people: shopkeepers behind their counters, and
  locals who want a fish from their own patch of water (Old Marlo on the dock, Pip on
  the beach by your hut, Juniper in town, Ivy in Willowford, Old Sable at the lake, and one
  on each island). Land one that fits and it's kept for them; bring it over for a reward.
  Between requests they tell you what's biting nearby right now.
- **Beachcombing.** Sparkles on any sandy shore are shells, sea glass and treasure to dig
  up. Low tide uncovers more beach.
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
    world.gd              the big map: terrain streaming, collision, sea, lake, plants, queries
    town_builder.gd       towns, buildings, docks, lamps, folk, the hut and the bridge
    interiors.gd          doors and the furnished room inside every building
    player.gd             the fisher and footsteps
    fishing.gd            cast, bite, fight styles, catch
    fish_school.gd        fish shadows and feeding frenzies
    town.gd               townsfolk, requests, cats, beachcombing
    shop.gd               the tackle and bait shops
    logbook.gd            the Logbook
    day_night.gd          sun, moon, lamps, weather, tide, music choice
    audio.gd              music, ambience and effects
    camera_rig.gd         follow camera and tilt-shift focus
    hud.gd, ui_kit.gd     on-screen layer and menu style
    save_game.gd          JSON save
    input_setup.gd        key, mouse and pad bindings
  shaders/                the sea (depth, foam, shadows, wind, rain rings), terrain, waterfall
  world/                  the generated map: height.bin, data.bin, world.json, map.png
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

The pixel art for characters, cats, plants, fish and interiors, and the world map itself,
are drawn by three more scripts (they need Python with `pillow` and `numpy`):

```
python3 tools/godot_art.py      # art/chars2, art/cats2, art/plants, art/fish2
python3 tools/godot_world.py    # world/ and the extra terrain textures
python3 tools/godot_interior_art.py   # floors, walls and decor for the interiors
```
