# Gullhaven launch kit: the $GULL coin and the Gullhaven Fishers

Everything needed to put the coin and the 3,333 Fishers on Solana, test it on devnet, and
then (when you choose) do the same on mainnet. Every script runs on **devnet** unless you
say otherwise, and refuses to touch mainnet without `GULL_MAINNET_CONFIRM=yes`.

What it makes:

- **$GULL**: a Token-2022 coin, 1,000,000,000 supply, 6 decimals. The name, symbol and
  gull-coin logo are stored on the mint itself (Phantom, Solflare, Jupiter and Meteora all
  read this). There's no freeze authority, and the mint authority is revoked once the
  supply is minted, so no more can ever be made.
- **Gullhaven Fishers**: 3,333 Metaplex Core NFTs (`assets/`, checked: every image and trait
  set is unique) in a Core collection with a 5% royalty, sold through a Core Candy Machine:
  0.25 SOL each, paid to your treasury, up to 5 per wallet, from a start date, random order.
- **A mint page** (`mint-site/`): connect Phantom, mint, see your Fisher.
- **The game hookup**: `scripts/status.mjs` writes `godot/data/chain.json`. In the browser
  version, the Harbour Exchange page can connect Phantom, show the wallet's $GULL, and count
  its Fishers towards your Harbour Licence and crew.

Every number above lives in `launch.config.json`.

## 1. Set up (once)

1. Install Node 20+ and the Solana CLI (https://solana.com/docs/intro/installation).
2. `cd launch && npm install`
3. Make a wallet to launch from: `solana-keygen new` (saved at `~/.config/solana/id.json`;
   or point `GULL_KEYPAIR` at another file). **Back up its seed phrase.** This wallet pays
   for everything and holds the authorities.
4. Devnet SOL: `solana airdrop 2 --url devnet` (or https://faucet.solana.com).

## 2. Edit `launch.config.json`

- `"SELF"` means the launch wallet. Replace it with real addresses before mainnet:
  each `token.allocations[].wallet`, `nft.treasury`, and `nft.creators[].wallet`.
- `nft.priceSol`, `nft.startDate` (UTC), `nft.mintLimitPerWallet`.
- `game.mintPageUrl`: where you'll host the mint page (the game's button opens it).

Any script with `--dry-run` prints what it would do without sending anything.

## 3. Launch on devnet

```bash
export GULL_NETWORK=devnet
npm run token              # the coin: upload logo, create mint, mint allocations, revoke
npm run nft:upload         # 3,333 images + metadata to Irys (resumable)
npm run nft:collection     # the Core collection with the royalty
npm run nft:candy          # the Candy Machine + guards, then loads all 3,333 (resumable)
GULL_MINT_COUNT=2 npm run nft:mint   # (only works after startDate) mint a couple yourself
npm run status             # prints the addresses; writes mint-site/mint-config.json and godot/data/chain.json
node mint-site/build.mjs   # mint page -> mint-site/dist/ (host it anywhere static)
```

Every step writes to `state/devnet.json` (and `state/devnet-uploads.json`), so if one stops
halfway, run it again and it carries on. Keep `state/` safe: it's your record of what exists.
To test the mint page before the real start date, make a devnet Candy Machine with an
earlier `startDate` (delete `nft.candyMachine` from `state/devnet.json` first).

## 4. Rehearse locally (optional, no internet chain at all)

`npm run test:local` runs the whole launch on a throwaway local validator: coin, first 60
Fishers, collection, Candy Machine, 3 mints, then reads it all back from the chain, plays
the mint page in a headless browser with a stand-in Phantom, and runs the game's wallet
code against it. It needs `solana-test-validator` and the three Metaplex programs in
`PROGRAMS` (default `../programs`):

- `mpl_core.so` from github.com/metaplex-foundation/mpl-core, release `release/core@0.9.9`, asset `mpl_core_program.so`
- `mpl_core_candy_machine.so` and `mpl_core_candy_guard.so` from
  github.com/metaplex-foundation/mpl-core-candy-machine releases
  `release/candy-machine-core@0.2.2` and `release/candy-guard@0.2.3`

## 5. Mainnet checklist

Do every devnet step first and play it through, in the game too. Then:

1. **A private RPC** (Helius, Triton, QuickNode): `export GULL_RPC=...`. The public mainnet
   RPC refuses big uploads of transactions and the game's Fisher lookup. For the mint page
   and the game, make a second key restricted to your site's domain and set
   `GULL_PUBLIC_RPC` before `npm run status`.
2. **Real wallets in `launch.config.json`** (no `SELF` left), ideally a hardware wallet or a
   Squads multisig for the treasury and team.
3. **Fund the launch wallet.** Rough costs: the coin about 0.01 SOL; uploading ~55 MB to
   Irys (`nft:upload --dry-run` on mainnet prints the price); the Candy Machine holds about
   1 SOL of rent for 3,333 lines (you get it back by withdrawing the Candy Machine after the
   mint); a few hundred transaction fees. Minters pay their own Fisher's rent.
4. `export GULL_NETWORK=mainnet GULL_MAINNET_CONFIRM=yes`, then the same commands as devnet.
5. **Team tokens**: lock the team allocation in a vesting contract (e.g. Streamflow,
   app.streamflow.finance: 12-month cliff, 24 months linear) and post the lock link.
6. **Liquidity**: create the $GULL/SOL pool on Meteora (DAMM v2) from the liquidity wallet,
   then lock the LP position for 24 months in Meteora's lock. Decide the starting price
   (SOL in the pool vs 100M $GULL) before you do this; it's the coin's opening price.
7. **Check it from outside**: the mint on Solscan / Solana Explorer shows mint authority
   none and freeze authority none; Phantom shows the name and logo; RugCheck shows no flags.
8. `npm run status`, rebuild the mint page and the game's web build, publish both.

## Layout

- `launch.config.json`: every number and wallet.
- `scripts/`: `token.mjs`, `nft-upload.mjs`, `nft-collection.mjs`, `nft-candy.mjs`,
  `nft-mint.mjs`, `status.mjs`; `lib/` has the network switch and the Metaplex client.
- `assets/`: the 3,333 Fishers (`0.png`/`0.json` to `3332`), `collection.png/json`;
  `ASSETS.md`, `rarity.csv`, `trait_counts.csv` describe them.
- `assets-token/gull-coin.png`: the $GULL logo.
- `mint-site/`: the mint page (`build.mjs` bundles it into `dist/`).
- `test/`: the local rehearsal.
- `state/`: what's been made on each network (devnet and mainnet files are worth keeping).
