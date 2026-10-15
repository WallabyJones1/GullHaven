// Gullhaven server: serves the game and runs the shared harbour over WebSockets.
//
// Free play only: each player's save holds Shells and personal RPG progression. The server shares
// presence, chat, houses, fishing records, co-op points, aquarium plaques and the free derby.
// Legacy token settings cannot activate wallets, payments, exchanges or capsule pulls.
//
// Run: npm install && npm start   (PORT env var, default 8080). Admin API: header  x-admin-token: <ADMIN_TOKEN>.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const vm = require('vm');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 8080;
const ROOT = __dirname;
const PUBLIC = path.join(ROOT, 'public');
const DATA_FILE = process.env.DATA_FILE || path.join(ROOT, 'data.json');

// ---------- the game's own rules, loaded from the same source the client runs ----------
const G = (() => {
  const ctx = { console, Math, Date, JSON, Set, Map, Array, Object, Number, String, Boolean, Uint8Array, Uint32Array, Float32Array, Int16Array, Int32Array, parseInt, parseFloat, isNaN, crypto: crypto.webcrypto, performance: { now: () => Date.now() } };
  vm.createContext(ctx);
  const src = fs.readFileSync(path.join(ROOT, 'shared.js'), 'utf8');
  vm.runInContext(src + '\n;this.G={CFG,CAT,CATI,ZONES,COOPS,COOPI,CSIM,envAt,condOK,hookTable,rollHook,rollSize,rollVariant,fishKg,catchPoints,sizeFrac,machOdds,machRoll,MACH,dropIds,DROP_ORDER,RARITY,SUPPLY,GEAR,BAIT,BOATI,pickW,rng,crewHaul,crewCheque,crewRtp,derbySpecies,timeOK};', ctx, { filename: 'shared.js' });
  return ctx.G;
})();
const CFG = G.CFG;

// ---------- operator config (the token address goes here) ----------
let CONF = { token: {}, adminToken: '', machine: {}, crew: {} };
try { CONF = Object.assign(CONF, JSON.parse(fs.readFileSync(path.join(ROOT, 'server', 'config.json'), 'utf8'))); } catch (e) { /* defaults */ }
const T = Object.assign({}, CFG.TOKEN, CONF.token || {});
if (process.env.GH_MINT) T.mint = process.env.GH_MINT;
if (process.env.GH_TREASURY) T.treasury = process.env.GH_TREASURY;
if (process.env.GH_RPC) T.rpc = process.env.GH_RPC;
if (process.env.GH_DECIMALS) T.decimals = +process.env.GH_DECIMALS;
const ADMIN = process.env.ADMIN_TOKEN || CONF.adminToken || '';
const LIVE = false; // Permanent: old config and GH_MODE cannot enable the retired token economy.
const RETIRED_ACTIONS = new Set(['nonce', 'auth', 'deposit', 'withdraw', 'pull', 'swap', 'xcode', 'xverify']);
const RETIRED_ERROR = 'Gullhaven is free to play with earned Shells. Wallets, tokens and capsule pulls are disabled.';
const UNIT = 10 ** (T.decimals || 6);
const HANDLE_RE = /^[A-Za-z0-9_]{1,15}$/;

// ---------- persistence ----------
let st = {
  v: 2, accounts: {},      // wallet -> {wallet, x, reel, licence, coop, coopSwitch, vote, voteFee, log:{}, pts:{day:pts}, raw, rawDay, season, owned:[], trips:{}, derby:{}}
  sessions: {},            // token -> wallet
  xhandles: {},            // lower-case X handle -> wallet
  xcodes: {},              // wallet -> {handle, code, at}
  licN: 1000,
  firsts: {}, aquarium: {}, trophies: {}, clean: 0,
  coopPts: {},             // day -> {coop: pts from real players}
  co: { pot: 0, carryIn: 0, bounty: 0, flows: {}, treasury: {}, fleet: {}, fees: {}, day: -1 },
  machine: { pool: CONF.machine && CONF.machine.seed != null ? +CONF.machine.seed : (LIVE ? 0 : CFG.MACHINE.seed), // live: only what the operator deposits (POST /admin/machine/deposit)
    drop: CFG.MACHINE.drop.n, minted: [], pulls: 0, paidOut: 0, taken: 0 },
  crewFund: CONF.crew && CONF.crew.seed != null ? +CONF.crew.seed : (LIVE ? 0 : CFG.CREW.fund.seed), // live: operator deposits (POST /admin/crew/deposit) plus fees
  ex: { s: CFG.EXCHANGE.pool0.s, r: CFG.EXCHANGE.pool0.r }, exHist: {}, exOut: {},
  derby: {},               // day -> {entries:{key: best cm}, pot}
  deposits: {},            // tx signature -> {wallet, amount, at}
  withdrawals: [],         // {id, wallet, amount, at, status, tx}
  awards: [],              // {id, wallet, nft, at, status, tx}
  ledger: [],              // last N money movements, for audit
  saves: {}                // wallet -> client save string (live mode)
};
try { const d = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); if (d && d.v === 2) st = Object.assign(st, d); } catch (e) { /* fresh */ }
st.co.fees = Object.assign({}, CFG.COOP.feeDefault);
let saveTimer = null;
function save() { clearTimeout(saveTimer); saveTimer = setTimeout(() => fs.writeFile(DATA_FILE + '.tmp', JSON.stringify(st), err => { if (!err) fs.rename(DATA_FILE + '.tmp', DATA_FILE, () => {}); }), 400); }
function audit(kind, wallet, amount, extra) { st.ledger.push(Object.assign({ t: Date.now(), kind, wallet, amount }, extra || {})); if (st.ledger.length > 5000) st.ledger.splice(0, st.ledger.length - 5000); }
function acct(w) { if (!st.accounts[w]) st.accounts[w] = { wallet: w, reel: 0, log: {}, pts: {}, season: 0, owned: [], trips: {}, derby: {} }; const a = st.accounts[w]; a.trips = a.trips || {}; a.owned = a.owned || []; a.derby = a.derby || {}; return a; }
const env = () => G.envAt(Date.now());
const secureRand = () => crypto.randomInt(0, 2 ** 32) / 2 ** 32;
const shortW = w => w ? w.slice(0, 4) + '…' + w.slice(-4) : 'Fisher';
const nameOf = a => a.x ? '@' + a.x : shortW(a.wallet);

