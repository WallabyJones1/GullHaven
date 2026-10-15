# Big merged update

- **Open sea:** the reef paths between islands are gone. Any boat can cross open water, but water beyond your boat's rating and storms wear the hull down. A swamped boat is towed home (150 Shells, some fish lost). Repair at the Boatyard or from Boat details. You can only fish grounds your boat is rated for.
- **Mirrorlake:** a hidden freshwater lake in the south wood behind an old gate. Four riddles open it: a carving at Lighthouse Point and a local on each island (Mara, Fern, Old Ivo). Nine freshwater fish and a new legend, The Mirror Cod.
- **Cats:** the ten cats from Catoshi's Catch wander the town and islands. Pet them for hearts; at five hearts adopt one at the new Cat Café and it follows you around.
- **Town and world:** a new lane with the Cat Café, a bakery, a cottage and garden plots; a fountain in the square (toss a Shell); flower boxes and wildflowers; a south wood with pines and toadstools; each island has its own look.
- **Music:** different tunes for town, night, indoors, home, open sea, the deep, islands, the lake and storms.

# Small RPG update

The original town, fishing system, collection art, pixel painters and single-file build remain in use. This is an incremental update to the supplied game.

- **Free progression:** new fishers start with 1,200 Shells. Licences, co-ops, character looks and derby entry are free. Earn Shells from catches, town requests, island bounties and daily activities.
- **Character atelier:** select any of the 500 unchanged Founding Fisher templates, or build a separate custom fisher with their existing pixel parts and palette. Appearance has no fishing advantage.
- **Ocean:** expanded from 160 × 120 to 224 × 152 tiles. Tideglass Cay has bait, Mossbank has home goods, and Lantern Key has a boat workshop. Each has a dock and a personal daily fish bounty.
- **Cottages:** three room styles and six furnishings. Buy furnishings once, then place or store them. Visit neighbours through Home → Visit neighbours. Guests share the owner's room and cannot decorate it.
- **Boats:** existing hull and equipment upgrades, Shells paint and names, plus small deck decorations. Other players can see your look, boat details and fishing activity.
- **Town:** the capsule machine is now an atelier. The exchange is an Island Guild. A few benches and flowers add detail without moving the streets.

The token wallet, swaps, deposits, withdrawals and capsule pulls are disabled. Existing NFT images and metadata are unchanged. An old v6 save keeps its Shells, boats, gear, catches, crew and collection; the obsolete token balance is retired. Saves remain under the existing `gullhaven.save` key.

Personal progress remains on each browser/device with the included server. Multiplayer shares presence, chat, public records and cottage snapshots. Friends fish alongside one another from their own boats; shared passengers and cross-device accounts are outside this small update.

Run `npm install`, `npm run build`, then `npm start`. Open `http://localhost:8080`. For solo play, open `game.html` in a browser. See README.md for server persistence details.

Checks: `npm test` for the server; `URL=http://localhost:8080 python3 test/rpg-browser.py` for migration, island routes, bounty delivery, Shells purchases and save persistence; `URL=http://localhost:8080 python3 tools/smoke.py` for mobile screens and existing fishing activities. `URL=http://localhost:8080 python3 test/social-browser.py` checks two-player cottage visits, custom looks, live decorations and boat sharing. The browser checks require Python Playwright and Chromium.
