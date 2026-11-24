// Plays the browser build of Gullhaven in headless Chromium (software WebGL 2), the way a
// visitor would load it, and reports what happened.
//
//   node .github/scripts/web_check.mjs http://localhost:8060 out-dir
//
// 1. Opens the page normally, waits for the title menu, screenshots it.
// 2. Opens it with ?ci-check, which runs a short scripted start (smoke_test.gd in quick
//    mode: skip the opening, new game, make a fisher, read Gran's letter, look around),
//    then screenshots the harbour.
// Prints the game's console output, and exits 1 if the game never reached the title or
// the harbour, or printed a script or shader error.
import { chromium } from "playwright";
import fs from "node:fs";

const base = process.argv[2] || "http://localhost:8060";
const out = process.argv[3] || "web-check";
fs.mkdirSync(out, { recursive: true });

const browser = await chromium.launch({
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"],
});

const bad = /SCRIPT ERROR|Parse Error|Shader compilation|SHADER ERROR|SMOKE CHECK FAIL|Uncaught|RuntimeError|out of memory/i;
const noise = /keyboard_get_keycode_from_physical|GPU stall due to ReadPixels|Automatic fallback to software WebGL/i;
let problems = []; // these fail the check
let notes = []; // other console errors, listed but not failing

async function visit(label, url, waitFor, timeoutS, { poke, then } = {}) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const lines = [];
  page.on("console", (m) => {
    const t = m.text();
    if (noise.test(t)) return;
    lines.push(`[${m.type()}] ${t}`);
    if (bad.test(t)) problems.push(`${label}: ${t}`);
    else if (m.type() === "error") notes.push(`${label}: ${t}`);
  });
  page.on("pageerror", (e) => problems.push(`${label}: page error: ${e.message}`));
  const t0 = Date.now();
  await page.goto(url, { waitUntil: "load", timeout: 120000 });
  let reached = false;
  while ((Date.now() - t0) / 1000 < timeoutS) {
    if (lines.some((l) => l.includes(waitFor))) { reached = true; break; }
    await page.waitForTimeout(1000);
    if (poke) await poke(page, (Date.now() - t0) / 1000);
  }
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  console.log(`== ${label}: ${reached ? "reached" : "DID NOT reach"} "${waitFor}" after ${secs} s`);
  if (!reached) problems.push(`${label}: never reached "${waitFor}" in ${timeoutS} s`);
  if (then) await then(page);
  await page.screenshot({ path: `${out}/${label}.png` });
  for (const l of lines.slice(-60)) console.log("   " + l.slice(0, 400));
  await page.close();
  return reached;
}

// a visitor: the opening plays on a first visit; any key skips it
let poked = 0;
await visit("title", `${base}/index.html`, "Gullhaven: title menu", 300, {
  // Esc skips the opening (and does nothing on the title page itself)
  poke: async (page, t) => { if (t > 25 && t - poked > 8) { poked = t; await page.keyboard.press("Escape"); } },
  then: async (page) => { await page.waitForTimeout(3000); },
});

// the scripted start
await visit("harbour", `${base}/index.html?ci-check`, "SMOKE DONE", 900, {
  then: async (page) => { await page.waitForTimeout(2000); },
});

await browser.close();
if (notes.length) {
  console.log("\n== Other console errors (not failing):");
  for (const n of [...new Set(notes)].slice(0, 40)) console.log("   " + n.slice(0, 400));
}
if (problems.length) {
  console.log("\n== Problems:");
  for (const p of problems) console.log("   " + p.slice(0, 500));
  process.exit(1);
}
console.log("\n== The browser build plays.");
