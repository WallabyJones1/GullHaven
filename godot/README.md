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
| Board your boat / steer it              | Space by the boat / move keys    | A / left stick       |
| Step ashore (beside a dock or beach)    | Esc                              | B                    |
| Arrange furniture (in your hut)         | B; Q/E choose, R turn, Space put | X                    |
| Steer against a run                     | A/D or left/right                | Left stick           |
| Change bait                             | R                                | Y                    |
| Logbook (Q / E turn the page)           | L or Tab                         | Back                 |
| Journal (mystery, quests, collection)   | J                                | Left stick click     |
| World map                               | M                                | Start                |
| Reel in early / close a menu            | Esc                              | B                    |
| Pause menu (settings, controls, quit)   | Esc when nothing else needs it   | B                    |
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
- **Boats.** Buy one at the Boatyard in Gullhaven (Rowboat, Dinghy, Skiff) or at Lantern
  Boatworks out east (Trawler, Deep-sea Cutter). Walk up to her at the dock, press Space
  to board, steer with the move keys (she turns toward the way you push), and fish off
  the side. Esc beside a dock or a beach steps you ashore, and she stays where you left
  her. Each hull reaches rougher water: the Rowboat keeps to the bay, the river and
  Tideglass Cay; the Dinghy reaches Mossbank and Kelpwood; the Skiff, Lantern Key and the
  Atoll; the Trawler gets through the breakers to Wrecker's Cove; only the Cutter goes out
  to the Deep. Kelpwood hides in a fog bank you can only find with a deck lamp. Paint the
  hull any of ten colours.
- **Your hut.** Tess the carpenter upgrades it from a beach shack to a snug cabin, a
  fisher's cottage and finally a harbour lodge, each bigger inside and with a
  housewarming gift. Upgrades and wooden furniture take materials: gather driftwood piles
  on sandy shores, dig some up while beachcombing, and fish up junk (tangled line gives
  rope; tins, tyres, trolleys and bikes give scrap metal), or buy them from Tess and the
  salvager at Wrecker's Cove. Fern's Home Goods on Mossbank sells rugs, paintings,
  plants, clocks, a fish tank (stocked with your own catches) and more; the salvager has
  ship's wheels, anchors, nets and a telescope. Inside your hut press B to arrange it all:
  a ghost shows where each piece goes, wall pieces snap to the walls.
- **Catch of the day.** The fishmongers pay double for three fish each day. Ask Mags in
  Gullhaven which.
- **Opening up the map.** Three things are locked at first:
  - **The estuary bridge** is washed out, so Willowford is a row up the river until Tess
    the carpenter mends it (her Projects tab: timber, rope and Shells).
  - **The ranger gate** on the north road keeps you out of the highlands and Mirrorlake.
    Ranger Hollis in Willowford sells a permit once you've caught four kinds of estuary
    fish.
  - **Ember Isle** is a live volcano: Harbourmaster Quill only lets seasoned fishers land
    (30 kinds of fish in your Logbook and a Skiff or bigger).
  The harbourmaster's notice board lists what's still locked.
- **The map** (M) fills in as you explore, marks the towns you've found, your boat, your
  hut and what's locked. Climb the lighthouse to see the whole bay at once.
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
- **Surprises.** Junk (yes, the rubber duck), treasure and letters in bottles, and rare
  colours: golden (1 in 400) and albino (1 in 250) any time, moonlit under a full moon,
  storm-touched in storms, ghostly in fog, and rainbow after a storm. Legends for those
  with the right rod and conditions. Cast right onto a fish's nose and it bites at once.
- **A big catalogue.** About 190 fish and 16 legends across the eleven fishing grounds,
  plus shells, coral, pearls, sea glass, fossils from the rock pools, treasure, and finds
  that only wash up on particular islands.
- **The mystery of the Gull's Eye.** Fifty years ago the lighthouse keeper took the great
  lens out of the lamp, hid it, and vanished. His marks (a gull with one wing, carved in
  stone) lead from the lighthouse through eight puzzles: a stone dug out at low tide, the
  mill's bells, Gull Rock's standing stones, Kelpwood's lanterns, a pike that never takes
  a hook twice, the keeper's chest, and a cave on Ember Isle. Twelve bottle letters drift
  about the sea with more of the story.
