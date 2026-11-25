// A friendly test visitor for the shared town: joins, strolls round Gran's garden, waves at
// anyone who arrives, and has a little hut you can visit.
// Run: node bot.js [ws://localhost:8787] [name]
'use strict';
const WebSocket = require('ws');

const url = process.argv[2] || 'ws://localhost:8787';
const name = process.argv[3] || 'Bramble Bot';
const ws = new WebSocket(url);
const centre = { x: 419, y: 1.1, z: 686 };
let t = 0;

ws.on('open', () => {
  ws.send(JSON.stringify({
    t: 'hello', name, x: centre.x, y: centre.y, z: centre.z,
    look: { skin: 'tan', hair: '#2a1a14', style: 'short', hat: 'straw', hatc: '#e0c070', shirt: '#7aa04a', pants: '#5a4a3a' },
    hut: { tier: 2, style: { wall: 'wall_paper_green', floor: 'wood' }, furniture: [
      { id: 'rocking_chair', x: 1.2, z: 0.2, rot: 0 }, { id: 'planter', x: -1.0, z: 1.2, rot: 0 },
      { id: 'antler_mount', side: 'back', along: -1.2 }, { id: 'rug_hide', x: 0.0, z: 0.8, rot: 0 }] },
  }));
  setInterval(() => {
    t += 0.1;
    const x = centre.x + Math.cos(t * 0.4) * 3;
    const z = centre.z + Math.sin(t * 0.4) * 3;
    ws.send(JSON.stringify({ t: 'pos', x, y: centre.y, z, fx: -Math.sin(t * 0.4), fz: Math.cos(t * 0.4), a: 1, in: '' }));
  }, 100);
});

ws.on('message', (raw) => {
  const m = JSON.parse(String(raw));
  if (m.t === 'join') setTimeout(() => ws.send(JSON.stringify({ t: 'chat', text: 'Welcome to Gullhaven, ' + m.name + '!' })), 500);
  if (m.t === 'chat' && m.name !== name) console.log('chat:', m.name + ':', m.text);
  if (m.t === 'sys') console.log('sys:', m.text);
});
ws.on('close', () => process.exit(0));
ws.on('error', (e) => { console.error('bot:', e.message); process.exit(1); });
