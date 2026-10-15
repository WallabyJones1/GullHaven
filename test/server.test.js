// End-to-end checks for the free harbour, including obsolete token settings.
'use strict';
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const WebSocket = require('ws');
const ROOT = path.resolve(__dirname, '..');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'gullhaven-free-'));
const delay = ms => new Promise(r => setTimeout(r, ms));
async function until(fn, timeout = 4500) {
  const end = Date.now() + timeout;
  do { const v = fn(); if (v) return v; await delay(30); } while (Date.now() < end);
  throw Error('Timed out waiting for shared state');
}
async function start(port, legacy) {
  const child = spawn(process.execPath, ['server.js'], {
    cwd: ROOT, env: { ...process.env, PORT: String(port), DATA_FILE: path.join(TMP, port + '.json'), ADMIN_TOKEN: 'test-admin',
      GH_MODE: legacy ? 'live' : 'play', GH_MINT: legacy ? '11111111111111111111111111111111' : '',
      GH_TREASURY: legacy ? '22222222222222222222222222222222' : '' }, stdio: ['ignore', 'pipe', 'pipe']
  });
  let ready = false, log = '';
  child.stdout.on('data', b => { log += b; if (log.includes('Gullhaven on')) ready = true; });
  child.stderr.on('data', b => { log += b; });
  try { await until(() => { if (child.exitCode != null) throw Error(log); return ready; }); }
  catch (e) { child.kill(); throw e; }
  return child;
}
async function client(port, cid) {
  const ws = new WebSocket('ws://127.0.0.1:' + port + '/ws');
  const c = { ws, messages: [], state: null, welcome: null };
  let seq = 0;
  ws.on('message', raw => { const m = JSON.parse(raw); c.messages.push(m); if (m.t === 'welcome') { c.welcome = m; c.state = m.state; } if (m.t === 'state') c.state = m.state; });
  ws.on('open', () => ws.send(JSON.stringify({ t: 'hello', cid, session: 'retired-session' })));
  c.send = m => ws.send(JSON.stringify(m));
  c.req = async m => { const q = ++seq; c.send({ ...m, q }); return until(() => c.messages.find(m => m.t === 'res' && m.q === q)); };
  await until(() => c.welcome); return c;
}
async function check(port, legacy) {
  const server = await start(port, legacy); const clients = [];
  const get = async (route, opts = {}) => fetch('http://127.0.0.1:' + port + route, opts);
  try {
    const health = await (await get('/health')).json();
    assert.equal(health.live, false); assert.equal(health.mode, 'free'); assert.equal(health.currency, 'Shells'); assert.equal(health.gacha, false);
    assert.equal((await get('/')).status, 200); assert.equal((await get('/favicon.ico')).status, 204);
    for (const route of ['/token', '/deposit', '/withdraw', '/pull', '/swap']) assert.equal((await get(route)).status, 410);
    for (const route of ['/admin/machine/deposit', '/admin/drop/next', '/admin/crew/deposit', '/admin/awards/a/sent', '/admin/withdrawals/a/paid']) {
      const r = await get(route, { method: 'POST', headers: { 'x-admin-token': 'test-admin', 'content-type': 'application/json' }, body: '{"amount":1000}' }); assert.equal(r.status, 410);
    }
    const host = await client(port, 'host'); clients.push(host);
    const guest = await client(port, 'guest'); clients.push(guest);
    assert.equal(host.welcome.live, false); assert.equal(host.welcome.acct, null); assert.equal(host.welcome.mint, ''); assert.equal(host.welcome.rpc, '');
    assert.equal(host.state.machine.enabled, false); assert.deepEqual(host.state.minted, []);
    for (const t of ['nonce', 'auth', 'deposit', 'withdraw', 'pull', 'swap', 'xcode', 'xverify', 'cast', 'land', 'crew', 'crewin', 'cosmetic']) {
      const r = await host.req({ t, amount: 1, tier: 4, wallet: '11111111111111111111111111111111' }); assert.equal(r.code, 'FREE_PLAY_ONLY', t);
    }
    host.send({ t: 'p', p: { x: 3500, y: 2300, d: 'up', n: 'HostFisher', id: 12345678, sc: 'in:home:hfriend123456', ht: 'hfriend123456',
      home: { theme: 'woodland', decor: ['plant', 'books', 'unknown', 'plant'] },
      look: { base: 17, skin: '#f8dcc0', hs: 2, hair: '#3d3048', eyes: 1, mouth: 0, shirt: '#e9675a', pants: '#3d4a78', pat: 2, acc: 1 },
      b: { k: 'dinghy', h: 3, p: '#5fae6a', de: 'flowers', n: 'Sea Fern' }, f: 1 } });
    const peer = await until(() => guest.messages.filter(m => m.t === 'peers').reverse().flatMap(m => Object.values(m.peers)).find(p => p.n === 'HostFisher'));
    assert.equal(peer.x, 3500); assert.equal(peer.id, 12345678); assert.equal(peer.sc, 'in:home:hfriend123456');
    assert.deepEqual(peer.home, { theme: 'woodland', decor: ['plant', 'books'] }); assert.equal(peer.ht, 'hfriend123456');
    assert.equal(peer.look.base, 17); assert.equal(peer.b.de, 'flowers'); assert.equal(peer.b.n, 'Sea Fern'); assert.equal(peer.f, 1);
    host.send({ t: 'chat', text: 'Meet you at the island!' });
    assert.equal((await until(() => guest.messages.find(m => m.t === 'chat'))).text, 'Meet you at the island!');
    host.send({ t: 'first', id: 'garfish' }); host.send({ t: 'donate', id: 'garfish' }); host.send({ t: 'catch', co: 'brine', id: 'garfish', cm: 30, pts: 12 });
    await until(() => guest.state.firsts.garfish && guest.state.aquarium.garfish && guest.state.coopPts.brine >= 12);
    const entry = await host.req({ t: 'derby' }); assert.equal(entry.ok, true); assert.ok((await host.req({ t: 'derby' })).err);
    await until(() => guest.state.derby.n === 1); assert.equal(guest.state.derby.pot, 500);
    console.log('PASS ' + (legacy ? 'obsolete live token configuration' : 'default free play') + ': disabled economy, presence, homes, looks, boats, chat, records and free derby');
  } finally {
    clients.forEach(c => c.ws.terminate());
    await new Promise(resolve => { if (server.exitCode != null) return resolve(); server.once('exit', resolve); server.kill(); });
  }
}
(async () => {
  try { await check(19331, false); await check(19332, true); console.log('ALL PASSED'); }
  finally { fs.rmSync(TMP, { recursive: true, force: true }); }
})().catch(e => { console.error(e); process.exitCode = 1; });
