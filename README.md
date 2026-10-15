# Gullhaven

A free pixel fishing RPG in a shared harbour. The existing code-drawn pixel art, original town and Founding Fishers character designs are preserved.

- Start with **1,200 Shells**, earn more through fishing and quests, then improve your gear, cottage and boat.
- Explore a larger ocean with island settlements, local shops and bounty boards.
- Choose a character from the existing Founding Fishers designs and customise their appearance for free. Appearance and collection rarity give no gameplay advantage.
- Decorate your cottage, visit other players' cottages, and customise your boat.
- Fish alongside other players in the same ocean, chat and contribute to a co-op's daily Harbour Cup.
- Fishing licences, co-op membership and daily derby entry are free. Crew trips use small Shells supply costs and return fish sales, with no random currency cheques.

**Shells are earned game currency with no cash value.** This version has no token, deposits, withdrawals, exchange or NFT gacha. Existing collection artwork is used as character templates; no wallet or NFT purchase is required.

## Run

Requires Node.js 18+ and Python 3.

```bash
npm install
npm run build
npm start
```

Open `http://localhost:8080`. Set `PORT` to change the port. Other players need to connect to the same running server. `npm test` checks the server's free-play and multiplayer rules.

`npm run build` combines `src/js/m*.js` with `src/template.html` and writes:

- `game.html`: the standalone game. Open it directly to play solo.
- `public/index.html`: the page served by `server.js`.
- `shared.js`: the common rules used by the server.

Edit source modules and rebuild these outputs together. No external art generation or image service is needed.

## Saves and multiplayer

With the included Node server, personal progress, Shells, gear and customisation are saved in the current browser's local storage. There is no save export/import interface in this update. Clearing site storage removes that local save.

The server shares player presence, chat, public discoveries, co-op scores, the derby board and visitors' cottage snapshots. It saves shared records to `data.json` by default; set `DATA_FILE` to change that path. Keep this file outside a disposable deployment filesystem if you want shared records to survive a server restart.

This is a small social multiplayer update with individual RPG progression. The included Node server does not provide personal account storage, cross-device cloud saves or a fully authoritative economy. Friends fish from their own boats in the same world; shared boat passengers are not part of this update. House visits show the owner's latest shared customisation snapshot.

## Source

- `m00*`–`m04*`: configuration, collection traits, existing pixel art and shared fishing rules.
- `m05*`–`m08*`: world, interiors, saves and networking.
- `m09*`–`m14*`: gameplay, rendering, controls, panels and boot.
- `tools/collection.py`: optional rendering of the existing Founding Fishers collection art and metadata.

Legacy token-era compatibility code remains in a few modules to keep the change small and preserve old saves. The public game and server keep those features disabled, even if old token environment variables are present.
