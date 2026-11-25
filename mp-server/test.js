// Two players join, see each other move, chat, and one visits the other's hut.
'use strict';
const assert = require('assert');
const os = require('os');
const path = require('path');
process.env.DATA_FILE = path.join(os.tmpdir(), 'gullhaven-huts-test.json');
const WebSocket = require('ws');
const { server, clean } = require('./server');

function client(port) {
  const ws = new WebSocket('ws://127.0.0.1:' + port);
  const inbox = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const m = JSON.parse(String(raw));
    inbox.push(m);
    for (const w of waiters.slice()) if (w.test(m)) { waiters.splice(waiters.indexOf(w), 1); w.resolve(m); }
  });
  ws.wait = (test) => new Promise((resolve, reject) => {
    const hit = inbox.find(test);
    if (hit) return resolve(hit);
    waiters.push({ test, resolve });
    setTimeout(() => reject(new Error('timed out waiting')), 3000);
  });
  ws.json = (m) => ws.send(JSON.stringify(m));
  return new Promise((r) => ws.on('open', () => r(ws)));
}

(async () => {
  await new Promise((r) => server.listen(0, r));
  const port = server.address().port;
  const a = await client(port);
  a.json({ t: 'hello', name: 'Wren', look: { skin: 'tan', hat: 'beanie', bad: { x: 1 } }, x: 420, y: 1, z: 676,
    hut: { tier: 2, style: { wall: 'wall_stone' }, furniture: [{ id: 'table', x: 1, z: 0, rot: 1 }, { id: '../hack' }] } });
  const wa = await a.wait((m) => m.t === 'welcome');
  assert.strictEqual(wa.players.length, 0);
  const b = await client(port);
  b.json({ t: 'hello', name: 'Wren', look: {}, x: 430, y: 1, z: 680 });
  const wb = await b.wait((m) => m.t === 'welcome');
  assert.strictEqual(wb.name, 'Wren 2', 'names are made unique');
  assert.strictEqual(wb.players.length, 1);
  assert.strictEqual(wb.players[0].look.bad, undefined, 'unknown look keys are dropped');
  await a.wait((m) => m.t === 'join' && m.name === 'Wren 2');
  b.json({ t: 'pos', x: 431, y: 1, z: 681, fx: 1, fz: 0, a: 1, in: '' });
  const st = await a.wait((m) => m.t === 'state');
  assert.deepStrictEqual(st.p[0].slice(0, 4), [wb.id, 431, 1, 681]);
  b.json({ t: 'chat', text: 'hello there, shit fish' });
  const ch = await a.wait((m) => m.t === 'chat');
  assert.strictEqual(ch.text, 'hello there, **** fish');
  b.json({ t: 'chat', text: 'too soon' });  // rate limited: dropped
  b.json({ t: 'visit', id: wa.id });
  const hut = await b.wait((m) => m.t === 'hut');
  assert.strictEqual(hut.owner, 'Wren');
  assert.strictEqual(hut.data.tier, 2);
  assert.strictEqual(hut.data.furniture.length, 1, 'bad furniture ids are dropped');
  await a.wait((m) => m.t === 'sys' && /visiting your hut/.test(m.text));
  b.close();
  await a.wait((m) => m.t === 'leave' && m.id === wb.id);
  assert.strictEqual(clean('a\u0000b', 10), 'ab');
  a.close();
  server.close();
  console.log('mp-server: all checks passed');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
