// Gullhaven shared town: the multiplayer server for the Godot game (godot/scripts/online.gd).
//
// Everyone who connects shares one coast: you see each other walk about, chat (speech
// bubbles and a chat log), and visit each other's huts. Each player keeps their own save on
// their own computer; the server only relays where people are, what they say, and a copy
// of each hut's layout so friends can visit. No accounts, no money, no tokens.
//
// Run:  cd mp-server && npm install && npm start     (PORT, default 8787; DATA_FILE for huts)
// Health check: GET /health. Status: GET /status returns {"ok":true,"players":N}.
// If a public/ folder sits next to this file (the web build of the game, put there by CI),
// the server also serves the game itself, and tells the page to join this same server.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = +(process.env.PORT || 8787);
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'huts.json');
const MAX_PLAYERS = +(process.env.MAX_PLAYERS || 60);
const TICK_MS = 100; // positions go out ten times a second
const CHAT_GAP_MS = 800;
const CHAT_MAX = 140;
const NAME_MAX = 16;
const HUT_MAX_BYTES = 24000;
const PROTOCOL = 1;
// A small list of words that get starred out in chat and names. Keep it short and obvious.
const BLOCKED = ['fuck', 'shit', 'cunt', 'bitch', 'nigger', 'faggot', 'retard', 'whore', 'slut'];

// What's kept between restarts: huts (by player name) and plots on Driftwood Lane (by slot).
let huts = {};
let plots = {};  // slot -> {owner, data}
const PLOT_SLOTS = 12;
try {
  const saved = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')) || {};
  if (saved.huts || saved.plots) { huts = saved.huts || {}; plots = saved.plots || {}; } else { huts = saved; }
} catch (e) { huts = {}; }
let hutsDirty = false;
function snapshot() { return JSON.stringify({ huts, plots }); }
function saveHuts() {
  if (!hutsDirty) return;
  hutsDirty = false;
  fs.writeFile(DATA_FILE, snapshot(), () => {});
}
setInterval(saveHuts, 10000);

function clean(text, max) {
  let s = String(text == null ? '' : text).replace(/[\u0000-\u001f\u007f\u200b-\u200f\u2028-\u202e]/g, '').trim();
  if (s.length > max) s = s.slice(0, max);
  for (const w of BLOCKED) {
    const re = new RegExp(w.split('').join('[\\W_]*'), 'gi');
    s = s.replace(re, (m) => '*'.repeat(m.length));
  }
  return s;
}

function num(v, lo, hi) {
  const n = Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(lo, Math.min(hi, n));
}

