#!/usr/bin/env node
/**
 * Basic load smoke for capacity notes (few thousand club members).
 * Usage: BASE_URL=http://127.0.0.1:3000/api node scripts/load-smoke.mjs
 *
 * Expected (single t4g.small, warm):
 * - GET /health: >500 rps trivial
 * - POST /auth/login: throttled (~10/min/IP) — do not hammer in prod
 * - Feed list authenticated: tens–low hundreds rps before DB saturates
 * Socket.IO: prefer sticky sessions + Redis adapter beyond ~1–2k concurrent
 */
import http from 'node:http';
import https from 'node:https';

const base = process.env.BASE_URL ?? 'http://127.0.0.1:3000/api';
const url = new URL(`${base}/health`);
const lib = url.protocol === 'https:' ? https : http;
const n = Number(process.env.LOAD_N ?? 50);
let ok = 0;
let fail = 0;
const started = Date.now();

await Promise.all(
  Array.from({ length: n }, () =>
    new Promise((resolve) => {
      const req = lib.get(url, (res) => {
        res.resume();
        if (res.statusCode === 200) ok++;
        else fail++;
        resolve();
      });
      req.on('error', () => {
        fail++;
        resolve();
      });
    }),
  ),
);

console.log(
  JSON.stringify({
    target: url.toString(),
    n,
    ok,
    fail,
    ms: Date.now() - started,
    note: 'Not a substitute for k6 soak tests; use staging.',
  }),
);
