// Mints Fishers from the Candy Machine with the paying wallet, the same way a player's mint
// works (pays the SOL price, counts towards the wallet limit). Handy for a devnet test or
// for minting your own before the public opens.
//
//   GULL_NETWORK=devnet GULL_MINT_COUNT=2 node scripts/nft-mint.mjs

import { generateSigner, publicKey, some, transactionBuilder } from "@metaplex-foundation/umi";
import { setComputeUnitLimit } from "@metaplex-foundation/mpl-toolbox";
import { mintV1, fetchCandyMachine } from "@metaplex-foundation/mpl-core-candy-machine";
import { fetchAsset } from "@metaplex-foundation/mpl-core";
import { guardMainnet, loadState, explorer } from "./lib/config.mjs";
import { makeUmi } from "./lib/umi.mjs";

guardMainnet("mint Fishers (paying the mint price)");
const umi = makeUmi();
const state = loadState();
if (!state.nft?.candyMachine) throw new Error("Set up the Candy Machine first: node scripts/nft-candy.mjs");
const n = Number(process.env.GULL_MINT_COUNT || 1);
const cmPk = publicKey(state.nft.candyMachine);

for (let k = 0; k < n; k++) {
  const asset = generateSigner(umi);
  await transactionBuilder()
    .add(setComputeUnitLimit(umi, { units: 800_000 }))
    .add(mintV1(umi, {
      candyMachine: cmPk,
      asset,
      collection: publicKey(state.nft.collection),
      mintArgs: {
        solPayment: some({ destination: publicKey(state.nft.treasury) }),
        mintLimit: some({ id: 1 }),
      },
    }))
    .sendAndConfirm(umi);
  const a = await fetchAsset(umi, asset.publicKey);
  console.log(`Minted ${a.name}: ${explorer(asset.publicKey.toString())}`);
}
const cm = await fetchCandyMachine(umi, cmPk);
console.log(`${cm.itemsRedeemed} of ${cm.data.itemsAvailable} Fishers minted so far.`);
