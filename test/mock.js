// Test preload: stands in for X's oEmbed endpoint and the Solana RPC so server.js can be tested offline.
'use strict';
const fs = require('fs');
const CODE_FILE = process.env.MOCK_CODE_FILE;
const realFetch = global.fetch;
global.fetch = async (url, opts) => {
  const u = String(url);
  if (u.startsWith('https://publish.twitter.com/oembed')) {
    const target = decodeURIComponent(u.split('url=')[1] || '');
    const m = /twitter\.com\/([A-Za-z0-9_]+)\/status\/(\d+)/.exec(target);
    if (!m || m[2] === '404404404') return { ok: false, json: async () => ({}) };
    const code = CODE_FILE && fs.existsSync(CODE_FILE) ? fs.readFileSync(CODE_FILE, 'utf8').trim() : '';
    return { ok: true, json: async () => ({ author_name: m[1], author_url: 'https://twitter.com/' + m[1], html: `<blockquote class="twitter-tweet"><p>Claiming my Gullhaven fishing licence ${code} #Gullhaven</p></blockquote>` }) };
  }
  if (opts && opts.method === 'POST' && /solana|rpc|localhost:8899/.test(u)) {
    const body = JSON.parse(opts.body); const [sig] = body.params; const w = process.env.MOCK_WALLET; const mint = process.env.GH_MINT, tr = process.env.GH_TREASURY;
    const amt = sig.startsWith('5bad') ? 0 : 1000000 * 1e6;
    const bal = (owner, n) => ({ mint, owner, uiTokenAmount: { amount: String(n) } });
    return { json: async () => ({ result: { meta: { err: null, preTokenBalances: [bal(w, 5e12), bal(tr, 0)], postTokenBalances: [bal(w, 5e12 - amt), bal(tr, amt)] } } }) };
  }
  return realFetch(url, opts);
};