// ---------- base58 + ed25519 (no external crypto deps) ----------
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58dec(s) { const bytes = [0]; for (const ch of s) { let v = B58.indexOf(ch); if (v < 0) throw new Error('b58'); for (let j = 0; j < bytes.length; j++) { v += bytes[j] * 58; bytes[j] = v & 255; v >>= 8; } while (v) { bytes.push(v & 255); v >>= 8; } } for (const ch of s) { if (ch !== '1') break; bytes.push(0); } return Buffer.from(bytes.reverse()); }
const SPKI = Buffer.from('302a300506032b6570032100', 'hex');
function verifySig(walletB58, msg, sigB58) { try { const pub = b58dec(walletB58); if (pub.length !== 32) return false; const key = crypto.createPublicKey({ key: Buffer.concat([SPKI, pub]), format: 'der', type: 'spki' }); return crypto.verify(null, Buffer.from(msg, 'utf8'), key, b58dec(sigB58)); } catch (e) { return false; } }

// ---------- Solana RPC: verify a deposit ----------
async function rpc(method, params) { const r = await fetch(T.rpc, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) }); const j = await r.json(); if (j.error) throw new Error(j.error.message || 'rpc'); return j.result; }
async function verifyDeposit(sig, wallet) {
  const tx = await rpc('getTransaction', [sig, { encoding: 'jsonParsed', commitment: 'finalized', maxSupportedTransactionVersion: 0 }]);
  if (!tx || !tx.meta || tx.meta.err) return { ok: false, err: 'Transaction not found yet (wait for it to finalize).' };
  const pre = tx.meta.preTokenBalances || [], post = tx.meta.postTokenBalances || [];
  const bal = (arr, owner) => arr.filter(b => b.mint === T.mint && b.owner === owner).reduce((s, b) => s + Number(b.uiTokenAmount.amount), 0);
  const got = bal(post, T.treasury) - bal(pre, T.treasury);
  const sent = bal(pre, wallet) - bal(post, wallet);
  if (got <= 0) return { ok: false, err: 'No $REEL reached the treasury in that transaction.' };
  if (sent < got) return { ok: false, err: 'That transfer did not come from your connected wallet.' };
  return { ok: true, amount: Math.floor(got / UNIT) };
}

// ---------- X handle: a code posted from the account, read through the public oEmbed endpoint ----------
function xCode(a, handle) {
  handle = String(handle || '').replace(/^@/, '').trim();
  if (!HANDLE_RE.test(handle)) return { err: 'That is not a valid X handle.' };
  const owner = st.xhandles[handle.toLowerCase()]; if (owner && owner !== a.wallet) return { err: 'That X handle is already linked to another wallet. One licence per person.' };
  const code = 'GH-' + crypto.randomBytes(4).toString('hex').toUpperCase();
  st.xcodes[a.wallet] = { handle, code, at: Date.now() }; save(); return { ok: true, code };
}
async function xVerify(a, url) {
  const pend = st.xcodes[a.wallet]; if (!pend || Date.now() - pend.at > 3 * 864e5) return { err: 'Get a new code first.' };
  const m = /^https?:\/\/(?:www\.|mobile\.)?(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})\/status(?:es)?\/(\d{5,25})/i.exec(String(url || '').trim());
  if (!m) return { err: 'Paste the link to your post (https://x.com/you/status/...).' };
  if (m[1].toLowerCase() !== pend.handle.toLowerCase()) return { err: `That post is from @${m[1]}, not @${pend.handle}.` };
  let j; try { const r = await fetch('https://publish.twitter.com/oembed?omit_script=1&dnt=true&url=' + encodeURIComponent(`https://twitter.com/${m[1]}/status/${m[2]}`), { headers: { 'user-agent': 'Gullhaven/1.0' } }); if (!r.ok) return { err: 'X could not find that post. Is the account public?' }; j = await r.json(); } catch (e) { return { err: 'Could not reach X. Try again in a minute.' }; }
  const au = /(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})\/?$/i.exec(String(j.author_url || ''));
  if (!au || au[1].toLowerCase() !== pend.handle.toLowerCase()) return { err: 'That post was not written by @' + pend.handle + '.' };
  if (!String(j.html || '').includes(pend.code)) return { err: `The post does not contain your code ${pend.code}.` };
  const key = au[1].toLowerCase(); const owner = st.xhandles[key]; if (owner && owner !== a.wallet) return { err: 'That X handle is already linked to another wallet.' };
  if (a.x && a.x.toLowerCase() !== key) delete st.xhandles[a.x.toLowerCase()];
  a.x = au[1]; st.xhandles[key] = a.wallet; delete st.xcodes[a.wallet]; save(); return { ok: true };
}

