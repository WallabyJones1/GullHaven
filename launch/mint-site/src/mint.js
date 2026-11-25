// The public Fisher mint page: connect Phantom (or any wallet that puts a Solana provider on
// window), see the price and how many are left, mint, and see the Fisher you got.
// Built into dist/mint.js by build.mjs. Addresses come from mint-config.json (scripts/status.mjs).

import { createUmi } from "@metaplex-foundation/umi-bundle-defaults";
import { generateSigner, publicKey, some, transactionBuilder } from "@metaplex-foundation/umi";
import { walletAdapterIdentity } from "@metaplex-foundation/umi-signer-wallet-adapters";
import { setComputeUnitLimit } from "@metaplex-foundation/mpl-toolbox";
import { mplCore, fetchAsset } from "@metaplex-foundation/mpl-core";
import { mplCandyMachine, mintV1, fetchCandyMachine } from "@metaplex-foundation/mpl-core-candy-machine";

const $ = (id) => document.getElementById(id);
let cfg, umi, wallet;

function provider() {
  return window.phantom?.solana ?? window.solflare ?? window.backpack?.solana ?? window.solana ?? null;
}

function say(text, kind = "") {
  $("status").textContent = text;
  $("status").className = kind;
}

async function refresh() {
  try {
    const cm = await fetchCandyMachine(umi, publicKey(cfg.candy_machine));
    const total = Number(cm.data.itemsAvailable);
    const minted = Number(cm.itemsRedeemed);
    $("count").textContent = `${minted.toLocaleString()} / ${total.toLocaleString()} minted`;
    $("bar").style.width = `${(100 * minted) / total}%`;
    const soldOut = minted >= total;
    const notYet = Date.now() < Date.parse(cfg.start_date);
    $("mint").disabled = !wallet || soldOut || notYet;
    $("mint").textContent = soldOut ? "Sold out" : notYet ? `Opens ${new Date(cfg.start_date).toLocaleString()}` : `Mint a Fisher (${cfg.price_sol} SOL)`;
  } catch (e) {
    say(`Couldn't read the mint: ${e.message}`, "bad");
  }
}

async function connect() {
  const p = provider();
  if (!p) {
    say("No Solana wallet found. Install Phantom (phantom.com), then reload.", "bad");
    return;
  }
  try {
    await p.connect();
    wallet = p;
    umi.use(walletAdapterIdentity(p));
    const k = p.publicKey.toString();
    $("connect").textContent = `${k.slice(0, 4)}…${k.slice(-4)}`;
    say("Wallet connected.");
    refresh();
  } catch (e) {
    say(`The wallet didn't connect: ${e.message}`, "bad");
  }
}

async function mint() {
  $("mint").disabled = true;
  say("Check your wallet to approve the mint…");
  try {
    const asset = generateSigner(umi);
    await transactionBuilder()
      .add(setComputeUnitLimit(umi, { units: 800_000 }))
      .add(mintV1(umi, {
        candyMachine: publicKey(cfg.candy_machine),
        asset,
        collection: publicKey(cfg.fisher_collection),
        mintArgs: {
          solPayment: some({ destination: publicKey(cfg.treasury) }),
          mintLimit: some({ id: 1 }),
        },
      }))
      .sendAndConfirm(umi);
    const a = await fetchAsset(umi, asset.publicKey);
    say(`You minted ${a.name}! It's in your wallet now, and in the game when you connect there.`, "good");
    try {
      const meta = await (await fetch(a.uri)).json();
      const card = document.createElement("figure");
      card.innerHTML = `<img alt="" src="${meta.image}"><figcaption>${a.name}</figcaption>`;
      $("minted").prepend(card);
    } catch { /* the picture can lag behind the gateway; the mint still worked */ }
    await refresh();
    return;
  } catch (e) {
    const msg = String(e.message || e);
    console.error(e);
    say(/mint limit|MintLimit/i.test(msg) ? `That wallet has reached the limit of ${cfg.mint_limit}.`
      : /insufficient|0x1\b/i.test(msg) ? "Not enough SOL in that wallet." : `The mint didn't go through: ${msg}`, "bad");
  }
  refresh();
}

async function main() {
  cfg = await (await fetch("mint-config.json", { cache: "no-store" })).json();
  if (!cfg.candy_machine) {
    say("The mint isn't set up yet.", "bad");
    return;
  }
  umi = createUmi(cfg.rpc, "confirmed").use(mplCore()).use(mplCandyMachine());
  $("network").textContent = cfg.network === "mainnet" ? "" : `(${cfg.network}: test coins, no real value)`;
  $("price").textContent = `${cfg.price_sol} SOL each, up to ${cfg.mint_limit} per wallet`;
  $("connect").onclick = connect;
  $("mint").onclick = mint;
  if (provider()?.isConnected) connect();
  refresh();
  setInterval(refresh, 15000);
}

main();
