// Gullhaven shared town: the multiplayer server for the Godot game (godot/scripts/online.gd).
//
// Everyone who connects shares one coast: you see each other walk about, chat (speech
// bubbles and a chat log), and visit each other's huts. Each player keeps their own save on
// their own computer; the server only relays where people are, what they say, and a copy
// of each hut's layout so friends can visit. No accounts, no money, no tokens.
//
// Run:  cd mp-server && npm install && npm start     (PORT, default 8787; DATA_FILE for huts)
// Health check: GET / returns {"ok":true,"players":N}.
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

let huts = {};
try { huts = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')) || {}; } catch (e) { huts = {}; }
let hutsDirty = false;
function saveHuts() {
  if (!hutsDirty) return;
  hutsDirty = false;
  fs.writeFile(DATA_FILE, JSON.stringify(huts), () => {});
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
  return { id: p.id, name: p.name, look: p.look, x: p.x, y: p.y, z: p.z, fx: p.fx, fz: p.fz, a: p.a, in: p.in };
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': '*' });
  res.end(JSON.stringify({ ok: true, game: 'gullhaven', players: players.size, protocol: PROTOCOL }));
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
      send(ws, { t: 'welcome', id: me.id, name: me.name, protocol: PROTOCOL,
        players: [...players.values()].filter((p) => p !== me).map(info) });
      broadcast({ t: 'join', ...info(me) }, ws);
      broadcast({ t: 'sys', text: me.name + ' arrived in Gullhaven.' }, ws);
      return;
    }
    switch (msg.t) {
      case 'pos':
        me.x = num(msg.x, -50, 1400); me.y = num(msg.y, -50, 400); me.z = num(msg.z, -50, 1200);
        me.fx = num(msg.fx, -1, 1); me.fz = num(msg.fz, -1, 1); me.a = Math.round(num(msg.a, 0, 4));
        me.in = typeof msg.in === 'string' ? msg.in.slice(0, 40) : '';
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
      moved.push([p.id, +p.x.toFixed(2), +p.y.toFixed(2), +p.z.toFixed(2), +p.fx.toFixed(2), +p.fz.toFixed(2), p.a, p.in]);
    }
  }
  if (moved.length) broadcast({ t: 'state', p: moved });
}, TICK_MS);

if (require.main === module) {
  server.listen(PORT, () => console.log('Gullhaven shared town on port ' + PORT));
}

process.on('SIGTERM', () => {
  try { fs.writeFileSync(DATA_FILE, JSON.stringify(huts)); } catch (e) { /* nothing to keep */ }
  process.exit(0);
});

module.exports = { server, wss, clean, cleanHut, cleanLook };
