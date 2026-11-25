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

Every prompt shows the real key or button as a keycap, and switches to pad buttons (Xbox,
PlayStation or Switch names) the moment you touch a controller. A strip along the bottom
lists what you can do right now. Keyboard keys can be changed in the game menu, under
Controls (saved per computer, in `user://settings.cfg`).

| Action                                  | Keyboard / mouse                 | Gamepad              |
|-----------------------------------------|----------------------------------|----------------------|
| Walk (relative to the camera)           | WASD or arrow keys               | Left stick           |
| Turn the camera                         | Q / E, or drag with right mouse  | Bumpers, right stick |
| Zoom                                    | Mouse wheel, - / =               | Right stick up/down  |
| Cast (hold, release), strike, reel      | Space, F or left click           | A                    |
| Talk, shop, pet a cat, dig, haul a pot  | Space or F (while facing them)   | A                    |
| Go inside (facing a door)               | Space or F; walk out to leave    | A                    |
| Board your boat / steer it              | Space by the boat / move keys    | A / left stick       |
| Step ashore (beside a dock or beach)    | Esc                              | B                    |
| Use your kit (pots, net, trolling, dive)| G                                | X                    |
| Arrange furniture (in your hut)         | B; Q/E choose, R turn, Space put | X                    |
| Steer against a run                     | A/D or left/right                | Left stick           |
| Change bait                             | R                                | Y                    |
| Bag                                     | I                                | D-pad right          |
| Logbook (Q / E turn the page)           | L or Tab                         | D-pad left           |
| Journal (story, mystery, quests)        | J                                | D-pad up, L3         |
| World map                               | M                                | Back / View          |
| Game menu                               | Esc                              | Start / Menu         |
| Reel in early / back / close a menu     | Esc or Backspace                 | B                    |
| Skip an hour                            | T                                |                      |
| Quality high/low                        | F2                               |                      |
| Hide the HUD (photo mode)               | P                                |                      |

The game menu (Esc or Start) has Fisher (your level, skills and stats), Bag, Logbook,
Journal, Map, Controls, Settings, and Save and quit. Screens opened from it come back to it.

## How it plays