// ---------- the Cup, pools and co-ops (same simulation as the client, plus real players) ----------
// st.co.pot is today's real money for the Cup (yesterday's carry plus every fee paid in today); in PLAY mode the
// simulated town's fees are added on top so the race and the pools move.
function addFlow(kind, amt) { st.co.flows[kind] = (st.co.flows[kind] || 0) + amt; st.co.pot += amt; }
function pools(E) {
  const inf = G.CSIM.inflow(E.day, E.dmin, st.co.fees); const flows = Object.assign({}, LIVE ? {} : inf.flows);
  for (const [k, v] of Object.entries(st.co.flows)) flows[k] = Math.round((flows[k] || 0) + v);
  return { cup: Math.round(st.co.pot + (LIVE ? 0 : inf.cup)), carry: Math.round(st.co.carryIn), flows, bounty: Math.round(st.co.bounty + (LIVE ? 0 : inf.bounty)) };
}
function realPts(day) { return st.coopPts[day] || {}; }
function rollDay() {
  const E = env(); if (st.co.day < 0) { st.co.day = E.day; return; }
  let guard = 0;
  while (st.co.day < E.day && guard++ < 500) {
    const day = st.co.day; const inf = G.CSIM.inflow(day, 1440, st.co.fees);
    const pool = st.co.pot + (LIVE ? 0 : inf.cup);
    const real = realPts(day); const rows = G.CSIM.standings(day, 1440, real); const pay = G.CSIM.payout(pool, rows); let rolled = 0;
    for (const p of pay) {
      const id = p.id;
      const members = Object.values(st.accounts).filter(a => a.coop === id && (a.pts[day] || 0) >= CFG.CUP.minPts);
      const realTotal = members.reduce((s, a) => s + a.pts[day], 0);
      const voters = Object.values(st.accounts).filter(a => a.coop === id && a.vote);
      const sp = G.CSIM.split(id, voters.map(a => ({ split: a.vote, act: a.pts[day] || 0 })));
      st.co.fees[id] = G.CSIM.fee(id, voters.map(a => ({ fee: a.voteFee })), st.co.fees[id]);
      const tr = p.treasury + (LIVE ? 0 : (inf.treasury[id] || 0)) + (st.co.trIn && st.co.trIn[id] || 0);
      st.co.treasury[id] = (st.co.treasury[id] || 0) + tr * (sp.reserve + sp.bait + sp.workshop) / 100;
      st.co.fleet[id] = (st.co.fleet[id] || 0) + tr * sp.fleet / 100;
      // the AI crews set the placings; the members' share goes to the real members who fished (by points), plus the
      // dividend bucket. Nobody qualified? The members' share rolls into tomorrow's Cup instead.
      const memberPot = p.members + tr * sp.dividends / 100;
      if (!members.length) { rolled += memberPot; continue; }
      for (const a of members) { const amt = Math.floor(memberPot * a.pts[day] / Math.max(1, realTotal)); if (amt > 0) { a.reel += amt; audit('cup', a.wallet, amt, { day, coop: id, place: p.place, pts: a.pts[day] }); } }
    }
    settleDerby(day);
    // a Crew Fund far above its target spills the surplus into the next day's Cup
    const spill = Math.max(0, st.crewFund - 2 * CFG.CREW.fund.target); if (spill > 0) { st.crewFund -= spill; audit('spill', 'crewfund', spill); }
    st.co.pot = pool * (1 - CFG.CUP.payoutFrac) + rolled; st.co.carryIn = st.co.pot; st.co.flows = {}; if (spill > 0) addFlow('spill', spill); st.co.lastDay = { day, pool: Math.round(pool), rolled: Math.round(rolled), spill: Math.round(spill), win: rows[0].id }; st.co.trIn = {};
    if (!LIVE) st.co.bounty += inf.bounty;
    st.exHist[day] = st.ex.r / st.ex.s; for (const d of Object.keys(st.exHist)) if (+d < day - 30) delete st.exHist[d];
    delete st.coopPts[day - 3]; delete st.derby[day - 3]; st.exOut = {}; st.co.day++;
  }
  save();
}
setInterval(() => { const before = st.co.day; rollDay(); if (st.co.day !== before) broadcastState(); }, 5000);
// points for a co-op, with the per-licence daily soft cap
function scorePts(a, raw, day) {
  a.raw = a.rawDay === day ? (a.raw || 0) : 0; a.rawDay = day; let left = raw, got = 0; const cap = CFG.CUP.softCap, tp = CFG.CUP.taper;
  while (left > 0) { const r0 = a.raw; const band = r0 < cap[0] ? 0 : r0 < cap[1] ? 1 : 2; const room = band < 2 ? cap[band] - r0 : left; const take = Math.min(left, room); got += take * tp[band]; a.raw += take; left -= take; }
  got = Math.round(got * 10) / 10;
  if (a.licence && a.coop && got > 0) { a.pts[day] = (a.pts[day] || 0) + got; a.season = (a.season || 0) + got; const cp = st.coopPts[day] || (st.coopPts[day] = {}); cp[a.coop] = (cp[a.coop] || 0) + got; }
  return a.licence && a.coop ? got : 0;
}

// ---------- the Founding Fisher machine ----------
function machineSync() { const M = G.MACH; M.pool = st.machine.pool; M.drop = st.machine.drop; M.minted = new Set(st.machine.minted); }
const dropLeft = () => G.dropIds(st.machine.drop).filter(id => !st.machine.minted.includes(id));
function pullMachine(a, ti) {
  const t = CFG.MACHINE.tiers[ti]; if (!t) return { err: 'No such capsule.' };
  if (LIVE) { if (!a) return { err: 'Connect your wallet first.' }; if (a.reel < t.price) return { err: `A ${t.n} capsule is ${t.price.toLocaleString()} $REEL.` }; a.reel -= t.price; }
  addFlow('machine', t.price * CFG.CUPFEED.machine);
  machineSync();
  st.machine.pool += t.price * CFG.MACHINE.poolTake; st.crewFund += t.price * (CFG.MACHINE.crewTake || 0); st.machine.taken += t.price; st.machine.pulls++; G.MACH.pool = st.machine.pool;
  const out = G.machRoll(ti, secureRand());
  if (out.kind === 'nft') {
    const ids = dropLeft(); if (!ids.length) { out.kind = 'mult'; out.m = .5; }
    else { const w = ids.map(id => [6, 3, 1.2, .4][G.RARITY[id]]); let x = secureRand() * w.reduce((s, v) => s + v, 0), pick = ids[ids.length - 1]; for (let i = 0; i < ids.length; i++) { x -= w[i]; if (x <= 0) { pick = ids[i]; break; } }
      out.id = pick; st.machine.minted.push(pick); if (a) { a.owned = (a.owned || []).concat(pick); if (LIVE) st.awards.push({ id: crypto.randomUUID(), wallet: a.wallet, nft: pick, at: Date.now(), status: 'queued' }); } }
  }
  out.pay = 0; if (out.kind === 'mult') { out.pay = Math.round(out.m * t.price); st.machine.pool -= out.pay; st.machine.paidOut += out.pay; if (LIVE) a.reel += out.pay; }
  if (LIVE) audit('pull', a.wallet, -t.price, { ti, out: out.kind, m: out.m, id: out.id, pay: out.pay });
  save(); return { out: { kind: out.kind, m: out.m, id: out.id } };
}

