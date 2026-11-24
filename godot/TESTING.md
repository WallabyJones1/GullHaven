# Testing Gullhaven

Every push to `hd2d` that touches `godot/` is played by a robot on GitHub before anyone
downloads it (`.github/workflows/gullhaven-beta.yml`, job **export**):

1. **Check every script with Godot** (`--check-only`). A parse error here would stop the
   game from starting at all.
2. **Smoke test**: `godot --headless --fixed-fps 60 -- --smoke` runs
   `scripts/smoke_test.gd`, which plays the game with nobody at the controls and checks
   that things actually work, by pressing the same inputs a player would.
3. **Export** Windows, macOS, Linux and the web, and zip them.
4. **Play the web build in a browser**: `.github/scripts/web_check.mjs` serves it and opens
   it in headless Chromium (software WebGL 2), once as a visitor (to the title menu) and
   once with `?ci-check`, which runs a short smoke test (new game, make a fisher, Gran's
   letter, look round the harbour). It prints the browser console and saves screenshots.
5. **Publish the site**: if the smoke test had no failures and the browser check passed,
   the web build goes to the `godot-web` branch (screenshots in `ci/`), which Railway
   serves at https://gullhaven-3d-production.up.railway.app.

The browser check runs at about 1 frame a second on GitHub's machines (no graphics card),
so it's a check that the game loads and plays, not of speed.

The run's log shows "N checks passed", then any `SMOKE CHECK FAIL` lines and engine errors
(with the line before each). Engine noise from running headless (no keyboard layout to ask)
is filtered out.

## What the smoke test covers

- **Menus:** the opening (and skipping it), the title page and every sub-page, starting a
  new game, the fisher creator, dialogue (including choices), the game menu and every
  screen in it, shops (every tab, buying), the outfitter.
- **Fishing:** landing fish of every kind, levelling up, crab pots (drop, check, haul),
  the cast net, trolling (strike and land), the speargun dive.
- **The story:** run from start to finish; summaries and journal.
- **Getting about** (these move the player with the move keys and check where they end up):
  - zooming with the wheel, a trackpad pinch and the keys;
  - the lighthouse: up the stairs to the gallery, round the gallery, back down;
  - walking up a 0.25 m step, and being stopped by a 1.2 m crate;
  - walking over the mended estuary bridge;
  - steering a rowboat out from a dock;
  - falling into deep water and swimming back to shore;
  - walking onto every dock and jetty from the shore;
  - going into every building, walking about inside, and coming back out onto the ground.

## Checking the map by hand

`tools/godot_reach.py godot` reads `world/world.json`, `height.bin` and `data.bin` and
works out which places you can walk or swim to from the spawn, and finds pits you could get
into but not out of. It found the docks at Kelpwood and Wrecker's Cove that didn't meet the
shore, and the Cove cottage that floated on the sea.

## Fixes this found (beta 0.5)

- Lighthouse stairs climbable; the keeper's desk no longer blocks their foot.
- Camera zoom: mouse wheel, trackpad pinch and two-finger scroll, - / =, right stick.
- The player walks up low ledges (up to 0.36 m: steps, kerbs, dock edges). Walls, crates
  and cliffs still block.
- Docks run on until they meet the shore; buildings out over the water stand on pilings
  with a boardwalk to their door.
- Rooms ignore the permit gates outside (rooms float above the map at the door's spot).
- Menus focus the first button (Godot 4.6 labels take focus only for a screen reader), so
  A / Enter works straight away.
- The atoll had no radius in the island data, which threw a script error.
