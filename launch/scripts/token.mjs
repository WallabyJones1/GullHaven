// Creates the $GULL coin: a Token-2022 mint with its name, symbol and logo stored on the
// mint itself (the metadata extension, which Phantom, Solflare, Jupiter and Meteora read),
// no freeze authority, the full supply minted to the allocation wallets in
// launch.config.json, then the mint authority revoked so no more can ever be made.
//
//   GULL_NETWORK=devnet node scripts/token.mjs            (or --dry-run to only print the plan)
//
// Every step is written to state/<network>.json, so running it again carries on where it
// stopped instead of making a second coin.

import fs from "node:fs";
import path from "node:path";
import {
  Connection, Keypair, PublicKey, SystemProgram, Transaction, sendAndConfirmTransaction,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID, ExtensionType, getMintLen, createInitializeMetadataPointerInstruction,
  createInitializeMintInstruction, TYPE_SIZE, LENGTH_SIZE, getOrCreateAssociatedTokenAccount, mintTo,
  setAuthority, AuthorityType, getMint,
} from "@solana/spl-token";
import { createInitializeInstruction, createUpdateAuthorityInstruction, pack } from "@solana/spl-token-metadata";
import { createGenericFile } from "@metaplex-foundation/umi";
import {
  ROOT, RPC, DRY_RUN, loadConfig, loadSecretKey, guardMainnet, loadState, saveState, resolveWallet, explorer,
} from "./lib/config.mjs";
import { makeUmi } from "./lib/umi.mjs";

const cfg = loadConfig().token;
guardMainnet("create the $GULL token");

const payer = Keypair.fromSecretKey(loadSecretKey());
const conn = new Connection(RPC, "confirmed");
const state = loadState();
state.token ??= { allocations: {} };
const t = state.token;

// --- the plan --------------------------------------------------------------------------
const decimals = BigInt(cfg.decimals);
const totalBase = BigInt(cfg.supply) * 10n ** decimals;
const pct = cfg.allocations.reduce((s, a) => s + a.percent, 0);
if (pct !== 100) throw new Error(`Allocations add up to ${pct}%, not 100%.`);
let given = 0n;
const plan = cfg.allocations.map((a, i) => {
  // the last allocation takes any rounding left over, so the total is exact
  const amount = i === cfg.allocations.length - 1 ? totalBase - given : (totalBase * BigInt(a.percent)) / 100n;
  given += amount;
  return { ...a, owner: resolveWallet(a.wallet, payer.publicKey.toBase58()), amount };
});

console.log(`\n$${cfg.symbol} (${cfg.name}): ${cfg.supply.toLocaleString()} coins, ${cfg.decimals} decimals, Token-2022`);
for (const p of plan) {
  console.log(`  ${String(p.percent).padStart(3)}%  ${(p.amount / 10n ** decimals).toLocaleString().padStart(13)}  ${p.label}\n        -> ${p.owner}`);
}
console.log(`  Mint authority: ${cfg.revokeMintAuthority ? "revoked after minting (fixed supply)" : "KEPT"}. Freeze authority: none.`);
console.log(`  Metadata update authority: ${cfg.revokeMetadataAuthority ? "revoked" : "kept (so the logo or description can be fixed later)"}.`);
if (DRY_RUN) process.exit(0);

const balance = await conn.getBalance(payer.publicKey);
console.log(`\nPaying wallet ${payer.publicKey.toBase58()} has ${(balance / 1e9).toFixed(4)} SOL`);
if (balance < 0.05e9) throw new Error("The paying wallet needs at least 0.05 SOL (devnet: solana airdrop 2).");

// --- 1. logo and metadata JSON ----------------------------------------------------------
if (!t.uri) {
  const umi = makeUmi();
  const logoPath = path.join(ROOT, cfg.logo);
  const [image] = await umi.uploader.upload([
    createGenericFile(fs.readFileSync(logoPath), path.basename(logoPath), { contentType: "image/png" }),
  ]);
  t.uri = await umi.uploader.uploadJson({
    name: cfg.name, symbol: cfg.symbol, description: cfg.description, image,
    properties: { files: [{ uri: image, type: "image/png" }], category: "image" },
  });
  t.image = image;
  saveState(state);
  console.log(`1. Uploaded the logo and metadata: ${t.uri}`);
} else console.log(`1. Metadata already uploaded: ${t.uri}`);

