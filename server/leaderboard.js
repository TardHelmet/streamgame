#!/usr/bin/env node
/*
  Starflappy 64 — tiny self-hosted leaderboard.
  Zero dependencies. Keeps one best entry per player id (with its ghost
  trace) in a JSON file and serves the top list.

    node server/leaderboard.js            # http://localhost:8787
    PORT=9000 DATA=/var/sf64.json node server/leaderboard.js

  Point the game at it with either
    <meta name="sf-leaderboard" content="https://your-host.example">
  in index.html, or window.SF_LEADERBOARD_URL = "..." before the game script.

  Endpoints
    GET  /health          → {ok:true, players:N}
    GET  /top?n=50        → [entry, …] sorted by score desc, dist desc
    POST /submit          → entry JSON {id,name,score,dist,rings,fish,ts,trace}
*/
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = +process.env.PORT || 8787;
const DATA = process.env.DATA || path.join(__dirname, 'data.json');
const MAX_ENTRIES = 500;
const MAX_TRACE = 64 * 1024;

let board = {};
try { board = JSON.parse(fs.readFileSync(DATA, 'utf8')); } catch (e) { board = {}; }
let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    fs.writeFile(DATA, JSON.stringify(board), () => {});
  }, 250);
}
function sorted() {
  return Object.values(board).sort((a, b) => (b.score - a.score) || (b.dist - a.dist) || (a.ts - b.ts));
}
function clean(e) {
  if (!e || typeof e !== 'object') return null;
  const id = String(e.id || '').slice(0, 64);
  if (!id) return null;
  const num = (v, max) => Math.max(0, Math.min(max, Math.floor(+v || 0)));
  const name = String(e.name || 'GANNET').replace(/[^\w \-'.]/g, '').trim().slice(0, 14) || 'GANNET';
  const trace = typeof e.trace === 'string' && e.trace.length <= MAX_TRACE ? e.trace : '';
  return { id, name, score: num(e.score, 1e7), dist: num(e.dist, 1e6), rings: num(e.rings, 1e5),
           fish: num(e.fish, 1e5), ts: Date.now(), trace, ver: 1 };
}
function send(res, code, body) {
  res.writeHead(code, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (req.method === 'OPTIONS') return send(res, 204, {});
  if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, { ok: true, players: Object.keys(board).length });
  if (req.method === 'GET' && url.pathname === '/top') {
    const n = Math.max(1, Math.min(200, +url.searchParams.get('n') || 50));
    return send(res, 200, sorted().slice(0, n));
  }
  if (req.method === 'POST' && url.pathname === '/submit') {
    let raw = '';
    req.on('data', c => { raw += c; if (raw.length > 256 * 1024) req.destroy(); });
    req.on('end', () => {
      let entry;
      try { entry = clean(JSON.parse(raw)); } catch (e) { entry = null; }
      if (!entry) return send(res, 400, { error: 'bad entry' });
      const old = board[entry.id];
      if (!old || entry.score > old.score || (entry.score === old.score && entry.dist > old.dist)) {
        board[entry.id] = entry;
        const list = sorted();
        if (list.length > MAX_ENTRIES) for (const e of list.slice(MAX_ENTRIES)) delete board[e.id];
        save();
      }
      const rank = sorted().findIndex(e => e.id === entry.id) + 1;
      return send(res, 200, { ok: true, rank });
    });
    return;
  }
  send(res, 404, { error: 'not found' });
}).listen(PORT, () => console.log(`Starflappy 64 leaderboard on http://localhost:${PORT} (${Object.keys(board).length} players)`));