// Only the parts of a look the game knows about, as short strings or booleans.
function cleanLook(look) {
  const out = {};
  if (!look || typeof look !== 'object') return out;
  const keys = ['skin', 'hair', 'style', 'beard', 'glasses', 'hat', 'hatc', 'shirt', 'pattern', 'patc', 'top', 'garment', 'legs', 'pants', 'shoes'];
  for (const k of keys) {
    const v = look[k];
    if (typeof v === 'boolean') out[k] = v;
    else if (typeof v === 'string' && v.length <= 24 && /^[#a-zA-Z0-9_ -]*$/.test(v)) out[k] = v;
  }
  return out;
}

function cleanHut(data) {
  if (!data || typeof data !== 'object') return null;
  const out = { tier: Math.round(num(data.tier, 0, 3)), style: {}, furniture: [] };
  if (data.style && typeof data.style === 'object') {
    for (const k of ['wall', 'floor']) {
      const v = data.style[k];
      if (typeof v === 'string' && /^[a-z_]{1,24}$/.test(v)) out.style[k] = v;
    }
  }
  if (Array.isArray(data.furniture)) {
    for (const it of data.furniture.slice(0, 80)) {
      if (!it || typeof it !== 'object' || typeof it.id !== 'string' || !/^[a-z_@0-9]{1,32}$/.test(it.id)) continue;
      const f = { id: it.id };
      if (typeof it.side === 'string' && /^(back|left|right)$/.test(it.side)) {
        f.side = it.side;
        f.along = num(it.along, -10, 10);
      } else {
        f.x = num(it.x, -10, 10);
        f.z = num(it.z, -10, 10);
        f.rot = Math.round(num(it.rot, 0, 3));
      }
      out.furniture.push(f);
    }
  }
  if (JSON.stringify(out).length > HUT_MAX_BYTES) return null;
  return out;
}

const WORD = /^[#a-z0-9_]{1,24}$/;
const TEX = /^[a-z0-9_\/]{1,48}$/;

function cleanFurniture(list, max) {
  const out = [];
  if (!Array.isArray(list)) return out;
  for (const it of list.slice(0, max)) {
    if (!it || typeof it !== 'object' || typeof it.id !== 'string' || !/^[a-z_@0-9]{1,40}$/.test(it.id)) continue;
    const f = { id: it.id };
    if (typeof it.side === 'string' && /^(back|left|right)$/.test(it.side)) {
      f.side = it.side; f.along = num(it.along, -10, 10);
    } else {
      f.x = num(it.x, -10, 10); f.z = num(it.z, -10, 10); f.rot = Math.round(num(it.rot, 0, 3));
    }
    out.push(f);
  }
  return out;
}

// A plot: its slot, the house outside, the fence, garden things (veg patches with their
// crops) and the inside of the home.
function cleanPlot(data) {
  if (!data || typeof data !== 'object') return null;
  const slot = Math.round(num(data.slot, -1, PLOT_SLOTS - 1));
  if (slot < 0) return null;
  const out = { slot, house: {}, fence: 'none', items: [], home: {} };
  const h = data.house && typeof data.house === 'object' ? data.house : {};
  out.house.size = Math.round(num(h.size, 0, 2));
  for (const k of ['wall', 'tint', 'roof', 'rtint', 'door', 'trim']) if (typeof h[k] === 'string' && WORD.test(h[k])) out.house[k] = h[k];
  for (const k of ['chimney', 'boxes']) if (typeof h[k] === 'boolean') out.house[k] = h[k];
  if (typeof data.fence === 'string' && WORD.test(data.fence)) out.fence = data.fence;
  if (Array.isArray(data.items)) {
    for (const it of data.items.slice(0, 60)) {
      if (!it || typeof it.id !== 'string' || !/^[a-z_]{1,24}$/.test(it.id)) continue;
      const o = { id: it.id, x: num(it.x, 0, 20), z: num(it.z, 0, 20) };
      if (typeof it.s === 'string' && /^(wild|tilled|crop)$/.test(it.s)) o.s = it.s;
      if (typeof it.crop === 'string' && /^[a-z]{1,16}$/.test(it.crop)) o.crop = it.crop;
      if (it.grow != null) o.grow = num(it.grow, 0, 100000);
      if (it.wet != null) o.wet = num(it.wet, 0, 1e12);
      out.items.push(o);
    }
  }
  const home = data.home && typeof data.home === 'object' ? data.home : {};
  if (typeof home.wall === 'string' && TEX.test(home.wall)) out.home.wall = home.wall;
  if (typeof home.floor === 'string' && TEX.test(home.floor)) out.home.floor = home.floor;
  out.home.furniture = cleanFurniture(home.furniture, 120);
  if (JSON.stringify(out).length > 40000) return null;
  return out;
}

// Put a player's plot in its slot (or tell them it's taken). Returns true if it changed.
function setPlot(p, data) {
  const plot = cleanPlot(data);
  if (!plot) return false;
  const have = plots[plot.slot];
  if (have && have.owner.toLowerCase() !== p.name.toLowerCase()) return false;
  for (const k of Object.keys(plots)) {  // one plot each
    if (+k !== plot.slot && plots[k].owner.toLowerCase() === p.name.toLowerCase()) delete plots[k];
  }
  plots[plot.slot] = { owner: p.name, data: plot };
  hutsDirty = true;
  return true;
}

const players = new Map(); // id -> {ws, id, name, look, x, y, z, fx, fz, a, in, lastChat}
let nextId = 1;

function send(ws, msg) {
  if (ws.readyState === 1) ws.send(JSON.stringify(msg));
}

function broadcast(msg, except) {
  const s = JSON.stringify(msg);
  for (const p of players.values()) {
    if (p.ws !== except && p.ws.readyState === 1) p.ws.send(s);
  }
}

function uniqueName(want) {
  let base = clean(want, NAME_MAX).replace(/\*/g, '') || 'Fisher';
  if (base.length < 2) base = 'Fisher ' + base;
  let name = base;
  let n = 2;
  const taken = new Set([...players.values()].map((p) => p.name.toLowerCase()));
  while (taken.has(name.toLowerCase())) name = (base.slice(0, NAME_MAX - 3) + ' ' + n++);
  return name;
}

function info(p) {
  return { id: p.id, name: p.name, look: p.look, x: p.x, y: p.y, z: p.z, fx: p.fx, fz: p.fz, a: p.a, in: p.in, b: p.b || '', h: p.h || 0 };
}

const PUBLIC = process.env.PUBLIC_DIR || path.join(__dirname, 'public');
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.ico': 'image/x-icon', '.svg': 'image/svg+xml',
  '.json': 'application/json', '.css': 'text/css', '.txt': 'text/plain; charset=utf-8', '.webmanifest': 'application/manifest+json' };
// The page learns where to connect before the game starts (same host, ws or wss).
const INJECT = '<script>window.GULLHAVEN_SERVER=(location.protocol==="https:"?"wss://":"ws://")+location.host;</script>' +
  '<style>#gh-rotate{display:none}@media (orientation:portrait) and (max-width:900px){#gh-rotate{display:flex;position:fixed;' +
  'inset:0;z-index:99;background:#0b1020;color:#f8f0dc;font:600 22px sans-serif;align-items:center;justify-content:center;' +
  'text-align:center;padding:32px}}</style>';
const ROTATE = '<div id="gh-rotate">Turn your phone sideways to play Gullhaven</div>';

function serveFile(req, res) {
  let rel = decodeURIComponent(String(req.url || '/').split('?')[0]);
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = path.normalize(path.join(PUBLIC, rel));
  if (!file.startsWith(PUBLIC + path.sep) || /\/(ci|node_modules)\//.test(rel)) {
    res.writeHead(404); res.end('Not found'); return;
  }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(file).toLowerCase();
    const headers = { 'content-type': MIME[ext] || 'application/octet-stream', 'cache-control': 'no-cache',
      'cross-origin-opener-policy': 'same-origin', 'cross-origin-embedder-policy': 'require-corp' };
    if (ext === '.html') {
      fs.readFile(file, 'utf8', (e, html) => {
        if (e) { res.writeHead(500); res.end(); return; }
        res.writeHead(200, headers);
        res.end(html.replace('<head>', '<head>' + INJECT).replace(/<body([^>]*)>/, '<body$1>' + ROTATE));
      });
      return;
    }
    const gz = file + '.gz';
    const wantsGz = /\bgzip\b/.test(String(req.headers['accept-encoding'] || ''));
    if (wantsGz && fs.existsSync(gz)) {
      headers['content-encoding'] = 'gzip';
      headers['content-length'] = fs.statSync(gz).size;
      res.writeHead(200, headers);
      fs.createReadStream(gz).pipe(res);
      return;
    }
    headers['content-length'] = st.size;
    res.writeHead(200, headers);
    fs.createReadStream(file).pipe(res);
  });
}

