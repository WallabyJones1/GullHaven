// Builds the mint page into mint-site/dist: one bundled script, the page, the fonts, the
// collection picture and mint-config.json. Host dist/ anywhere that serves static files.
//   node mint-site/build.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";

const here = path.dirname(fileURLToPath(import.meta.url));
const dist = path.join(here, "dist");
fs.mkdirSync(dist, { recursive: true });
await build({
  entryPoints: [path.join(here, "src", "mint.js")],
  bundle: true, minify: true, format: "iife", platform: "browser", target: "es2020",
  outfile: path.join(dist, "mint.js"),
  define: { global: "globalThis", "process.env.NODE_DEBUG": "false" },
  logLevel: "warning",
});
const copy = (from, to = path.basename(from)) => fs.copyFileSync(from, path.join(dist, to));
copy(path.join(here, "index.html"));
copy(path.join(here, "..", "assets", "collection.png"));
for (const f of ["pixelify_sans.woff2", "jersey_10.woff2"]) copy(path.join(here, "..", "..", "godot", "art", "fonts", f));
const cfg = path.join(here, "mint-config.json");
if (fs.existsSync(cfg)) copy(cfg);
else console.warn("No mint-config.json yet: run scripts/status.mjs after the Candy Machine is made.");
console.log(`Built ${dist} (${(fs.statSync(path.join(dist, "mint.js")).size / 1024).toFixed(0)} KB script)`);
