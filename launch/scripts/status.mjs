// Prints what's been launched on this network and writes the addresses where they're used:
//   mint-site/mint-config.json   (the public mint page)
//   ../godot/data/chain.json     (the game: reads $GULL and Fishers from the player's wallet)
//
//   GULL_NETWORK=devnet node scripts/status.mjs

import fs from "node:fs";
import path from "node:path";
import { ROOT, NETWORK, RPC, loadConfig, loadState, explorer } from "./lib/config.mjs";

const cfg = loadConfig();
const s = loadState();
const line = (label, v) => console.log(`${label.padEnd(18)} ${v ?? "not yet"}`);
console.log(`Gullhaven launch on ${NETWORK} (${RPC})\n`);
line("$GULL mint", s.token?.mint && `${s.token.mint}  ${explorer(s.token.mint)}`);
line("  mint authority", s.token ? (s.token.mintAuthority === null ? "revoked" : s.token.mintAuthority ?? "?") : undefined);
line("Fishers collection", s.nft?.collection && `${s.nft.collection}  ${explorer(s.nft.collection)}`);
line("Candy Machine", s.nft?.candyMachine && `${s.nft.candyMachine} (${s.nft.linesLoaded} loaded)`);

const publicRpc = process.env.GULL_PUBLIC_RPC || (NETWORK === "localnet" ? RPC : NETWORK === "devnet" ? "https://api.devnet.solana.com" : "");
if (NETWORK === "mainnet" && !publicRpc) {
  console.log("\nSet GULL_PUBLIC_RPC to a browser-safe RPC URL (a Helius or Triton key restricted to your site) before writing the page and game config.");
}
const out = {
  network: NETWORK,
  rpc: publicRpc,
  gull_mint: s.token?.mint ?? "",
  gull_decimals: s.token?.decimals ?? cfg.token.decimals,
  gull_symbol: cfg.token.symbol,
  fisher_collection: s.nft?.collection ?? "",
  candy_machine: s.nft?.candyMachine ?? "",
  treasury: s.nft?.treasury ?? "",
  price_sol: s.nft?.priceSol ?? cfg.nft.priceSol,
  start_date: s.nft?.startDate ?? cfg.nft.startDate,
  mint_limit: cfg.nft.mintLimitPerWallet,
  mint_page_url: cfg.game.mintPageUrl,
  core_program: "CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d",
};
fs.writeFileSync(path.join(ROOT, "mint-site", "mint-config.json"), JSON.stringify(out, null, 2) + "\n");
const game = path.join(ROOT, "..", "godot", "data", "chain.json");
if (NETWORK === "localnet") {
  console.log("\nWrote mint-site/mint-config.json (localnet: the game's chain.json is left alone).");
} else if (fs.existsSync(path.dirname(game))) {
  fs.writeFileSync(game, JSON.stringify(out, null, 2) + "\n");
  console.log(`\nWrote mint-site/mint-config.json and godot/data/chain.json for ${NETWORK}.`);
}