// ---------- catches (LIVE): the server rolls the bite, the phone plays the fight ----------
const pending = new Map(); // tok -> {wallet, roll, at, zone}
function rollCast(a, m) {
  const now = Date.now(); if (a.lastCast && now - a.lastCast < 3000) return { err: 'Easy, one cast at a time.' };
  a.lastCast = now; const zone = G.ZONES[m.zone] && G.ZONES[m.zone].depth ? m.zone : 'harbour'; const E = env();
  const gr = m.gear || {}; const tier = (k, max) => Math.max(-1, Math.min(max, gr[k] | 0));
  const reel = G.GEAR.reel[Math.max(0, tier('reel', 4))], hook = G.GEAR.hook[Math.max(0, tier('hook', 2))];
  const near = {}; for (const k of Array.isArray(m.near) ? m.near : []) if (['birds', 'debris', 'schools'].includes(k)) near[k] = true;
  const ctx = { zone, bait: G.BAIT[m.bait] ? m.bait : 'dough', gear: { rodT: Math.max(0, tier('rod', 4)), deepreel: !!reel.deep, lamp: tier('lamp', 1) >= 0 && G.timeOK('night', E.hour), hookSnag: hook.snag }, env: E, near, shadowR: m.shadow == null ? null : Math.max(0, Math.min(3, m.shadow | 0)) };
  const r = G.rollHook(ctx, secureRand); if (!r) return { ok: true };
  const tok = crypto.randomBytes(9).toString('base64url'); pending.set(tok, { wallet: a.wallet, roll: { id: r.e.id, cm: r.cm, v: r.v, kg: r.kg }, at: now });
  return { ok: true, tok, id: r.e.id, cm: r.cm, v: r.v, kg: r.kg };
}
function landed(a, tok) {
  const p = pending.get(String(tok || '')); if (!p || p.wallet !== a.wallet) return { err: 'No fish on the line.' }; pending.delete(tok);
  const age = Date.now() - p.at; if (age < 2500) return { err: 'Too quick.' }; if (age > 240000) return { err: 'It got away while you waited.' };
  const e = G.CATI[p.roll.id]; const E = env(); const day = E.day; const L = a.log[e.id] || (a.log[e.id] = { n: 0, best: 0 }); const isNew = !L.n; L.n++; if (p.roll.cm > L.best) L.best = p.roll.cm;
  let raw = G.catchPoints(e, p.roll.cm, p.roll.v); if (isNew) raw += CFG.CUP.firstBonus * (e.r + 1) / 2; if (e.cat === 'legend') raw += CFG.CUP.legendBonus;
  const got = scorePts(a, raw, day);
  let first = false; if (!st.firsts[e.id]) { st.firsts[e.id] = nameOf(a); first = true; }
  let bounty = 0; if (e.cat === 'legend' && a.licence) { bounty = Math.floor(st.co.bounty * CFG.BOUNTY.share); if (bounty > 0) { st.co.bounty -= bounty; a.reel += bounty; audit('bounty', a.wallet, bounty, { id: e.id }); } }
  if (a.coop && (e.cat === 'fish' || e.cat === 'legend') && e.r >= 2) trophy(a.coop, e, p.roll.cm, nameOf(a));
  const D = st.derby[day]; const sp = G.derbySpecies(day); if (D && D.entries[a.wallet] != null && sp && sp.id === e.id && p.roll.cm > D.entries[a.wallet]) D.entries[a.wallet] = p.roll.cm;
  save(); return { ok: true, pts: got, first, bounty, isNew };
}
function trophy(co, e, cm, n) { const list = st.trophies[co] || (st.trophies[co] = []); const cur = list.find(q => q.id === e.id); if (!cur || cur.cm < cm) { if (cur) list.splice(list.indexOf(cur), 1); list.push({ id: e.id, cm, n }); if (list.length > 40) list.shift(); } }

// ---------- crew trips (LIVE) ----------
function crewLv(a, id) { a.crewLv = a.crewLv || {}; return a.crewLv[id] || (a.crewLv[id] = { lvl: 1, xp: 0 }); }
function crewOk(a, id) { const m = /^(nft|hand):(\d{1,3})$/.exec(String(id || '')); if (!m) return false; if (m[1] === 'nft') return a.owned.includes(+m[2]); return +m[2] < CFG.CREW.maxHired; }
function crewSend(a, m) {
  if (!a.licence) return { err: 'Crew fish under your licence.' }; if (!crewOk(a, m.crew)) return { err: 'That is not one of your crew.' };
  if (a.trips[m.crew]) return { err: 'Already out.' }; const ti = m.trip | 0; const T2 = CFG.CREW.trips[ti]; if (!T2) return { err: 'No such trip.' };
  const zone = G.ZONES[m.zone] && G.ZONES[m.zone].depth ? m.zone : 'harbour'; if (a.reel < T2.fee) return { err: `That trip is ${T2.fee.toLocaleString()} $REEL.` };
  a.reel -= T2.fee; const sp = CFG.CREW.split; addFlow('crew', T2.fee * sp.cup); st.crewFund += T2.fee * sp.pool; if (a.coop) { st.co.trIn = st.co.trIn || {}; st.co.trIn[a.coop] = (st.co.trIn[a.coop] || 0) + T2.fee * sp.treasury; }
  const now = Date.now(); a.trips[m.crew] = { zone, trip: ti, start: now, end: now + T2.min * 60000, seed: crypto.randomInt(0, 2 ** 31), lvl: crewLv(a, m.crew).lvl };
  audit('crew', a.wallet, -T2.fee, { crew: m.crew, trip: ti }); save(); return { ok: true, start: now, end: a.trips[m.crew].end };
}
function crewIn(a, m) {
  const t = a.trips[m.crew]; if (!t) return { err: 'Not out.' }; if (Date.now() < t.end) return { err: 'Not back yet.' }; delete a.trips[m.crew];
  const nft = String(m.crew).startsWith('nft:'); const rar = nft ? (G.RARITY[+String(m.crew).slice(4)] || 0) : 0;
  const haul = G.crewHaul({ zone: t.zone, trip: t.trip, start: t.start, nft, rar, lvl: t.lvl }, G.rng(t.seed));
  let shells = 0, raw = 0; for (const h of haul) { const e = G.CATI[h.id]; shells += Math.round(e.price * (.7 + .8 * G.sizeFrac(e, h.cm || 0))); raw += G.catchPoints(e, h.cm, '') * CFG.CREW.ptsShare; }
  const pts = scorePts(a, raw, env().day);
  const ch = G.crewCheque({ nft, rar, lvl: t.lvl, trip: t.trip }, st.crewFund, G.rng(t.seed + 77));
  if (ch.amt > 0) { st.crewFund -= ch.amt; a.reel += ch.amt; audit('crewcheque', a.wallet, ch.amt, { crew: m.crew, m: ch.m }); }
  const L = crewLv(a, m.crew); L.xp += haul.length; while (L.xp >= L.lvl * 25) { L.xp -= L.lvl * 25; L.lvl++; }
  save(); return { ok: true, haul, shells, pts, reel: ch.amt, m: ch.m, lvl: L.lvl, xp: L.xp };
}

// ---------- the derby ----------
function derbyEnter(a, key) { const E = env(); const D = st.derby[E.day] || (st.derby[E.day] = { entries: {}, pot: CFG.DERBY.reward }); if (D.entries[key] != null) return { err: 'Already entered today.' };
  D.entries[key] = 0; D.pot = CFG.DERBY.reward; save(); return { ok: true }; }
