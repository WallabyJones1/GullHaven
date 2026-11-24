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
quality** in the game menu's **Settings** (or press F2).

## Controls

The game shows the right key or button in every prompt, and a strip along the bottom
lists what you can do right now. You can change keyboard keys in the game menu (Controls).

| Do this | Keyboard and mouse | Gamepad |
|---|---|---|
| Walk | WASD or arrows | Left stick |
| Turn the camera | Q / E, or drag with the right mouse button | Right stick, bumpers |
| Zoom | Mouse wheel, - / = | Right stick |
| Cast (hold to charge), reel, talk, open doors, board boats, dig | Space, F or left click | A |
| Reel in, step ashore, back | Esc | B |
| Game menu | Esc | Start |
| Use your kit (crab pots, cast net, trolling, speargun) | G | X |
| Change bait | R | Y |
| Bag | I | D-pad right |
| Logbook | L or Tab | D-pad left |
| Journal (story, mystery, quests, letters, collection) | J | D-pad up |
| Map | M | Back / View |
| Arrange your hut (inside it) | B | X |

## Where to start

A new game starts with making your fisher, then Gran's letter. After that, follow the
gold corner at the top right: it always says what to do next, how far away it is and
which way, and a beam of light marks the spot. Old Marlo on the docks shows you the ropes.

Every fish you land earns XP. New levels bring skill points (game menu, Fisher) and new
ways to fish from Hale's Tackle: crab pots, a cast net, trolling lines and a speargun.

## Reporting bugs

Tell us what you were doing, what happened, and (if you can) attach a screenshot. Your
save file helps too. It's called `gullhaven_save.json` and lives in:

- Windows: `%APPDATA%\Godot\app_userdata\Gullhaven\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Gullhaven/`
- Linux: `~/.local/share/godot/app_userdata/Gullhaven/`

The game saves when you quit (game menu > Save and quit) and after most things you do.
