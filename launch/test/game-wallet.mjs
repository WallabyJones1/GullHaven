// Runs the game's wallet bridge (the JavaScript inside godot/scripts/token/wallet.gd) in
// Node against the local validator, with a stand-in Phantom for the rehearsal wallet, and
// checks it reads the right $GULL balance and Fisher count. Step "wallet" of local-e2e.sh.

import fs from "node:fs";
import path from "node:path";
import { Keypair } from "@solana/web3.js";
import { ROOT, RPC, KEYPAIR_PATH, loadConfig, loadState } from "../scripts/lib/config.mjs";

const gd = fs.readFileSync(path.join(ROOT, "..", "godot", "scripts", "token", "wallet.gd"), "utf8");
const js = gd.split("// BRIDGE START")[1].split("// BRIDGE END")[0];
const kp = Keypair.fromSecretKey(Uint8Array.from(JSON.parse(fs.readFileSync(KEYPAIR_PATH, "utf8"))));
globalThis.window = { phantom: { solana: { async connect() { return { publicKey: kp.publicKey }; }, publicKey: kp.publicKey } } };
new Function(js)();

const cfg = loadConfig();
const s = loadState();
window.gullWallet.setConfig(JSON.stringify({
  rpc: RPC, gull_mint: s.token.mint, fisher_collection: s.nft.collection,
  core_program: "CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d",
}));
await window.gullWallet.connect();
const got = JSON.parse(window.gullWallet.json());
console.log("bridge:", got);
const want = Number(process.env.GULL_EXPECT_FISHERS ?? 4);
let failed = 0;
const check = (ok, what) => { console.log(`WALLET CHECK ${ok ? "ok" : "FAIL"} ${what}`); if (!ok) failed++; };
check(got.status === "connected" && got.address === kp.publicKey.toBase58() && !got.error, "connects and reads without errors");
check(got.gull === cfg.token.supply, `reads the $GULL balance (${got.gull})`);
check(got.fishers === want, `counts the wallet's Fishers (${got.fishers}, expected ${want})`);
check(got.sol > 0, "reads the SOL balance");
process.exit(failed ? 1 : 0);
