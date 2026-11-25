// A Umi client (Metaplex's toolkit) set up for this network and wallet, with an uploader:
// Irys (permanent Arweave storage) on devnet and mainnet, an in-memory stand-in on localnet.

import { createUmi } from "@metaplex-foundation/umi-bundle-defaults";
import { keypairIdentity } from "@metaplex-foundation/umi";
import { mplCore } from "@metaplex-foundation/mpl-core";
import { mplCandyMachine } from "@metaplex-foundation/mpl-core-candy-machine";
import { irysUploader } from "@metaplex-foundation/umi-uploader-irys";
import { mockStorage } from "@metaplex-foundation/umi-storage-mock";
import { NETWORK, RPC, loadSecretKey } from "./config.mjs";

export function makeUmi() {
  const umi = createUmi(RPC, "confirmed").use(mplCore()).use(mplCandyMachine());
  const kp = umi.eddsa.createKeypairFromSecretKey(loadSecretKey());
  umi.use(keypairIdentity(kp));
  if (NETWORK === "localnet") {
    umi.use(mockStorage());
  } else {
    umi.use(irysUploader({
      address: NETWORK === "mainnet" ? "https://node1.irys.xyz" : "https://devnet.irys.xyz",
      priceMultiplier: 1.1,
    }));
  }
  return umi;
}
