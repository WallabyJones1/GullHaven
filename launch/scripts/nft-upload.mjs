// Uploads the Fishers to permanent storage (Arweave, through Irys): every image, then every
// metadata JSON pointing at its image, then the collection image and JSON. The links are
// kept in state/<network>-uploads.json, so a stopped upload carries on where it left off.
//
//   GULL_NETWORK=devnet node scripts/nft-upload.mjs        (--dry-run to see the size only)
//   GULL_ITEMS=60 ...   upload only the first 60 (for a rehearsal)
//
// Irys is paid in SOL from the paying wallet as it goes. Devnet uploads are free-ish and
// are deleted after a while; mainnet uploads are permanent.

import fs from "node:fs";
import path from "node:path";
import { createGenericFile } from "@metaplex-foundation/umi";
import { ROOT, NETWORK, DRY_RUN, loadConfig, guardMainnet } from "./lib/config.mjs";
import { makeUmi } from "./lib/umi.mjs";

const cfg = loadConfig().nft;
guardMainnet("upload the Fishers to permanent storage");
const dir = path.join(ROOT, cfg.assetsDir);
const count = itemCount(dir);
const BATCH = 25;

const cachePath = path.join(ROOT, "state", `${NETWORK}-uploads.json`);
const cache = fs.existsSync(cachePath) ? JSON.parse(fs.readFileSync(cachePath, "utf8")) : { images: {}, json: {} };
const save = () => { fs.mkdirSync(path.dirname(cachePath), { recursive: true }); fs.writeFileSync(cachePath, JSON.stringify(cache, null, 1)); };

let bytes = 0;
for (let i = 0; i < count; i++) bytes += fs.statSync(path.join(dir, `${i}.png`)).size;
console.log(`${count} Fishers, ${(bytes / 1e6).toFixed(1)} MB of images, ${Object.keys(cache.json).length} already uploaded`);
if (DRY_RUN) process.exit(0);

const umi = makeUmi();
if (umi.uploader.getUploadPrice && NETWORK !== "localnet") {
  const price = await umi.uploader.getUploadPrice([createGenericFile(new Uint8Array(bytes), "all")]);
  console.log(`Irys price for the images: about ${Number(price.basisPoints) / 1e9} SOL (plus a little for the JSON)`);
}

// images, in batches
const needImages = range(count).filter((i) => !cache.images[i]);
for (let b = 0; b < needImages.length; b += BATCH) {
  const ids = needImages.slice(b, b + BATCH);
  const files = ids.map((i) => createGenericFile(fs.readFileSync(path.join(dir, `${i}.png`)), `${i}.png`, { contentType: "image/png" }));
  const uris = await retry(() => umi.uploader.upload(files));
  ids.forEach((i, k) => { cache.images[i] = uris[k]; });
  save();
  process.stdout.write(`\rimages ${Object.keys(cache.images).length}/${count}`);
}
console.log();

// metadata JSON, pointing at the uploaded images
const needJson = range(count).filter((i) => !cache.json[i]);
for (let b = 0; b < needJson.length; b += BATCH) {
  const ids = needJson.slice(b, b + BATCH);
  const files = ids.map((i) => {
    const meta = withImage(JSON.parse(fs.readFileSync(path.join(dir, `${i}.json`), "utf8")), cache.images[i]);
    return createGenericFile(JSON.stringify(meta), `${i}.json`, { contentType: "application/json" });
  });
  const uris = await retry(() => umi.uploader.upload(files));
  ids.forEach((i, k) => { cache.json[i] = uris[k]; });
  save();
  process.stdout.write(`\rmetadata ${Object.keys(cache.json).length}/${count}`);
}
console.log();

// the collection
if (!cache.collection) {
  const [image] = await retry(() => umi.uploader.upload([
    createGenericFile(fs.readFileSync(path.join(dir, "collection.png")), "collection.png", { contentType: "image/png" }),
  ]));
  const meta = withImage(JSON.parse(fs.readFileSync(path.join(dir, "collection.json"), "utf8")), image);
  cache.collection = { image, json: await retry(() => umi.uploader.uploadJson(meta)) };
  save();
}
console.log(`Collection: ${cache.collection.json}\nDone: ${count} Fishers uploaded (${cachePath}).`);

// --- helpers ---------------------------------------------------------------------------
export function itemCount(d) {
  const limit = Number(process.env.GULL_ITEMS || 0);
  let n = 0;
  while (fs.existsSync(path.join(d, `${n}.png`)) && fs.existsSync(path.join(d, `${n}.json`))) n++;
  return limit > 0 ? Math.min(limit, n) : n;
}

function withImage(meta, uri) {
  const files = (meta.properties?.files ?? []).map((f) => (f.type?.startsWith("image/") ? { ...f, uri } : f));
  return { ...meta, image: uri, properties: { ...(meta.properties ?? {}), files } };
}

function range(n) { return Array.from({ length: n }, (_, i) => i); }

async function retry(fn, tries = 4) {
  for (let k = 1; ; k++) {
    try { return await fn(); } catch (e) {
      if (k >= tries) throw e;
      console.warn(`\n  upload failed (${e.message}); trying again in ${k * 3}s`);
      await new Promise((r) => setTimeout(r, k * 3000));
    }
  }
}