function settleDerby(day) { const D = st.derby[day]; if (!D || D.paid) return; D.paid = true; const best = Object.entries(D.entries).filter(([, cm]) => cm > 0).sort((x, y) => y[1] - x[1])[0];
  if (!best) { st.co.pot += D.pot; return; } if (LIVE && st.accounts[best[0]]) { st.accounts[best[0]].reel += Math.floor(D.pot); audit('derbywin', best[0], Math.floor(D.pot), { day }); } D.winner = best[0]; }
function derbyPublic(E) { const D = st.derby[E.day]; if (!D) return { day: E.day, n: 0, top: [], pot: 0 }; const top = Object.values(D.entries).filter(cm => cm > 0).sort((x, y) => y - x).slice(0, 5); return { day: E.day, n: Object.keys(D.entries).length, top, pot: Math.round(D.pot) }; }

// ---------- the Harbour Exchange (one constant-product pool) ----------
function swap(a, c, m) {
  const dir = m.dir === 's2r' ? 's2r' : 'r2s'; const amt = Math.floor(Number(m.amt) || 0); if (amt <= 0) return { err: 'Amount?' };
  if (LIVE && dir === 's2r') return { err: 'On the live harbour the exchange only sells Shells.' };
  if (LIVE && (!a || a.reel < amt)) return { err: 'Not enough $REEL.' };
  const P = st.ex, f = CFG.EXCHANGE.fee, k = P.s * P.r, inn = amt * (1 - f);
  let out;
  if (dir === 's2r') { out = Math.floor(P.r - k / (P.s + inn)); const key = c.cid || c.key; const used = st.exOut[key] || 0; if (used + out > CFG.EXCHANGE.dailyReelOut) return { err: `The exchange pays out at most ${CFG.EXCHANGE.dailyReelOut.toLocaleString()} $REEL per person a day.` }; st.exOut[key] = used + out; P.s += inn; P.r -= out; addFlow('exchange', amt * f * (P.r / P.s) * CFG.CUPFEED.exchange); }
  else { out = Math.floor(P.s - k / (P.r + inn)); P.r += inn; P.s -= out; if (LIVE) { a.reel -= amt; audit('swap', a.wallet, -amt, { shells: out }); } addFlow('exchange', amt * f * CFG.CUPFEED.exchange); }
  save(); return { ok: true, out };
}

// ---------- http: the game and the admin API ----------
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.png': 'image/png', '.json': 'application/json', '.css': 'text/css' };
function json(res, code, obj) { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(obj)); }
function body(req) { return new Promise(r => { let b = ''; req.on('data', d => { b += d; if (b.length > 1e5) req.destroy(); }); req.on('end', () => { try { r(JSON.parse(b || '{}')); } catch (e) { r({}); } }); }); }
const server = http.createServer(async (req, res) => {
  const u = new URL(req.url || '/', 'http://x'); const p = decodeURIComponent(u.pathname);
  if (p === '/favicon.ico') { res.writeHead(204); return res.end(); }
  if (p === '/health') return json(res, 200, { ok: true, live: false, mode: 'free', currency: 'Shells', gacha: false, online: clients.size, cup: pools(env()).cup });
  if (/^\/(?:token|deposit|withdraw|pull|swap)(?:\/|$)/.test(p)) return json(res, 410, { err: RETIRED_ERROR, code: 'FREE_PLAY_ONLY' });
  if (p.startsWith('/admin/')) {
    if (!ADMIN || req.headers['x-admin-token'] !== ADMIN) return json(res, 403, { err: 'forbidden' });
    if (/^\/admin\/(?:withdrawals|awards|machine|drop)(?:\/|$)/.test(p) || p === '/admin/crew/deposit') return json(res, 410, { err: RETIRED_ERROR, code: 'FREE_PLAY_ONLY' });
    if (p === '/admin/queue') return json(res, 200, { withdrawals: [], awards: [], mode: 'free', pools: pools(env()), treasuries: st.co.treasury, fleet: st.co.fleet, fees: st.co.fees });
    if (p === '/admin/ledger') return json(res, 200, st.ledger.slice(-500));
    if (req.method === 'POST') { const b = await body(req); let m;
      if ((m = /^\/admin\/withdrawals\/([\w-]+)\/(paid|reject)$/.exec(p))) { const w = st.withdrawals.find(x => x.id === m[1]); if (!w || w.status !== 'queued') return json(res, 404, { err: 'not found' }); if (m[2] === 'paid') { w.status = 'paid'; w.tx = String(b.tx || ''); } else { w.status = 'rejected'; acct(w.wallet).reel += w.amount; audit('refund', w.wallet, w.amount); pushAcct(w.wallet); } save(); return json(res, 200, w); }
      if ((m = /^\/admin\/awards\/([\w-]+)\/sent$/.exec(p))) { const a = st.awards.find(x => x.id === m[1]); if (!a) return json(res, 404, { err: 'not found' }); a.status = 'sent'; a.tx = String(b.tx || ''); save(); return json(res, 200, a); }
      if (p === '/admin/machine/deposit') { const amt = Math.max(0, Number(b.amount) || 0); st.machine.pool += amt; audit('seed', 'operator', amt, { tx: b.tx || '' }); save(); broadcastState(); return json(res, 200, st.machine); }
      if (p === '/admin/crew/deposit') { const amt = Math.max(0, Number(b.amount) || 0); st.crewFund += amt; audit('crewseed', 'operator', amt, { tx: b.tx || '' }); save(); broadcastState(); return json(res, 200, { crewFund: st.crewFund }); }
      if (p === '/admin/drop/next') { st.machine.drop = Math.min(G.SUPPLY / CFG.MACHINE.drop.size, st.machine.drop + 1); save(); broadcastState(); return json(res, 200, st.machine); }
      if (p === '/admin/coop/fee') { const id = String(b.coop || ''); if (!G.COOPI[id]) return json(res, 400, { err: 'coop' }); st.co.fees[id] = Math.max(0, Math.min(CFG.COOP.feeCap, Number(b.fee) || 0)); save(); broadcastState(); return json(res, 200, st.co.fees); }
      if (p === '/admin/cup/seed') { const amt = Math.max(0, Number(b.amount) || 0); st.co.pot += amt; audit('cupseed', 'operator', amt, { tx: b.tx || '' }); save(); broadcastState(); return json(res, 200, pools(env())); }
    }
    return json(res, 404, { err: 'unknown admin route' });
  }
  const file = path.join(PUBLIC, p === '/' ? 'index.html' : p);
  if (!file.startsWith(PUBLIC)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, buf) => { if (err) { res.writeHead(404); return res.end('Not found'); } res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-cache' }); res.end(buf); });
});

// ---------- websockets ----------
const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 256 * 1024 });
const clients = new Map(); // ws -> {key, cid, p, wallet, nonce, t:{}}
let seq = 0;
const send = (ws, m) => { if (ws.readyState === 1) ws.send(JSON.stringify(m)); };
const broadcast = m => { const s = JSON.stringify(m); for (const ws of clients.keys()) if (ws.readyState === 1) ws.send(s); };
function publicState() { const E = env(); return { firsts: st.firsts, aquarium: st.aquarium, minted: [], machine: { enabled: false, pool: 0, drop: 0 }, coopPts: realPts(E.day), coopPtsY: realPts(E.day - 1),
  co: { pools: pools(E), treasury: st.co.treasury, fleet: st.co.fleet, fees: Object.assign({}, CFG.COOP.feeDefault, st.co.fees), day: st.co.day, ex: { s: Math.round(st.ex.s), r: Math.round(st.ex.r) }, exHist: st.exHist }, derby: derbyPublic(E), crewFund: Math.round(st.crewFund), trophies: st.trophies, clean: st.clean }; }