// --- 2. the mint, with its metadata on it -----------------------------------------------
if (!t.mint) {
  const mintKp = Keypair.generate();
  const metadata = { mint: mintKp.publicKey, name: cfg.name, symbol: cfg.symbol, uri: t.uri, additionalMetadata: [] };
  const mintLen = getMintLen([ExtensionType.MetadataPointer]);
  const metaLen = TYPE_SIZE + LENGTH_SIZE + pack(metadata).length;
  const lamports = await conn.getMinimumBalanceForRentExemption(mintLen + metaLen);
  const tx = new Transaction().add(
    SystemProgram.createAccount({
      fromPubkey: payer.publicKey, newAccountPubkey: mintKp.publicKey, space: mintLen, lamports, programId: TOKEN_2022_PROGRAM_ID,
    }),
    createInitializeMetadataPointerInstruction(mintKp.publicKey, payer.publicKey, mintKp.publicKey, TOKEN_2022_PROGRAM_ID),
    createInitializeMintInstruction(mintKp.publicKey, Number(decimals), payer.publicKey, null, TOKEN_2022_PROGRAM_ID),
    createInitializeInstruction({
      programId: TOKEN_2022_PROGRAM_ID, metadata: mintKp.publicKey, updateAuthority: payer.publicKey,
      mint: mintKp.publicKey, mintAuthority: payer.publicKey, name: cfg.name, symbol: cfg.symbol, uri: t.uri,
    }),
  );
  const sig = await sendAndConfirmTransaction(conn, tx, [payer, mintKp]);
  t.mint = mintKp.publicKey.toBase58();
  t.createdSig = sig;
  saveState(state);
  console.log(`2. Created the mint ${t.mint}`);
} else console.log(`2. Mint already made: ${t.mint}`);
const mint = new PublicKey(t.mint);

// --- 3. mint the allocations: one mint per wallet (allocations sharing a wallet are summed) --
const byOwner = new Map();
for (const [i, p] of plan.entries()) {
  if (t.allocations[i]) continue;
  const g = byOwner.get(p.owner) ?? { amount: 0n, items: [] };
  g.amount += p.amount;
  g.items.push([i, p]);
  byOwner.set(p.owner, g);
}
for (const [ownerStr, g] of byOwner) {
  const ata = await getOrCreateAssociatedTokenAccount(conn, payer, mint, new PublicKey(ownerStr), true, "confirmed", undefined, TOKEN_2022_PROGRAM_ID);
  const sig = await mintTo(conn, payer, mint, ata.address, payer, g.amount, [], undefined, TOKEN_2022_PROGRAM_ID);
  for (const [i, p] of g.items) {
    t.allocations[i] = { label: p.label, owner: p.owner, account: ata.address.toBase58(), amount: p.amount.toString(), sig };
  }
  saveState(state);
  console.log(`3. Minted ${(g.amount / 10n ** decimals).toLocaleString()} to ${ownerStr} (${g.items.map(([, p]) => p.label.split(" (")[0]).join(", ")})`);
}

// --- 4. check the supply, then lock it --------------------------------------------------
let info = await getMint(conn, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
if (info.supply !== totalBase) throw new Error(`Supply is ${info.supply}, expected ${totalBase}. Not revoking.`);
console.log(`4. Supply checked: ${(info.supply / 10n ** decimals).toLocaleString()}`);
if (cfg.revokeMintAuthority && info.mintAuthority) {
  await setAuthority(conn, payer, mint, payer, AuthorityType.MintTokens, null, [], undefined, TOKEN_2022_PROGRAM_ID);
  console.log("   Mint authority revoked: no more $GULL can ever be made.");
}
if (cfg.revokeMetadataAuthority && !t.metadataRevoked) {
  const tx = new Transaction().add(createUpdateAuthorityInstruction({
    programId: TOKEN_2022_PROGRAM_ID, metadata: mint, oldAuthority: payer.publicKey, newAuthority: null,
  }));
  await sendAndConfirmTransaction(conn, tx, [payer]);
  t.metadataRevoked = true;
  console.log("   Metadata authority revoked.");
}
info = await getMint(conn, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
t.mintAuthority = info.mintAuthority ? info.mintAuthority.toBase58() : null;
t.freezeAuthority = info.freezeAuthority ? info.freezeAuthority.toBase58() : null;
t.decimals = Number(decimals);
saveState(state);
console.log(`\nDone. $${cfg.symbol}: ${explorer(t.mint)}`);