const server = http.createServer((req, res) => {
  const url = String(req.url || '/');
  if (url === '/health') { res.writeHead(200, { 'content-type': 'text/plain' }); res.end('ok'); return; }
  if (url.startsWith('/status') || !fs.existsSync(path.join(PUBLIC, 'index.html'))) {
    res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': '*' });
    res.end(JSON.stringify({ ok: true, game: 'gullhaven', players: players.size, protocol: PROTOCOL }));
    return;
  }
  serveFile(req, res);
});

const wss = new WebSocketServer({ server, maxPayload: 64 * 1024 });

wss.on('connection', (ws) => {
  let me = null;
  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(String(raw)); } catch (e) { return; }
    if (!msg || typeof msg.t !== 'string') return;
    if (!me) {
      if (msg.t !== 'hello') return;
      if (players.size >= MAX_PLAYERS) {
        send(ws, { t: 'full', text: 'The town is full right now. Try again soon.' });
        ws.close();
        return;
      }
      me = { ws, id: nextId++, name: uniqueName(msg.name), look: cleanLook(msg.look), x: num(msg.x, -50, 1400),
        y: num(msg.y, -50, 400), z: num(msg.z, -50, 1200), fx: 0, fz: 1, a: 0, in: '', lastChat: 0 };
      const hut = cleanHut(msg.hut);
      if (hut) { huts[me.name.toLowerCase()] = { owner: me.name, data: hut }; hutsDirty = true; }
      players.set(me.id, me);
      const plotChanged = msg.plot ? setPlot(me, msg.plot) : false;
      send(ws, { t: 'welcome', id: me.id, name: me.name, protocol: PROTOCOL,
        players: [...players.values()].filter((p) => p !== me).map(info), plots });
      if (plotChanged) broadcast({ t: 'plots', plots }, ws);
      broadcast({ t: 'join', ...info(me) }, ws);
      broadcast({ t: 'sys', text: me.name + ' arrived in Gullhaven.' }, ws);
      return;
    }
    switch (msg.t) {
      case 'pos':
        me.x = num(msg.x, -50, 1400); me.y = num(msg.y, -50, 400); me.z = num(msg.z, -50, 1200);
        me.fx = num(msg.fx, -1, 1); me.fz = num(msg.fz, -1, 1); me.a = Math.round(num(msg.a, 0, 4));
        me.in = typeof msg.in === 'string' ? msg.in.slice(0, 40) : '';
        me.b = typeof msg.b === 'string' && /^[a-z_]{0,16}$/.test(msg.b) ? msg.b : '';
        me.h = num(msg.h, -10, 10);
        me.dirty = true;
        break;
      case 'chat': {
        const now = Date.now();
        if (now - me.lastChat < CHAT_GAP_MS) return;
        const text = clean(msg.text, CHAT_MAX);
        if (!text) return;
        me.lastChat = now;
        broadcast({ t: 'chat', id: me.id, name: me.name, text });
        break;
      }
      case 'look':
        me.look = cleanLook(msg.look);
        broadcast({ t: 'look', id: me.id, look: me.look }, ws);
        break;
      case 'hut': {
        const hut = cleanHut(msg.data);
        if (hut) { huts[me.name.toLowerCase()] = { owner: me.name, data: hut }; hutsDirty = true; }
        break;
      }
      case 'plot':
        if (setPlot(me, msg.data)) broadcast({ t: 'plots', plots });
        else send(ws, { t: 'plots', plots });
        break;
      case 'visit': {
        let rec = null;
        const target = players.get(Number(msg.id));
        if (target) rec = huts[target.name.toLowerCase()];
        else if (typeof msg.name === 'string') rec = huts[msg.name.toLowerCase()];
        if (rec) send(ws, { t: 'hut', owner: rec.owner, data: rec.data });
        else send(ws, { t: 'sys', text: "That hut's door is locked (nobody's home)." });
        if (target && target !== me) send(target.ws, { t: 'sys', text: me.name + ' is visiting your hut.' });
        break;
      }
      case 'brag': {
        const now = Date.now();
        if (now - (me.lastBrag || 0) < 5000) return;
        me.lastBrag = now;
        const text = clean(msg.text, 80);
        if (text) broadcast({ t: 'sys', text: me.name + ' ' + text });
        break;
      }
      case 'emote':
        broadcast({ t: 'emote', id: me.id, e: String(msg.e || '').slice(0, 12) }, ws);
        break;
      default:
        break;
    }
  });
  ws.on('close', () => {
    if (!me) return;
    players.delete(me.id);
    broadcast({ t: 'leave', id: me.id });
    broadcast({ t: 'sys', text: me.name + ' headed home.' });
  });
  ws.on('error', () => {});
});

// Positions out ten times a second: only the players who moved.
setInterval(() => {
  const moved = [];
  for (const p of players.values()) {
    if (p.dirty) {
      p.dirty = false;
      moved.push([p.id, +p.x.toFixed(2), +p.y.toFixed(2), +p.z.toFixed(2), +p.fx.toFixed(2), +p.fz.toFixed(2), p.a, p.in, p.b || '', +(p.h || 0).toFixed(2)]);
    }
  }
  if (moved.length) broadcast({ t: 'state', p: moved });
}, TICK_MS);

if (require.main === module) {
  server.listen(PORT, () => console.log('Gullhaven shared town on port ' + PORT));
}

process.on('SIGTERM', () => {
  try { fs.writeFileSync(DATA_FILE, snapshot()); } catch (e) { /* nothing to keep */ }
  process.exit(0);
});

module.exports = { server, wss, clean, cleanHut, cleanLook };