- **An opening and a main menu.** The first time the game starts, a short flight round
  Gullhaven at dawn sets up the mystery (any key skips it; the menu can play it again).
  The main menu sits over the harbour with Continue (showing where your story's got to),
  New game, Settings, Controls, Watch the opening, Credits and Quit.
- **Make your fisher.** A new game opens the character creator: skin, hair style and
  colour, beard, glasses, hat, shirt and pattern, jacket, trousers or a dress, shoes, with
  a live preview walking round. Odette at **Threads & Tides** (behind the tavern) changes
  any of it later and sells more: overalls, aprons, dresses, check and flowery cloth,
  bucket, straw, ranger's and captain's hats, a bandana, and dyes for brighter colours.
- **A story to follow.** Gran's letter leaves you her hut and her rod, and Old Marlo on
  the docks teaches you to fish (casting, bait, the Logbook, her old crab pot) before
  telling you about the lighthouse. Then five chapters follow the Gull's Eye round the
  whole coast: the keeper's marks, the bridge, Willowford, a boat, Kelpwood's lanterns, the
  ranger's permit, Silverjaw, the keeper's chest, Ember Isle, and finally the Warden.
  The next step sits in the top-right corner with how far away it is and which way, a
  beam of light marks the spot, and a gold pin marks it on the map. Marlo sends notes by
  gull as chapters open and as each new way of fishing unlocks. Conversations open a
  dialogue box with the speaker's portrait.
- **Fisher levels.** Everything you land earns XP: more for harder and bigger fish, clean
  fights and anything new. Requests, the mystery and mini-game prizes count too. Each of
  the 30 levels brings a skill point for six skills (steady hands, strong arms, patience,
  keen eye, haggler, sea legs; spend them under Fisher in the game menu), and better rods,
  reels and lines need higher levels.
- **Difficulty.** Every fish fights at a difficulty from 1 (easy) to 5 (fearsome), shown in
  the Logbook and on the catch card. Difficulty 4 and 5 fish, and every legend, fight on
  the **reel bar**: hold to lift your green zone, let go to drop it, and keep the fish
  inside until it tires.
- **Four more ways to fish** (the Kit tab at Hale's Tackle, as your level allows; G or
  pad X to use):
  - **Crab pots** (level 2): drop one in the water, come back a few town hours later and
    haul it up. Twelve crabs, lobsters and crayfish only turn up in pots. Crab bait helps.
  - **Cast net** (level 4): throw it, pull when it's sunk to the gold mark, and land a few
    small fish at once plus a tin of live bait.
  - **Trolling** (level 5): let lines out behind your boat and keep moving over open water;
    the fast fish strike out of nowhere.
  - **Spearfishing** (level 6): stop your boat over clear water (reef, kelp, shallows, a
    wreck, the lagoon, seagrass) and dive. A side-on breath-hold dive: swim, aim, fire,
    mind the jellyfish, and surface with up to five fish on your stringer.
- **Music for every place.** A title theme, Gullhaven, Willowford, the islands,
  Mirrorlake, sailing, the keeper's mystery, a tavern jig, tough fights, diving and your
  hut, alongside the web game's day, night and storm loops.
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
- **A big catalogue.** About 200 fish and 16 legends across the eleven fishing grounds,
  plus shells, coral, pearls, sea glass, fossils from the rock pools, treasure, and finds
  that only wash up on particular islands.
- **The mystery of the Gull's Eye.** Fifty years ago the lighthouse keeper took the great
  lens out of the lamp, hid it, and vanished. His marks (a gull with one wing, carved in
  stone) lead from the lighthouse through eight puzzles: a stone dug out at low tide, the
  mill's bells, Gull Rock's standing stones, Kelpwood's lanterns, a pike that never takes
  a hook twice, the keeper's chest, and a cave on Ember Isle. Twelve bottle letters drift
  about the sea with more of the story.
- **Journal (J).** The story and the mystery so far, quests and mini-game records, the
  letters you've found, and how much of the sea you've collected.
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

## Harbour Life (this branch)

Things to do on land, a second story, and a shared online town. The fishing game is all
still here and plays the same; none of this gets in its way.

- **Gran's garden.** Farmer Bramble, beside your hut, gives you Gran's hoe and watering can.
  Face a bed: dig it over, plant seeds, water them (rain does it for you). Turnips take six
  minutes of watered growing, pumpkins half an hour. Six crops; Bramble sells seeds and
  digs more beds (up to twelve). Compost makes things grow half again as fast.
- **Foraging.** Any tree gives wood once a town day (you need an axe), bramble bushes give
  blackberries, ferns herbs, flowers wildflowers, the little rocks stones, and mushrooms pop
  up in the woods. Wood counts as driftwood for the hut, the bridge and furniture.
- **Mining.** Six quarries round the coast (south of the hut, the Willowford hills, the
  highlands, Gull Rock, Wrecker's Cove and Ember Isle) with stone, coal, copper, iron,
  silver, gold, quartz, amethyst and ember crystal. Better pickaxes crack harder veins.
  Rocks come back the next town day.
- **Hunting.** With a bow, face a rabbit, pheasant, duck, wild boar or red deer and press
  Space to draw; press it again when the gold line is in the green. Run at them and they
  bolt. Meat, hides, feathers and antlers.
- **Crafting and cooking.** Gran's workbench in the yard (fix it first) makes tools, smelts
  ore, twists wheat into twine (and twine into rope), and makes fifteen new pieces of hut
  furniture: a rocking chair, hide rug, antler mount, stone hearth, crystal lamp and more.
  The cook pot makes stews, pies, tarts and a roast dinner.
- **Buying and selling.** Bramble (by the hut) buys crops, forage and cooking; Delve the
  smith (Willowford) buys ore, bars and gems; Ash the hunter (Willowford) buys game. Each
  sells tools.
- **Five land skills** (farming, foraging, mining, hunting, crafting) level up as you go,
  and everything earns XP for your level too. Your Field Notes count the different land
  finds you've gathered.
- **A second story: the Tideday Fair.** Six chapters with Bramble, Delve and Ash to bring
  back the spring fair Gran used to run. Its next step shows in green under the main story,
  with a green beam of light. It opens the map without fishing: Ash vouches for you with
  the ranger, and the harbourmaster takes 12 kinds of land finds instead of 30 fish.
- **Your hut.** Tess's new Decorate tab changes your walls and floors (seven walls, five
  floors; bought once, swapped back free).
- **Townsfolk requests** no longer sit in the corner of the screen. They're listed in the
  Journal (Quests), and Settings can put them back in the corner.
- **Your own plot on Driftwood Lane** (west of Gullhaven, twelve plots). Walk to a for-sale
  sign and it's yours: a cosy cottage, a picket fence and a mailbox. The mailbox opens the
  plot planner: walls, paint, roof, door, trim, chimney and window boxes; grow to a family
  house or a grand villa (Shells, wood and stone; more room inside); fences and hedges;
  and the Garden Centre (veg patches that grow crops like Gran's garden, trees, bushes,
  flowers, a bench, lamps, a well, a gnome and more). Walk where a thing goes and press
  Space. Inside, the Home Catalogue does wallpaper, floors and furniture in every colour.
- **Sea monsters.** Out in a boat on the reef, kelp, wrecks, open blue or the deep, a sea
  serpent, a kraken or (out in the deep) the leviathan sometimes surfaces, more at night
  and in storms. Space throws a harpoon (Delve sells them; three from Gran's bench): hit
  when the gold line's in the red. Drive it off for Shells, scales, ink or teeth, and often
  a treasure map. Let it reach you and it rams the boat. The new Corsair Sloop (28,000
  Shells, Gullhaven boatyard) is the fastest boat and harpoons hit harder from it.
- **Treasure hunts.** Pip, on the beach by Gran's hut, finds a map in a bottle every day
  (the same map for everyone that day); monsters leave maps too. A red ring on the world
  map, then warmer, warmer, hot in the corner. Dig on the X with your hoe for Shells,
  gems, gold, garden things or furniture.
- **Play online.** Main menu, Play online with friends: run the server in `mp-server/`
  (`npm install`, `npm start`) and join it, or open the hosted game (Railway serves the web
  build and the town together, and joins it for you). You see each other (in your boats
  too), Enter opens the chat, 1-5 are emotes, plots and homes are shared and you can walk
  into anyone's house; the game menu's Online page visits huts. Your own save comes with
  you. Single player is unchanged.
- **Phones and tablets.** On a touch screen you get a thumbstick and buttons (action, back,
  tool, bait, bag, map, journal, build, chat, emotes); drag to turn the camera, pinch to
  zoom. Settings, Touch controls switches them on or off.

Art for all of it: `python3 tools/godot_land_art.py` (icons, crops, rocks, animals, the
yard and the furniture).

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
    menus.gd              the main menu, the game menu, settings and key changes
    opening.gd            the opening flight and the main menu's drifting view
    story.gd              the main story: chapters, Old Marlo's notes, the corner tracker, the beacon
    dialogue.gd           the conversation box (portraits, typed text, choices)
    progress.gd           fisher level, XP, skills and what each level unlocks
    kit.gd                crab pots, the cast net and trolling
    spearfishing.gd       the side-on spearfishing dive
    bag.gd                the Bag
    character.gd          builds your character's sprite from the layered wardrobe art
    wardrobe.gd           the character creator and Threads & Tides
    music.gd              picks the music for where you are and what you're doing
    input_glyphs.gd       keycaps and pad button names in prompts
    player.gd             the fisher and footsteps
    fishing.gd            cast, bite, fight styles, the reel bar, catch
    fish_school.gd        fish shadows and feeding frenzies
    town.gd               townsfolk, requests, cats, beachcombing
    shop.gd               the tackle and bait shops
    logbook.gd            the Logbook
    day_night.gd          sun, moon, lamps, weather, tide
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
python3 tools/godot_catalog_extra.py  # new fish, legends, pot catches and finds, with their art
python3 tools/godot_wardrobe.py       # the layered character art for the creator and outfitter
python3 tools/godot_music.py          # the new music (needs scipy and ffmpeg)
python3 tools/godot_branding.py       # the logo, icon, boot splash and store art in store/
```

## Sharing the beta

`godot/SHARING.md` has the step-by-step guide. In short:

- Push a tag starting with `beta-` (or publish a release on GitHub targeting `hd2d`), and
  `.github/workflows/gullhaven-beta.yml` builds Windows, macOS and Linux zips on GitHub's
  computers and attaches them to a pre-release, ready to share.
- Every push to `hd2d` also builds all three as a download on the Actions tab, without
  publishing anything.
- **itch.io:** make the project page once (the cover and description are in `store/`),
  then either upload the zips by hand or add a `BUTLER_API_KEY` secret and an `ITCH_GAME`
  variable to the repo, and every beta tag uploads itself.
- **Steam:** needs a Steamworks account, the Steam Direct fee and an App ID first. After
  that, three repo settings switch on automatic uploads (Steam Playtest suits a beta).

The builds aren't signed yet, so Windows shows a SmartScreen warning and macOS needs
**Open Anyway** in Privacy & Security; `BETA.md` walks testers through it.
