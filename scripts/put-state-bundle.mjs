// scripts/put-state-bundle.mjs
//
// UCC live-feed Phase 2 PR D — PUTs the assembled FT2 state bundle (built by
// scripts/push-state-bundle.py) to a deterministic PUBLIC Vercel Blob that the
// fitme-story control-room reads at request time.
//
// Uses the official @vercel/blob `put()` SDK with the SAME options the
// fitme-story audit-log cron uses (access:public, addRandomSuffix:false,
// allowOverwrite:true) so the URL is stable and operator-pinnable as
// FT2_STATE_BLOB_URL once.
//
// Token: BLOB_READ_WRITE_TOKEN (FT2 repo secret, set by operator in PR E).
// Skips cleanly with exit 0 when the token is absent, so a fork / unconfigured
// run is a no-op rather than a red workflow.
//
// Usage: node scripts/put-state-bundle.mjs [bundlePath]

import { readFileSync } from 'node:fs';
import { put } from '@vercel/blob';

const bundlePath = process.argv[2] ?? '.build/ft2-state-bundle.json';
const pathname = process.env.FT2_STATE_BLOB_PATH ?? 'control-room/ft2-state-bundle.json';
const token = process.env.BLOB_READ_WRITE_TOKEN;

if (!token) {
  console.log('BLOB_READ_WRITE_TOKEN absent — skipping blob push (no-op).');
  process.exit(0);
}

let body;
try {
  body = readFileSync(bundlePath, 'utf-8');
} catch (err) {
  console.error(`bundle not found at ${bundlePath}: ${err.message}`);
  process.exit(1);
}

const blob = await put(pathname, body, {
  access: 'public',
  addRandomSuffix: false,
  allowOverwrite: true,
  contentType: 'application/json',
  token,
});

console.log(`pushed FT2 state bundle (${(body.length / 1024).toFixed(1)} KB) → ${blob.url}`);
