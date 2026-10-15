> Historical notes from the supplied version. The current free RPG update supersedes the token, wallet and capsule-machine decisions below. See UPDATE.md and README.md for current behavior.

# Gullhaven build notes (for future me after context compaction / container loss)

Source of truth: /home/claude/gullhaven/src (template.html + js/m*.js, concatenated in name order by build.py).
BACKUP: /mnt/user-data/outputs/gullhaven_src.zip (re-zip after each milestone). Old OddTown v7 source recovered
from the published artifact into /home/claude/oddtown_v7/src/js (split by module headers) - reference only.
Plan doc: Claude Docs 8832ea07-72fe-4586-aaea-0c39a2bfda8e. OddTown artifact: https://claude.ai/artifact/MKzra6coK4GcPU9pEAMKYh

## User decisions
- Town Gullhaven, token $REEL, soft money Shells. 5 co-ops. Licence one per wallet + X account.
- Pools (daily Cup, bounty) funded by licence + co-op fees, crew trip fees, exchange (REEL->Shells 50%), machine 5%, derby 50%, cosmetics.
- NFT vending machine: 5 tiers 10k/5%,20k/10%,30k/15%,40k/20%,50k/25% (~200k REEL per NFT). Else 0.3x/0.5x/2x/5x from prize pool
  (pool = 60% of pulls + operator seed). Wins only offered while the pool covers them (safety 3x); hot pool doubles win weight.
- NFTs have NO names: "Founding Fisher #001". Username = player's X handle; play mode typed, live mode verified via tweet + oEmbed (no API).
- Crew: own Founding Fishers + up to 3 hired deckhands; auto-fish trips (short/half/long) for a $REEL fee; half Cup points; no Logbook.
- User knows it's not legal to launch (AU); build to full spec "ready to plug my token address" (CFG.TOKEN / server/config.json).

## Module map (gullhaven/src/js)
m00_util, m00a_config (CFG), m00b_audio, m00c_font, m01_collection (RARITY, traits, nftName), m02_art (chars, tiles, buildings, machine),
m03a_tiles, m03b_props, m03c_icons (UI_ICON, uiIcon, gearIcon, baitIcon, boatIcon), m03d_facart (coop emblem/crest/flag),
m03e_catart (PN painter, fish engine, CREATURE, FIND, catArt(id,v)), m03g_coast (boats boatImg/boatSide, coastal props, lighthouse),
m04_items (GEAR, BAIT, BOATS, POTS), m04c_csim (COOPS, CSIM), m04d_catalog (CAT, CATI, ZONES...), m04e_env (envAt, condOK, hookTable,
rollHook, catchPoints, pots/comb/salvage, chestLoot, crewHaul, derbySpecies), m04f_machine (MACH, machOdds, machRoll, DROP_ORDER),
m05_world (genWorld: coast field landF, zones, harbour, town, berths, salvage sites, comb tiles)
SHARED (server vm): m00_util m00a_config m01_collection m04_items m04c_csim m04d_catalog m04e_env m04f_machine -> shared.js
Tools: tools/artsheet.py (render JS expr to png; MODS env picks module prefixes), tools/sheet_*.js, tools/map.js

## Progress (2026-10-14)
- [x] All runtime modules written: m12b_mg (Fishing 2.0, dig, salvage, pots), m12c_panels, m12d_coop (Cup + crew), m12e_logbook,
      m13_machine_ui (5 tiers), m14_boot. Lint clean (eslint no-undef). tools/smoke.py: no errors at iPhone size (file + ws mode).
- [x] server.js rewritten: xcode/xverify (oEmbed), cast/land tokens, crew/crewin (+Crew Fund cheques, server-side levels), derby,
      cosmetic, swap, pull in both modes, fee msgs (play), Cup pays real members only (minPts 5, rollover), Crew Fund spill to Cup.
      npm test (test/server.test.js + test/mock.js) ALL PASSED.
- [x] Crew Fund: 60% of trip fees + 5% machine pulls; cheque rtp by rarity (hand .5, nft .75/.9/1.08/1.35) x trip x level x health.
- [x] Collection rendered: tools/collection.py -> collection/ (500 png + metadata, seaside portraits).
- [x] Published artifact: https://claude.ai/artifact/HA9LGfN3pRMLAhrkx4wjYE (db rules fishers/machinep {self}, room chat/news, user)
- [ ] Possible next: plan doc update (Claude Docs), Railway deploy of play server if user wants, more art polish.
