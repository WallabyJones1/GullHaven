# Gullhaven beta

Thanks for testing! Gullhaven is a cosy fishing and exploration game: fish a big coast of
towns, rivers and islands, sail further as you upgrade your boat, build up your hut, and
work out what happened to the lighthouse keeper.

This is an early beta. Expect rough edges, and please tell us about them.

## Installing

**Windows:** unzip, then run `Gullhaven.exe`. Windows may say it "protected your PC"
because the game isn't signed yet: click **More info**, then **Run anyway**.

**macOS:** unzip, then open `Gullhaven.app`. The first time, macOS will refuse because
the game isn't notarized by Apple yet. Open **System Settings > Privacy & Security**,
scroll down and click **Open Anyway** next to Gullhaven, then open it again. If macOS
says the app is "damaged", open Terminal and run `xattr -cr ` followed by a space,
then drag `Gullhaven.app` into the window and press Return.

**Linux:** unzip, then run `./Gullhaven.x86_64` (it may need `chmod +x Gullhaven.x86_64`).

A recent graphics card (or Apple Silicon Mac) is best. If it runs slowly, turn off **High
quality** in the pause menu's **Settings** (or press F2).

## Controls

| Do this | Keyboard and mouse | Gamepad |
|---|---|---|
| Walk | WASD or arrows | Left stick |
| Turn the camera | Q / E, or drag with the right mouse button | Right stick, bumpers |
| Zoom | Mouse wheel, - / = | Right stick |
| Cast (hold to charge), reel, talk, open doors, board boats, dig | Space, F or left click | A |
| Reel in, step ashore, back, pause menu | Esc | B |
| Change bait | R | Y |
| Logbook | L or Tab | Back |
| Journal (mystery, quests, letters, collection) | J | Click the left stick |
| Map | M | Start |
| Arrange your hut (inside it) | B | X |

## Where to start

- Hale's Tackle on the quay sells bait and better gear. Townsfolk ask for fish.
- Save up for a rowboat at the Boatyard to reach the river and the nearest islands.
- They say the old lighthouse keeper left something behind. Have a look inside the
  lighthouse on the breakwater.

## Reporting bugs

Tell us what you were doing, what happened, and (if you can) attach a screenshot. Your
save file helps too. It's called `gullhaven_save.json` and lives in:

- Windows: `%APPDATA%\Godot\app_userdata\Gullhaven\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Gullhaven/`
- Linux: `~/.local/share/godot/app_userdata/Gullhaven/`

The game saves when you quit (pause menu > Save and quit) and after most things you do.
