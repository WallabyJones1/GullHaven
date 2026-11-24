# Sharing the Gullhaven beta

Every beta build is made on GitHub's computers by `.github/workflows/gullhaven-beta.yml`, so
nobody has to export by hand. There are four places to put it: the website (play in the
browser, nothing to install), a GitHub release (works straight away), itch.io (the best home
for a beta) and Steam (later; it takes a few weeks to set up).

## 0. The website (play in the browser)

The game also builds for the web. On every push to `hd2d`, once the smoke test passes with
no failures and the web build plays in a real browser (Chromium), the web files go to the
`godot-web` branch. Railway's **gullhaven-3d** service (in the Gullhaven project) deploys
that branch automatically, so the site always has the latest build that passed:

**https://gullhaven-3d-production.up.railway.app**

- It plays in desktop browsers (Chrome, Edge, Firefox, Safari) with a keyboard, mouse or
  controller. Phones and tablets load it but there are no touch controls yet.
- The browser version uses Godot's lighter web renderer (WebGL 2), so it has fewer effects
  than the downloads, such as no ambient occlusion or light shafts, and softer-edged shadows.
- Saves live in the visitor's browser storage. Clearing site data wipes them.
- A custom domain (for example `play.gullhaven.com`) can be added in Railway under the
  service's **Settings > Networking**. Railway shows the DNS record to add.
- The old web game on `main` keeps its own site and isn't touched.

## 1. Make a beta build

Push a tag that starts with `beta-` (for example `beta-0.5`), or on github.com open
**Releases > Draft a new release**, type a new tag such as `beta-0.5`, set the target to
**hd2d**, tick **Set as a pre-release**, and publish.

About ten minutes later the release has four zips attached (Windows, macOS, Linux and the
web build), the desktop ones with the tester guide. The release link is shareable as it is: anyone with the link can
download it.

Every push to `hd2d` also builds all three (without publishing anything), so you can grab
a test copy from the **Actions** tab: open the latest "Gullhaven beta builds" run and
download **gullhaven-builds** at the bottom.

## 2. itch.io

### Make the page (once)

1. Sign in at itch.io, then **Dashboard > Create new project**.
2. Fill it in:
   - **Title:** Gullhaven. **Project URL:** gullhaven.
   - **Kind of project:** Downloadable. **Classification:** Games.
   - **Pricing:** No payments, or Donate if you like.
   - **Cover image:** `store/itch_cover.png` from this repo (630 x 500).
   - **Description:** paste from `store/itch_page.md`.
   - **Genre:** Simulation. **Tags:** fishing, cozy, pixel-art, exploration, mystery.
   - **Screenshots:** take a few in the game (press P to hide the HUD) and add them.
3. **Visibility:** pick one:
   - **Draft:** only you can see it. Good for checking the page.
   - **Restricted:** only people you invite, or who have a download key. Best for a
     closed beta. Under **Distribute > Download keys** you can make keys or a shareable
     link.
   - **Public:** anyone can find it.
4. Save.

### Put builds on it

You can do this by hand or automatically.

- **By hand:** on the project's **Edit** page, **Upload files**, and add the three zips
  from the GitHub release. Tick the right platform (Windows, macOS, Linux) for each.
- **To play in the browser on itch.io:** set **Kind of project** to **HTML**, upload the
  `-web.zip` and tick **This file will be played in the browser**. Set the embed size to
  1280 x 720 and tick **Fullscreen button**. You can keep the downloads on the same page.
- **Automatically, on every beta tag:**
  1. On itch.io, **Settings > API keys > Generate new API key**, and copy it.
  2. On github.com, open the repo's **Settings > Secrets and variables > Actions**.
  3. Under **Secrets**, click **New repository secret**. Name it `BUTLER_API_KEY` and
     paste the key.
  4. Under **Variables**, click **New repository variable**. Name it `ITCH_GAME`, with the
     value `your-itch-username/gullhaven`.
  5. From then on, every `beta-` tag uploads to the Windows, Mac, Linux and HTML5 channels
     of your itch page by itself. The itch.io app keeps testers updated automatically.

Keep the API key secret: paste it only into GitHub's secret box, not into chats or files.

## 3. Steam

Steam needs some things only you can do, and they take time:

1. **Join Steamworks** at partner.steamgames.com. You'll need ID and tax details, bank
   details, and the **Steam Direct fee** (US$100 per game, paid back after the game earns
   US$1,000).
2. **Create the app.** Steam gives it an App ID and depots. Make three depots, one each for
   Windows, macOS and Linux, in that order (they're usually App ID + 1, + 2, + 3), and a
   branch called `beta`.
3. **For a beta on Steam, turn on Steam Playtest** for the app (Steamworks > your app >
   Playtest). Players request access from your store page and you let them in. Playtest
   needs the store page to exist, but it doesn't need to be released.
4. **The store page** needs capsule art; starters are in `store/` (`steam_header.png`
   920 x 430, `steam_capsule.png` 616 x 353, `steam_library.png` 600 x 900), plus
   screenshots and a trailer. Valve reviews the page and the build before anything goes
   public. New developers wait 30 days after paying before they can release, and the page
   must show "Coming soon" for at least two weeks.
5. **Automatic uploads:** make a separate Steam account just for uploading builds, give it
   build access in Steamworks, log in once with `steamcmd` on your Mac to get past Steam
   Guard, then add these to the GitHub repo (**Settings > Secrets and variables >
   Actions**):
   - secret `STEAM_USERNAME`: that account's name
   - secret `STEAM_CONFIG_VDF`: the base64 of `config/config.vdf` from steamcmd's folder,
     made with `base64 -i config.vdf`
   - variable `STEAM_APP_ID`: your App ID (for a Playtest, the Playtest's App ID)
   - variable `STEAM_BRANCH` (optional): the branch to set live, `beta` if unset

   Every `beta-` tag then uploads to Steam too, using the game-ci steam-deploy action.

## Before sending it out

- Play the build from the release yourself on a Mac and, if you can, on a Windows PC.
- The builds aren't code-signed yet. Windows shows SmartScreen ("More info > Run anyway")
  and macOS needs **Open Anyway** in Privacy & Security. `BETA.md` walks testers through
  both. Signing (an Apple Developer account, US$99 a year, and a Windows code-signing
  certificate) can come before a public launch.
