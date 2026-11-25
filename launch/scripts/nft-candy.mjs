// Sets up the public mint: a Metaplex Core Candy Machine holding every uploaded Fisher,
// guarded by a SOL price (paid to the treasury), a start date and a per-wallet limit.
// Then loads every Fisher into it, a few per transaction, picking up where it stopped.
//
//   GULL_NETWORK=devnet node scripts/nft-candy.mjs
//
// Mint order is random (not sequential), and each Fisher keeps its own name and number.

import fs from "node:fs";
import path from "node:path";
import { generateSigner, publicKey, some, sol, dateTime } from "@metaplex-foundation/umi";
import { create, addConfigLines, fetchCandyMachine, findCandyGuardPda } from "@metaplex-foundation/mpl-core-candy-machine";
import { ROOT, NETWORK, DRY_RUN, loadConfig, guardMainnet, loadState, saveState, resolveWallet, explorer } from "./lib/config.mjs";
import { makeUmi } from "./lib/umi.mjs";

const all = loadConfig();
const cfg = all.nft;
guardMainnet("create the Candy Machine for the public mint");
const umi = makeUmi();
const self = umi.identity.publicKey.toString();
const state = loadState();
if (!state.nft?.collection) throw new Error("Make the collection first: node scripts/nft-collection.mjs");

const uploads = JSON.parse(fs.readFileSync(path.join(ROOT, "state", `${NETWORK}-uploads.json`), "utf8"));
const count = Object.keys(uploads.json).length;
const uris = Array.from({ length: count }, (_, i) => {
  if (!uploads.json[i]) throw new Error(`Fisher ${i} has no uploaded metadata.`);
  return uploads.json[i];
});

// shared start of every link goes in the Candy Machine once; each line keeps only the rest
let prefix = uris[0];
for (const u of uris) while (!u.startsWith(prefix)) prefix = prefix.slice(0, -1);
const uriLength = Math.max(...uris.map((u) => u.length - prefix.length));
const prefixName = `${cfg.name.replace(/s$/, "")} #$ID+1$`; // "Gullhaven Fisher #1" ... matches the JSON names
const treasury = publicKey(resolveWallet(cfg.treasury, self));
const start = process.env.GULL_TEST_START_NOW ? new Date(Date.now() - 60_000) : new Date(cfg.startDate);

console.log(`Candy Machine: ${count} Fishers at ${cfg.priceSol} SOL to ${treasury}, from ${start.toISOString()}, ${cfg.mintLimitPerWallet} per wallet`);
console.log(`  names "${prefixName}", links "${prefix}" + ${uriLength} characters`);
if (DRY_RUN) process.exit(0);

if (!state.nft.candyMachine) {
  const cm = generateSigner(umi);
  await (await create(umi, {
    candyMachine: cm,
    collection: publicKey(state.nft.collection),
    collectionUpdateAuthority: umi.identity,
    itemsAvailable: count,
    isMutable: true,
    configLineSettings: some({ prefixName, nameLength: 0, prefixUri: prefix, uriLength, isSequential: false }),
    guards: {
      solPayment: some({ lamports: sol(cfg.priceSol), destination: treasury }),
      startDate: some({ date: dateTime(start.toISOString()) }),
      mintLimit: some({ id: 1, limit: cfg.mintLimitPerWallet }),
    },
  })).sendAndConfirm(umi);
  state.nft.candyMachine = cm.publicKey.toString();
  state.nft.candyGuard = findCandyGuardPda(umi, { base: cm.publicKey })[0].toString();
  state.nft.linesLoaded = 0;
  state.nft.priceSol = cfg.priceSol;
  state.nft.treasury = treasury.toString();
  state.nft.startDate = start.toISOString();
  saveState(state);
  console.log(`Made the Candy Machine ${state.nft.candyMachine}`);
}

const per = cfg.configLinesPerTx;
const cmPk = publicKey(state.nft.candyMachine);
for (let i = state.nft.linesLoaded ?? 0; i < count; i += per) {
  const lines = uris.slice(i, i + per).map((u) => ({ name: "", uri: u.slice(prefix.length) }));
  await retry(() => addConfigLines(umi, { candyMachine: cmPk, index: i, configLines: lines }).sendAndConfirm(umi));
  state.nft.linesLoaded = Math.min(i + per, count);
  saveState(state);
  process.stdout.write(`\rloaded ${state.nft.linesLoaded}/${count}`);
}
console.log();
const cm = await fetchCandyMachine(umi, cmPk);
if (cm.itemsLoaded !== count) throw new Error(`Only ${cm.itemsLoaded} of ${count} Fishers are loaded.`);
console.log(`All ${count} Fishers are in the Candy Machine: ${explorer(state.nft.candyMachine)}`);

async function retry(fn, tries = 4) {
  for (let k = 1; ; k++) {
    try { return await fn(); } catch (e) {
      if (k >= tries) throw e;
      await new Promise((r) => setTimeout(r, k * 2000));
    }
  }
}
