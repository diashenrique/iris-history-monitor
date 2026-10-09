// Fails when the JavaScript the first screen loads exceeds the budget (research R11, SC-002).
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { gzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';

const BUDGET = 200 * 1024;
const dir = fileURLToPath(new URL('../../src/web/historymonitor', import.meta.url));
const html = readFileSync(join(dir, 'index.html'), 'utf8');
// The entry script and every module it preloads are what the first screen downloads.
const files = [...html.matchAll(/(?:src|href)="\.\/(assets\/[^"]+\.js)"/g)].map((m) => m[1]);
let total = 0;
for (const f of new Set(files)) {
  const size = gzipSync(readFileSync(join(dir, f))).length;
  total += size;
  console.log(`${f}: ${(size / 1024).toFixed(1)} KB gzipped`);
}
console.log(`first screen JavaScript: ${(total / 1024).toFixed(1)} KB gzipped (budget ${BUDGET / 1024} KB)`);
if (!files.length) {
  console.error('no entry script found in index.html');
  process.exit(1);
}
if (total > BUDGET) process.exit(1);
