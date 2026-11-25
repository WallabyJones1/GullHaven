// Plays the mint page in headless Chromium against the local validator: a stand-in for
// Phantom (signing with the rehearsal wallet) connects, mints one Fisher, and the page
// must say so. Run by test/local-e2e.sh (step "page"), after status.mjs and the build.

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { build } from "esbuild";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { ROOT, KEYPAIR_PATH } from "../scripts/lib/config.mjs";

// Playwright from this project if installed here, otherwise the machine's global install
let chromium;
try { ({ chromium } = await import("playwright")); } catch {
  const globalRoot = execSync("npm root -g").toString().trim();
  ({ chromium } = createRequire(path.join(globalRoot, "noop.js"))("playwright"));
}

const dist = path.join(ROOT, "mint-site", "dist");
const types = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".png": "image/png", ".woff2": "font/woff2" };
const server = http.createServer((req, res) => {
  const f = path.join(dist, decodeURIComponent(req.url.split("?")[0]).replace(/^\/$/, "/index.html"));
  if (!f.startsWith(dist) || !fs.existsSync(f)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { "content-type": types[path.extname(f)] ?? "application/octet-stream" });
  fs.createReadStream(f).pipe(res);
}).listen(0);
const url = `http://127.0.0.1:${server.address().port}/`;

// the stand-in wallet: same shape as window.phantom.solana
const secret = JSON.parse(fs.readFileSync(KEYPAIR_PATH, "utf8"));
const shim = await build({
  stdin: {
    contents: `
      import { Keypair } from "@solana/web3.js";
      const kp = Keypair.fromSecretKey(Uint8Array.from(${JSON.stringify(secret)}));
      const sign = (tx) => { if (tx.version !== undefined) tx.sign([kp]); else tx.partialSign(kp); return tx; };
      window.phantom = { solana: { isPhantom: true, isConnected: false, publicKey: null,
        async connect() { this.publicKey = kp.publicKey; this.isConnected = true; return { publicKey: kp.publicKey }; },
        async disconnect() { this.isConnected = false; },
        async signTransaction(tx) { return sign(tx); },
        async signAllTransactions(txs) { return txs.map(sign); },
      } };`,
    resolveDir: ROOT, loader: "js",
  },
  bundle: true, write: false, format: "iife", platform: "browser", define: { global: "globalThis" }, logLevel: "error",
});

const browser = await chromium.launch();
const page = await browser.newPage();
page.on("pageerror", (e) => console.log("page error:", e.message));
await page.addInitScript(shim.outputFiles[0].text);
await page.goto(url);
await page.waitForFunction(() => /minted/.test(document.getElementById("count").textContent), null, { timeout: 30000 });
console.log("page:", await page.textContent("#count"), "|", await page.textContent("#price"));
await page.click("#connect");
await page.waitForFunction(() => !document.getElementById("mint").disabled, null, { timeout: 30000 });
await page.click("#mint");
await page.waitForFunction(() => /You minted|didn't|limit|Not enough/.test(document.getElementById("status").textContent), null, { timeout: 90000 });
const status = await page.textContent("#status");
console.log("page:", status);
if (process.env.GULL_SHOT) await page.screenshot({ path: process.env.GULL_SHOT, fullPage: true });
await browser.close();
server.close();
if (!/You minted Gullhaven Fisher #\d+/.test(status)) { console.log("MINT PAGE FAIL"); process.exit(1); }
console.log("MINT PAGE ok");
