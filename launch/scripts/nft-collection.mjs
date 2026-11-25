// Creates the Gullhaven Fishers collection as a Metaplex Core collection, with the royalty
// (5% by default) enforced on the collection, so every Fisher in it carries it.
//
//   GULL_NETWORK=devnet node scripts/nft-collection.mjs

import fs from "node:fs";
import path from "node:path";
import { generateSigner, publicKey } from "@metaplex-foundation/umi";
import { createCollection, ruleSet, fetchCollection } from "@metaplex-foundation/mpl-core";
import { ROOT, NETWORK, DRY_RUN, loadConfig, guardMainnet, loadState, saveState, resolveWallet, explorer } from "./lib/config.mjs";
import { makeUmi } from "./lib/umi.mjs";

const cfg = loadConfig().nft;
guardMainnet("create the Fishers collection");
const umi = makeUmi();
const self = umi.identity.publicKey.toString();
const creators = cfg.creators.map((c) => ({ address: publicKey(resolveWallet(c.wallet, self)), percentage: c.percent }));
if (creators.reduce((s, c) => s + c.percentage, 0) !== 100) throw new Error("Creator percentages must add up to 100.");

const state = loadState();
state.nft ??= {};
if (state.nft.collection) {
  console.log(`Collection already made: ${state.nft.collection}`);
  process.exit(0);
}
const uploadsPath = path.join(ROOT, "state", `${NETWORK}-uploads.json`);
if (!fs.existsSync(uploadsPath)) throw new Error("Upload the Fishers first: node scripts/nft-upload.mjs");
const uploads = JSON.parse(fs.readFileSync(uploadsPath, "utf8"));
if (!uploads.collection) throw new Error("The collection image isn't uploaded yet: run nft-upload.mjs to the end.");

console.log(`Collection "${cfg.name}", royalty ${cfg.royaltyBasisPoints / 100}% to ${creators.map((c) => `${c.address} (${c.percentage}%)`).join(", ")}`);
if (DRY_RUN) process.exit(0);

const collection = generateSigner(umi);
await createCollection(umi, {
  collection,
  name: cfg.name,
  uri: uploads.collection.json,
  plugins: [{ type: "Royalties", basisPoints: cfg.royaltyBasisPoints, creators, ruleSet: ruleSet("None") }],
}).sendAndConfirm(umi);
const made = await fetchCollection(umi, collection.publicKey);
state.nft.collection = collection.publicKey.toString();
state.nft.collectionName = made.name;
saveState(state);
console.log(`Made the collection: ${explorer(state.nft.collection)}`);
