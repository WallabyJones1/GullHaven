// Shared settings for every launch script: which network, which RPC, which wallet pays,
// and where the addresses we create are written down (state/<network>.json).
//
//   GULL_NETWORK   localnet | devnet (default) | mainnet
//   GULL_RPC       an RPC URL (use a private one for mainnet: Helius, Triton, QuickNode...)
//   GULL_KEYPAIR   path to the paying wallet's keypair JSON (default ~/.config/solana/id.json)
//   GULL_MAINNET_CONFIRM=yes   required before anything is sent to mainnet

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

const RPCS = {
  localnet: "http://127.0.0.1:8899",
  devnet: "https://api.devnet.solana.com",
  mainnet: "https://api.mainnet-beta.solana.com",
};

export const NETWORK = (process.env.GULL_NETWORK || "devnet").toLowerCase();
if (!RPCS[NETWORK]) {
  throw new Error(`GULL_NETWORK must be localnet, devnet or mainnet (got "${NETWORK}")`);
}
export const RPC = process.env.GULL_RPC || RPCS[NETWORK];
export const KEYPAIR_PATH = process.env.GULL_KEYPAIR || path.join(os.homedir(), ".config", "solana", "id.json");
export const DRY_RUN = process.argv.includes("--dry-run");

export function loadConfig() {
  return JSON.parse(fs.readFileSync(path.join(ROOT, "launch.config.json"), "utf8"));
}

export function loadSecretKey() {
  if (!fs.existsSync(KEYPAIR_PATH)) {
    throw new Error(`No wallet keypair at ${KEYPAIR_PATH}. Make one with "solana-keygen new" or set GULL_KEYPAIR.`);
  }
  return Uint8Array.from(JSON.parse(fs.readFileSync(KEYPAIR_PATH, "utf8")));
}

// Stop before mainnet unless the person running it has said yes on purpose.
export function guardMainnet(what) {
  console.log(`Network: ${NETWORK}   RPC: ${RPC}${DRY_RUN ? "   (dry run: nothing is sent)" : ""}`);
  if (NETWORK === "mainnet" && !DRY_RUN && process.env.GULL_MAINNET_CONFIRM !== "yes") {
    console.error(`\nThis would ${what} on MAINNET, with real SOL.\nRun it again with GULL_MAINNET_CONFIRM=yes once devnet has gone through cleanly.`);
    process.exit(1);
  }
}

const statePath = () => path.join(ROOT, "state", `${NETWORK}.json`);

export function loadState() {
  const p = statePath();
  return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : {};
}

export function saveState(state) {
  fs.mkdirSync(path.dirname(statePath()), { recursive: true });
  fs.writeFileSync(statePath(), JSON.stringify(state, null, 2) + "\n");
}

// "SELF" in the config means the paying wallet.
export function resolveWallet(value, self) {
  return !value || value === "SELF" ? self : value;
}

export function explorer(address, kind = "address") {
  const cluster = NETWORK === "mainnet" ? "" : NETWORK === "devnet" ? "?cluster=devnet" : `?cluster=custom&customUrl=${encodeURIComponent(RPC)}`;
  return `https://explorer.solana.com/${kind}/${address}${cluster}`;
}