- **Journal (J).** The mystery so far, quests and mini-game records, the letters you've
  found, and how much of the sea you've collected.
- **Side quests and games.** Granny Wick's lost cats, the mill sails, bottle post; stone
  skipping on the beach, the bay race round six buoys, darts at the Gull & Anchor.
- **Cats.** Feed a town cat fish from your bait tin (pilchards, live yakka, squid or prawns)
  to win its trust; a tamed cat becomes your companion, follows you, rides in your boat
  and sniffs out buried finds.
- **A living coast.** Gulls that land and scatter and dive on frenzies, crabs, butterflies,
  fireflies, jumping fish, dolphins, whales, chimney smoke, boats on the bay, townsfolk
  strolling about, and plants that sway in the wind.
- **Feeding frenzies.** Every few minutes the water boils somewhere. Bites come fast and
  rare fish are three times as likely, for one minute.
- **Townsfolk.** Every town has its people: shopkeepers behind their counters, and
  locals who want a fish from their own patch of water (Old Marlo on the dock, Pip on
  the beach by your hut, Juniper in town, Ivy in Willowford, Old Sable at the lake, and one
  on each island). Land one that fits and it's kept for them; bring it over for a reward.
  Between requests they tell you what's biting nearby right now.
- **Beachcombing.** Sparkles on sandy shores are shells, sea glass and treasure to dig
  up; on rocky shores they're rock pools with fossils and coins. Low tide uncovers more.
- **Logbook.** A page for each of the eleven fishing grounds plus one for finds, with
  silhouettes for ones you haven't caught, a hint for each, your best sizes, and a
  "Biting now" marker.

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
    boats.gd              boats: buying, boarding, steering, sea limits, fog, wake
    boatyard.gd           the Boatyard and Lantern Boatworks menus
    furniture.gd          furniture, materials and hut upgrade data
    trade.gd              the carpenter, Home Goods and salvager menus
    hut_build.gd          arranging furniture in your hut
    quests.gd             the bridge, the ranger's permit and the Ember Isle permit
    map_screen.gd         the world map with fog of war
    mystery.gd            the Gull's Eye: puzzles, the keeper's marks, bottle letters
    sidequests.gd         Granny Wick's cats, the mill, bottle post
    minigames.gd          stone skipping, the bay race, darts
    companion.gd          taming cats and your companion
    journal.gd            the Journal
    ambient.gd            gulls, crabs, butterflies, fireflies, dolphins, whales, smoke, boats
    menus.gd              the title screen, pause menu and settings
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
  data/catalog_extra.json the Godot build's own new fish, legends and finds
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
are drawn by four more scripts (they need Python with `pillow` and `numpy`):

```
python3 tools/godot_art.py      # art/chars2, art/cats2, art/plants, art/fish2
python3 tools/godot_world.py    # world/ and the extra terrain textures
python3 tools/godot_interior_art.py   # floors, walls, decor and critters
python3 tools/godot_catalog_extra.py  # new fish, legends and finds, with their art
```

## Sharing the beta

`export_presets.cfg` has Windows, macOS and Linux exports set up, and
`.github/workflows/gullhaven-beta.yml` builds all three on GitHub's computers, so nobody
has to export by hand:

1. In GitHub Desktop, make sure everything's pushed to `hd2d`.
2. On github.com, open the repo's **Releases**, click **Draft a new release**, choose
   a new tag such as `beta-0.4`, set the target to `hd2d`, tick **Set as a pre-release**,
   and publish. (Pushing a tag starting with `beta-` does the same.)
3. About ten minutes later the release has three zips attached, one per system, each
   with the tester guide (`BETA.md`). Send testers the release link.

You can also export from the Godot editor yourself: **Project > Export**, pick a preset,
**Export Project** (Godot will offer to download the export templates the first time).

For a public or semi-public beta, **itch.io** is the easiest home: make a new project,
upload the three zips (or use itch's `butler` tool), and set it to **Restricted** with
download keys, or **Draft**, so only people you invite can get it. Steam Playtest comes
later, once the game has a Steam page.

The builds aren't signed yet, so Windows shows a SmartScreen warning and macOS needs
**Open Anyway** in Privacy & Security; `BETA.md` walks testers through it. Signing and
notarizing (an Apple Developer account, a Windows code-signing certificate) can come
before a wider release.