let stateDirty = false; function broadcastState() { stateDirty = true; }
setInterval(() => { if (stateDirty) { stateDirty = false; broadcast({ t: 'state', state: publicState() }); } }, 1500);
setInterval(broadcastState, 60000); // the simulated town keeps moving the pools
function acctMsg(w) { const a = acct(w); const s = Object.entries(st.sessions).find(([, v]) => v === w); return { wallet: w, x: a.x || null, bal: Math.floor(a.reel), licence: a.licence || null, coop: a.coop || null, owned: a.owned || [], crew: a.trips, session: s ? s[0] : null }; }
function pushAcct(w) { for (const [ws, c] of clients) if (c.wallet === w) send(ws, { t: 'acct', acct: acctMsg(w) }); }
function cleanPresence(p) {
  if (!p || typeof p !== 'object') return null;
  const num = (v, a, b) => Math.max(a, Math.min(b, Number(v) || 0));
  const hex = v => /^#[0-9a-f]{6}$/i.test(v) ? v : null;
  const text = (v, n) => String(v || '').replace(/[\u0000-\u001f]/g, '').slice(0, n);
  const b = p.b && typeof p.b === 'object' && G.BOATI[p.b.k] ? { k: p.b.k, h: num(p.b.h, 0, 15) | 0, p: hex(p.b.p), de: ['none', 'lifebuoy', 'crates', 'flowers'].includes(p.b.de) ? p.b.de : 'none', n: text(p.b.n, 24) } : null;
  const home = p.home && typeof p.home === 'object' ? { theme: ['coastal', 'sunset', 'woodland'].includes(p.home.theme) ? p.home.theme : 'coastal', decor: Array.isArray(p.home.decor) ? [...new Set(p.home.decor.filter(k => ['plant', 'table', 'books', 'net', 'model', 'tank'].includes(k)))].slice(0, 8) : [] } : null;
  const ht = /^[a-z0-9]{1,20}$/.test(p.ht) ? p.ht : null;
  const l = p.look;
  const look = l && typeof l === 'object' ? { base: num(l.base, 1, 500) | 0, skin: hex(l.skin), hs: num(l.hs, 0, 5) | 0, hair: l.hair === 'prism' ? 'prism' : hex(l.hair), eyes: num(l.eyes, 0, 4) | 0, mouth: num(l.mouth, 0, 3) | 0, shirt: hex(l.shirt), pants: hex(l.pants), pat: num(l.pat, 0, 3) | 0, acc: num(l.acc, 0, 10) | 0 } : null;
  return { x: num(p.x, 0, 20000), y: num(p.y, 0, 20000), d: ['down', 'up', 'left', 'right'].includes(p.d) ? p.d : 'down', m: p.m ? 1 : 0, id: num(p.id, 1, 1e9) | 0, n: text(p.n || 'Fisher', 16), sc: /^[a-z0-9:_]{1,48}$/.test(p.sc) ? p.sc : 'world', co: G.COOPI[p.co] ? p.co : null, b, home, ht, look, e: typeof p.e === 'string' ? p.e.slice(0, 8) : null, et: num(p.et, 0, 9e15), f: p.f ? 1 : 0 };
}
function limit(c, k, ms) { const now = Date.now(); if (now - (c.t[k] || 0) < ms) return false; c.t[k] = now; return true; }
wss.on('connection', ws => {
  const c = { key: 'p' + (++seq), cid: null, p: null, wallet: null, nonce: null, t: {}, alive: true };
  clients.set(ws, c); ws.on('pong', () => { c.alive = true; });
  ws.on('message', async raw => {
    let m; try { m = JSON.parse(raw); } catch (e) { return; }
    if (!m || typeof m !== 'object') return;
    const reply = o => send(ws, Object.assign({ t: 'res', q: m.q }, o));
    if (RETIRED_ACTIONS.has(m.t)) return reply({ err: RETIRED_ERROR, code: 'FREE_PLAY_ONLY' });
    const a = c.wallet ? acct(c.wallet) : null;
    const needLive = () => { if (!LIVE) { reply({ err: 'This action belongs to the retired token game. Use your local Shells progression.', code: 'FREE_PLAY_ONLY' }); return false; } if (!a) { reply({ err: 'Connect your wallet first (Menu > Wallet).' }); return false; } return true; };
    try {
      switch (m.t) {
        case 'hello': { c.cid = String(m.cid || c.key).slice(0, 64);
          send(ws, { t: 'welcome', you: c.key, live: false, mode: 'free', currency: 'Shells', mint: '', treasury: '', decimals: 0, rpc: '', state: publicState(), acct: null }); break; }
        case 'p': c.p = cleanPresence(m.p); break;
        case 'chat': { if (!limit(c, 'chat', 800)) return; const text = String(m.text || '').replace(/[\u0000-\u001f]/g, '').slice(0, 90).trim(); if (!text) return; for (const [w2] of clients) if (w2 !== ws) send(w2, { t: 'chat', id: c.key, n: a && a.x ? '@' + a.x : (c.p ? c.p.n : 'Someone'), text }); break; }
        case 'news': { if (!limit(c, 'news', 3000)) return; for (const [w2] of clients) if (w2 !== ws) send(w2, { t: 'news', id: c.key, n: a && a.x ? '@' + a.x : (c.p ? c.p.n : 'Someone'), msg: String(m.msg || '').slice(0, 140), type: m.type === 'legend' || m.type === 'rare' ? m.type : null }); break; }
        // ---- shared registry (both modes) ----
        case 'first': { if (LIVE) return; const id = String(m.id || ''); if (!G.CATI[id] || st.firsts[id]) return; st.firsts[id] = c.p ? c.p.n : 'Fisher'; save(); broadcastState(); break; }
        case 'donate': { const id = String(m.id || ''); if (!G.CATI[id] || st.aquarium[id]) return; if (!limit(c, 'donate', 2000)) return; st.aquarium[id] = { n: a ? nameOf(a) : (c.p ? c.p.n : 'Fisher'), at: Date.now() }; save(); broadcastState(); break; }
        case 'catch': { if (LIVE) return; if (!limit(c, 'catch', 1200)) return; const co = G.COOPI[m.co] ? m.co : null; const pts = Math.max(0, Math.min(400, Number(m.pts) || 0)); const d = env().day;
          if (co && pts) { const cp = st.coopPts[d] || (st.coopPts[d] = {}); cp[co] = (cp[co] || 0) + pts; broadcastState(); }
          const e = G.CATI[m.id]; if (co && e && (e.cat === 'fish' || e.cat === 'legend') && e.r >= 2 && m.cm) trophy(co, e, Math.min(e.sz[1], Number(m.cm) || 0), c.p ? c.p.n : 'Fisher'); save(); break; }
        case 'clean': { const n = Math.max(0, Math.min(40, m.n | 0)); st.clean += n; broadcastState(); break; }
        // play mode: fees paid with play balances still feed the shared play Cup (live fees are charged here instead)
        case 'fee': { if (LIVE || !limit(c, 'fee', 1000)) return; const amt = Math.max(0, Math.min(200000, Number(m.amt) || 0)); const k = String(m.kind || '');
          if (k === 'licence') { addFlow('licence', amt * CFG.LICENCE.split.cup); st.co.bounty += amt * CFG.LICENCE.split.bounty; st.machine.pool += amt * CFG.LICENCE.split.machine; }
          else if (/^coop_\w+$/.test(k) && G.COOPI[k.slice(5)]) { addFlow('coop', amt * CFG.COOP.split.cup); st.co.trIn = st.co.trIn || {}; st.co.trIn[k.slice(5)] = (st.co.trIn[k.slice(5)] || 0) + amt * CFG.COOP.split.treasury; }
          else if (k === 'crew') { addFlow('crew', amt * CFG.CREW.split.cup); st.crewFund += amt * CFG.CREW.split.pool; }
          else if (k === 'cosmetic') addFlow('cosmetic', amt * CFG.CUPFEED.cosmetic);
          else return; save(); broadcastState(); break; }
        // ---- wallet sign-in ----
        case 'nonce': { const w = String(m.wallet || ''); if (!/^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(w)) return reply({ err: 'Bad wallet address.' }); c.nonce = { w, msg: `Gullhaven sign-in\nWallet: ${w}\nNonce: ${crypto.randomBytes(12).toString('hex')}\nIssued: ${new Date().toISOString()}` }; return reply({ msg: c.nonce.msg }); }
        case 'auth': { if (!c.nonce || c.nonce.w !== m.wallet) return reply({ err: 'Ask for a sign-in message first.' }); const ok = verifySig(m.wallet, c.nonce.msg, String(m.sig || '')); c.nonce = null; if (!ok) return reply({ err: 'Signature did not verify.' });
          c.wallet = m.wallet; const tok = crypto.randomBytes(24).toString('hex'); for (const [k, v] of Object.entries(st.sessions)) if (v === m.wallet) delete st.sessions[k]; st.sessions[tok] = m.wallet; acct(m.wallet); save(); return reply({ ok: true, acct: acctMsg(m.wallet) }); }
        case 'save': { if (!c.wallet || !limit(c, 'save', 4000)) return; const s = String(m.s || ''); if (s.length < 2e5) { st.saves[c.wallet] = s; save(); } break; }
        // ---- X handle (no API key: a code in a public post, read through oEmbed) ----
        case 'xcode': { if (!needLive()) return; if (!limit(c, 'xcode', 3000)) return reply({ err: 'Slow down.' }); return reply(xCode(a, m.handle)); }
        case 'xverify': { if (!needLive()) return; if (!limit(c, 'xverify', 5000)) return reply({ err: 'One check every few seconds.' }); const r = await xVerify(a, m.url); return reply(r.ok ? { ok: true, acct: acctMsg(a.wallet) } : r); }
        // ---- licences and co-ops (live) ----
        case 'licence': { if (!needLive()) return; if (a.licence) return reply({ err: 'You already have a licence.' }); if (!a.x) return reply({ err: 'Verify your X handle first. One licence per person.' });
          const fee = CFG.LICENCE.fee; if (a.reel < fee) return reply({ err: `The licence is ${fee.toLocaleString()} $REEL. Deposit first.` }); a.reel -= fee; const sp = CFG.LICENCE.split;
          addFlow('licence', fee * sp.cup); st.co.bounty += fee * sp.bounty; st.machine.pool += fee * sp.machine; a.licence = { no: ++st.licN, at: Date.now(), x: a.x }; audit('licence', a.wallet, -fee); save(); broadcastState(); return reply({ ok: true, acct: acctMsg(a.wallet) }); }
        case 'join': { if (!needLive()) return; if (!a.licence) return reply({ err: 'Licence first.' }); const id = String(m.co || ''); if (!G.COOPI[id]) return reply({ err: 'No such co-op.' }); if (a.coop === id) return reply({ ok: true, acct: acctMsg(a.wallet) });
          const wk = env().wk; if (a.coop && a.coopSwitchWk === wk && (a.coopSwitch || 0) >= CFG.COOP.switchPerSeason) return reply({ err: 'One co-op switch per season (a real week).' });
          const fee = st.co.fees[id] != null ? st.co.fees[id] : CFG.COOP.feeDefault[id]; if (a.reel < fee) return reply({ err: `The entry fee is ${fee.toLocaleString()} $REEL.` });
          a.reel -= fee; st.co.trIn = st.co.trIn || {}; st.co.trIn[id] = (st.co.trIn[id] || 0) + fee * CFG.COOP.split.treasury; addFlow('coop', fee * CFG.COOP.split.cup);
          if (a.coop) { a.coopSwitch = a.coopSwitchWk === wk ? (a.coopSwitch || 0) + 1 : 1; a.coopSwitchWk = wk; } a.coop = id; a.vote = null; audit('coop', a.wallet, -fee, { coop: id }); save(); broadcastState(); return reply({ ok: true, acct: acctMsg(a.wallet) }); }
        case 'vote': { if (!a || !a.coop || a.coop !== m.co) return; const v = {}; let tot = 0; for (const k of CFG.COOP.buckets) { v[k] = Math.max(0, Math.min(100, Number(m.v && m.v[k]) || 0)); tot += v[k]; } if (tot > 0) { for (const k in v) v[k] = Math.round(v[k] / tot * 100); a.vote = v; }
          if (m.fee != null) a.voteFee = Math.max(CFG.COOP.feeMin, Math.min(CFG.COOP.feeCap, Math.round(Number(m.fee) || 0))); save(); break; }
        // ---- catches (live: the server rolls) ----
        case 'cast': { if (!needLive()) return; return reply(rollCast(a, m)); }
        case 'land': { if (!needLive()) return; const r = landed(a, m.tok); if (r.err) return reply(r); broadcastState(); return reply(Object.assign(r, { acct: acctMsg(a.wallet) })); }
        case 'lost': { const tok = String(m.tok || ''); const p2 = pending.get(tok); if (p2 && a && p2.wallet === a.wallet) pending.delete(tok); break; }
        // ---- crew ----
        case 'crew': { if (!needLive()) return; const r = crewSend(a, m); if (r.err) return reply(r); broadcastState(); return reply(Object.assign(r, { acct: acctMsg(a.wallet) })); }
        case 'crewin': { if (!needLive()) return; const r = crewIn(a, m); if (r.err) return reply(r); broadcastState(); return reply(Object.assign(r, { acct: acctMsg(a.wallet) })); }
        // ---- the derby ----
        case 'derby': { const key = LIVE ? (a && a.wallet) : (c.cid || c.key); if (LIVE && !needLive()) return; const r = derbyEnter(a, key); if (r.err) return reply(r); broadcastState(); return reply(Object.assign(r, a ? { acct: acctMsg(a.wallet) } : {})); }
        case 'derbybest': { if (LIVE) return; const D = st.derby[env().day]; const key = c.cid || c.key; if (!D || D.entries[key] == null) return; const sp = G.derbySpecies(env().day); const cm = Math.max(0, Math.min(sp.sz[1], Number(m.cm) || 0)); if (cm > D.entries[key]) { D.entries[key] = cm; broadcastState(); } break; }
        // ---- cosmetics: paint and boat names, the whole fee goes to the Cup ----
        case 'cosmetic': { if (!needLive()) return; const cost = m.kind === 'paint' ? CFG.COSMETIC.paint : CFG.COSMETIC.boatName; if (a.reel < cost) return reply({ err: `That costs ${cost.toLocaleString()} $REEL.` }); a.reel -= cost; addFlow('cosmetic', cost * CFG.CUPFEED.cosmetic); audit('cosmetic', a.wallet, -cost, { what: m.kind === 'paint' ? 'paint' : 'name' }); save(); broadcastState(); return reply({ ok: true, acct: acctMsg(a.wallet) }); }
        // ---- the exchange ----
        case 'swap': { if (!limit(c, 'swap', 800)) return reply({ err: 'Slow down.' }); const r = swap(a, c, m); if (r.err) return reply(r); broadcastState(); return reply(Object.assign(r, a && LIVE ? { acct: acctMsg(a.wallet) } : {})); }
        // ---- the machine (both modes: the pool and the 500 are shared) ----
        case 'pull': { if (!limit(c, 'pull', 1200)) return reply({ err: 'One capsule at a time.' }); if (LIVE && !needLive()) return;
          const ti = Math.max(0, Math.min(CFG.MACHINE.tiers.length - 1, m.tier | 0)); const r = pullMachine(a, ti); if (r.err) return reply({ err: r.err }); broadcastState(); return reply(Object.assign({ ok: true, out: r.out }, a ? { acct: acctMsg(a.wallet) } : {})); }
        // ---- deposits and withdrawals (live) ----
        case 'deposit': { if (!needLive()) return; const sig = String(m.sig || ''); if (!/^[1-9A-HJ-NP-Za-km-z]{60,100}$/.test(sig)) return reply({ err: 'That is not a transaction signature.' }); if (st.deposits[sig]) return reply({ err: 'That deposit was already credited.' });
          const v = await verifyDeposit(sig, a.wallet); if (!v.ok) return reply({ err: v.err }); if (st.deposits[sig]) return reply({ err: 'Already credited.' }); st.deposits[sig] = { wallet: a.wallet, amount: v.amount, at: Date.now() }; a.reel += v.amount; audit('deposit', a.wallet, v.amount, { sig }); save(); return reply({ ok: true, amount: v.amount, acct: acctMsg(a.wallet) }); }
        case 'withdraw': { if (!needLive()) return; const amt = Math.floor(Number(m.amount) || 0); if (amt <= 0) return reply({ err: 'Amount?' }); if (amt > a.reel) return reply({ err: 'Not enough $REEL.' }); if (!limit(c, 'wd', 10000)) return reply({ err: 'Slow down.' });
          a.reel -= amt; const w = { id: crypto.randomUUID(), wallet: a.wallet, amount: amt, at: Date.now(), status: 'queued' }; st.withdrawals.push(w); audit('withdraw', a.wallet, -amt, { id: w.id }); save(); return reply({ ok: true, acct: acctMsg(a.wallet) }); }
      }
    } catch (e) { console.error('msg', m && m.t, e); reply({ err: 'Server error.' }); }
  });
  ws.on('close', () => clients.delete(ws));
});
setInterval(() => { const peers = {}; for (const c of clients.values()) if (c.p) peers[c.key] = c.p; const s = JSON.stringify({ t: 'peers', peers }); for (const ws of clients.keys()) if (ws.readyState === 1) ws.send(s.slice(0, -1) + `,"you":"${clients.get(ws).key}"}`); }, 120);
setInterval(() => { for (const [ws, c] of clients) { if (!c.alive) { ws.terminate(); clients.delete(ws); continue; } c.alive = false; ws.ping(); } }, 15000);
setInterval(() => { const now = Date.now(); for (const [k, v] of pending) if (now - v.at > 300000) pending.delete(k); for (const [w, v] of Object.entries(st.xcodes)) if (now - v.at > 3 * 864e5) delete st.xcodes[w]; }, 60000);

rollDay();
server.listen(PORT, () => console.log(`Gullhaven on http://localhost:${PORT} · FREE PLAY · Shells only`));
