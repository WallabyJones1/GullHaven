# Islands update

- **A much bigger sea:** the ocean is now about twice the size, with lots more room between islands. The mainland ends in a south coast, and the open sea beyond it has **Seagrass Meadows** along the shore (9 new fish, any boat but a rowboat) and a coral atoll holding the **Turquoise Lagoon** (8 new fish, dinghy or better), plus reef, kelp, wreck and blue water further out.
- Locked islands stay off the minimap and sea chart until you open them.
- **Three locked islands**, each with a shop, bounty board, dive flag and a local:
  - **Kelpwood** hides in a fog bank north-east of Tideglass. Keeper Odile at Lighthouse Point trades her fog chart for 3 Kelp Forest fish.
  - **Wrecker's Cove** sits behind breakers in the far north-east. Once Kelpwood is open, Captain Moe, Sully and Wren in town each know one word of the password. Sail to the breakers and **Call out**.
  - **Ember Isle**, south of Lantern Key, has a volcano and a hot spring. The Harbourmaster stamps a permit once you've done 3 island bounties and own a trawler or bigger.
- Opening an island pays 750 Shells and gives a title. The **Adventures** board (on the notice board) tracks every secret, including Mirrorlake.

# Friends update

- **Ride with a friend:** walk up to a friend's boat and tap **Hop aboard**. You ride along wherever they sail and can fish from their deck (their boat decides which grounds are calm enough). Tap **Hop off** to step ashore, or get dropped back at the quay if you're at sea.
- **Your progress follows your name:** the server keeps your save under your fisher name. Type the same name on another phone or computer and your Shells, boats, catches and cottage come with you. There's no password, so pick a name your friends won't type by accident. Renaming to a name someone already uses is refused.

# Diving update

- **Diving:** buy a dive kit (2,000 Shells) at the Boatyard or Lantern Key. Red-and-white dive flags mark the wrecks and island reefs. Stop your boat by a flag and tap **Dive**.
- Each site is its own sea floor: coral garden, sandy flats, kelp forest, shipwreck, drop-off or the trench. Open chests for Shells and treasure, collect a few pieces of coral, and dodge the jellyfish (a sting costs 8 seconds of air).
- You get 45 seconds of air (75 with Twin tanks, 3,500 Shells). Get back to the rope and tap **Surface**, or you'll be pulled up when the air runs out. Chests refill after 30 minutes. No diving in storms.

# Big merged update

- **Open sea:** the reef paths between islands are gone. Any boat can cross open water, but water beyond your boat's rating and storms wear the hull down. A swamped boat is towed home (150 Shells, some fish lost). Repair at the Boatyard or from Boat details. You can only fish grounds your boat is rated for.
- **Mirrorlake:** a hidden freshwater lake in the south wood behind an old gate. Four riddles open it: a carving at Lighthouse Point and a local on each island (Mara, Fern, Old Ivo). Nine freshwater fish and a new legend, The Mirror Cod.
- **Cats:** the ten cats from Catoshi's Catch wander the town and islands. Pet them for hearts; at five hearts adopt one at the new Cat Café and it follows you around.
- **Town and world:** a new lane with the Cat Café, a bakery, a cottage and garden plots; a fountain in the square (toss a Shell); flower boxes and wildflowers; a south wood with pines and toadstools; each island has its own look.
- **Title sequence:** a full-screen intro: shadowy fish in deep water while the GULLHAVEN sign is hooked off the seabed and reeled up into the dusk. Tap to skip.
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
