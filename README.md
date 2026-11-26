# Gullhaven shared town (multiplayer server)

The server for the Godot game's **Play online** mode. Everyone who joins shares one coast:
you see each other walking about, chat (speech bubbles plus a chat log), and visit each
other's huts. Each player keeps their own save on their own computer; the server only
relays positions and chat, and keeps a copy of each hut's layout so friends can visit.

## Run it

```
cd mp-server
npm install
npm start            # port 8787 (set PORT to change it)
```

Then in the game: main menu, **Play online with friends**. Type a name, and give the server
address, e.g. `ws://localhost:8787` on the same computer, or `ws://192.168.1.20:8787` for a
friend on your Wi-Fi. A server on the internet behind HTTPS is `wss://your-host`.

- `node bot.js ws://localhost:8787` adds a test visitor who strolls round Gran's garden,
  says hello when you arrive, and has a hut you can visit.
- `npm test` checks joining, moving, chat (rate limit and word filter) and hut visits.
- `GET /` answers `{"ok":true,"players":N}` (a health check for hosting).

## What it accepts

| Message | What it does |
| --- | --- |
| `hello` | Join with a name (made unique), your look and your hut |
| `pos` | Where you are, which way you face, walking or not (sent 10 times a second) |
| `chat` | Up to 140 characters, one message every 0.8 s, rude words starred out |
| `hut` | Your hut's tier, walls, floor and furniture, so friends can visit |
| `visit` | Ask for someone's hut; they get told you're visiting |

Huts are kept in `huts.json` (or `DATA_FILE`). At most 60 players (`MAX_PLAYERS`).
