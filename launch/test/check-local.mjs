// After a local rehearsal: reads everything back from the chain and checks it is what a
// launch should be. Also checks the account layout the game uses to count a wallet's
// Fishers (getProgramAccounts on Metaplex Core: owner at byte 1, collection at byte 34).

import { Connection, PublicKey } from "@solana/web3.js";
import { TOKEN_2022_PROGRAM_ID, getMint, getTokenMetadata } from "@solana/spl-token";
import { publicKey } from "@metaplex-foundation/umi";
import { fetchCollection, fetchAsset } from "@metaplex-foundation/mpl-core";
import { fetchCandyMachine } from "@metaplex-foundation/mpl-core-candy-machine";
import bs58 from "bs58";
import { RPC, loadConfig, loadState } from "../scripts/lib/config.mjs";
import { makeUmi } from "../scripts/lib/umi.mjs";

const cfg = loadConfig();
const state = loadState();
const conn = new Connection(RPC, "confirmed");
const umi = makeUmi();
let failed = 0;
const check = (ok, what) => { console.log(`CHECK ${ok ? "ok" : "FAIL"} ${what}`); if (!ok) failed++; };

// the coin
if (state.token?.mint) {
  const mint = new PublicKey(state.token.mint);
  const info = await getMint(conn, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
  check(info.supply === BigInt(cfg.token.supply) * 10n ** BigInt(cfg.token.decimals), "$GULL supply is exactly 1,000,000,000");
  check(info.mintAuthority === null, "mint authority is revoked");
  check(info.freezeAuthority === null, "there is no freeze authority");
  const md = await getTokenMetadata(conn, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
  check(md?.name === cfg.token.name && md?.symbol === cfg.token.symbol && md?.uri === state.token.uri, "name, symbol and logo link are on the mint");
}

// the Fishers
if (state.nft?.candyMachine) {
  const coll = await fetchCollection(umi, publicKey(state.nft.collection));
  check(coll.name === cfg.nft.name, "collection name");
  check(coll.royalties?.basisPoints === cfg.nft.royaltyBasisPoints, "royalty is set on the collection");
  const cm = await fetchCandyMachine(umi, publicKey(state.nft.candyMachine));
  check(cm.itemsLoaded === Number(cm.data.itemsAvailable), `all ${cm.data.itemsAvailable} Fishers loaded`);
  check(Number(cm.itemsRedeemed) === Number(process.env.GULL_EXPECT_MINTED ?? 3), `${cm.itemsRedeemed} minted`);

  // the game's query: Core assets owned by this wallet in this collection
  const owner = new PublicKey(umi.identity.publicKey.toString());
  const accounts = await conn.getProgramAccounts(new PublicKey("CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d"), {
    filters: [
      { memcmp: { offset: 0, bytes: bs58.encode(Uint8Array.from([1])) } },  // AssetV1
      { memcmp: { offset: 1, bytes: owner.toBase58() } },
      { memcmp: { offset: 33, bytes: bs58.encode(Uint8Array.from([2])) } }, // update authority = collection
      { memcmp: { offset: 34, bytes: state.nft.collection } },
    ],
  });
  check(accounts.length === Number(cm.itemsRedeemed), `the game's owner+collection query finds ${accounts.length} Fishers`);
  for (const a of accounts) {
    const asset = await fetchAsset(umi, publicKey(a.pubkey.toBase58()));
    const n = Number(asset.name.split("#")[1]);
    check(/^Gullhaven Fisher #\d+$/.test(asset.name) && asset.uri === (await uploadsUri(n - 1)), `${asset.name} has its own metadata link`);
  }
}

console.log(failed ? `CHECKS FAILED: ${failed}` : "ALL CHECKS PASSED");
process.exit(failed ? 1 : 0);

async function uploadsUri(i) {
  const fs = await import("node:fs");
  const path = await import("node:path");
  const { ROOT, NETWORK } = await import("../scripts/lib/config.mjs");
  return JSON.parse(fs.readFileSync(path.join(ROOT, "state", `${NETWORK}-uploads.json`), "utf8")).json[i];
}
